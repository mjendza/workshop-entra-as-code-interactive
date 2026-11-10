<#
.SYNOPSIS
    Flags service principals in the tenant whose application id appears on the OAuthSentry
    risky / malicious OAuth application threat-intelligence feed.
.DESCRIPTION
    OAuthSentry (https://github.com/OAuthSentry/oauthsentry.github.io) publishes a curated
    inventory of OAuth application ids seen in attacker tradecraft, split into three buckets:

      compliance   legitimate first-party or vetted third-party apps
      risky        legitimate apps frequently abused (mailbox sync, bulk mail, storage sync)
      malicious    confirmed in-the-wild consent-phishing / AiTM / impersonation apps

    This test downloads the per-service CSV feeds for the "risky" and "malicious" categories
    from the remote site, enumerates every service principal in the tenant via Microsoft
    Graph, and reports any service principal whose appId is on the feed. A match on
    "malicious" is a confirmed-bad application and should be treated as an active incident;
    a match on "risky" is an abused-but-legitimate client to confirm and justify.

    Scope is driven entirely by GlobalSettings.RiskyMaliciousServicePrincipals in
    ./Custom/maester-config.json so it can be tuned without editing this file:

      FeedBaseUri                 root of the OAuthSentry feed tree
      Service                     feed service slug (entra, google, github)
      IncludeCategories           which feed buckets to load and match on
      IncludeSeverities           feed metadata_severity values to keep (drops info/low noise)
      ExcludeAppIds               per-tenant allowlist applied after triage
      ExcludeMicrosoftFirstParty  drop matches whose SP is owned by a Microsoft tenant

    $env:MAESTER_OAUTHSENTRY_FEED_URI overrides FeedBaseUri so an offline mirror can be used.

    The test never fails for infrastructure reasons. It returns $null (and records a Skipped
    result) when Graph is not connected or the remote feed cannot be reached - a missing
    verdict is better than a false one. It returns $false only when a real match is found,
    so the finding surfaces as a failed test with the matching service principals listed.
.EXAMPLE
    Test-MtRiskyMaliciousServicePrincipals
    Returns $true when no service principal matches, $false with a table of matches otherwise.
.EXAMPLE
    $env:MAESTER_OAUTHSENTRY_FEED_URI = 'https://intel.contoso.example/oauthsentry/feeds'
    Invoke-Maester -Path ./Custom -Tag 'CTS.1023'
    Runs the test against an internal mirror of the feed.
#>

<#
.SYNOPSIS
    Returns the effective configuration for the risky / malicious service principal test.
.DESCRIPTION
    Built-in defaults are overlaid with GlobalSettings.RiskyMaliciousServicePrincipals from
    ./Custom/maester-config.json, and $env:MAESTER_OAUTHSENTRY_FEED_URI then overrides the
    feed base uri. Any key missing from the config file keeps its default, so an empty
    GlobalSettings object still produces a usable configuration.
#>
function Get-MtRiskyMaliciousSpConfiguration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string] $ConfigurationPath = (Join-Path $PSScriptRoot '..' 'maester-config.json')
    )

    $configuration = [PSCustomObject]@{
        FeedBaseUri                = 'https://oauthsentry.github.io/feeds'
        Service                    = 'entra'
        IncludeCategories          = @('malicious', 'risky')
        IncludeSeverities          = @('critical', 'high', 'medium')
        ExcludeAppIds              = @()
        ExcludeMicrosoftFirstParty = $true
    }

    if (Test-Path -Path $ConfigurationPath) {
        try {
            $settings = (Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json).GlobalSettings.RiskyMaliciousServicePrincipals

            if ($settings) {
                foreach ($property in $configuration.PSObject.Properties.Name) {
                    $setting = $settings.PSObject.Properties[$property]
                    if ($null -eq $setting -or $null -eq $setting.Value) { continue }

                    # An empty string counts as "not set" so the committed default survives.
                    # An empty *array* is deliberate - "apply no filter on this dimension".
                    if ($setting.Value -isnot [array] -and "$($setting.Value)" -eq '') { continue }

                    $configuration.$property = $setting.Value
                }
            }
        } catch {
            Write-Verbose "Could not read RiskyMaliciousServicePrincipals settings from $ConfigurationPath : $($_.Exception.Message)"
        }
    }

    if ($env:MAESTER_OAUTHSENTRY_FEED_URI) {
        $configuration.FeedBaseUri = $env:MAESTER_OAUTHSENTRY_FEED_URI
    }

    # Normalise so callers can compare and index unconditionally.
    $configuration.FeedBaseUri = "$($configuration.FeedBaseUri)".TrimEnd('/')
    $configuration.Service = "$($configuration.Service)".Trim().ToLowerInvariant()
    $configuration.IncludeCategories = @(@($configuration.IncludeCategories) | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ })
    $configuration.IncludeSeverities = @(@($configuration.IncludeSeverities) | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ })
    $configuration.ExcludeAppIds = @(@($configuration.ExcludeAppIds) | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ })
    $configuration.ExcludeMicrosoftFirstParty = [bool]$configuration.ExcludeMicrosoftFirstParty

    return $configuration
}

<#
.SYNOPSIS
    Downloads and parses the OAuthSentry CSV feed(s) for the given service and categories.
.DESCRIPTION
    One request per category against {FeedBaseUri}/{service}/{service}_{category}.csv. The
    body is parsed with ConvertFrom-Csv rather than a manual split because the
    metadata_comment field is quoted and contains commas. Throws on a transport error;
    callers are expected to catch and record a Skipped result.
#>
function Get-MtOAuthSentryFeed {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string] $FeedBaseUri,

        [Parameter(Mandatory)]
        [string] $Service,

        [Parameter(Mandatory)]
        [string[]] $Category
    )

    $records = [System.Collections.Generic.List[object]]::new()

    foreach ($cat in $Category) {
        $uri = "$FeedBaseUri/$Service/${Service}_$cat.csv"
        Write-Verbose "Fetching OAuthSentry feed: $uri"

        $response = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorAction Stop
        $csv = if ($response.Content -is [byte[]]) {
            [System.Text.Encoding]::UTF8.GetString($response.Content)
        } else {
            [string]$response.Content
        }

        foreach ($row in ($csv | ConvertFrom-Csv)) {
            $rowService = "$($row.service)".Trim().ToLowerInvariant()
            if ($rowService -and $rowService -ne $Service.ToLowerInvariant()) { continue }

            $appId = "$($row.appid)".Trim().ToLowerInvariant()
            if (-not $appId) { continue }

            $records.Add([PSCustomObject]@{
                    AppName   = "$($row.appname)".Trim()
                    AppId     = $appId
                    Category  = "$($row.metadata_category)".Trim().ToLowerInvariant()
                    Severity  = "$($row.metadata_severity)".Trim().ToLowerInvariant()
                    Comment   = "$($row.metadata_comment)".Trim()
                    Reference = "$($row.metadata_reference)".Trim()
                })
        }
    }

    # Callers wrap this in @() so empty, single and multi-row results all behave as arrays.
    return $records.ToArray()
}

<#
.SYNOPSIS
    Joins the tenant's service principals against the in-scope feed rows.
.DESCRIPTION
    The feed is filtered to IncludeCategories / IncludeSeverities and turned into a lookup
    keyed on lower-cased appId, then every service principal is walked once. ExcludeAppIds
    and ExcludeMicrosoftFirstParty are applied to each match. The service principal's own
    appOwnerOrganizationId is reported (never matched on) so a human can tell an
    attacker-owned impersonation app from a name collision.
#>
function Get-MtRiskyMaliciousServicePrincipalData {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Feed
    )

    # Both well-known owner tenants used by Microsoft first-party applications.
    $microsoftOwnerOrganizations = @(
        'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
        '72f988bf-86f1-41af-91ab-2d7cd011db47'
    )

    # The two OAuthSentry feeds do not currently share any appId, but the precedence is made
    # explicit rather than left to depend on the order of IncludeCategories in the config:
    # if the same appId ever appears on both feeds, the worse classification is kept.
    $categoryRank = @{ 'malicious' = 0; 'risky' = 1 }

    $feedByAppId = @{}
    foreach ($row in $Feed) {
        if ($Configuration.IncludeCategories.Count -gt 0 -and $row.Category -notin $Configuration.IncludeCategories) { continue }
        if ($Configuration.IncludeSeverities.Count -gt 0 -and $row.Severity -notin $Configuration.IncludeSeverities) { continue }
        if (-not $row.AppId) { continue }

        $existing = $feedByAppId[$row.AppId]
        if ($null -ne $existing) {
            $incomingRank = if ($categoryRank.ContainsKey($row.Category)) { $categoryRank[$row.Category] } else { 9 }
            $existingRank = if ($categoryRank.ContainsKey($existing.Category)) { $categoryRank[$existing.Category] } else { 9 }
            if ($incomingRank -ge $existingRank) { continue }
        }
        $feedByAppId[$row.AppId] = $row
    }

    $servicePrincipals = Invoke-MtGraphRequest -RelativeUri 'servicePrincipals' -ApiVersion v1.0 `
        -Select @('id', 'appId', 'displayName', 'appOwnerOrganizationId', 'accountEnabled',
        'servicePrincipalType', 'createdDateTime')

    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($servicePrincipal in $servicePrincipals) {
        $appId = "$($servicePrincipal.appId)".Trim().ToLowerInvariant()
        if (-not $appId) { continue }

        $match = $feedByAppId[$appId]
        if ($null -eq $match) { continue }

        if ($appId -in $Configuration.ExcludeAppIds) { continue }

        $ownerOrg = "$($servicePrincipal.appOwnerOrganizationId)".Trim().ToLowerInvariant()
        $isMicrosoftFirstParty = $ownerOrg -in $microsoftOwnerOrganizations
        if ($Configuration.ExcludeMicrosoftFirstParty -and $isMicrosoftFirstParty) { continue }

        $createdDateTime = if ($servicePrincipal.createdDateTime) { [datetime]$servicePrincipal.createdDateTime } else { $null }

        $rows.Add([PSCustomObject]@{
                DisplayName            = "$($servicePrincipal.displayName)"
                AppId                  = $appId
                ObjectId               = "$($servicePrincipal.id)"
                FeedAppName            = $match.AppName
                Category               = $match.Category
                Severity               = $match.Severity
                Comment                = $match.Comment
                Reference              = $match.Reference
                AccountEnabled         = $servicePrincipal.accountEnabled
                ServicePrincipalType   = "$($servicePrincipal.servicePrincipalType)"
                AppOwnerOrganizationId = "$($servicePrincipal.appOwnerOrganizationId)"
                CreatedDateTime        = $createdDateTime
                IsMicrosoftFirstParty  = $isMicrosoftFirstParty
            })
    }

    # Callers wrap this in @() so empty, single and multi-row results all behave as arrays.
    return $rows.ToArray()
}

<#
.SYNOPSIS
    Escapes a value so it is safe to place inside a markdown table cell.
#>
function Format-MtRiskyMaliciousSpCell {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or "$Value" -eq '') {
        return '—'
    }

    # Get-MtSafeMarkdown escapes brackets; pipes additionally break table rows, and the
    # feed's reference field uses " | " as its own separator.
    return (Get-MtSafeMarkdown -Text "$Value") -replace '\|', '\|'
}

<#
.SYNOPSIS
    Renders the matched service principals as a markdown table, worst first.
#>
function Get-MtRiskyMaliciousSpTable {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object[]] $Rows
    )

    $severityRank = @{ 'critical' = 0; 'high' = 1; 'medium' = 2; 'low' = 3; 'info' = 4 }

    $table = "| Service principal | App ID | Feed listing | Category | Severity | Enabled | SP owner tenant | Threat intel note | References |`n"
    $table += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |`n"

    # Malicious first, then by feed severity, so the rows that need action are at the top.
    $sorted = $Rows | Sort-Object `
    @{ Expression = { if ($_.Category -eq 'malicious') { 0 } else { 1 } } },
    @{ Expression = { if ($severityRank.ContainsKey([string]$_.Severity)) { $severityRank[[string]$_.Severity] } else { 9 } } },
    DisplayName

    foreach ($row in $sorted) {
        $categoryCell = if ($row.Category -eq 'malicious') { "⚠️ malicious" } else { "risky" }
        $enabledCell = if ($row.AccountEnabled -eq $false) { 'No' } else { 'Yes' }

        $cells = @(
            (Format-MtRiskyMaliciousSpCell $row.DisplayName)
            (Format-MtRiskyMaliciousSpCell $row.AppId)
            (Format-MtRiskyMaliciousSpCell $row.FeedAppName)
            $categoryCell
            (Format-MtRiskyMaliciousSpCell $row.Severity)
            $enabledCell
            (Format-MtRiskyMaliciousSpCell $row.AppOwnerOrganizationId)
            (Format-MtRiskyMaliciousSpCell $row.Comment)
            (Format-MtRiskyMaliciousSpCell $row.Reference)
        )
        $table += "| " + ($cells -join " | ") + " |`n"
    }

    return $table
}

<#
.SYNOPSIS
    Reports service principals matching the OAuthSentry risky / malicious OAuth app feed.
.DESCRIPTION
    Returns $null (Skipped) when Graph is not connected or the feed is unreachable, $true
    when nothing matches, and $false with a table of matches when one or more service
    principals in the tenant are on the feed.
.EXAMPLE
    Test-MtRiskyMaliciousServicePrincipals
#>
function Test-MtRiskyMaliciousServicePrincipals {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $configuration = Get-MtRiskyMaliciousSpConfiguration

    try {
        $feed = @(Get-MtOAuthSentryFeed -FeedBaseUri $configuration.FeedBaseUri -Service $configuration.Service -Category $configuration.IncludeCategories)
    } catch {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Could not download the OAuthSentry OAuth application feed from ``$($configuration.FeedBaseUri)``: $($_.Exception.Message). This test compares the tenant's service principals against a remote threat-intelligence feed — point ``\$env:MAESTER_OAUTHSENTRY_FEED_URI`` at a reachable mirror or restore outbound access to run it."
        return $null
    }

    if ($feed.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "The OAuthSentry feed at ``$($configuration.FeedBaseUri)`` returned no rows for service ``$($configuration.Service)`` and categories $($configuration.IncludeCategories -join ', '). There is nothing to compare the tenant against."
        return $null
    }

    try {
        $rows = @(Get-MtRiskyMaliciousServicePrincipalData -Configuration $configuration -Feed $feed)
    } catch {
        Add-MtTestResultDetail -Result "Failed to compare service principals against the OAuthSentry feed: $($_.Exception.Message)"
        return $null
    }

    $malicious = @($rows | Where-Object { $_.Category -eq 'malicious' })
    $risky = @($rows | Where-Object { $_.Category -eq 'risky' })

    $scopeNote = "_Compared every service principal in the tenant against the OAuthSentry ``$($configuration.Service)`` feed " +
    "(categories: $($configuration.IncludeCategories -join ', '); severities: $($configuration.IncludeSeverities -join ', ')). " +
    $(if ($configuration.ExcludeMicrosoftFirstParty) { 'Microsoft first-party applications are excluded. ' } else { '' }) +
    "Feed source: <https://github.com/OAuthSentry/oauthsentry.github.io>. Scope is set by ``GlobalSettings.RiskyMaliciousServicePrincipals`` in ``./Custom/maester-config.json``._"

    if ($rows.Count -eq 0) {
        Add-MtTestResultDetail -Result "Well done. No service principal in the tenant matches a **risky** or **malicious** OAuth application on the OAuthSentry threat-intelligence feed.`n`n$scopeNote"
        return $true
    }

    $summary = "**$($rows.Count) service principal(s)** in your tenant match a **risky or malicious** OAuth application on the OAuthSentry threat-intelligence feed"
    if ($malicious.Count -gt 0) {
        $summary += " — **$($malicious.Count) malicious**, $($risky.Count) risky.`n`n"
        $summary += "A **malicious** match is a confirmed in-the-wild consent-phishing / AiTM / impersonation application. Treat it as an active incident: review the application's OAuth grants and sign-in activity, revoke user and admin consent, disable the service principal, and check for mailbox rules or data access created through it."
    } else {
        $summary += " — all **risky**.`n`n"
        $summary += "A **risky** match is a legitimate application frequently abused in attacker tradecraft (mailbox synchronisation, bulk mail, cloud-storage sync). Confirm each one was deliberately consented to, is owned by a known team, and is still required — otherwise revoke consent and remove the service principal."
    }

    $md = "$summary`n`n"
    $md += Get-MtRiskyMaliciousSpTable -Rows $rows
    $md += "`n$scopeNote"

    Add-MtTestResultDetail -Result $md -Investigate
    return $false
}

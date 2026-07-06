<#
.SYNOPSIS
    Shared helpers for the External-01 native-authentication E2E tests (sign-up and sign-in).

.DESCRIPTION
    Dot-sourced by External-01.NativeAuth-SignUp.E2E.Tests.ps1 and External-01.NativeAuth-SignIn.E2E.Tests.ps1.
    Pure functions (no Pester dependencies) so both flows share the same HTTP, JWT and OTP-parsing logic.
#>

# Default headers that make requests resemble a browser-based SPA calling the native-auth REST
# endpoints directly (what MSAL.js sends), rather than PowerShell's default "PowerShell/7.x" UA.
# Some fronting infrastructure (WAF/CDN) treats non-browser clients differently, so every
# Invoke-NativeAuth call applies these; -Headers can add to or override them per call.
$script:NativeAuthBrowserHeaders = @{
    'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0'
    'Accept'          = 'application/json, text/plain, */*'
    'Accept-Language' = 'en-US,en;q=0.9'
    'sec-ch-ua'       = '"Chromium";v="126", "Microsoft Edge";v="126", "Not.A/Brand";v="24"'
    'sec-ch-ua-mobile'    = '?0'
    'sec-ch-ua-platform'  = '"Windows"'
    'Sec-Fetch-Site'  = 'same-origin'
    'Sec-Fetch-Mode'  = 'cors'
    'Sec-Fetch-Dest'  = 'empty'
}

# POST an x-www-form-urlencoded request to a Native Auth endpoint. Returns a uniform result object
# @{ Ok; Status; Data; Raw; Uri } so callers can branch on the JSON error body (error / suberror /
# error_description / continuation_token) instead of catching exceptions on documented 4xx responses.
# Uri is always populated (success and failure) so failure messages can show exactly which endpoint
# was called instead of forcing a re-run to find out. Headers simulate a same-origin browser SPA
# call (see $script:NativeAuthBrowserHeaders); pass -Headers to add to/override the defaults.
function Invoke-NativeAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]    $BaseUri,
        [Parameter(Mandatory)][string]    $Path,
        [Parameter(Mandatory)][hashtable] $Form,
        [hashtable]                       $Headers
    )

    $uri    = "$BaseUri/$Path"
    $origin = ([uri]$BaseUri).GetLeftPart([System.UriPartial]::Authority)

    $reqHeaders = @{} + $script:NativeAuthBrowserHeaders
    $reqHeaders['Origin']  = $origin
    $reqHeaders['Referer'] = "$origin/"
    if ($Headers) { foreach ($key in $Headers.Keys) { $reqHeaders[$key] = $Headers[$key] } }

    try {
        $resp = Invoke-RestMethod -Method POST -Uri $uri -Body $Form -Headers $reqHeaders `
            -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
        return [pscustomobject]@{ Ok = $true; Status = 200; Data = $resp; Raw = $null; Uri = $uri }
    } catch {
        $status  = $null
        $bodyTxt = $null
        $webResp = $_.Exception.Response
        # $_.Exception.Response is $null on transport-level failures (DNS/TLS/connection refused -
        # no HTTP response ever arrived). PowerShell resolves a property access on $null to $null
        # rather than throwing, and [int]$null casts to 0, so without this guard a connection
        # failure was misreported as "HTTP 0" - masking the real .NET exception message.
        if ($webResp) {
            try { $status = [int]$webResp.StatusCode } catch { }
        }

        # PowerShell 7 exposes the response body via ErrorDetails.Message; fall back to the raw stream.
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $bodyTxt = $_.ErrorDetails.Message
        } elseif ($webResp) {
            try {
                $stream = $webResp.GetResponseStream()
                $bodyTxt = (New-Object System.IO.StreamReader($stream)).ReadToEnd()
            } catch { }
        }

        $data = $null
        if ($bodyTxt) { try { $data = $bodyTxt | ConvertFrom-Json } catch { } }

        if (-not $data) {
            # No HTTP response body to parse - surface the actual transport exception (e.g. DNS
            # resolution failure, TLS handshake failure, connection refused/timeout) instead of
            # returning blank error/suberror/desc, which gave no way to diagnose the failure.
            $inner = $_.Exception
            while ($inner.InnerException) { $inner = $inner.InnerException }
            $data = [pscustomobject]@{
                error             = $_.Exception.GetType().Name
                suberror          = $null
                error_description = $inner.Message
            }
        }

        return [pscustomobject]@{ Ok = $false; Status = $status; Data = $data; Raw = $bodyTxt; Uri = $uri }
    }
}

# Decode the payload (claims) of a JWT id_token/access_token without validating the signature.
function ConvertFrom-JwtPayload {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Jwt)

    $p = $Jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
    switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
}

# Extract the OTP from one e-mail's subject + HTML body. Kept text-only (no I/O) so it is unit-testable.
# Strips <style>/<script>/comment/tag noise and CSS hex-colors (a #123456 could otherwise look like a
# 6-digit code), then matches the exact challenge code_length when known. When several candidates
# remain, one that immediately follows a "code / verification / passcode" keyword wins; otherwise the
# first candidate is returned. Returns $null when nothing plausible is found.
function Get-OtpFromMailText {
    [CmdletBinding()]
    param(
        [string] $TitleText,
        [string] $BodyText,
        [int]    $CodeLength = 0
    )

    $t = "$TitleText`n$BodyText"
    $t = [regex]::Replace($t, '(?is)<style.*?</style>', ' ')
    $t = [regex]::Replace($t, '(?is)<script.*?</script>', ' ')
    $t = [regex]::Replace($t, '(?s)<!--.*?-->', ' ')
    $t = [regex]::Replace($t, '<[^>]+>', ' ')
    $t = [regex]::Replace($t, '#[0-9a-fA-F]{3,8}\b', ' ')   # drop CSS hex colors

    # Boundaries reject digit runs embedded in a longer alphanumeric token (e.g. a URL id).
    $exact    = if ($CodeLength -gt 0) { "(?<![0-9A-Za-z])\d{$CodeLength}(?![0-9A-Za-z])" } else { $null }
    $loose    = '(?<![0-9A-Za-z])\d{6,8}(?![0-9A-Za-z])'
    $matches  = if ($exact) { [regex]::Matches($t, $exact) } else { [regex]::Matches($t, $loose) }
    if ($matches.Count -eq 0 -and $exact) { $matches = [regex]::Matches($t, $loose) }
    if ($matches.Count -eq 0) { return $null }

    # Prefer a candidate that follows a verification-code keyword within a short window.
    $keyword = '(?i)(?:code|código|passcode|verification|verificación|one[- ]?time|otp|passcode)'
    foreach ($m in $matches) {
        $before = $t.Substring([Math]::Max(0, $m.Index - 40), [Math]::Min(40, $m.Index))
        if ($before -match $keyword) { return $m.Value }
    }
    return $matches[0].Value
}

# Poll the per-address fakemail RSS feed until the Entra verification e-mail arrives, then extract the
# numeric OTP. -NewerThan discards mails older than the given UTC time so a re-used mailbox (sign-in)
# never returns a stale code from a previous run; leave it default for a fresh mailbox (sign-up).
# Throws a clear message on timeout so the failure is actionable.
function Get-OtpFromRss {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $RssUrl,
        [int]      $CodeLength = 0,
        [int]      $TimeoutSec = 90,
        [datetime] $NewerThan  = [datetime]::MinValue
    )

    $newerThanUtc = $NewerThan.ToUniversalTime()
    $deadline     = [DateTime]::UtcNow.AddSeconds($TimeoutSec)

    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $resp  = Invoke-WebRequest -Uri $RssUrl -UseBasicParsing -ErrorAction Stop
            [xml] $xml = $resp.Content
            $items = @($xml.rss.channel.item)
            if ($items.Count -gt 0) {
                # Newest first (PowerShell's XML adapter returns element type names for .title/.description,
                # so read the actual text via the DOM nodes), then scan each mail for a matching code.
                $withDate = foreach ($item in $items) {
                    $pub = try { [DateTimeOffset]::Parse($item.SelectSingleNode('pubDate').InnerText).UtcDateTime } catch { [datetime]::MinValue }
                    [pscustomobject]@{ Item = $item; Pub = $pub }
                }
                $sorted = $withDate | Where-Object { $_.Pub -ge $newerThanUtc } | Sort-Object Pub -Descending
                foreach ($entry in $sorted) {
                    $item  = $entry.Item
                    $title = $item.SelectSingleNode('title').InnerText
                    $body  = $item.SelectSingleNode('description').InnerText
                    $code  = Get-OtpFromMailText -TitleText $title -BodyText $body -CodeLength $CodeLength
                    if ($code) { return $code }
                }
            }
        } catch {
            Write-Verbose "RSS poll error (will retry): $($_.Exception.Message)"
        }
        Start-Sleep -Seconds 5
    }

    throw "No OTP (length $CodeLength, newer than $newerThanUtc UTC) appeared in the mailbox RSS feed within ${TimeoutSec}s: $RssUrl"
}

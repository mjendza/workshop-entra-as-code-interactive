# =============================================================================
# custom_user_attribute / create.ps1  (External-04)
# =============================================================================
# Creates ONE tenant-level custom user attribute through the Entra admin
# portal's backend API (main.b2cadmin.ext.azure.com), the same call the portal
# makes under External Identities -> Custom user attributes -> Add.
#
# Called by terraform_data.this (local-exec). Inputs come from env variables:
#   ATTR_TENANT_ID, ATTR_NAME, ATTR_DESCRIPTION, ATTR_DATA_TYPE (1 = string, 2 = boolean)
#
# Auth: a DELEGATED token of the user signed in to Azure CLI, audience
# https://management.core.windows.net/. Requires:
#   az login --tenant <external tenant id> --allow-no-subscriptions
#
# Idempotent: if extension_<name> already exists with the same data type the
# script does nothing; with a different data type it fails (data type is
# immutable - delete the attribute in the portal first).
# =============================================================================

$ErrorActionPreference = 'Stop'

$tenantId    = $env:ATTR_TENANT_ID
$name        = $env:ATTR_NAME
$description = $env:ATTR_DESCRIPTION
$dataType    = [int]$env:ATTR_DATA_TYPE

$token = az account get-access-token `
    --resource 'https://management.core.windows.net/' `
    --tenant $tenantId `
    --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw "No Azure CLI token for tenant $tenantId. Run: az login --tenant $tenantId --allow-no-subscriptions"
}

$headers = @{
    Authorization = "Bearer $token"
    Accept        = 'application/json'
}
$base = 'https://main.b2cadmin.ext.azure.com/api/userAttribute'

# 1. Already there? (portal ids are extension_<name>, case-insensitive)
$existing = Invoke-RestMethod -Method Get -Headers $headers `
    -Uri "$base/GetAllUserAttributes?tenantId=$tenantId"
$match = @($existing) | Where-Object { $_.id -eq "extension_$name" } | Select-Object -First 1

if ($match) {
    if ([int]$match.dataType -ne $dataType) {
        throw "Custom attribute '$name' already exists with dataType $($match.dataType) (wanted $dataType). Data type is immutable: delete it in the portal and apply again."
    }
    Write-Host "Custom attribute '$name' already exists - nothing to do."
    return
}

# 2. Create. attributeType 3 = custom, userInputType 1 = default input
#    (a boolean renders as a checkbox in the user flow).
$body = @{
    dataType             = $dataType
    label                = $name
    adminHelpText        = $description
    userInputType        = 1
    userAttributeOptions = @()
    attributeType        = 3
} | ConvertTo-Json -Compress

Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
    -Uri "$base`?tenantId=$tenantId&`$orderby=DisplayName" `
    -Body $body | Out-Null

# 3. Verify. The POST can return success without storing the attribute (e.g.
#    two creates running in parallel - last write wins). Fail here so
#    Terraform does not record a create that did not happen.
$found = $false
foreach ($attempt in 1..5) {
    $after = Invoke-RestMethod -Method Get -Headers $headers `
        -Uri "$base/GetAllUserAttributes?tenantId=$tenantId"
    if (@($after) | Where-Object { $_.id -eq "extension_$name" }) { $found = $true; break }
    Start-Sleep -Seconds 3
}
if (-not $found) {
    throw "Custom attribute '$name' was POSTed but is not listed afterwards. Run terraform apply again."
}

Write-Host "Custom attribute '$name' created."

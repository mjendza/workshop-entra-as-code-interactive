$ClientSecretCredential = [pscredential]::new("YOUR_CLIENT_ID_HERE",(ConvertTo-SecureString "YOUR_SECRET_HERE" -AsPlainText -Force))
Connect-MgGraph -ClientSecretCredential $ClientSecretCredential -TenantId "YOUR_TENANT_ID_HERE"

Invoke-Maester -Tag 'MT.1068'
Invoke-Maester -Tag 'DIFF'
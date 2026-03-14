Get-MgApplication -Filter "AppId eq 'GUID_HERE'"
 
Get-MgServicePrincipal -ServicePrincipalId GUID_HERE

Get-MgServicePrincipal -Search '"DisplayName:TF.Workshop.NAME_HERE-MyAgent.AgentBlueprint"' -ConsistencyLevel eventual -Count spCount

Get-MgApplication -Filter "AppId eq 'GUID_HERE'" | ConvertTo-Json -Depth 10 | Out-File agent.json
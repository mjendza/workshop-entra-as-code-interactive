  $app = Get-MgApplication -Filter "AppId eq 'YOUR BLUEPRINT OBJECT ID'"

  # Generate a client secret (valid for 1 year)
  $secret = Add-MgApplicationPassword -ApplicationId $app.Id -PasswordCredential @{
      DisplayName = "Workshop Secret"
      EndDateTime = (Get-Date).AddYears(1)
  }
  $secret.SecretText

  #Get-MgApplication -Filter "AppId eq 'YOUR BLUEPRINT OBJECT ID'"| ConvertTo-Json -Depth 10 | Out-File agent.json
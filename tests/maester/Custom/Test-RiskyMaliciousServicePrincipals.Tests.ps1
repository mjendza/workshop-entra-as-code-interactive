
Describe "MJ.CTS" -Tag "MJ", "Assessment" {
    BeforeAll {
        . $PSScriptRoot/Modules/Test-MtRiskyMaliciousServicePrincipals.ps1
    }

    It "CTS.1023: Tenant service principals should not match a risky or malicious OAuth application feed" -Tag "CTS.1023" {
        $result = Test-MtRiskyMaliciousServicePrincipals

        if ($null -ne $result) {
            $result | Should -Be $true -Because "A service principal whose application id is on the OAuthSentry risky or malicious OAuth application feed is either a known-abused client or a confirmed in-the-wild consent-phishing app, and its presence in the tenant is a finding to investigate."
        }
    }
}

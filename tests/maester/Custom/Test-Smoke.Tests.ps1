Describe "MJ.Smoke" {
    It "MT9999.1: Smoke test - pipeline is operational" -Tag "Smoke", "MT9999", "MT9999.1" {
        $true | Should -BeTrue -Because "this smoke test validates the pipeline is working"
    }
}

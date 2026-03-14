# This is temporary code to load the correct Compare-MtJsonObject function during development.
# In production, this should be part of the Maester module.
BeforeAll {
    # Ensure the Compare-MtJsonObject function is available
    if (-not (Get-Command -Name Compare-MtJsonObject -ErrorAction SilentlyContinue)) {
        Write-Verbose "Loading Compare-MtJsonObject function from public/maester/drift/Compare-MtJsonObject.ps1"
        . "$PSScriptRoot/../../../powershell/public/maester/drift/Compare-MtJsonObject.ps1"
    }else {
        Write-Verbose "Compare-MtJsonObject function already available."
    }
}

# By default this will not run if either the function Compare-MtJsonObject is not available or if the user has not created the mandatory diff folder structure.
# Using discovery to dynamically add diff folders to the test suite.
# This allows the user to "define" diff tests by creating folders in the "diff" directory (recursively).
# The test will find all baseline-*.json files and test each one individually.
BeforeDiscovery {

    # Initialize early so Describe -ForEach always gets a valid array (empty = zero iterations)
    $driftFolders = @()

    # Get root directory for diff tests
    # When running from Invoke-Maester -Path ./Custom, we need to go up one level to find diff folder
    $testScriptRoot = $PSScriptRoot
    if ([string]::IsNullOrEmpty($testScriptRoot)) {
        $testScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $driftRoot = Join-Path -Path $testScriptRoot -ChildPath "diff"
    Write-Verbose "Using diff root path: $driftRoot"

    # Ensure the diff root directory exists
    if ($null -eq $driftRoot -or -not (Test-Path -Path $driftRoot)) {
        Write-Verbose "Diff root path does not exist: $driftRoot"
        # $driftFolders stays @(), Describe -ForEach @() produces zero test iterations
    }
    # Ensure the Compare-MtJsonObject function is available
    elseif (-not (Get-Command -Name Compare-MtJsonObject -ErrorAction SilentlyContinue)) {
        Write-Warning "Compare-MtJsonObject function missing, not the right version of Maester?"
        # $driftFolders stays @()
    }
    else {
        # Recursively find all baseline-*.json files and create one test entry per file.
        # This correctly handles directories with multiple baseline files (e.g., AuthenticationMethodConfigurations).
        $driftList = [System.Collections.Generic.List[hashtable]]::new()
        Get-ChildItem -Path $driftRoot -Filter "baseline-*.json" -File -Recurse | ForEach-Object {
            $parentDir = $_.Directory
            # Compute relative path from diff root (e.g., "Identity/Conditional/AccessPolicies/guid")
            $relativePath = $parentDir.FullName.Substring($driftRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
            # Extract resource type from baseline filename
            $resourceType = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -replace "^baseline-", ""
            $driftList.Add(@{
                FolderPath   = $parentDir.FullName
                FolderName   = $parentDir.Name
                RelativePath = $relativePath
                ResourceType = $resourceType
            })
        }
        $driftFolders = $driftList.ToArray()

        if ($driftFolders.Count -eq 0) {
            Write-Verbose "No baseline-*.json files found in: $driftRoot"
        } else {
            Write-Verbose "Found $($driftFolders.Count) baseline files across diff folders"
        }
    }
}

# $driftFolders is coming from BeforeDiscovery.
Describe "MJ.CTS.Governance" -ForEach $driftFolders {
    # BeforeAll is run once for each drift folder, allowing us to set up the context for each drift test.
    BeforeAll {
        # Capture the drift folder context from the discovery hashtable
        $driftFolder = $_
        $script:driftFolderPath = $driftFolder.FolderPath

        # Initialize variables to avoid linting errors
        $script:baselineData = $null
        $script:currentData = $null
        $script:settingsObject = $null
        $script:resourceType = $driftFolder.ResourceType
        $script:hasBaseline = $false
        $script:hasCurrent = $false

        # Load the baseline file
        $baselinePath = Join-Path -Path $script:driftFolderPath -ChildPath "baseline-$($script:resourceType).json"
        $script:hasBaseline = Test-Path -Path $baselinePath -ErrorAction SilentlyContinue
        if ($script:hasBaseline) {
            try {
                $script:baselineData = Get-Content -Path $baselinePath -Raw | ConvertFrom-Json -Depth 100
            } catch {
                Write-Warning "Invalid baseline JSON in $($baselinePath): $($_.Exception.Message)"
                $script:baselineData = $null
            }
        }

        # Look for corresponding current file with same resource type
        $currentFileName = "current-$($script:resourceType).json"
        $driftCurrentPath = Join-Path -Path $script:driftFolderPath -ChildPath $currentFileName
        $script:hasCurrent = Test-Path -Path $driftCurrentPath -ErrorAction SilentlyContinue
        if ($script:hasCurrent) {
            try {
                $script:currentData = Get-Content -Path $driftCurrentPath -Raw | ConvertFrom-Json -Depth 100
            } catch {
                Write-Warning "Invalid current JSON in $($driftCurrentPath): $($_.Exception.Message)"
                $script:currentData = $null
            }
        }

        # Detect and parse settings.json for all settings
        $settingsPath = Join-Path -Path $script:driftFolderPath -ChildPath "settings.json"
        if (Test-Path -Path $settingsPath -ErrorAction SilentlyContinue) {
            try {
                $script:settingsObject = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json -Depth 100
            } catch {
                Write-Warning "Could not parse settings.json in $($driftFolder.RelativePath): $($_.Exception.Message)"
                $script:settingsObject = $null
            }
        }

        # Preload the differences if both the current data and baseline data are available
        if ($script:hasBaseline -and $script:hasCurrent -and $null -ne $script:baselineData -and $null -ne $script:currentData) {
            try {
                # Use the recursive comparison function to find all differences, passing settingsObject
                $script:driftIssues = Compare-MtJsonObject -Baseline $script:baselineData -Current $script:currentData -Settings $script:settingsObject
            } catch {
                # If an error occurs during comparison, capture it as an issue using PSCustomObject fallback
                # to avoid depending on [MtPropertyDifference] class being loaded
                $script:driftIssues = @([PSCustomObject]@{
                    PropertyName  = ""
                    ExpectedValue = "N/A"
                    ActualValue   = "N/A"
                    Description   = "An error occurred while comparing JSON objects: $($_.Exception.Message)"
                    Reason        = "ComparisonError"
                })
            }
        }
    }

    # MT1060.1: Validate that the baseline JSON file is valid, if you're using drift checks. you probably want it to fail if the baseline file is not valid or missing.
    # The ID of this test will be `MT1060.{RelativePath}.1` and has a tag of `MT1060`, `MT1060.1`, `MT1060.{FolderName}`, and `MT1060.{FolderName}.1`.
    It "MT1060.<RelativePath>.1: Drift baseline for '<ResourceType>' is valid JSON" -Tag "DIFF", "MT1060","MT1060.1","MT1060.$($_.FolderName)","MT1060.$($_.FolderName).1" {
        Add-MtTestResultDetail -Description "The ``baseline-$($script:resourceType).json`` file should be valid JSON."
        $script:hasBaseline | Should -BeTrue -Because "the baseline file should exist for drift checks"
        $script:baselineData | Should -Not -BeNullOrEmpty -Because "the baseline file should contain valid JSON data"
    }

    # MT1060.2: Validate that the current JSON file is valid, if you're using drift checks. you probably want it to fail if the current file is not valid or missing.
    # The ID of this test will be `MT1060.{RelativePath}.2` and has a tag of `MT1060`, `MT1060.2`, `MT1060.{FolderName}`, and `MT1060.{FolderName}.2`.
    It "MT1060.<RelativePath>.2: Drift current for '<ResourceType>' is valid JSON" -Tag "DIFF", "MT1060","MT1060.2","MT1060.$($_.FolderName)","MT1060.$($_.FolderName).2" {
        Add-MtTestResultDetail -Description "The ``current-$($script:resourceType).json`` file should be valid JSON, how else can we compare it?"
        $script:hasCurrent | Should -BeTrue -Because "the current file should exist for drift checks"
        $script:currentData | Should -Not -BeNullOrEmpty -Because "the current file should contain valid JSON data"
    }

    # MT1060.3: Validate that there are missing properties between baseline and current JSON files, skipping if either file is missing.
    # The ID of this test will be `MT1060.{RelativePath}.3` and has a tag of `MT1060`, `MT1060.3`, `MT1060.{FolderName}`, and `MT1060.{FolderName}.3`.
    It "MT1060.<RelativePath>.3: Drift current for '<ResourceType>' has no missing properties" -Tag "DIFF", "MT1060","MT1060.3","MT1060.$($_.FolderName)","MT1060.$($_.FolderName).3" -Skip:(($script:hasBaseline -eq $false) -or ($script:hasCurrent -eq $false)) {
        $description = "The ``current-$($script:resourceType).json`` file should not have any missing properties compared to the ``baseline-$($script:resourceType).json`` file."

        $missingProperties = $script:driftIssues | Where-Object { $_.Reason -eq "MissingProperty" } |
            Select-Object -ExpandProperty PropertyName -Unique

        if ($missingProperties.Count -gt 0) {
            # If there are missing properties, format them for the test result
            $formattedMissing = "The following properties are in the baseline but missing in ``current-$($script:resourceType).json``: `n`n"
            $missingProperties | ForEach-Object {
                $formattedMissing += "- ``$_```n"
            }

            $formattedMissing += "`n"
            $formattedMissing += "Files compared in folder: ``$($script:driftFolderPath)```n"
            $formattedMissing += "Baseline: ``baseline-$($script:resourceType).json`` | Current: ``current-$($script:resourceType).json```n"

            Add-MtTestResultDetail -Result $formattedMissing -Description $description
        } else {
            Add-MtTestResultDetail -Result "No missing properties found in current-$($script:resourceType).json." -Description $description
        }
        $missingProperties | Should -BeNullOrEmpty -Because "there should be no missing properties in current-$($script:resourceType).json"
    }

    # MT1060.4: Validate that there are no drift issues between baseline and current JSON files, skipping if either file is missing.
    # The ID of this test will be `MT1060.{RelativePath}.4` and has a tag of `MT1060`, `MT1060.4`, `MT1060.{FolderName}`, and `MT1060.{FolderName}.4`.
    It "MT1060.<RelativePath>.4: Drift all values in '<ResourceType>' match" -Tag "DIFF", "MT1060","MT1060.4","MT1060.$($_.FolderName)","MT1060.$($_.FolderName).4" -Skip:(($script:hasBaseline -eq $false) -or ($script:hasCurrent -eq $false)) {
        $description = "The ``current-$($script:resourceType).json`` file should not drift from the ``baseline-$($script:resourceType).json`` file."

        $propertyIssues = $script:driftIssues | Where-Object { $_.Reason -ne "MissingProperty" }

        # Format issues into a more readable format if there are any
        if ($propertyIssues.Count -gt 0) {
            # Convert issues to a more readable format for error messages
            $formattedIssues = "| Property | Reason | Expected Value | Actual Value | Description |" + "`n"
            $formattedIssues += "|----------|---------|----------------|--------------|-------------|" + "`n"
            $propertyIssues | ForEach-Object {
                $formattedIssues += "| ``$($_.PropertyName)`` | $($_.Reason) | ``$($_.ExpectedValue)`` | ``$($_.ActualValue)`` | $($_.Description) |`n"
            }
            $formattedIssues += "`n"
            $formattedIssues += "Files compared in folder: ``$($script:driftFolderPath)```n"
            $formattedIssues += "Baseline: ``baseline-$($script:resourceType).json`` | Current: ``current-$($script:resourceType).json```n"

            Add-MtTestResultDetail -Result $formattedIssues -Description $description
        }
        else {
            Add-MtTestResultDetail -Result "No issues found in current-$($script:resourceType).json." -Description $description
        }

        # Report all issues at once
        $propertyIssues.Count | Should -Be 0 -Because "there should be no differences between baseline and current JSON files"
    }
}

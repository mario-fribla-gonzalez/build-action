# Requires PowerShell 5.1+

param(
    [string]$Command = "",
    [string]$SelfContained = $false,
    [string]$CoberturaPruebasUnitarias= ""
)

if ($env:RUNNER_DEBUG -eq "1") {
    Set-PSDebug -Trace 1
}
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Build {
    # Find the first .csproj with <Version>
    Get-ChildItem -Path ./src -Recurse -Filter *.csproj
    $csproj = Get-ChildItem -Path ./src -Recurse -Filter *.csproj | Where-Object {
        $xml = [xml](Get-Content $_.FullName)
        $hasVersion = $xml.Project.PropertyGroup.Version
        return $hasVersion
    } | Select-Object -First 1

    if (-not $csproj) {
        Write-Error "No .csproj file with <Version> found in ./src."
        exit 1
    }

    [xml]$projXml = Get-Content $csproj.FullName
    $AssemblyName = $projXml.Project.PropertyGroup.AssemblyName
    if (-not $AssemblyName) {
        $AssemblyName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)
    }
    $package_extension = "zip"
    $release_version = $projXml.Project.PropertyGroup.Version

    Write-Host "Package Name: $AssemblyName"
    Write-Host "Package Extension: $package_extension"
    Write-Host "Release Version: $release_version"

    Write-Host "Building $AssemblyName version $release_version"
    Get-Process SuscribirPago -ErrorAction SilentlyContinue | Stop-Process -Force

    if (Test-Path release) {
        Remove-Item -Path release -Recurse -Force
    }
    New-Item -Path release -ItemType Directory | Out-Null

    $sln = Get-ChildItem -Path . -Recurse -Filter *.sln | Select-Object -First 1
    if (-not $sln) {
        Write-Error "No .sln file found in the repository."
        exit 1
    }

    Get-Process dotnet -ErrorAction SilentlyContinue | Stop-Process -Force

    dotnet publish $sln.FullName -c Release /t:Package /p:PackageDir=$PWD/

    Add-Content -Path $env:GITHUB_OUTPUT -Value "package-name=$AssemblyName"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "package-extension=$package_extension"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "release-version=$release_version"
}

function Invoke-Test {
    $dotnet_version = dotnet --version
    Write-Host "Detected .NET version: $dotnet_version"

    $sln = Get-ChildItem -Path . -Recurse -Filter *.sln | Select-Object -First 1
    if (-not $sln) {
        Write-Error "No .sln file found in the repository."
        exit 1
    }
    Write-Host "Using solution file: $($sln.FullName)"

    if (-not (Test-Path "coverage")) {
        New-Item -Path "coverage" -ItemType Directory | Out-Null
    }

    # Build the test project
    dotnet build $sln.FullName
    dotnet test $sln.FullName --collect:"XPlat Code Coverage;Format=opencover"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "dotnet test failed."
        exit 1
    }

    # Patch coverage file: replace repo root and current directory with 'src' or nothing in the XML
    $coverageFile = Get-ChildItem -Recurse -Filter 'coverage*.xml' | Select-Object -First 1
    if ($coverageFile) {
        $xmlContent = Get-Content $coverageFile.FullName -Raw

        # Remove with trailing slash/backslash
        $cwd = (Get-Location).Path
        $patchedXml = $xmlContent -replace ([regex]::Escape($cwd) + '[\\/]+'), ''

        # Save the patched XML
        $patchedPath = 'coverage/coverage.opencover.xml'
        $patchedXml | Set-Content $patchedPath

        # --- Coverage summary table ---
        [xml]$xml = Get-Content $patchedPath

        if ($xml.DocumentElement.LocalName -eq 'coverage') {
            # Cobertura format
            $cov = $xml.DocumentElement
            $lineRate = [math]::Round([double]$cov.GetAttribute("line-rate") * 100, 2)
            $branchRate = [math]::Round([double]$cov.GetAttribute("branch-rate") * 100, 2)
            $linesCovered = $cov.GetAttribute("lines-covered")
            $linesValid = $cov.GetAttribute("lines-valid")
            $branchesCovered = $cov.GetAttribute("branches-covered")
            $branchesValid = $cov.GetAttribute("branches-valid")
        }
        elseif ($xml.DocumentElement.LocalName -eq 'CoverageSession') {
            # OpenCover format
            $summary = $xml.SelectSingleNode('//Summary')
            if (-not $summary) {
                Write-Error "No <Summary> element found in OpenCover report."
                exit 1
            }
            $linesCovered = [int]$summary.visitedSequencePoints
            $linesValid = [int]$summary.numSequencePoints
            $branchesCovered = [int]$summary.visitedBranchPoints
            $branchesValid = [int]$summary.numBranchPoints
            $lineRate = [math]::Round([double]$summary.sequenceCoverage, 2)
            $branchRate = [math]::Round([double]$summary.branchCoverage, 2)
        }
        else {
            Write-Error "Unknown coverage XML format: <$($xml.DocumentElement.LocalName)>"
            exit 1
        }

        Write-Host ""
        Write-Host "COVERAGE SUMMARY"
        Write-Host "--------------------------------------------"
        Write-Host "| Metric        | Covered | Total | %      |"
        Write-Host "|---------------|---------|-------|--------|"
        Write-Host ("| Lines         | {0,7} | {1,5} | {2,5}% |" -f $linesCovered, $linesValid, $lineRate)
        Write-Host ("| Branches      | {0,7} | {1,5} | {2,5}% |" -f $branchesCovered, $branchesValid, $branchRate)
        Write-Host "--------------------------------------------"
        if ( $lineRate -lt [double]$CoberturaPruebasUnitarias ) {
          Write-Host "error:: Cobertura insuficiente ($lineRate% < $CoberturaPruebasUnitarias%)"
          exit 1
        } else {
          Write-Host "Cobertura OK: $lineRate% >= $CoberturaPruebasUnitarias%"
        }	        
        exit 0
    } else {
        Write-Error "Coverage report generation failed."
        exit
    }
    Get-ChildItem -Recurse -Filter 'coverage*.xml'
}

if ($Command -eq "build") {
    Invoke-Build
}
elseif ($Command -eq "test") {
    Invoke-Test
}

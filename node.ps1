# Requires: PowerShell 5.1+

param(
    [string]$Framework = "",
    [string]$Command = "build"
)

Write-Host "Framework: $Framework"
Write-Host "Command: $Command"

function Install-AngularCLI {
    $cliVersion = node -p "require('./package.json').devDependencies['@angular/cli'] || require('./package.json').dependencies['@angular/cli']"
    Write-Host "Installing @angular/cli version: $cliVersion"
    if ($cliVersion) {
        npm install -g "@angular/cli@$cliVersion"
        #npm ci
    } else {
        Write-Host "::error::@angular/cli not found in package.json"
        exit 1
    }
}

function Install-Dependencies {
    Write-Host "Installing dependencies for Node.js application"
    npm ci --production
}

function Install-Dependencies2 {
    Write-Host "Installing dependencies2 for Node.js application"
    npm install --save-dev @vercel/ncc
}

function Build-App {
    Write-Host "npm setting:"
    npm run build -- --configuration production
    $application_name = node -p "require('./package.json').name.replace(/^@.*\//, '')"
    $release_version = node -p "require('./package.json').version"
    $packageExtension = "zip"

    Set-Location dist
    Compress-Archive -Path * -DestinationPath ../$application_name.zip
    Set-Location ..
    Get-ChildItem -Path dist

    echo "package-name=$application_name"  >> $env:GITHUB_OUTPUT
    echo "package-extension=$packageExtension" >> $env:GITHUB_OUTPUT
    echo "release-version=$release_version"    >> $env:GITHUB_OUTPUT
}

function Install-Chrome {
    $ErrorActionPreference = "Stop"
    $chromeInstaller = "$env:TEMP\chrome_installer.exe"
    Invoke-WebRequest "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile $chromeInstaller
    Start-Process -FilePath $chromeInstaller -Args "/silent /install" -Wait
    Remove-Item $chromeInstaller
    $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    if (-Not (Test-Path $chromePath)) {
        $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    }
    echo "CHROME_BIN=$chromePath" | Out-File -FilePath $env:GITHUB_ENV -Append
    $ErrorActionPreference = "Continue"
}

function Run-Tests {
    npm test -- --watch=false --browsers=ChromeHeadless --no-progress --code-coverage | Tee-Object -FilePath test-output.log
    $failed = 0
    $success = 0
    Get-Content test-output.log | ForEach-Object {
        if ($_ -match '(\d+)\s+failed') { $failed = [int]$matches[1] }
        if ($_ -match '(\d+)\s+successful|\s+passed') { $success = [int]$matches[1] }
    }
    if ($failed -ne 0) {
        Write-Host "::error::TOTAL: $failed FAILED, $success SUCCESS"
        exit 1
    } else {
        Write-Host "::notice::TOTAL: $failed FAILED, $success SUCCESS"
        exit 0
    }
}

if ($Framework -eq "angular") {
    Install-AngularCLI
    Install-Dependencies2
} else {
    Install-Dependencies
}

if ($Command -eq "build") {
    Build-App
} elseif ($Command -eq "test") {
    Install-Chrome
    Run-Tests
}

param (
    $configuration = (property configuration Release),
    $hostname = (property hostname "usedefault"),
    $shortVersion = (property shortVersion 0.0.0.0), # Numeric-only version
    $version = (property version 0.0.0.0) # Full version... may include branch name etc
)

$oneconfig_version = "0.1.0-alpha.22"

$powerplatform_solution = "$PSScriptRoot\solution"
#$solution = "" WIP for later ticket. Need to work out multiple .sln handling (maybe)
$build_dir = "$PSScriptRoot\build"
$build_solution_dir = "$build_dir\solution"
$packages_dir = "$PSScriptRoot\packages"


$root_dir = (Get-Location)


task clean check-for-dotnet-sdk, {
    #Todo future ticket when handling PCF builds
    #exec { dotnet.exe clean $solution -c $configuration }  WIP Will be covered under future ticket. This will need to be able to handle multiple PowerApps soltions in the solutions folder, 
    # containing multiple custom components, which may mean multiple .sln to process
    if (Test-Path $build_dir) {
        Remove-Item -Path $build_dir -Recurse
    }
}

task prepare {
    $null = New-Item -ItemType Directory -Force -Path $build_dir
    $null = New-Item -ItemType Directory -Force -Path $packages_dir
}

task setup-nuget {
	if (Get-Command -ErrorAction SilentlyContinue -Name "nuget") {
		Write-Output "Nuget is already installed"
	} else {
		choco install nuget.commandline -y
		if ($LASTEXITCODE -ne 0) {
			throw "Nuget install failed!"
		}
	}
}

task setup-tools setup-nuget, prepare, {
    Push-Location -Path $packages_dir
    nuget install RACT_OneConfig -Version $oneconfig_version
    nuget install Microsoft.PowerApps.CLI 
    Pop-Location
}

task restore-packages check-for-dotnet-sdk, {
    #Todo future ticket when handling PCF builds
    #exec { dotnet.exe tool restore }
    #exec { dotnet.exe restore $solution /p:RestoreUseSkipNonexistentTargets="false" }
    #WIP will not be needed until later ticket. Placeholder
}

task generate generate-static, generate-tools, generate-main

task generate-main prepare, restore-packages, {
    #Todo future ticket when handling PCF builds
    #exec { dotnet.exe build $solution -c $configuration /p:Version=$shortVersion /p:InformationalVersion=$version }
    #if ($LASTEXITCODE -ne 0) {
    #    throw "Failure running dotnet build"
    #}

    robocopy "$powerplatform_solution" "$build_solution_dir" /e | Out-Null
    cmd.exe /c "$build_dir\setup.cmd -hostname $hostname" pack-solution
}

task generate-static prepare, {
    robocopy ".\setup" "$build_dir" /e | Out-Null
}

task generate-tools setup-tools, setup-powerapps-cli, {

    # Copy the "one config" tool to the build folder
    $oneConfigFolder = "RACT_OneConfig.$oneconfig_version"
    robocopy "$packages_dir\$oneConfigFolder\tools" "$build_dir\tools\OneConfig" /e | Out-Null
    robocopy "$packages_dir" "$build_dir\packages" /e | Out-Null

}

task setup-chocolatey {
    # install chocolatey, if its not already there for some reason
    try {
        $chocoVersion = choco --version
    }
    catch {
        $chocoVersion = ""
    }
    If ($chocoVersion.Length -eq 0) {
        [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    Else {
        Write-Host "Chocolatey version $chocoVersion already installed."
    }
}

task setup-powerapps-cli {
    # install PowerApps CLI (PAC), if its not already there for some reason
    try {
        $pacVersion = pac | Select-String -Pattern 'Version:' -SimpleMatch
    }
    catch {
        $pacVersion = ""
    }
    If ($pacVersion.Length -eq 0) {
        choco install Microsoft.PowerApps.CLI -s $packages_dir
    }
    Else {
        Write-Host "PowerAdmin CLI $pacVersion already installed."
    }
}

task check-for-dotnet-sdk setup-chocolatey, {
    $globalJson = Get-Content -Path "$root_dir\global.json" | Out-String | ConvertFrom-Json
    $sdkVersion = $globalJson.sdk.version

    Write-Host "Checking for required dotnet sdk version $sdkVersion..."

    if (!(dotnet --list-sdks | Where-object { $_ -match $sdkVersion })) {
        Write-Host "Installing required dotnet sdk version $sdkVersion..."
        choco install -y dotnet-sdk --version=$sdkVersion --allow-downgrade --ignoredetectedreboot | Write-Host
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
            exit $LASTEXITCODE
        }
    }
    else {
        Write-Host "Found dotnet sdk version $sdkVersion"
    }
}

task apply generate, apply-bare

task apply-bare {
	cmd.exe /c "$build_dir\setup.cmd -hostname $hostname" apply

    if ($LASTEXITCODE -ne 0) {
        throw "Failure while running apply"
    }
}

task apply-managed {
	cmd.exe /c "$build_dir\setup.cmd -hostname $hostname" apply-managed

    if ($LASTEXITCODE -ne 0) {
        throw "Failure while running apply-managed"
    }
}

task capture prepare, generate-static, generate-tools, capture-bare

task capture-bare {
	cmd.exe /c "$build_dir\setup.cmd" capture

    if ($LASTEXITCODE -ne 0) {
        throw "Failure while running capture"
    }
}

task package-managed generate, package-managed-bare

task package-managed-bare {
	cmd.exe /c "$build_dir\setup.cmd -hostname $hostname" package-managed

    if ($LASTEXITCODE -ne 0) {
        throw "Failure while generating managed package"
    }
}

task upgrade generate, upgrade-bare

task upgrade-bare {
	cmd.exe /c "$build_dir\setup.cmd -hostname $hostname" upgrade
}

task configure generate, configure-bare 

task configure-bare {
	cmd.exe /c "$build_dir\setup.cmd -hostname $hostname" configure
}

task . clean, generate
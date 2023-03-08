$temp_dir = "temp"
$settings_file_name = "settings.json"
$settings_path = "$temp_dir\$settings_file_name"
$solution_dir = ".\solution"
$root_solution_dir = "$PsScriptRoot\..\solution"

task prepare setup-dependencies, {
	if (Test-Path -Path $temp_dir) {
		$null = Remove-Item -Path $temp_dir -Force -Recurse
	}	
    $null = New-Item -ItemType Directory -Path $temp_dir
}


task setup-dependencies {
	# Install .NET 6 runtime
	# There is no doubt a better way than this	
	$needNet6 = $true
	if (Get-Command -ErrorAction SilentlyContinue -Name "dotnet") {
		$dn = dotnet --list-runtimes | Select-String -SimpleMatch "Microsoft.NETCore.App 6.0"
		if (-not($dn -eq $null)) {
			Write-Output ".NET 6 runtime already installed"
			Write-Output $dn	
			$needNet6 = $false 
		}
	}
	if ($needNet6 -eq $true) {
		Write-Output "Installing .NET 6 runtime"
		choco install dotnet-6.0-runtime -y
		if ($LASTEXITCODE -ne 0) {
			throw ".NET 6 runtime install failed!"
		}
	}	
	
}

task clean {
	if (Test-Path -Path $temp_dir) {
		Remove-Item $temp_dir -Recurse
		Write-Output "$temp_dir folder removed"
	}	
}


task configure-settings prepare, {	
	#copy settings file to temp folder for value replacement
	robocopy ".\$settings_file_name" "$temp_dir" /e | Out-Null

	# Replace cross-referenced values		
	Configure-Settings $settings_file_name $temp_dir
	
	$settings = Get-Settings
	$Global:solution_name = $settings.solution_name
	$Global:hostname = $settings.environment.hostname
	$Global:application_id = $settings.application_id
	$Global:tennant = $settings.tennant
	$Global:client_secret = $settings.client_secret
}

task configure configure-settings

task deploy-infra connect, deploy-infra-bare, disconnect


task deploy-infra-bare {
	
	#Todo future ticket
	#Write-Host "Infrastructure deployed"
	
}   

task pack-solution configure, {
	
	# pack solution file
	
	Write-Host "Packing the solution content directory $solution_dir to $solution_name.zip"
	pac solution pack --zipfile ".\$solution_name.zip" --folder "$solution_dir" --packageType Unmanaged --processCanvasApps
}

task unpack-solution configure, {
	
	# unpack solution file
	
	Write-Host "Unpacking the solution package $solution_name.zip to $root_solution_dir"
	pac solution unpack --zipfile ".\$solution_name.zip" --folder "$root_solution_dir" --packageType Unmanaged --processCanvasApps

	#robocopy "$solution_dir" "$root_solution_dir"  /E /ZB /X /PURGE /COPYALL | Out-Null
}

task import-solution connect, pack-solution, import-solution-bare, disconnect

task import-solution-bare {
	# Publish
	Write-Host "Importing the solution '$solution_name'..."
	pac solution import --path ".\$solution_name.zip" --publish-changes

	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to import solution $solution_name.zip"
    }
}

task export-solution-bare configure, {
	# Publish
	Write-Host "Exporting the solution '$solution_name'..."
	pac solution export --path ".\" --name "$solution_name" --overwrite

	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to export solution $solution_name"
    }
}

task apply connect, deploy-infra-bare, pack-solution, import-solution-bare, disconnect

task capture connect, export-solution-bare, unpack-solution, disconnect

#Todo future ticket
#task upgrade connect, deploy-infra-bare, pack-solution, import-solution-bare, disconnect

task connect configure, {
	#Revisit this - currently not exporting correctly in the new development environment if applicaitonId is specified
	#pac auth create --url https://$hostname/ --name RACT_DEV-SPN --applicationId $application_id --clientSecret $client_secret --tenant $tennant
	pac auth create --url https://$hostname/ --name RACT_DEV-SPN --clientSecret $client_secret --tenant $tennant
	pac auth create --kind ADMIN

	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to connect/authenticate with $hostname"
    }
}

task disconnect configure, {
	
}


function Configure-Settings($filePath, $outputDir) {
	
	$fileName = [System.IO.Path]::GetFileName($filePath)
	$outputFilePath = "$outputDir\$fileName"
	
	.\tools\OneConfig\OneConfig.exe --mode Settings --settingsPath $settings_file_name --outputFilePath $outputFilePath
	
	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to create a configured version of the settings $filePath"
    }
	
}

function Get-Settings() {
	Get-Content $settings_path | ConvertFrom-Json 
}

function Save-Settings($settings) {
	$settings | ConvertTo-Json -Depth 10 | Set-Content $settings_path
}

task . apply
param (
    $hostname_override
)

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
	$Global:application_id = $settings.application_id
	$Global:client_secret = $settings.client_secret
	if ($hostname_override -ne "usedefault") {
		$Global:hostname = $hostname_override
	} else {
		$Global:hostname = $settings.environment.hostname
	}
	$Global:solution_name = $settings.solution_name
	$Global:tennant = $settings.tennant
}

task configure configure-settings

task deploy-infra connect, deploy-infra-bare, disconnect


task deploy-infra-bare {
	
	#Todo future ticket for standing up throw-away development environments
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
}

task import-solution connect, { 
	import-solution-bare($false) 
}, disconnect

task import-managed-solution connect, { 
	import-solution-bare($true) 
}, disconnect

function import-solution-bare($managed) {
	# Publish

	if ($managed -eq $true) {
		Write-Host "Importing the managed solution '$solution_name-managed'..."
		pac solution import --path ".\$solution_name-managed.zip" --publish-changes
	} else {
		Write-Host "Importing the unmanaged solution '$solution_name'..."
		pac solution import --path ".\$solution_name.zip" --publish-changes
	}
	
	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to import solution $solution_name.zip"
    }
}

task export-managed-solution connect, {
	export-solution-bare($true)
}, disconnect

task export-unmanaged-solution connect, {
	export-solution-bare($false)
}, disconnect

function export-solution-bare($managed) {
	if ($managed -eq $true) {
		Write-Host "Exporting the solution '$solution_name' as managed..."
		pac solution export --path ".\$solution_name-managed.zip" --name "$solution_name" --managed --overwrite
	} else {
		Write-Host "Exporting the solution '$solution_name' as unmanaged..."
		pac solution export --path ".\$solution_name.zip" --name "$solution_name" --overwrite
	}
	
	if ($LASTEXITCODE -ne 0) {
		if ($managed -eq $true) {
        	throw "Failure while trying to export solution $solution_name-managed.zip"
		} else {
			throw "Failure while trying to export solution $solution_name.zip"
		}
    }
}

task apply deploy-infra-bare, import-solution

task apply-managed import-managed-solution

task package-managed import-solution, export-managed-solution

task capture export-unmanaged-solution, unpack-solution

#Todo future ticket
#task upgrade connect, deploy-infra-bare, import-solution-bare, disconnect

task connect configure, {
	#Revisit this - currently not exporting correctly in the new development environment if applicaitonId is specified
	#pac auth create --url https://$hostname/ --name RACT_DEV-SPN --applicationId $application_id --clientSecret $client_secret --tenant $tennant
	pac auth create --url https://$hostname/ --name RACT_DEV-SPN --clientSecret $client_secret --tenant $tennant
	#pac auth create --kind ADMIN

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
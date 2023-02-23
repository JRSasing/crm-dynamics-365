#This file is here as a placeholder at the moment, just so I have a reference. Not used yet. Obviously from Roadside project. Will modify as required under later tickets


param (
    [string]$azureClientId,
    [string]$azureServicePrincipalKey
)


$settings_file_name = "settings.json"

$prince_dir = "tools\prince"
$infra_dir = "infrastructure"

$temp_dir = "temp";
$temp_settings_path = "$temp_dir\$settings_file_name"
$temp_web_path = "$temp_dir\web"
$temp_web_zip_path = "$temp_dir\web-app-deploy.zip"
$temp_prince_dir = "$temp_web_path\prince"
$temp_webappsettings_path = "$temp_web_path\appsettings.json"
$temp_infra_dir = "$temp_dir\infrastructure"

$web_dir = ".\web"


task prepare setup-dependencies, {
	if (Test-Path -Path $temp_dir) {
		$null = Remove-Item -Path $temp_dir -Force -Recurse
	}	
    $null = New-Item -ItemType Directory -Path $temp_dir
	$null = New-Item -ItemType Directory -Path $temp_infra_dir
}


task setup-dependencies {
	
	if (Get-Command -ErrorAction SilentlyContinue -Name "bicep") {
		Write-Output "Bicep is already installed"
    } else {
	    choco install bicep -y
	    if ($LASTEXITCODE -ne 0) {
		    throw "bicep install failed!"
	    }
    }
	
	# Install Azure CLI
	if (Get-Command -ErrorAction SilentlyContinue -Name "az") {
		Write-Output "AzureCLI is already installed"
	} else {
		choco install azure-cli -y
		if ($LASTEXITCODE -ne 0) {
			throw "AzureCLI install failed!"
		}
	}	
	
	if (-not($null -eq (Get-InstalledModule -Name "Az" -ErrorAction SilentlyContinue))) {     # Specify minimum version in this check?
		Write-Output "Az Powershell module is already installed"
    } else {
		Write-Host "Installing Az Powershell module..."
		Install-Module -Name Az -Scope AllUsers -Confirm:$False -Force
	}
	
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
	# Replace cross-referenced values		
	Configure-Settings $settings_file_name $temp_dir		
}

task configure-templates configure-settings, {		
	$null = Remove-Item -Path "$temp_infra_dir\*.bicep"  
	Configure-Template $temp_infra_dir "$infra_dir\app.bicep"
	Configure-Template $temp_infra_dir "$infra_dir\app.bicep.params.json"
	Configure-Template $temp_infra_dir "$infra_dir\resourcegroup.bicep"
}

task configure configure-settings, configure-templates 

task deploy-infra connect, deploy-infra-bare, disconnect


task deploy-infra-bare {
	
	# Create a configured version of the bicep params

	$infraOutputs = GetSharedInfraOutputs

	Write-Host "Updating bicep params for app..."
	$appParamsPath = "$temp_infra_dir\app.bicep.params.json"
	$params = Get-Content $appParamsPath | ConvertFrom-Json 
	$params.parameters.appServicePlanId.value = $infraOutputs.documentapi_appserviceplan_id	
	$params.parameters.appInsightsInstrumentationKey.value = $infraOutputs.documentapi_appinsights_instrumentationkey	
	$params.parameters.appInsightsConnectionString.value = $infraOutputs.documentapi_appinsights_connectionstring
	$params.parameters.createPrivateEndpoint.value = $infraOutputs.common_privateendpoints_supported
	$params | ConvertTo-Json -Depth 10 | Set-Content $appParamsPath
	

	# Set the context

	Write-Host "Setting context to required subscription..."
	$null = Get-AzSubscription -SubscriptionId $settings.subscription_id -TenantId $settings.tenant.id | Set-AzContext


	# Run the bicep templates

	$settings = Get-Settings
	$resourceGroupName = $settings.resource_group_name
    $location = $settings.location.name

	Write-Host "Ensuring the resource group '$resourceGroupName' exists..."
	$null = New-AzSubscriptionDeployment -TemplateFile "$temp_infra_dir\resourcegroup.bicep" -location $location -locationFromTemplate $location

	Write-Host "Deploying into resource group '$resourceGroupName' ..."
	$null = New-AzResourceGroupDeployment -TemplateFile "$temp_infra_dir\app.bicep" -ResourceGroupName $resourceGroupName -TemplateParameterFile $appParamsPath -Force -Mode Complete
	
	Write-Host "Infrastructure deployed"
	
}   

task create-zip configure, {
	
	# Copy the web site, and the prince tool, to the temp directory
	
	if (Test-Path -Path $temp_web_path) {
		Remove-Item $temp_web_path -Recurse
	}
	Copy-Item -Path $web_dir -Destination $temp_web_path -Recurse -Force
	Copy-Item -Path $prince_dir -Destination $temp_prince_dir -Recurse -Force
	
	
	# Save the prince license key to a file 
	
	$settings = Get-Settings
	$princeLicenceKey = $settings.princexml_license_key
	
	if ($princeLicenceKey -eq "") {
		Write-Host "No PrinceXML license key is defined; the demo license will be used"
	} else {	
		$princeXmlLicensePath = "$temp_prince_dir\license\license.dat"
		$null = $princeLicenceKey | Set-Content $princeXmlLicensePath
		Write-Host "PrinceXML license saved: $princeXmlLicensePath"
	}	
	
	
	# Update appsettings.json	
	
	$appSettings = Get-Content $temp_webappsettings_path | ConvertFrom-Json
	$appSettings.PrinceXML.ExePath = "prince\bin\prince.exe"
	$null = $appSettings | ConvertTo-Json -Depth 10 | Set-Content $temp_webappsettings_path
	Write-Host "AppSettings.json updated"
	
	
	# Zip it
	
	Write-Host "Compressing the web app content directory $webFilesPath to $temp_web_zip_path"
	Compress-Archive -Path "$temp_web_path\*" -DestinationPath $temp_web_zip_path -Force
	
}

task deploy-app connect, create-zip, deploy-app-bare, disconnect

task deploy-app-bare {
	
	$settings = Get-Settings
	$webAppName = $settings.web_app_name
	$resourceGroupName = $settings.resource_group_name
	
	# Publish
	Write-Host "Publishing the web app '$webAppName' in resource group '$resourceGroupName'..."
	$null = Publish-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -ArchivePath $temp_web_zip_path -Force	
	
}   

task upgrade connect, deploy-infra-bare, create-zip, deploy-app-bare, disconnect

task connect configure, {
	
	# Stop when there are errors, even just statement terminating errors that wouldn't be stopped by the -ErrorAction parameter
	# https://github.com/MicrosoftDocs/PowerShell-Docs/issues/1583
	$ErrorActionPreference = "Stop"

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


	# Read settings

	$settings = Get-Settings
	$tenantId = $settings.tenant.id 
	$clientId = $settings.tenant.account.client 
	$servicePrincipalKey = $settings.tenant.account.password   
	

	## Verifying dependencies
	# Checking if Az Powershell is installed
	# Specify minimum version in this check?
	Write-Host "Verifying dependencies..."
	if ($null -eq (Get-InstalledModule -Name "Az" -ErrorAction SilentlyContinue)) {
		Write-Host "Az Powershell module is not installed"

		Install-Module -Name Az -Scope AllUsers -Confirm:$False -Force
	}

    ## Connecting to Azure Account 
	Write-Host "Connecting to Azure..."
	if ($clientId -eq "") {
		# Connect using logged in user
		$context = Get-AzContext
		if (!$context) {
			Write-Host "Need to login"
			Connect-AzAccount -Tenant $tenantId
		} else {
			if (-not($context.Tenant.Id -eq $tenantId)) {
				Write-Host "Switching to required tenant"
				$null = Set-AzContext -Tenant $tenantId
			}			
		}		
	} else {
		
		# https://docs.microsoft.com/en-us/powershell/module/az.accounts/Connect-AzAccount?view=azps-7.1.0#example-3--connect-to-azure-using-a-service-principal-account
		Write-Host "Connecting to Azure using Service Principal"
		$secureSpKey = ConvertTo-SecureString $servicePrincipalKey -AsPlainText -Force
		$servicePrincipalCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $secureSpKey
		$contextName = Get-AzContextName
		Connect-AzAccount -ServicePrincipal -TenantId $tenantId -Credential $servicePrincipalCredential -ContextName $contextName -Force
	}

}

task force-disconnect {
	Disconnect-Azure
}

task disconnect configure, {
	## Disconnect from Azure Account if we connected using a service principal
	# Unsure if this is necessary, but wouldn't want to leave the session authenticated to Azure
	# This might also be our friend/alternative Disable-AzContextAutosave
	# https://docs.microsoft.com/en-us/powershell/module/az.accounts
	
	# TODO think about if okay to not disconnect interactive session
	#      doing so would require login every time... 
	#      if go back to using service principal locally, means you need to keep a key secure
	
	$settings = Get-Settings
	$clientId = $settings.tenant.account.client 
	
	if ($clientId -eq "") {
		Write-Host "WARNING: Interactive login, not disconnecting; 'force-disconnect' can be used to disconnect"
	} else {
		Disconnect-Azure
	}	
}

function Get-AzContextName() {
	$settings = Get-Settings
	$tenantId = $settings.tenant.id 
	$clientId = $settings.tenant.account.client 
	"$tenantId-$clientId"
}

function GetSharedInfraOutputs() {
	
	# Get dynamic infrastructure-dependent settings from Blob Storage
	# Assumes already connected to Azure
	
	Write-Host "Getting infrastructure details from blob storage... "
	$settings = Get-Settings
	
	$subscriptionId = $settings.shared_infra_outputs_storage.subscription_id
	$resourceGroupName = $settings.shared_infra_outputs_storage.resource_group_name
	$storageAccountName = $settings.shared_infra_outputs_storage.storage_account_name
	$containerName = $settings.shared_infra_outputs_storage.container_name
	$fileName = $settings.shared_infra_outputs_storage.file_name
	
	$downloadPath = "$temp_dir\$fileName"

	if (Test-Path -Path $downloadPath) {
		Write-Host "Shared infrastructure details already retrieved from blob storage"
	} else {

		$null = Get-AzSubscription -SubscriptionId $subscriptionId -TenantId $settings.tenant.id | Set-AzContext
		$sacc = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName 
			
		$blobDownload = @{
			Blob        = $fileName
			Container   = $containerName
			Destination = $temp_dir 
			Context     = $sacc.Context
		}
		Write-Host "Getting shared infrastructure details from container '$containerName', file '$fileName'"
		$null = Get-AzStorageBlobContent @blobDownload -Force -ErrorVariable blobNotFound -ErrorAction SilentlyContinue

		if ($blobNotFound)
		{
			throw "Shared infrastructure details not found in Blob Storage; 'azure-infra' must be used to create the shared resources"
		}
	}

	# Return as object
	
	Get-Content $downloadPath | ConvertFrom-Json 

}


function Configure-Settings($filePath, $outputDir) {
	
	$fileName = [System.IO.Path]::GetFileName($filePath)
	$outputFilePath = "$outputDir\$fileName"
	
	.\tools\OneConfig\OneConfig.exe --mode Settings --settingsPath $settings_file_name --outputFilePath $outputFilePath
	
	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to create a configured version of the settings $filePath"
    }
	
}

function Configure-Template($outputDir, $templateFilePath) {
	
	$fileName = [System.IO.Path]::GetFileName($templateFilePath)
	$outputFilePath = "$outputDir\$fileName"
	
	.\tools\OneConfig\OneConfig.exe --mode Template --settingsPath $temp_settings_path --templatePath $templateFilePath --outputFilePath $outputFilePath
	
	if ($LASTEXITCODE -ne 0) {
        throw "Failure while trying to create a configured version of the template $templateFilePath"
    }
	
}

function Get-Settings() {
	Get-Content $temp_settings_path | ConvertFrom-Json 
}

function Save-Settings($settings) {
	$settings | ConvertTo-Json -Depth 10 | Set-Content $temp_settings_path
}

function Disconnect-Azure() {
	$context = Get-AzContext
	if (!$context) {
		Write-Host "Already disconnected"
	} else {
		$contextName = $context.Name
		Write-Host "Disconnecting from Azure context '$contextName' ..."
		$null = Disconnect-AzAccount -ContextName $contextName | Out-Null
		Write-Host "Disconnected Azure connection"
	}
}

task . upgrade
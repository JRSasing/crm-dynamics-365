if (Get-Command -ErrorAction SilentlyContinue -Name "choco") {
	Write-Output "Chocolatey is already installed"
} else {
	Write-Output "Installing Chocolatey"
	Set-ExecutionPolicy Bypass -Scope Process -Force
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
	iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

if (Get-Command -ErrorAction SilentlyContinue -Name "Invoke-Build") {
	Write-Output "Invoke-Build is already installed"
} else {
	Write-Output "Installing Invoke-Build"
	choco install invoke-build -y
}

Invoke-Build -File .\setup.ps1 $args
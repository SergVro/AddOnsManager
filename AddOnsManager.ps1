Function Get-FileNames($initialDirectory)
{   
	 [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") |
	 Out-Null

	 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	 $OpenFileDialog.initialDirectory = $initialDirectory
	 $OpenFileDialog.filter = "Add-On files (*.nupkg)| *.nupkg"
	 $OpenFileDialog.Multiselect = $true
	 
	 $OpenFileDialog.ShowDialog() | Out-Null
	 $OpenFileDialog.FileNames
}

Function Get-Confirmation($message) 
{
	 [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") |
	 Out-Null
	 
	 return [System.Windows.Forms.MessageBox]::Show($message, "Confirm" , 4)
}
Function Show-Message($message) 
{
	 [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") |
	 Out-Null
	 
	 return [System.Windows.Forms.MessageBox]::Show($message, "Information" , 0)
}

trap [Exception]
{
    echo ""
    echo "An unhandled error has occured:"
    echo $_.Exception
    echo "When executing"
    echo $_.InvocationInfo.PositionMessage
    break
}

if ($env:Processor_Architecture -ne "x86")
{ 
	echo 'Launching x86 PowerShell'
	&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $myinvocation.Mycommand.path -executionpolicy bypass
	break
}

Add-PSSnapin "EPiServer.Install.Common.1"
Add-PSSnapin "EPiServer.Install.Packaging.*"
$exit = $false
do {

	$wizard = New-Object "EPiServer.Install.UI.Wizards.SelectSiteWizard, EPiServerInstall.Common.1" 
	$wizard.Title = "Select a web application."
	$wizard.TypeOfWizard = 3
	try {
		$result = $wizard.show()
	}
	catch {
		break
	}
	if (-not $result)
	{
		Break
	}
	$apiPath = $null
	$appPath = $wizard.SelectedApplication.PhysicalPath
	$supportedVersion = New-Object "System.Version" 7, 5
	if ($wizard.SelectedApplication.EPiServerVersion -lt $supportedVersion) 
	{
		$framework = Get-EPiProductInformation -ProductName "EPiServerFramework" -ProductVersion "7.5.394.2"
		if (-not $framework.IsInstalled)
		{
			Show-Message("Can't find required version of EPiServer Framework") 
			break
		}
		$apiPath = "$($framework.InstallationPath)\Install\Tools" ;
		echo "Using ApiPath $apiPath"
	}
	
	echo "Reading Add-On feeds configured on $appPath ..."
	$feeds = Get-EPiAddOnFeeds -ApplicationPath $appPath -ApiPath $apiPath

	$selectApp = $false
	do {
		$menu=@("- Installed") + $feeds + @("- Install from file(s)", "- Remove Add-On", "- Update Add-On", "- Disable Add-On", "- Enable Add-On", "- Select another site", "- Exit")
		$choice = $null
		$choice = $menu | Out-GridView -PassThru -Title "Select an action for site $appPath"
		if ($choice -eq $null) {
			$exit = $true
			Break
		}
		switch ($choice)
		{
			"- Installed" {
				echo "Reading Add-Ons installed on $appPath ..."
				Get-EPiAddOns -ApplicationPath $appPath -ApiPath $apiPath | Select Id, Title, Version, Authors, IsSystemPackage, IsDisabled, CanBeDisabled, CanBeUninstalled, CompatibleDependencies  | Out-GridView -Title "Installed Add-Ons on $appPath" -PassThru | Out-Null
			}
			"- Install from file(s)" {
				$files = Get-FileNames -initialDirectory "c:\"
				if ($files -ne $null -and $files.Length -gt 0) 
				{
					Write-Host "Installing Add-On $files to $appPath"
					Add-EPiAddOn -ApplicationPath $appPath -ApiPath $apiPath -Files $files | %{$_.Package} | Select Id, Title, Version, IsInstalled
				}
			}
			"- Remove Add-On" {
				echo "Reading Add-Ons that can be removed from $appPath ..."
				$selectableAddOns = Get-EPiAddOns -ApplicationPath $appPath -ApiPath $apiPath | Where-Object {$_.CanBeUninstalled -or $_.IsDisabled} | Select Id, Title, Version,  Authors, CompatibleDependencies
				if ($selectableAddOns -ne $null) 
				{
					$addOnToRemove = $selectableAddOns | Out-GridView -Title "Select Add-On to remove from $appPath" -PassThru
					if ($addOnToRemove -ne $null)
					{
						$confirmed = Get-Confirmation("Are you sure you want to remove  $($addOnToRemove.Id) from $appPath ?");
						if ($confirmed -eq "YES") 
						{
							echo "Removing Add-On $($addOnToRemove.Id) from $appPath ..."
							Remove-EPiAddOn -ApplicationPath $appPath -ApiPath $apiPath -Id $addOnToRemove.Id | Select Id, Title, Version, IsInstalled
						}
					}
				}
				else 
				{
					Show-Message("There is no add-ons on $appPath that can be removed") | Out-Null
				}				
			}
			"- Update Add-On" {
				echo "Reading Add-Ons that can be updated on $appPath ..."
				$selectableAddOns = Get-EPiAddOns -ApplicationPath $appPath -ApiPath $apiPath | Where-Object {$_.AvailableUpdate -ne $null} | Select Id, Title, Version,  Authors, AvailableUpdate, CompatibleDependencies
				if ($selectableAddOns -ne $null) 
				{
					$addOnToUpdate = $selectableAddOns | Out-GridView -Title "Select Add-On to update on $appPath" -PassThru
					if ($addOnToUpdate -ne $null)
					{
						$confirmed = Get-Confirmation("Are you sure you want to update  $($addOnToUpdate.Id) on $appPath ?");
						if ($confirmed -eq "YES") 
						{
							echo "Updating Add-On $($addOnToUpdate.Id) from version $($addOnToUpdate.Version) to version $($addOnToUpdate.AvailableUpdate.Version) on $appPath ..."
							Update-EPiAddOn -ApplicationPath $appPath -ApiPath $apiPath -Id $addOnToUpdate.AvailableUpdate.Id -Version $addOnToUpdate.AvailableUpdate.Version | Select Id, Version, IsInstalled
						}
					}
				}
				else 
				{
					Show-Message("There is no add-ons on $appPath that can be updated") | Out-Null
				}
			}
			"- Disable Add-On" {
				echo "Reading Add-Ons that can be disabled on $appPath ..."
				$selectableAddOns = Get-EPiAddOns -ApplicationPath $appPath -ApiPath $apiPath | Where-Object {$_.CanBeDisabled} | Select Id, Title, Version, Authors, CompatibleDependencies 
				if ($selectableAddOns -ne $null) 
				{				
					$addOnToDisable = $selectableAddOns | Out-GridView -Title "Select Add-On to disable on $appPath" -PassThru
					if ($addOnToDisable -ne $null)
					{
						$confirmed = Get-Confirmation("Are you sure you want to disable  $($addOnToDisable.Id) on $appPath ?");
						if ($confirmed -eq "YES") 
						{
							echo "Disabling Add-On $($addOnToDisable.Id) on $appPath ..."
							Disable-EPiAddOn -ApplicationPath $appPath -ApiPath $apiPath -Id $addOnToDisable.Id | Select Id, Title, Version, IsDisabled
						}
					}
				}
				else 
				{
					Show-Message("There is no add-ons on $appPath that can be disabled") | Out-Null
				}
			}
			"- Enable Add-On" {
				echo "Reading Add-Ons that can be enabled on $appPath ..."
				$selectableAddOns = Get-EPiAddOns -ApplicationPath $appPath -ApiPath $apiPath | Where-Object {$_.IsDisabled -eq $true} | Select Id, Title, Version, Authors, CompatibleDependencies
				if ($selectableAddOns -ne $null) 
				{
					$addOnToEnable = $selectableAddOns | Out-GridView -Title "Select Add-On to enable on $appPath" -PassThru
					if ($addOnToEnable -ne $null)
					{
						$confirmed = Get-Confirmation("Are you sure you want to enable  $($addOnToEnable.Id) on $appPath ?");
						if ($confirmed -eq "YES") 
						{
							echo "Enabling Add-On $($addOnToEnable.Id) on $appPath ..."
							Enable-EPiAddOn -ApplicationPath $appPath -ApiPath $apiPath -Id $addOnToEnable.Id | Select Id, Title, Version, IsDisabled
						}
					}
				}
				else 
				{
					Show-Message("There is no add-ons on $appPath that can be enabled") | Out-Null
				}
			}
			"- Select another site" {
				$selectApp = $true
			}
			"- Exit" {
				$exit = $true
			}
			default {
				echo "Reading Add-Ons from feed '$choice' that can be installed on $appPath ..."
				$selectableAddOns = Get-EPiAddOns -ApplicationPath $appPath -ApiPath $apiPath -FeedName $choice | Select Id, Title, Version, Authors, CompatibleDependencies
				if ($selectableAddOns -ne $null) 
				{
					$selectedAddOn = $selectableAddOns | Out-GridView -Title "Select Add-On to install from $choice feed on $appPath" -PassThru
					if ($selectedAddOn -ne $null) 
					{
						$confirmed = Get-Confirmation("Are you sure you want to install  $($selectedAddOn.Id) on $appPath ?");
						if ($confirmed -eq "YES") 
						{
							Write-Host "Installing Add-On $($selectedAddOn.Id) to $appPath"
							Add-EPiAddOn -ApplicationPath $appPath -ApiPath $apiPath -Id $selectedAddOn.Id -Version $selectedAddOn.Version | Select Id, Title, Version, IsInstalled
						}
					}
				}
				else 
				{
					Show-Message("There is no add-ons in $choice feed that can be installed on $appPath") | Out-Null
				}
			}
		}
	}
	while (-not $exit -and -not $selectApp)
}
while (-not $exit)

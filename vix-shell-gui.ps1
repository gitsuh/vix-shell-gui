$inputXML = @"
<Window x:Name="window_main" x:Class="WpfApp1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApp1"
        mc:Ignorable="d"
        Title="Virtual Shell" Height="480" Width="530">
    <Grid Margin="0,0,2,0">
        <TextBox x:Name="txtbox_vcentertarget" HorizontalAlignment="Left" Height="23" Margin="10,40,0,0" TextWrapping="Wrap" Text="vCenter" VerticalAlignment="Top" Width="306"/>
        <TextBox x:Name="textbox_vmtarget" HorizontalAlignment="Left" Height="23" Margin="10,96,0,0" TextWrapping="Wrap" Text="Virtual Machine Name" VerticalAlignment="Top" Width="306"/>
        <Button x:Name="button_copytoguest" Content="Copy To Guest" HorizontalAlignment="Left" Margin="321,183,0,0" VerticalAlignment="Top" Width="108"/>
        <Button x:Name="button_copytolocal" Content="Copy To Local" HorizontalAlignment="Left" Margin="321,155,0,0" VerticalAlignment="Top" Width="108"/>
        <TextBox x:Name="textbox_localtarget" HorizontalAlignment="Left" Height="23" Margin="10,152,0,0" TextWrapping="Wrap" Text="Local File or Folder" VerticalAlignment="Top" Width="306"/>
        <TextBox x:Name="textbox_guesttarget" HorizontalAlignment="Left" Height="23" Margin="10,180,0,0" TextWrapping="Wrap" Text="Guest File or Folder" VerticalAlignment="Top" Width="306"/>
        <CheckBox x:Name="checkbox_fileoverwrite" Content="Overwrite" HorizontalAlignment="Left" Margin="436,169,0,0" VerticalAlignment="Top" Width="67" RenderTransformOrigin="0.448,2.615"/>
        <Button x:Name="button_loginvcenter" Content="Login" HorizontalAlignment="Left" Margin="321,40,0,0" VerticalAlignment="Top" Width="75"/>
        <Label x:Name="label_vCenterStatus" Content="Not connected to any vCenter Server" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Width="386" BorderThickness="1"/>
        <Label x:Name="label_vmtargetstatus" Content="No target VM" HorizontalAlignment="Left" Margin="10,68,0,0" VerticalAlignment="Top" Width="386"/>
        <Button x:Name="button_targetvm" Content="Target VM" HorizontalAlignment="Left" Margin="321,96,0,0" VerticalAlignment="Top" Width="75"/>
        <TextBox x:Name="textbox_commandinput" HorizontalAlignment="Left" Height="20" Margin="10,404,0,0" TextWrapping="Wrap" Text="Enter command" VerticalAlignment="Top" Width="391"/>
        <Button x:Name="button_sendcommand" Content="Send Command" HorizontalAlignment="Left" Margin="406,404,0,0" VerticalAlignment="Top" Width="103"/>
        <TextBox x:Name="textbox_resultoutput" HorizontalAlignment="Left" Height="189" Margin="10,210,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="499"/>
        <Button x:Name="button_setcredentials" Content="Set Credential" HorizontalAlignment="Left" Margin="401,40,0,0" VerticalAlignment="Top" Width="75" Height="20"/>
        <Label x:Name="label_vcentercredential" Content="No vCenter cred" HorizontalAlignment="Left" Margin="401,10,0,0" VerticalAlignment="Top" RenderTransformOrigin="-0.528,0.609" Width="106"/>
        <Label x:Name="label_vmtoolsstatus" Content="VMTools status" HorizontalAlignment="Left" Margin="406,68,0,0" VerticalAlignment="Top" Width="101"/>
        <Label x:Name="label_filestatus" Content="No target VM" HorizontalAlignment="Left" Margin="10,124,0,0" VerticalAlignment="Top" Width="306"/>
        <Button x:Name="button_guestcredential" Content="Set Guest Credential" HorizontalAlignment="Left" Margin="321,127,0,0" VerticalAlignment="Top" Width="108"/>
        <Label x:Name="label_guestcredential" Content="No guest cred" HorizontalAlignment="Left" Margin="406,96,0,0" VerticalAlignment="Top"/>
    </Grid>
</Window>
"@
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'
 
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
  try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}
 
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}
 
Function Get-FormVariables{
get-variable WPF*
}
$vars = Get-FormVariables
if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
}
Import-Module VMware.VimAutomation.Core
 
#$vmpicklistView.items.Add([pscustomobject]@{'VMName'=($_).Name;Status=$_.Status;Other="Yes"})
$script:connection_vcenter = $null
$script:connection_vcentercredential = $null
$script:connection_guestcredential = $null
$script:target_vms = $null
$script:file_local = $null
$script:file_guest = $null

function onclick_button_loginvcenter {
	$WPFlabel_vCenterStatus.Content = "Attempting to connect to vCenter..."
	$connection = $null
	if($script:connection_vcentercredential){
		$connection = connect-viserver -server $WPFtxtbox_vcentertarget.Text -credential $script:connection_vcentercredential
		if($connection){	
			$WPFlabel_vCenterStatus.Content = "Connected to $connection"
			return $connection
		}else{
			$WPFlabel_vCenterStatus.Content = "Could not connect to vCenter"
			return $null
			}
	}else{
		$WPFlabel_vCenterStatus.Content = "Must load credentials."
		return $null
	}
}

function onclick_button_setvcentercredentials {
	$cred = $null
	$cred = get-credential
	if($cred){
		$script:connection_vcentercredential = $cred
		$WPFlabel_vcentercredential.Content = $script:connection_vcentercredential.getNetworkCredential().domain + "\" + $script:connection_vcentercredential.getNetworkCredential().username
	}else{
		write-host "cred is null"
	}
	return $cred
	}
function onclick_button_setguestcredentials {
	$cred = $null
	$cred = get-credential
	if($cred){
		$script:connection_guestcredential = $cred
		$WPFlabel_guestcredential.Content = $script:connection_guestcredential.getNetworkCredential().domain + "\" + $script:connection_guestcredential.getNetworkCredential().username
	}else{
		write-host "Credential is null"
	}
	return $cred
	}

function onclick_button_targetvm {
	$vms = $null
	if($script:connection_vcenter){
		$WPFlabel_vmtargetstatus.Content = "Attempting to retrieve VMs..."
		$vms = get-vm -name ($WPFtextbox_vmtarget.Text)
		if($vms){
			write-host $vms.length
			$WPFlabel_vmtargetstatus.Content = "Retrieved VM: $vms"
			$WPFlabel_vmtoolsstatus.Content = "Tools are " + ($vms | get-view).guest.GuestOperationsReady
			return $vms
		}else{
			$WPFlabel_vmtargetstatus.Content = "Could not retrieve VMs"
			return $null
			}
	}else{
		$WPFlabel_vmtargetstatus.Content = "Must be connected to vCenter."
		return $null
	}
}

function validate-fileordir {
param (
	[string]$filestring
)
	$tempstr = $null
	$tempstr = $filestring.Substring($filestring.get_length()-1)
	if($tempstr){
		if($tempstr -eq "/"){
			return "path"
		}elseif($tempstr -eq "\"){
			return "path"
		}else{
			return "file"
		}
	}else{
		return $null
	}
}

function copy-file-toguest {
$result = $null
$copycred = $null
	if($script:target_vms){
		if($script:connection_guestcredential){
			if(($script:target_vms.GuestId).StartsWith("win") -eq $True){$copycred = $script:connection_guestcredential.getNetworkCredential().domain + "\" + $script:connection_guestcredential.getNetworkCredential().username}else{$copycred = $script:connection_guestcredential.getNetworkCredential().username}
				if( (get-vm $script:target_vms | get-view).guest.GuestOperationsReady -eq "True"){
					if(validate-fileordir -filestring ($WPFtextbox_localtarget.text) -eq "file"){
						if(validate-fileordir -filestring ($WPFtextbox_guesttarget.text) -eq "path"){
							if($WPFcheckbox_fileoverwrite.IsChecked -eq "True"){
								$result = Copy-VMGuestFile -source $WPFtextbox_localtarget.text -destination $WPFtextbox_guesttarget.text -localtoguest -Force -VM $script:target_vms -GuestUser $copycred -GuestPassword $script:connection_guestcredential.GetNetworkCredential().Password -Confirm:$false
							}else{
								$WPFtextbox_resultoutput.text = "$script:target_vms $script:connection_guestcredential.getNetworkCredential().username - $script:connection_guestcredential.GetNetworkCredential().Password"
								$result = Copy-VMGuestFile -source $WPFtextbox_localtarget.text -destination $WPFtextbox_guesttarget.text -localtoguest -VM $script:target_vms -GuestUser $copycred -GuestPassword $script:connection_guestcredential.GetNetworkCredential().Password -Confirm:$false
							}
						}else{$WPFlabel_filestatus.text = "Invalid guest string"}
					}else{$WPFlabel_filestatus.text = "Invalid local string"}
				}else{$WPFlabel_filestatus.text = "Tools is not ready"}
		}else{$WPFlabel_filestatus.text = "No guest credentials set"}
	}else{$WPFlabel_filestatus.text = "No targeted VM"}
if($result){
	return $result
}else{
	return $null
}
}

function copy-file-tolocal {
$result = $null
$copycred = $null
	if($script:target_vms){
		if($script:connection_guestcredential){
			if(($script:target_vms.GuestId).StartsWith("win") -eq $True){$copycred = $script:connection_guestcredential.getNetworkCredential().domain + "\" + $script:connection_guestcredential.getNetworkCredential().username}else{$copycred = $script:connection_guestcredential.getNetworkCredential().username}
				if( (get-vm $script:target_vms | get-view).guest.GuestOperationsReady -eq "True"){
					if(validate-fileordir -filestring ($WPFtextbox_guesttarget.text) -eq "file"){
						if(validate-fileordir -filestring ($WPFtextbox_localtarget.text) -eq "path"){
							if($WPFcheckbox_fileoverwrite.IsChecked -eq "True"){
								$result = Copy-VMGuestFile -source $WPFtextbox_guesttarget.text -destination $WPFtextbox_localtarget.text -guesttolocal -Force -VM $script:target_vms -GuestUser $copycred -GuestPassword $script:connection_guestcredential.GetNetworkCredential().Password -Confirm:$false
							}else{
								$result = Copy-VMGuestFile -source $WPFtextbox_guesttarget.text -destination $WPFtextbox_localtarget.text -guesttolocal -VM $script:target_vms -GuestUser $copycred -GuestPassword $script:connection_guestcredential.GetNetworkCredential().Password -Confirm:$false
							}
						}else{$WPFlabel_filestatus.text = "Invalid local string"}
					}else{$WPFlabel_filestatus.text = "Invalid guest string"}
				}else{$WPFlabel_filestatus.text = "Tools is not ready"}
		}else{$WPFlabel_filestatus.text = "No guest credentials set"}
	}else{$WPFlabel_filestatus.text = "No targeted VM"}
if($result){
	return $result
}else{
	return $null
}
}
function onclick_button_sendcommand {
	$result = $null
	$copycred = $null
	$scripttext = $WPFtextbox_commandinput.Text
	
	if(($script:target_vms.GuestId).StartsWith("win") -eq $True){
		$copycred = $script:connection_guestcredential.getNetworkCredential().domain + "\" + $script:connection_guestcredential.getNetworkCredential().username
	}else{
		$copycred = $script:connection_guestcredential.getNetworkCredential().username
	}
	write-host $scripttext
	$result = Invoke-VMScript -ScriptText $scripttext -VM $script:target_vms -GuestUser $copycred -GuestPassword $script:connection_guestcredential.GetNetworkCredential().Password
	$WPFtextbox_resultoutput.Text = $result
}



$WPFbutton_sendcommand.Add_Click({onclick_button_sendcommand})
$WPFbutton_copytoguest.Add_Click({$script:file_move_result = copy-file-toguest})
$WPFbutton_copytolocal.Add_Click({$script:file_move_result = copy-file-tolocal})
$WPFbutton_setcredentials.Add_Click({onclick_button_setvcentercredentials})
$WPFbutton_guestcredential.Add_Click({onclick_button_setguestcredentials})
$WPFbutton_loginvcenter.Add_Click({$script:connection_vcenter = onclick_button_loginvcenter})
$WPFbutton_targetvm.Add_Click({$script:target_vms = onclick_button_targetvm})
$Form.ShowDialog()
if($script:connection_vcenter){disconnect-viserver -server $script:connection_vcenter -Force:$true -confirm:$False}

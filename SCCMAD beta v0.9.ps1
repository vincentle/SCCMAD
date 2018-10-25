#Your XAML goes here :)
$inputXML = @"
<Window x:Class="SCCMAD.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:SCCMAD"
        ResizeMode="NoResize"
        mc:Ignorable="d"
        Title="SCCMAD" Height="586.176" Width="600">
    <Grid Margin="0,0,0,-29" HorizontalAlignment="Right" Width="594" Height="351" VerticalAlignment="Bottom">
        <Grid.ColumnDefinitions>
            <ColumnDefinition/>
            <ColumnDefinition/>
        </Grid.ColumnDefinitions>
        <Image Height="102" Margin="200,-231,196,0" VerticalAlignment="Top" Source="https://image.flaticon.com/icons/svg/25/25231.svg" Grid.ColumnSpan="2"/>

        <TextBox x:Name="Input" Margin="40,-124,125,454" TextWrapping="Wrap" Grid.ColumnSpan="2" RenderTransformOrigin="0.501,0.522"/>
        <Label x:Name="secondTitle" Content="Tool used for removal of devices from SCCM and/or AD" Margin="128,-155,125,0" VerticalAlignment="Top" Grid.ColumnSpan="2" FontWeight="Bold"/>
        <ListView x:Name="Grid" Margin="40,-98,40,107" Grid.ColumnSpan="2">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Name" DisplayMemberBinding ="{Binding Name}" Width="120"/>
                    <GridViewColumn Header="Distinguished Name" DisplayMemberBinding ="{Binding DistinguishedName}" Width="215"/>
                    <GridViewColumn Header="Last Logon" DisplayMemberBinding ="{Binding LastLogonDate}" Width="150"/>
                </GridView>
            </ListView.View>
        </ListView>
        <Button x:Name="OK" Content="GO" Grid.Column="1" Margin="180,-124,40,454" IsDefault="True"/>
        <Button x:Name="SCCM" Content="SCCM" HorizontalAlignment="Left" Margin="127,277,0,56" Width="75"/>
        <Button x:Name="Both" Grid.ColumnSpan="2" Content="Both" Margin="250,277,252,56"/>
        <Button x:Name="AD" Content="AD" Grid.Column="1" Margin="87,277,127,56"/>
        <Label Content="Remove from:" Margin="250,251,250,76" Grid.ColumnSpan="2" FontWeight="Bold"/>
        <TextBlock x:Name="textBlock" HorizontalAlignment="Left" Margin="10,302,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Grid.ColumnSpan="2" Width="567" Height="20"/>
    </Grid>
</Window>
"@ 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML

#Read XAML
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try{
    $Form=[Windows.Markup.XamlReader]::Load( $reader )
}
catch{
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}
#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
  
$xaml.SelectNodes("//*[@Name]") | %{"trying item $($_.Name)";
    try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch{throw}
    }
 
Function Get-FormVariables{
if ($global:ReadmeDisplay -ne $true){Write-Output "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
Write-Output "Found the following interactable elements from the form" -ForegroundColor Cyan
get-variable WPF*
}
 
Get-FormVariables

#Loads Powershell presentation framwork
Add-Type -AssemblyName PresentationCore,PresentationFramework 	
Add-Type -AssemblyName System.Windows.Forms
import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" 
#===========================================================================
# Use this space to add code to the various form elements in your GUI
#===========================================================================


#===========================================================================
# METHODS HERE
#===========================================================================

Function Get-ADDevice{
    param($computername =$env:COMPUTERNAME)
    Get-ADComputer -Filter "name -like '$computername*'" -SearchBase "OU=PLACE,DC=OU,DC=HERE,DC=XXXX" -Properties Name, DistinguishedName, LastLogonDate | Select-Object Name, DistinguishedName, LastLogonDate
}

Function Get-ADVariable{
    param($computername =$env:COMPUTERNAME)
    Get-ADComputer -Filter "name -like '$computername*'" -SearchBase "OU=PLACE,DC=OU,DC=HERE,DC=XXXX" -Properties Name | Select-Object Name
}

Function Get-SCCMDevice{
    param($computername =$env:COMPUTERNAME) 
    cd PLACE SCCM DIRECTORY/SITE HERE:
    Get-CMDevice -name $computername* | Select-Object name
}

Function Delete-ADDevice{
    $data = $item.name
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageIcon = [System.Windows.MessageBoxImage]::Error
    $MessageBody = "Are you sure you want to delete '$data' from AD?"
    $MessageTitle = "Confirm Deletion of Each Object"
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
    Write-Host "Your choice is $Result"
        if($Result -eq "Yes"){
            Remove-ADComputer -Identity $data -Confirm:$false 
            $WPFtextBlock.Text = "Last deleted: '$data'. Good job!"
        }
        else{
            $WPFtextBlock.Text = "Deletion CANCELLED on: '$data'. Good job!"
        }
}

Function Delete-CMDevice{
    $data = $item.name
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageIcon = [System.Windows.MessageBoxImage]::Error
    $MessageBody = "Are you sure you want to delete '$data' from SCCM?"
    $MessageTitle = "Confirm Deletion of Each Object"
    $Result = [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
    Write-Host "Your choice is $Result"
        if($Result -eq "Yes"){
            Remove-CMDevice -DeviceName $data -force -ErrorAction Stop
            $WPFtextBlock.Text = "Last deleted: '$data'. Good job!"
        }
        else{
            $WPFtextBlock.Text = "Deletion CANCELLED on: '$data'. Good job!"
        }
}

Function Create-ErrorMessage{
    $warning = $_
    $WPFtextBlock.Text = "ERROR: $warning"
}
#===========================================================================
# EVENTS
#===========================================================================

#Populates ListView with computer info after clicking OK button
$WPFOK.Add_Click({
    $WPFGrid.Items.Clear()
    $WPFtextBlock.Text = ""
    try{
        if ([string]::IsNullOrWhiteSpace($WPFInput.Text)){
            $WPFtextBlock.Text = "ERROR: EMPTY STRING/WHITESPACE, TYPE SOMETHING CMON"
        }
        else{
            #Takes input and turns device names into array for parsing
            $adv = Get-ADVariable -computername $WPFInput.Text
            $scv = Get-SCCMDevice -computername $WPFInput.Text
            write-host $adv
            write-host $scv
            $ADarr = $adv.name -split ' '
            $SCarr = $scv.name -split ' '
            $SCCMADarr = $ADarr + $SCarr
            $uniq = $SCCMADarr | select -uniq
            write-host $uniq
            write-host $SCCMADarr[0]
            $meme = "@{name=||SCCM DEVICES BELOW||}"
            if($adv){
                foreach($name in $ADarr){
                    Get-ADDevice -computername $name | % {$WPFGrid.AddChild($_)}
                }
                if($scv){
                    #Adds break between AD devices and SCCM devices
                    $WPFGrid.AddChild($meme)
                    foreach($name in $SCarr){
                        Get-SCCMDevice -computername $name | % {$WPFGrid.AddChild($_)}
                    }
                    $WPFtextBlock.Text = "NOTICE: Devices found in both databases. Be sure to match names before deletion."
                }
                else{
                    $WPFtextBlock.Text = "NOTICE: Device found in AD"
                    write-host 'variable is null' -ErrorAction Stop
                }
            }
            elseif($scv){
                foreach($name in $SCarr){
                    Get-SCCMDevice -computername $name | % {$WPFGrid.AddChild($_)}
                    $WPFtextBlock.Text = "NOTICE: Device found in SCCM"
                }
            }
            else{
                $WPFtextBlock.Text = "ERROR: Device not found"
                write-host 'variable is null' -ErrorAction Stop
            }
        }
    }
    catch{
        Create-ErrorMessage
    }
})

#Executes Delete-ADDevice after clicking AD button
$WPFAD.Add_Click({
    try{
        foreach($item in $WPFGrid.SelectedItems){ 
            Delete-ADDevice
        }
    }
    catch{
        Create-ErrorMessage
    }
})

#Executes Delete-CMDevice after clicking SCCM
$WPFSCCM.Add_Click({
    try{
        foreach($item in $WPFGrid.SelectedItems){ 
            Delete-CMDevice
        }
    }
    catch{
        Create-ErrorMessage
    }
})

#Executes both Delete methods after clicking Both
$WPFBoth.Add_Click({
    try{
        foreach($item in $WPFGrid.SelectedItems){ 
            Delete-ADDevice
        }
    }
    catch{
        Create-ErrorMessage
    }
    
    try{
        foreach($item in $WPFGrid.SelectedItems){ 
            Delete-CMDevice
        }
    }
    catch{
        Create-ErrorMessage
    }
})

#Reference 
 
#Adding items to a dropdown/combo box
    #$vmpicklistView.items.Add([pscustomobject]@{'VMName'=($_).Name;Status=$_.Status;Other="Yes"})
     
#Setting the text of a text box to the current PC name    
    #$WPFtextBox.Text = $env:COMPUTERNAME
     
#Adding code to a button, so that when clicked, it pings a system
# $WPFbutton.Add_Click({ Test-connection -count 1 -ComputerName $WPFtextBox.Text
# })
#===========================================================================
# Shows the form
#===========================================================================
#write-host "To show the form, run the following" -ForegroundColor Cyan
$Form.ShowDialog() | out-null

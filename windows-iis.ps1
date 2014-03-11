# Windows Server 2012 on Amazon AWS c3.large

# ASP.NET
Write-Host "Installing IIS, .NET and ASP.NET..."

# Enable Windows Update to get rid of the yellow warnings
# But this is not strictly neccessary
$Updates = (New-Object -ComObject "Microsoft.Update.AutoUpdate").Settings
$Updates.NotificationLevel = 2 # Notify before download
$Updates.Save()
$Updates.Refresh()

Install-WindowsFeature Web-Server
Install-WindowsFeature Web-Mgmt-Console
Install-WindowsFeature NET-Framework-45-ASPNET
Install-WindowsFeature Web-Asp-Net45
Install-WindowsFeature Web-Stat-Compression
Install-WindowsFeature Web-Dyn-Compression

# swap
$RAM = Get-WmiObject -Class Win32_OperatingSystem | Select TotalVisibleMemorySize
$RAM = ($RAM.TotalVisibleMemorySize / 1kb).tostring("F00")
wmic computersystem set AutomaticManagedPagefile=False
wmic pagefileset delete
wmic pagefileset create name=`"Z:\pagefile.sys`"
wmic pagefileset create name=`"Y:\pagefile.sys`"
foreach ($PageFile in Get-WmiObject -Class Win32_PageFileSetting)
{
  $PageFile.InitialSize = $RAM
  $PageFile.MaximumSize = $RAM
  [void]$PageFile.Put()
}
wmic pagefileset

# todo: IIS ignores this :(
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v TEMP /d "Z:\TEMP" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v TMP /d "Z:\TEMP" /f
New-Item -Path Z:\TEMP -Type Directory
&icacls Z:\TEMP /grant "Everyone:F"
#&icacls C:\Windows\TEMP /grant "Everyone:(OI)(CI)F"

# change administrator password
([adsi]"WinNT://$env:COMPUTERNAME/Administrator").SetPassword("Adm123!")

# firewall
netsh firewall add portopening protocol = TCP port = 80 name = Web mode = ENABLE scope = ALL  profile = CURRENT

# IIS
Remove-WebSite -Name 'Default Web Site'
$web = 'C:\www\web'
New-Item -Path $web -Type Directory
New-WebSite -Name Web -Port 80 -PhysicalPath $web

# dynamic compression
$env:Path += ";C:\Windows\system32\inetsrv"; [Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
#appcmd set config -section:system.webServer/httpErrors -errorMode:Detailed
appcmd set config /section:urlCompression /doDynamicCompression:True
appcmd set config /section:httpCompression /[name=`'gzip`'].staticCompressionLevel:9 /[name=`'gzip`'].dynamicCompressionLevel:9

# user & share for deployment
NET USER deployment "Dep123!" /ADD
NET SHARE www=C:\www "/GRANT:deployment,FULL"

# box-setup.ps1 - set up recording tools inside an isolated analysis VM (run in an elevated PowerShell inside the VM).
# Installs: Sysmon (with the public SwiftOnSecurity config), Process Monitor, Autoruns. Creates desktop shortcuts.
# No company data, no secrets. Safe to re-run.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tools = 'C:\Tools'
New-Item -ItemType Directory -Force -Path $tools | Out-Null
$dl = @{
  'Sysmon.zip'         = 'https://download.sysinternals.com/files/Sysmon.zip'
  'ProcessMonitor.zip' = 'https://download.sysinternals.com/files/ProcessMonitor.zip'
  'Autoruns.zip'       = 'https://download.sysinternals.com/files/Autoruns.zip'
  'sysmonconfig-export.xml' = 'https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml'
}
foreach ($name in $dl.Keys) {
  $dst = Join-Path $tools $name
  Write-Host ("downloading {0} ..." -f $name)
  Invoke-WebRequest -Uri $dl[$name] -OutFile $dst -UseBasicParsing
}
foreach ($z in 'Sysmon.zip','ProcessMonitor.zip','Autoruns.zip') {
  Expand-Archive -Path (Join-Path $tools $z) -DestinationPath $tools -Force
}
# accept EULAs silently (Sysinternals)
foreach ($k in 'Sysmon','Sysmon64','Process Monitor','Autoruns','Autoruns64') {
  New-Item -Path ("HKCU:\Software\Sysinternals\{0}" -f $k) -Force | Out-Null
  New-ItemProperty -Path ("HKCU:\Software\Sysinternals\{0}" -f $k) -Name EulaAccepted -Value 1 -PropertyType DWord -Force | Out-Null
}
# install Sysmon as a service with the public config
$sysmon = Join-Path $tools 'Sysmon64.exe'
if (-not (Test-Path $sysmon)) { $sysmon = Join-Path $tools 'Sysmon.exe' }
$svc = Get-Service -Name Sysmon64 -ErrorAction SilentlyContinue
if ($svc) { & $sysmon -c (Join-Path $tools 'sysmonconfig-export.xml') | Out-Null }
else { & $sysmon -accepteula -i (Join-Path $tools 'sysmonconfig-export.xml') | Out-Null }
# desktop shortcuts
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
foreach ($pair in @(@('Process Monitor','Procmon64.exe'), @('Autoruns','Autoruns64.exe'))) {
  $exe = Join-Path $tools $pair[1]
  if (Test-Path $exe) {
    $sc = $ws.CreateShortcut((Join-Path $desktop ($pair[0] + '.lnk')))
    $sc.TargetPath = $exe; $sc.WorkingDirectory = $tools; $sc.Save()
  }
}
# a folder for samples and logs
New-Item -ItemType Directory -Force -Path 'C:\Box\in','C:\Box\logs' | Out-Null
$sysmonState = (Get-Service -Name Sysmon64 -ErrorAction SilentlyContinue).Status
Write-Host ''
Write-Host ("DONE  tools: {0}  sysmon service: {1}  samples: C:\Box\in  logs: C:\Box\logs" -f $tools, $sysmonState) -ForegroundColor Green

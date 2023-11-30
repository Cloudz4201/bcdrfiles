# PowerShell Script to Collect Information and Save it as JSON

function Check-BackupSoftwareInstalled {
    param ([string]$softwareName)
    $softwarePattern = "*$softwareName*"
    $installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like $softwarePattern }) -ne $null
    return $installed
}

function Get-LatestEvent {
    param (
        [string]$Source,
        [int[]]$EventIDs,
        [string]$LogName
    )
    try {
        $latestEvents = Get-WinEvent -FilterHashtable @{
            LogName = $LogName
            ProviderName = $Source
            ID = $EventIDs
        } -MaxEvents 1 -ErrorAction Stop
        if ($latestEvents) {
            return $latestEvents[0]
        }
    } catch {
        Write-Host "No events found for source: $Source"
    }
    return $null
}

$backupProduct = ""
if (Check-BackupSoftwareInstalled -softwareName "StorageCraft") {
    $backupProduct = "StorageCraft"
} elseif (Check-BackupSoftwareInstalled -softwareName "Veeam") {
    $backupProduct = "Veeam"
}

$eventSources = @{
    "StorageCraftAgent" = @(1000, 1001, 1002, 1004, 1005, 1006, 1007, 1017, 1008, 1009, 1010, 1018, 1011, 1012, 1013, 1019, 1014, 1015, 1016, 1020)
    "ShadowProtect" = @(1002, 1007, 1120, 1121, 1122)
    "ShadowProtect SPX" = @(1, 2, 3, 4, 5)
    "stcvsm" = @(1, 2, 6, 7, 13, 15, 260, 263, 265, 1283)
    "StorageCraft ImageManager" = @(1120, 1121, 1122, 1123, 1124, 1125, 1126, 1127, 1128, 1129)
    "Veeam Agent" = @(110, 115, 190, 191, 195, 196, 197, 4010, 4020, 4030, 4025, 4040, 4050, 4060, 10010, 10050, 23010, 23050, 23090, 23051, 23501, 23110, 23120, 26010, 178, 179, 201, 202)
    "User32" = @(1074) # This event is logged under the System log
}

$foundEvents = @()
foreach ($source in $eventSources.Keys) {
    $logName = if ($source -eq 'User32') { 'System' } else { 'Application' }
    $event = Get-LatestEvent -Source $source -EventIDs $eventSources[$source] -LogName $logName
    if ($event) {
        $foundEvents += $event
    }
}

$mostRecentEvent = $foundEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1

$logFilePath = "C:\Program Files (x86)\StorageCraft\ImageManager\Logs\ImageManager.log"
$spLogEntries = if (Test-Path $logFilePath) {
    (Get-Content $logFilePath -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
} else {
    "Log file not found"
}

$currentTime = Get-Date -Format "MM/dd/yyyy hh:mm tt -1300"

$info = @{
    'Client Name'  = 'Valve Services'
    time = if ($mostRecentEvent) { $mostRecentEvent.TimeCreated.ToString() } else { "No recent successful backup found." }
    eventmessage = if ($mostRecentEvent) { $mostRecentEvent.Message } else { "No recent successful backup found." }
    eventid = if ($mostRecentEvent) { $mostRecentEvent.Id.ToString() } else { "No Event ID" }
    type = $backupProduct
    device = [System.Net.Dns]::GetHostName()
    splog = $spLogEntries
    lastupdated = $currentTime
}

$json = $info | ConvertTo-Json
Set-Content -Path "C:\Temp\output.json" -Value $json

Write-Host "Output.json Has been updated!"

$executablePath = "C:\Temp\UPDATER.exe"

if (Test-Path $executablePath) {
    Start-Process $executablePath
} else {
    Write-Host "Executable not found: $executablePath"
}

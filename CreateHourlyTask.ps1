# PowerShell Script to Create a Scheduled Task

# Define the task properties
$scriptPath = "C:\Temp\InfoGatherer.ps1"  # Path to your PowerShell script
$taskName = "InfoGathererHourlyTask"  # Name of the scheduled task
$taskDescription = "Runs InfoGatherer.ps1 script every hour."

# Create the task action to run the PowerShell script
$taskAction = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoProfile -File `"$scriptPath`""

# Create the task trigger for hourly execution
$taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 3650) # 10 years

# Set the task to run as SYSTEM to ensure it has the necessary privileges
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task (if it doesn't already exist)
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal
    Write-Host "Scheduled task '$taskName' created to run the script every hour."
} else {
    Write-Host "Scheduled task '$taskName' already exists."
}

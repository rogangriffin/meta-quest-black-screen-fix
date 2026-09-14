# Requires: an authorized ADB connection to the Quest.
# Optional: set QUEST_SERIAL if more than one authorized device is listed.

$ErrorActionPreference = "Stop"
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Meta Quest Developer Hub\resources\bin\adb.exe"),
        (Join-Path ${env:ProgramFiles} "Meta Quest Developer Hub\resources\bin\adb.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Meta Quest Developer Hub\resources\bin\adb.exe")
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Invoke-Adb {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $script:Adb @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$Adb = Find-Adb
if (-not $Adb) {
    Write-Host "adb was not found."
    Write-Host "Install Meta Quest Developer Hub or Android SDK Platform Tools, then either add adb to PATH or keep MQDH installed."
    Write-Host
    Read-Host "Press Enter to close"
    exit 1
}

$QuestSerial = $env:QUEST_SERIAL

Write-Host "Waiting for the Quest 2 over ADB..."
$connected = $false

for ($attempt = 1; $attempt -le 90; $attempt++) {
    $state = ""
    try {
        $deviceList = & $Adb devices 2>$null
        if ($QuestSerial) {
            $state = ((& $Adb -s $QuestSerial get-state 2>$null) | Out-String).Trim()
        } else {
            $authorized = @()
            foreach ($line in @($deviceList)) {
                if ($line -match '^\s*(\S+)\s+device(\s|$)') {
                    $authorized += $Matches[1]
                }
            }
            if ($authorized.Count -eq 1) {
                $QuestSerial = $authorized[0]
                $state = "device"
            }
        }
    } catch {
        $state = ""
    }

    if ($state -eq "device" -and $QuestSerial) {
        $connected = $true
        break
    }

    Start-Sleep -Seconds 1
}

if (-not $connected) {
    Write-Host
    Write-Host "The headset was not found after 90 seconds."
    Write-Host "Make sure it is on, connected, and (if using wireless debugging) on the same Wi-Fi."
    Write-Host "If multiple authorized devices are listed, run this script as:"
    Write-Host '  $env:QUEST_SERIAL="<device ID>"; .\Restore-QuestDisplay.ps1'
    Write-Host
    & $Adb devices -l
    Write-Host
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "Headset connected as $QuestSerial. Applying the display recovery override..."

Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "setprop", "debug.oculus.sysPropDebug", "1")
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "setprop", "debug.oculus.colorspace.use_typical_chromaticities", "1")
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "setprop", "debug.oculus.visualizeLayers", "0")
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "setprop", "debug.oculus.showAlpha", "0")

Write-Host "Restarting the VR compositor..."
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "am", "force-stop", "com.oculus.systemdriver")
Start-Sleep -Seconds 6

Write-Host "Restarting Home..."
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "am", "force-stop", "com.oculus.vrshell")
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "am", "start", "-n", "com.oculus.vrshell/.HomeActivity")
Start-Sleep -Seconds 3
Invoke-Adb -Arguments @("-s", $QuestSerial, "shell", "am", "broadcast", "-a", "com.oculus.vrpowermanager.prox_close")

$applied = ((& $Adb -s $QuestSerial shell getprop debug.oculus.colorspace.use_typical_chromaticities) | Out-String).Trim()
if ($applied -ne "1") {
    Write-Host "The headset connected, but the display override was not accepted."
    Write-Host
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host
Write-Host "Done. Normal headset color should now be restored."
Write-Host "You can close this window."
Write-Host
Read-Host "Press Enter to close"

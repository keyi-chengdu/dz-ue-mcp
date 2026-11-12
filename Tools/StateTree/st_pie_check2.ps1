param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -and $txt.Trim()) {
        if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
        return (($txt | ConvertFrom-Json).result.content[0].text)
      }
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 600
  }
  return $null
}

$id = 2100

# 1) Accessed None 调用栈（LogScript 类别）
$le = Call (++$id) 'EditorToolset.LogsToolset' 'GetLogEntries' @{ category = 'LogScript'; pattern = 'Accessed None'; maxEntries = 3 }
Write-Output ("=== SCRIPT NONE x3 ===")
Write-Output ($le | Out-String)

# 2) 敌人位置采样 1
$e1 = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'find_actors' @{ name = 'Enemy'; limit = 30 }
Write-Output ("=== ENEMIES T1 ===")
Write-Output ($e1 | Out-String)

Start-Sleep -Seconds 6

# 3) 敌人位置采样 2（对比是否移动）
$e2 = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'find_actors' @{ name = 'Enemy'; limit = 30 }
Write-Output ("=== ENEMIES T2 (+6s) ===")
Write-Output ($e2 | Out-String)

# 4) StateTree 全部日志（不过滤）
$le2 = Call (++$id) 'EditorToolset.LogsToolset' 'GetLogEntries' @{ category = 'LogStateTree'; pattern = ''; maxEntries = 30 }
Write-Output ("=== STATETREE ALL x30 ===")
Write-Output ($le2 | Out-String)

Write-Output "PIE-CHECK DONE"

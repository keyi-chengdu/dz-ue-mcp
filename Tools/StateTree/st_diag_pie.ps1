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

$id = 2600

# 1) 加载关卡 + PIE
$lv = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'load_level' @{ level_path = '/Game/Maps/Test_Level/Lv_Test_AI' }
Write-Output ("LOAD: " + $lv)
$pie = Call (++$id) 'EditorToolset.EditorAppToolset' 'StartPIE' @{ options = @{ bSimulate = $false; playMode = 'PlayMode_InViewPort'; warmupSeconds = 30 } }
Write-Output ("PIE len=$($pie.Length)")
Start-Sleep -Seconds 12

# 2) 诊断日志
$le = Call (++$id) 'EditorToolset.LogsToolset' 'GetLogEntries' @{ category = 'LogDZAI'; pattern = ''; maxEntries = 40 }
Write-Output ("=== LogDZAI ===")
Write-Output ($le | Out-String)

Write-Output "DIAG DONE"

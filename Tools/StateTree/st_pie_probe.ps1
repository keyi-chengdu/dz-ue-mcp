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

$id = 2000

# 1) StateTree/NetParam/Error 相关日志
foreach ($cat in @('', 'LogStateTree')) {
  $args_ = @{ pattern = 'Error|Warning|NetParam|StateTree'; maxEntries = 60 }
  if ($cat) { $args_.category = $cat } else { $args_.Remove('category') }
  $le = Call (++$id) 'EditorToolset.LogsToolset' 'GetLogEntries' $args_
  Write-Output ("=== LOGS cat='${cat}' ===")
  Write-Output ($le | Out-String)
}

# 2) PIE 是否在跑 + 敌人 actor
$pie = Call (++$id) 'EditorToolset.EditorAppToolset' 'IsPIERunning' @{}
Write-Output ("PIE running: " + $pie)

$en = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'find_actors' @{ search = 'Enemy'; limit = 20 }
Write-Output ("ENEMIES: " + $en)

Write-Output "PROBE-PIE DONE"

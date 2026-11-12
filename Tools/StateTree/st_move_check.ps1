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

$id = 2200

$fa = @{ name = ''; tag = ''; actor_type = @{ refPath = '/Script/DZProject.DZEnemyCharacter' } }

# 采样 1
$e1 = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'find_actors' $fa
Write-Output ("=== T1 ===")
Write-Output ($e1 | Out-String)
Start-Sleep -Seconds 8
# 采样 2
$e2 = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'find_actors' $fa
Write-Output ("=== T2 (+8s) ===")
Write-Output ($e2 | Out-String)

Write-Output "MOVE-CHECK DONE"

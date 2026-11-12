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

$id = 2300

foreach ($n in 0..1) {
  $p = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'get_properties' @{ instance = @{ refPath = "/Game/Maps/Test_Level/Lv_Test_AI.Lv_Test_AI:PersistentLevel.BP_Enemy_C_${n}" }; properties = @('AssetID','EnemyAreaID') }
  Write-Output ("BP_Enemy_C_${n}: " + $p)
}

# 找关卡里是否有敌人生成器 actor
$fa = @{ name = 'Spawn'; tag = ''; collision_channels = @() }
$sp = Call (++$id) 'editor_toolset.toolsets.scene.SceneTools' 'find_actors' $fa
Write-Output ("SPAWNERS: " + $sp)

Write-Output "PROBE3 DONE"

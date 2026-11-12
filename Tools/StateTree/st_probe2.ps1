param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'

function Call($id, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = 'DZStateTreeToolset.DZStateTreeEditTools'; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 8 -Compress
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

function TreeArg($path) { @{ stateTree = @{ refPath = $path }; targetStructId = $zeroGuid } }
$id = 950

# 全部绑定 dump：看 LAST_SELFATTACKER / 距离 的读写双方
$dumpTrees = @(
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_HurtReaction.ST_Sub_HurtReaction',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle',
  '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)

foreach ($path in $dumpTrees) {
  $name = ($path -replace '.*/','') -replace '\..*',''
  Write-Output "===== BINDINGS $name ====="
  $b = Call (++$id) 'GetPropertyBindings' (TreeArg $path)
  try {
    $binds = ($b | ConvertFrom-Json).returnValue
    $binds | ForEach-Object { Write-Output ("  src='{0}'[{1}] -> dst='{2}'[{3}]" -f $_.sourcePath, $_.sourceStructID, $_.targetPath, $_.targetStructID) }
    Write-Output ("  TOTAL: " + $binds.Count)
  } catch { Write-Output ("  ERR: " + $b) }
}

Write-Output "PROBE2 DONE"

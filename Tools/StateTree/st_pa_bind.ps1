param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'
$netParamGuid = '6E657450-6172-614D-4354-786553746174'

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 400
  }
  return $null
}

$script:id = 4800

function AddBind($treePath, $nodeId, $src, $dst, $label) {
  $r = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $treePath }; binding = @{ sourceStructID = $netParamGuid; sourcePath = $src; targetStructID = $nodeId; targetPath = $dst } }
  $ok = '?'
  $c = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $treePath }; targetStructId = $zeroGuid }
  try { $ok = (($c | ConvertFrom-Json).returnValue).bSucceeded } catch {}
  Write-Output ("BIND {0}: add={1} compile={2}" -f $label, $r, $ok)
}

# ParallelAttack 并行攻击任务
AddBind '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack' '32BC6FED-855F-4AF6-4516-21A5186B8619' 'ATTACK_TARGET' 'InAttackTarget' 'PA.Attack.InAttackTarget'

# ParallelAttack 射线检测（蓝图字段小写 inTargetActor）
AddBind '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack' '34698A08-59FA-AE34-E767-3922A4199576' 'ACTOR_TARGET' 'inTargetActor' 'PA.LineTrace.inTargetActor'

# Battle 转移链射线检测
AddBind '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle' '18696487-1EA7-0FEB-3FCB-DFBFABCB781E' 'ACTOR_TARGET' 'inTargetActor' 'Battle.LineTrace.inTargetActor'

$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "PA-BIND DONE"

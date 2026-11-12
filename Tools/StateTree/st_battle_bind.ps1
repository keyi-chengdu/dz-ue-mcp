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

$id = 3800
$sub = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle'

function AddBind($srcPath, $targetId, $targetPath, $label) {
  $r = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $script:sub }; binding = @{ sourceStructID = $netParamGuid; sourcePath = $srcPath; targetStructID = $targetId; targetPath = $targetPath } }
  Write-Output ("BIND {0}: {1}" -f $label, $r)
}

# 攻击任务：InAttackTarget <- ATTACK_TARGET
AddBind 'ATTACK_TARGET' '8A91E6A5-ACBD-D8D0-132B-5E54CE50B666' 'InAttackTarget' 'Attack.InAttackTarget'

# 移动任务 x3：InActorTarget <- ACTOR_TARGET；InHasPointTarget <- HAS_POINT_TARGET；InTargetPoint <- POINT_TARGET
$moveIds = @(
  @{ id = 'B5369530-168A-9FFD-B60C-A656C82901A8'; label = 'Move-Transfer' },
  @{ id = 'BB0FCBC4-5B86-61A7-F241-3F7A7121058A'; label = 'Move-Wander' },
  @{ id = 'E5ED1BC1-4C17-EF40-3690-CE2D3BC74877'; label = 'Move-OutRange' }
)
foreach ($m in $moveIds) {
  AddBind 'ACTOR_TARGET' $m.id 'InActorTarget' ($m.label + '.InActorTarget')
  AddBind 'HAS_POINT_TARGET' $m.id 'InHasPointTarget' ($m.label + '.InHasPointTarget')
  AddBind 'POINT_TARGET' $m.id 'InTargetPoint' ($m.label + '.InTargetPoint')
}

# 编译 + 保存
$c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $sub }; targetStructId = $zeroGuid }
Write-Output ("COMPILE: " + $c)
$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "BATTLE-BIND DONE"

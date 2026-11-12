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

$id = 4200
$tree = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'

# 1) 删除 3 条悬空绑定
foreach ($dead in @('444984A9-4A94-76DF-8313-04A40C1BF56D','681AAE2C-4082-9B7A-3CDA-1FAC014E6370','6AAFD67F-4BFA-18B8-0FE0-16A3A43EB2E7')) {
  $r = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'RemovePropertyBinding' @{ stateTree = @{ refPath = $tree }; targetStructID = $dead; targetPath = 'in:交战对象' }
  Write-Output ("REMOVE dead ${dead}: " + $r)
}

# 2) 补绑真实「是否有交战对象」条件实例 InAttackTarget <- NetParam.ATTACK_TARGET
foreach ($cid in @('74934E8C-6945-92B1-D6D5-12B1D017C407','9D80ED52-2B88-1C6C-0E03-26E0A4F26C8F','D9E0646B-5F47-E468-3299-32B0B5B22CBE')) {
  $r = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $netParamGuid; sourcePath = 'ATTACK_TARGET'; targetStructID = $cid; targetPath = 'InAttackTarget' } }
  Write-Output ("BIND cond ${cid}.InAttackTarget: " + $r)
}

# 3) 补绑「是否有目标对象」条件实例
$r = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $netParamGuid; sourcePath = 'ACTOR_TARGET'; targetStructID = 'C03E09A6-298F-BD7D-77BD-39A43D54EA09'; targetPath = 'InActorTarget' } }
Write-Output ("BIND CheckHasTarget.InActorTarget: " + $r)
$r = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $netParamGuid; sourcePath = 'HAS_POINT_TARGET'; targetStructID = 'C03E09A6-298F-BD7D-77BD-39A43D54EA09'; targetPath = 'InHasPointTarget' } }
Write-Output ("BIND CheckHasTarget.InHasPointTarget: " + $r)

# 4) 编译 + 保存
$c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $tree }; targetStructId = $zeroGuid }
Write-Output ("COMPILE: " + $c)
$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "COND-FIX DONE"

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

function AddBind($treePath, $condId, $src, $dst, $label) {
  $r = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $treePath }; binding = @{ sourceStructID = $netParamGuid; sourcePath = $src; targetStructID = $condId; targetPath = $dst } }
  Write-Output ("BIND {0}: {1}" -f $label, $r)
  $c = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $treePath }; targetStructId = $zeroGuid }
  $ok = '?'
  try { $ok = (($c | ConvertFrom-Json).returnValue).bSucceeded } catch {}
  Write-Output ("  COMPILE {0}: {1}" -f $treePath, $ok)
}

$script:id = 4400

# SELECT 子树
$select = '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget'
AddBind $select '7239660D-BDAD-E108-E6CB-83D7F8DE661B' 'ATTACK_TARGET' 'InAttackTarget' 'SELECT.HasBattleTarget'
AddBind $select '9A0A0E2F-F0B1-F3BC-F7AB-E030D9B9AB91' 'ACTOR_TARGET' 'InActorTarget' 'SELECT.CheckHasTarget.InActorTarget'
AddBind $select '9A0A0E2F-F0B1-F3BC-F7AB-E030D9B9AB91' 'HAS_POINT_TARGET' 'InHasPointTarget' 'SELECT.CheckHasTarget.InHasPointTarget'

# BATTLE 子树
$battle = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle'
AddBind $battle '1AD78FA3-BB8E-5127-BB78-C4F1E73D76A4' 'ATTACK_TARGET' 'InAttackTarget' 'BATTLE.HasBattleTarget'

# 保存全部
$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "SUBTREE-COND-FIX DONE"

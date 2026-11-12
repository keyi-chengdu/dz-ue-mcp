param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'

function Call($id, $tool, $toolArgs) {
  $inner = @{ toolset_name = 'DZStateTreeToolset.DZStateTreeEditTools'; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 8 -Compress
  $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -and $txt.Trim()) {
        if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
        return (($txt | ConvertFrom-Json).result.content[0].text)
      }
    } catch { if ($attempt -eq 3) { return "HTTP-ERR" } }
    Start-Sleep -Milliseconds 600
  }
  return $null
}

$id = 1800
$tree = '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget'
$treeArg = @{ stateTree = @{ refPath = $tree } }
$fields = @('ACTOR_TARGET', 'ATTACK_TARGET', 'LAST_SELFATTACKER')

# 1) bag 三字段换 Ref 接线柱（删旧值字段连带删绑定 → 加 Ref 字段 → 配默认类型）
foreach ($f in $fields) {
  $r1 = Call (++$id) 'RemoveTreeParameter' @{ stateTree = @{ refPath = $tree }; paramName = $f }
  $r2 = Call (++$id) 'AddTreeParameter' @{ stateTree = @{ refPath = $tree }; paramName = $f; valueType = 'Struct'; valueTypeObjectPath = '/Script/StateTreeModule.StateTreeBlueprintPropertyRef' }
  $r3 = Call (++$id) 'SetTreeParameterRefDefault' @{ stateTree = @{ refPath = $tree }; paramName = $f; refTypeName = 'Object'; typeObjectPath = '/Script/Engine.Actor' }
  Write-Output "$f : rm=$($r1 -replace '[\r\n]+',' ') add=$($r2 -replace '[\r\n]+',' ') set=$($r3 -replace '[\r\n]+',' ')"
}

# 2) 迁移工具重建任务 Ref 绑定（source 现在是 Ref 字段 = 链式直达）
$m = Call (++$id) 'MigrateWriteParamToPropertyRef' $treeArg
Write-Output "MIGRATE: $m"

# 3) 编译
$cr = ((Call (++$id) 'CompileStateTree' $treeArg) | ConvertFrom-Json).returnValue
Write-Output "COMPILE ok=$($cr.bSucceeded) msgs=$($cr.messages.Count)"
foreach ($msg in $cr.messages) { if ($msg.severity -ne 'Info') { Write-Output ("  [{0}] {1}" -f $msg.severity, $msg.message) } }

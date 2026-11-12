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
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 400
  }
  return $null
}

$id = 3400
$sub = '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget:StateTreeEditorData_0'

function DumpDetail($rp, $label) {
  $si = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = @{ refPath = $rp } }
  $s = ($si | ConvertFrom-Json).returnValue
  Write-Output "===== $label ($($s.name)) ====="
  foreach ($tr in $s.transitions) {
    $tgt = '?'
    try { $tgt = $tr.settings.targetState.refPath } catch {}
    Write-Output ("  transition: trigger={0} type={1} priority={2} to={3}" -f $tr.settings.trigger, $tr.settings.type, $tr.settings.priority, $tgt)
    foreach ($c in $tr.conditions) { Write-Output ("    cond: {0} | {1}" -f $c.name, $c.description) }
  }
  foreach ($t in $s.tasks) { Write-Output ("  task id={0} name={1} desc={2}" -f $t.iD, $t.name, $t.description) }
}

DumpDetail "$sub.StateTreeState_0.StateTreeState_1" 'PARENT-combat'
# 用 DescribeState 列出完整子树（带 children 顺序），再逐个读
$si = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = @{ refPath = "$sub.StateTreeState_0" } }
$s = ($si | ConvertFrom-Json).returnValue
foreach ($lvl1 in $s.children) {
  Write-Output ("L1: {0} ({1})" -f $lvl1.refPath, $lvl1.objectPath)
}
DumpDetail "$sub.StateTreeState_0" 'SUBTREE-ROOT'

Write-Output "DETAIL DONE"

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
    Start-Sleep -Milliseconds 400
  }
  return $null
}

$script:id = 3100
$tree = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'

function DumpState($stateRef, $depth) {
  $rp = $stateRef.refPath
  if (-not $rp) { $rp = $stateRef.objectPath }
  $si = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = @{ refPath = $rp } }
  try {
    $s = ($si | ConvertFrom-Json).returnValue
    $pad = (' ' * $depth)
    Write-Output ("{0}[{1}] path={2}" -f $pad, $s.type, $s.path)
    foreach ($t in $s.tasks) { Write-Output ("{0}  task: {1}" -f $pad, $t.name) }
    foreach ($c in $s.enterConditions) { Write-Output ("{0}  enterCond: {1} | {2}" -f $pad, $c.name, $c.description) }
    foreach ($tr in $s.transitions) {
      $condStr = ($tr.conditions | ForEach-Object { "$($_.name)[$($_.description)]" }) -join ' AND '
      $tgt = '?'
      try { if ($tr.settings.targetState) { $tgt = $tr.settings.targetState.refPath } else { $tgt = $tr.settings.type } } catch {}
      Write-Output ("{0}  -> transition: trigger={1} type={2} to={3} conds: {4}" -f $pad, $tr.settings.trigger, $tr.settings.type, $tgt, $condStr)
    }
    foreach ($ch in $s.children) { DumpState $ch ($depth + 2) }
  } catch { Write-Output ("DESCRIBE-ERR: " + $si) }
}

$root = @{ objectPath = "$tree`:StateTreeEditorData_0.StateTreeState_0" }
DumpState $root 0
Write-Output "FULL-TREE DONE"

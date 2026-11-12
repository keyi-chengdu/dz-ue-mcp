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

$id = 4700
$inRange = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle:StateTreeEditorData_0.StateTreeState_0.StateTreeState_3.StateTreeState_0'

foreach ($suffix in @('','' + '.StateTreeState_0', '.StateTreeState_1')) {
  $rp = $inRange + $suffix
  $si = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = @{ refPath = $rp } }
  try {
    $s = ($si | ConvertFrom-Json).returnValue
    Write-Output ("== {0} ({1})" -f $s.name, $s.path)
    foreach ($c in $s.enterConditions) { Write-Output ("   cond: {0} | {1}" -f $c.name, $c.description) }
    foreach ($t in $s.tasks) { Write-Output ("   task: {0}" -f $t.name) }
    foreach ($tr in $s.transitions) {
      $tgt = '?'; try { $tgt = $tr.settings.targetState.refPath } catch {}
      Write-Output ("   -> {0} to {1}" -f $tr.settings.trigger, $tgt)
    }
  } catch { Write-Output ("ERR ${rp}: " + $si) }
}

Write-Output "INRANGE DONE"

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
    Start-Sleep -Milliseconds 300
  }
  return $null
}

$script:id = 4300

function DumpAll($rp, $label) {
  $si = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = @{ refPath = $rp } }
  try {
    $s = ($si | ConvertFrom-Json).returnValue
    foreach ($c in $s.enterConditions) {
      if ($c.name -match '交战对象|目标对象') { Write-Output ("{0} enterCond id={1} name={2}" -f $label, $c.iD, $c.name) }
    }
    foreach ($tr in $s.transitions) {
      foreach ($c in $tr.conditions) {
        if ($c.name -match '交战对象|目标对象') { Write-Output ("{0} transCond id={1} name={2}" -f $label, $c.iD, $c.name) }
      }
    }
    foreach ($ch in $s.children) {
      $crp = $ch.refPath; if (-not $crp) { $crp = $ch.objectPath }
      DumpAll $crp $label
    }
  } catch {}
}

DumpAll '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102:StateTreeEditorData_0.StateTreeState_0' 'MAIN'
DumpAll '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle:StateTreeEditorData_0.StateTreeState_0' 'BATTLE'
DumpAll '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget:StateTreeEditorData_0.StateTreeState_0' 'SELECT'
Write-Output "ALL-COND DONE"

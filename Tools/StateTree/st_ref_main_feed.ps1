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

$id = 2200
$feed = @('ACTOR_TARGET', 'ATTACK_TARGET', 'LAST_SELFATTACKER')
$mains = @(
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102',
  '/Game/Blueprint/StateTree/05002103/ST_05002103.ST_05002103',
  '/Game/Blueprint/StateTree/05002104/ST_05002104.ST_05002104',
  '/Game/Blueprint/StateTree/05002105/ST_05002105.ST_05002105',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)

foreach ($tree in $mains) {
  $name = ($tree -replace '.*/','') -replace '\..*',''
  $treeArg = @{ stateTree = @{ refPath = $tree } }
  # 链接态指定 feed：主树 Parameters.X(值) -> State.Parameters.X(Ref 接线柱)。Ref 绑定不走 CopyAllBindings，Object feed 安全。
  $b = Call (++$id) 'BindLinkedStateParametersFromTree' @{ stateTree = @{ refPath = $tree }; paramNames = $feed }
  $bound = '?'
  try { $bound = ($b | ConvertFrom-Json).returnValue } catch { $bound = $b }
  $cr = ((Call (++$id) 'CompileStateTree' $treeArg) | ConvertFrom-Json).returnValue
  Write-Output ("{0}: feed={1} compile={2}" -f $name, $bound, $cr.bSucceeded)
  if (-not $cr.bSucceeded) { foreach ($m in $cr.messages) { if ($m.severity -ne 'Info') { Write-Output ("  [{0}] {1}" -f $m.severity, $m.message) } } }
}

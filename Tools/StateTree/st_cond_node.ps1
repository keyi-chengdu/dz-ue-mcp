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

$id = 4000
$tree = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'

foreach ($nid in @('444984A9-4A94-76DF-8313-04A40C1BF56D','681AAE2C-4082-9B7A-3CDA-1FAC014E6370','6AAFD67F-4BFA-18B8-0FE0-16A3A43EB2E7')) {
  $np = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'GetNodeProperties' @{ stateTree = @{ refPath = $tree }; nodeID = $nid }
  Write-Output ("NODE ${nid}: " + $np.Substring(0, [Math]::Min(400, $np.Length)))
}

Write-Output "COND-NODE DONE"

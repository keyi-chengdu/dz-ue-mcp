param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'

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

$id = 3200
$tree = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'

$b = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'GetPropertyBindings' @{ stateTree = @{ refPath = $tree }; targetStructId = $zeroGuid }
$binds = ($b | ConvertFrom-Json).returnValue
Write-Output ("TOTAL: " + @($binds).Count)
$binds | Where-Object { $_.sourcePath -match 'ATTACK|ACTOR|SELF' -or $_.targetPath -match 'ATTACK|ACTOR|SELF|交战' } | ForEach-Object {
  Write-Output ("  src='{0}'[{1}] -> dst='{2}'[{3}]" -f $_.sourcePath, $_.sourceStructID, $_.targetPath, $_.targetStructID)
}

# 链接态参数
$ls = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeLinkedStates' @{ stateTree = @{ refPath = $tree } }
(($ls | ConvertFrom-Json).returnValue | ForEach-Object { "LINKED: $_" })

Write-Output "BIND-CHECK DONE"

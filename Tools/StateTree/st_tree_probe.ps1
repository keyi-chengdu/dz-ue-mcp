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
      if ($txt -and $txt.Trim()) {
        if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
        return (($txt | ConvertFrom-Json).result.content[0].text)
      }
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 600
  }
  return $null
}

$id = 3000
$tree = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'

# 1) 顶层结构
$info = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeStateTree' @{ stateTree = @{ refPath = $tree } }
$rv = ($info | ConvertFrom-Json).returnValue
Write-Output ("SUBTREES: " + (($rv.subTrees | ForEach-Object { $_.refPath }) -join "`n  "))

# 2) 根状态的子状态（找【战斗】）
$root = $rv.subTrees[0]
$si = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = $root }
Write-Output ("ROOT STATE INFO: " + $si)

Write-Output "TREE-PROBE DONE"

param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 12 -Compress
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

$script:id = 7000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'

Write-Output "=== 1. CREATE ST_ParTest ==="
$c = Call (++$script:id) $st 'CreateStateTree' @{ packagePath = '/Game'; assetName = 'ST_ParTest'; schemaClass = @{ refPath = '/Script/GameplayStateTreeModule.StateTreeAIComponentSchema' } }
Write-Output ("CREATE: " + $c)

$tree = '/Game/ST_ParTest.ST_ParTest'

Write-Output "=== 2. ADD PARAM Out INt (Int32) ==="
$p = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $tree }; paramName = 'Out INt'; valueType = 'Int32'; valueTypeObjectPath = 'None' }
Write-Output ("PARAM: " + $p)

Write-Output "=== 3. DESCRIBE TREE (find default root states) ==="
$d = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $tree } }
Write-Output ("DESCRIBE: " + $d)

Write-Output "=== 4. ROOT STATE CHILDREN ==="
$s = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = "$tree`:StateTreeEditorData_0.StateTreeState_0" } }
Write-Output ("ROOT: " + $s)
Write-Output "PAR-CREATE DONE"

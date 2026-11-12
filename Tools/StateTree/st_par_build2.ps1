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

$script:id = 7300
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$tree = '/Game/ST_ParTest.ST_ParTest'
$parRef = '/Game/ST_ParTest.ST_ParTest:StateTreeEditorData_0.StateTreeState_0.StateTreeState_0'
$paramId = '00F990C5-40DB-6F94-F840-C2A1CB028746'

Write-Output "=== 1. ADD PARAM OutINt (no-space name for path resolver) ==="
$p = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $tree }; ParamName = 'OutINt'; ValueType = 'Int32'; ValueTypeObjectPath = 'None' }
Write-Output ("PARAM: " + $p)

Write-Output "=== 2. ADD TASKS ==="
$t1 = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $parRef }; Slot = 'Task'; NodeType = @{ refPath = '/Game/STT_Test.STT_Test_C' } }
Write-Output ("STT_Test NODE: " + $t1)
$t2 = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $parRef }; Slot = 'Task'; NodeType = @{ refPath = '/Script/StateTreeModule.StateTreeDelayTask' } }
Write-Output ("DELAY NODE: " + $t2)
try { $t1g = ($t1 | ConvertFrom-Json).returnValue; $t2g = ($t2 | ConvertFrom-Json).returnValue } catch { $t1g = $null; $t2g = $null }

Write-Output "=== 3. SET DELAY 0.5 ==="
$dp = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $tree }; nodeID = $t2g; values = @{ Duration = '0.5' } }
Write-Output ("DELAY-SET: " + $dp)

Write-Output "=== 4. ADD TRANSITION ==="
$tr = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $parRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'Succeeded'; bEnabled = $true } }
Write-Output ("TRANSITION: " + $tr)

Write-Output "=== 5. ADD REF BINDING ==="
$bd = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; Binding = @{ SourceStructID = $paramId; SourcePath = 'OutINt'; TargetStructID = $t1g; TargetPath = 'InInt' } }
Write-Output ("BINDING: " + $bd)

Write-Output "=== 6. COMPILE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $tree } }
Write-Output ("COMPILE: " + $cp)
Write-Output "PAR-BUILD2 DONE"

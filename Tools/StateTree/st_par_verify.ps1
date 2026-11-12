param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 12 -Compress
  $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
  try {
    $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 120 -UseBasicParsing
    $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
    if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
    return (($txt | ConvertFrom-Json).result.content[0].text)
  } catch { return "HTTP-ERR: $($_.Exception.Message)" }
}

$st = 'DZStateTreeToolset.DZStateTreeEditTools'

Write-Output "=== ST_ParTest ParTask STATE (verify Delay duration) ==="
$s = Call 10500 $st 'DescribeState' @{ state = @{ refPath = '/Game/ST_ParTest.ST_ParTest:StateTreeEditorData_0.StateTreeState_0.StateTreeState_0' } }
Write-Output ("PARTASK: " + $s)

Write-Output "=== RESTORE bShouldCopyParametersOnTick=false ==="
$sv = Call 10501 $st 'SetNodeProperties' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' }; nodeID = 'C543DE26-3E8C-9B3D-7E54-9D4C0D54C5C6'; values = @{ bShouldCopyParametersOnTick = 'false' } }
Write-Output ("RESTORE: " + $sv)

$cp = Call 10502 $st 'CompileStateTree' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' } }
Write-Output ("COMPILE: " + $cp)
Write-Output "VERIFY-RESTORE DONE"

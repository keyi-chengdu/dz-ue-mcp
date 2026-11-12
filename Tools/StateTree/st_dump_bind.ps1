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
$d = Call 10300 $st 'DumpAllBindings' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' } }
Write-Output ("DUMP: " + $d)
Write-Output "DUMP DONE"

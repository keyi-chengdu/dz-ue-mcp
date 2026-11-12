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

Write-Output "=== BIND OwnerActor <- Context Actor (ST_ParTest) ==="
$b = Call 10710 $st 'AddPropertyBinding' @{ stateTree = @{ refPath = '/Game/ST_ParTest.ST_ParTest' }; Binding = @{ SourceStructID = '1D971B00-2888-4FDE-B543-680236984FD5'; SourcePath = 'Actor'; TargetStructID = 'BF94AEA4-F9AC-DEA5-804E-A96BB0FDB173'; TargetPath = 'OwnerActor' } }
Write-Output ("BIND: " + $b)

$cp = Call 10711 $st 'CompileStateTree' @{ stateTree = @{ refPath = '/Game/ST_ParTest.ST_ParTest' } }
Write-Output ("COMPILE: " + $cp)

$sid = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt").Trim()
$inner = '{"toolset_name":"SlateInspectorToolset.SlateInspectorToolset"}'
$payload = '{"jsonrpc":"2.0","id":10712,"method":"tools/call","params":{"name":"describe_toolset","arguments":' + $inner + '}}'
$r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/mcp' -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $sid } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 120 -UseBasicParsing
$txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
$j = ($txt | ConvertFrom-Json).result.content[0].text
($j -split '"name":"' | ForEach-Object { if ($_ -match '^([A-Za-z_][A-Za-z0-9_.]+)"') { $Matches[1] } }) | Sort-Object -Unique
Write-Output "PREP-B DONE"

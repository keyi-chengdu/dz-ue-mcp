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

$script:id = 7100
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$tree = '/Game/ST_ParTest.ST_ParTest'
$root = "$tree`:StateTreeEditorData_0.StateTreeState_0"
$paramId = '00F990C5-40DB-6F94-F840-C2A1CB028746'

Write-Output "=== 1. ADD STATE None ==="
$sa = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $tree }; Name = 'None'; Type = 'State'; ParentState = @{ refPath = $root } }
Write-Output ("ADDSTATE: " + $sa)

Write-Output "=== 2. DESCRIBE ROOT (find new state refPath) ==="
$s = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $root } }
Write-Output ("ROOT: " + $s)

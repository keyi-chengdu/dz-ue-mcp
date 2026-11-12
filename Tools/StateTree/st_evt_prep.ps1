param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { if ($attempt -eq 2) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 300
  }
  return $null
}

$script:id = 10810
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$graph = @{ refPath = '/Game/STT_Test.STT_Test:EventGraph' }

Write-Output "=== 0. SCAN node types ==="
foreach ($f in @('SendEvent', 'FStateTreeEvent', 'MakeEvent')) {
  $r = Call (++$script:id) $bp 'find_node_types' @{ graph = $graph; type_id_filter = $f; context_pins = @() }
  Write-Output ("TYPE '{0}': {1}" -f $f, $r)
}

Write-Output "=== 1. ADD bSendOnExit VARIABLE ==="
$v = Call (++$script:id) $bp 'add_variable' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' }; name = 'bSendOnExit'; type_name = 'bool' }
Write-Output ("VAR: " + $v)

Write-Output "=== 2. COMPILE BP (expose var) ==="
$cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
Write-Output ("BP-COMPILE: " + $cb)
Write-Output "EVT-PREP DONE"

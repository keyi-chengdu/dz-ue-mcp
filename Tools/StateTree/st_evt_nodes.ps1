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

$script:id = 10820
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$graph = @{ refPath = '/Game/STT_Test.STT_Test:EventGraph' }

Write-Output "=== CREATE SendEvent NODE ==="
$n1 = Call (++$script:id) $bp 'create_node' @{ graph = $graph; type_id = 'StateTree|StateTreeSendEvent'; pos = @{ x = 1400; y = 256 } }
Write-Output ("SEND-NODE: " + $n1)

Write-Output "=== CREATE MakeEventPayload NODE ==="
$n2 = Call (++$script:id) $bp 'create_node' @{ graph = $graph; type_id = 'Utilities|Struct|MakeEventPayload'; pos = @{ x = 1150; y = 420 } }
Write-Output ("MAKE-NODE: " + $n2)

Write-Output "=== CREATE BRANCH NODE ==="
$n3 = Call (++$script:id) $bp 'create_node' @{ graph = $graph; type_id = 'Utilities|FlowControl|Branch'; pos = @{ x = 950; y = 256 } }
Write-Output ("BRANCH-NODE: " + $n3)

try {
  $nl = @((($n1 | ConvertFrom-Json).returnValue), (($n2 | ConvertFrom-Json).returnValue), (($n3 | ConvertFrom-Json).returnValue)) | Where-Object { $_ -and $_.refPath }
  if (@($nl).Count -gt 0) {
    $info = Call (++$script:id) $bp 'get_node_infos' @{ nodes = @($nl) }
    Write-Output ("PINS: " + $info)
  }
} catch { Write-Output ("INFO-ERR: " + $_.Exception.Message) }
Write-Output "EVT-NODES DONE"

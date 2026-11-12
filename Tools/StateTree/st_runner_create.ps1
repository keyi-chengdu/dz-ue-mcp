param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 12 -Compress
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

$script:id = 9300
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$runner = '/Game/BP_STTestRunner.BP_STTestRunner'

Write-Output "=== 1. CREATE BP (AIController) ==="
$c = Call (++$script:id) $bp 'create' @{ folder_path = '/Game'; asset_name = 'BP_STTestRunner'; asset_type = @{ refPath = '/Script/AIModule.AAIController' } }
Write-Output ("CREATE: " + $c)

$g = Call (++$script:id) $bp 'get_graph' @{ blueprint = @{ refPath = $runner }; graph_name = 'EventGraph' }
Write-Output ("GRAPH: " + $g)

foreach ($q in @('Spawn Actor', 'Possess', 'Add Component', 'StateTreeAsset')) {
  $f = Call (++$script:id) $bp 'find_node_types' @{ graph = @{ refPath = "$runner`:EventGraph" }; title = $q }
  Write-Output ("TYPES '{0}': {1}" -f $q, $f)
}
Write-Output "RUNNER-CREATE DONE"

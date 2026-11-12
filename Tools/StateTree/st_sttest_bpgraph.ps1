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

$script:id = 6100
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'

foreach ($asset in @('/Game/STT_Test.STT_Test', '/Game/STT_Test1.STT_Test1')) {
  Write-Output ("===== {0} EventGraph nodes =====" -f $asset)
  $nodes = Call (++$script:id) $bp 'find_nodes' @{ graph = @{ refPath = "$asset`:EventGraph" }; title = "" }
  Write-Output ("NODES-LIST: " + $nodes)
  try {
    $nlist = (($nodes | ConvertFrom-Json).returnValue)
    if ($nlist) {
      $info = Call (++$script:id) $bp 'get_node_infos' @{ nodes = @($nlist) }
      Write-Output ("NODE-INFO: " + $info)
    }
  } catch { Write-Output ("NODE-INFO-ERR: " + $_.Exception.Message) }
}
Write-Output "BP-GRAPH DONE"

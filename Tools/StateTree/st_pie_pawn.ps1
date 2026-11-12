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

$script:id = 9500
$sc = 'editor_toolset.toolsets.scene.SceneTools'
$at = 'editor_toolset.toolsets.actor.ActorTools'
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$ed = 'EditorToolset.EditorAppToolset'

Write-Output "=== 1. SPAWN DefaultPawn ==="
$sp = Call (++$script:id) $sc 'add_to_scene_from_class' @{ actor_type = @{ refPath = '/Script/Engine.DefaultPawn' }; name = 'STParRunnerPawn'; xform = @{ location = @{ x = 0; y = 0; z = 200 }; rotation = @{ pitch = 0; yaw = 0; roll = 0 }; scale = @{ x = 1; y = 1; z = 1 } } }
Write-Output ("SPAWN: " + $sp)
try { $pawn = (($sp | ConvertFrom-Json).returnValue).refPath } catch { $pawn = $null }
if (-not $pawn) { Write-Output "PAWN-REF-FAIL"; exit 1 }
Write-Output ("PAWN: " + $pawn)

Write-Output "=== 2. ADD UStateTreeComponent ==="
$ac = Call (++$script:id) $at 'add_component' @{ actor = @{ refPath = $pawn }; component_class = @{ refPath = '/Script/GameplayStateTreeModule.StateTreeComponent' } }
Write-Output ("ADD-COMP: " + $ac)

Write-Output "=== 3. LIST COMPONENTS ==="
$lc = Call (++$script:id) $at 'get_components' @{ actor = @{ refPath = $pawn } }
Write-Output ("COMPS: " + $lc)

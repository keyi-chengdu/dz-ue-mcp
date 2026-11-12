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

$script:id = 9600
$at = 'editor_toolset.toolsets.actor.ActorTools'
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$ed = 'EditorToolset.EditorAppToolset'
$pawn = '/Game/Maps/Test_Level/Lv_Test_AI.Lv_Test_AI:PersistentLevel.DefaultPawn_0'

Write-Output "=== 1. ADD COMPONENT ==="
$ac = Call (++$script:id) $at 'add_component' @{ owner = @{ refPath = $pawn }; component_type = @{ refPath = '/Script/GameplayStateTreeModule.StateTreeComponent' }; name = 'STParRunnerComp' }
Write-Output ("ADD-COMP: " + $ac)
try { $comp = (($ac | ConvertFrom-Json).returnValue).refPath } catch { $comp = $null }
if (-not $comp) { Write-Output "COMP-REF-FAIL"; exit 1 }
Write-Output ("COMP: " + $comp)

Write-Output "=== 2. SET StateTreeRef ==="
$sp = Call (++$script:id) $ot 'set_properties' @{ object = @{ refPath = $comp }; properties = @{ StateTreeRef = '(StateTree=/Game/ST_Test.ST_Test.ST_Test)' } }
Write-Output ("SET-REF: " + $sp)

Write-Output "=== 3. VERIFY PROPERTIES ==="
$gp = Call (++$script:id) $ot 'get_properties' @{ object = @{ refPath = $comp }; properties = @('StateTreeRef', 'bStartLogicAutomatically') }
Write-Output ("PROPS: " + $gp)

Write-Output "=== 4. START PIE ==="
$pi = Call (++$script:id) $ed 'StartPIE' @{}
Write-Output ("PIE: " + $pi)
Write-Output "PIE-START DONE"

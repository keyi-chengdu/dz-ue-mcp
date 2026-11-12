param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($i = 1; $i -le 4; $i++) {
    try {
      $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
      $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 180 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { Start-Sleep -Seconds 1 }
  }
  return "HTTP-ERR-ALL"
}

$script:id = 38000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$ed = 'EditorToolset.EditorAppToolset'
$main = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'
$capRef = $main + ':StateTreeEditorData_0.StateTreeState_0.StateTreeState_9.StateTreeState_0'

Write-Output "=== SET bConsumeEventOnSelect=false ==="
$sp = Call (++$script:id) $ot 'set_properties' @{ instance = @{ refPath = $capRef }; values = '{"bConsumeEventOnSelect": "false"}' }
Write-Output ("SET: " + $sp)
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $main } }
Write-Output ("COMPILE: " + $cp)
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($main) }
Write-Output ("SAVE: " + $sv)

Write-Output "=== LOAD Lv_Test_AI ==="
$ll = Call (++$script:id) $ed 'describe_toolset_x' @{ }
# load level via SceneTools
$sc = 'editor_toolset.toolsets.scene.SceneTools'
$ll2 = Call (++$script:id) $sc 'load_level' @{ }
if ($ll2 -match 'required|missing') {
  Write-Output ("LOAD-SCHEMA: " + $ll2.Substring(0, [Math]::Min(500, $ll2.Length)))
}
Write-Output 'PREP DONE'

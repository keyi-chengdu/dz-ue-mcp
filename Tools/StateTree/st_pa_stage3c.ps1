param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
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

$script:id = 17600
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$paTree = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack'
$notifyRef = "$paTree" + ':StateTreeEditorData_0.StateTreeState_0.StateTreeState_1.StateTreeState_1'
$detRef = "$paTree" + ':StateTreeEditorData_0.StateTreeState_0.StateTreeState_1'

Write-Output "=== 1. ADD TR: notify -> det loop entry (StateTreeState_1) ==="
$tr = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $notifyRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $detRef }; RequiredEventTag = 'None'; Priority = 'Normal'; bDelayTransition = 'false'; DelayDuration = '0'; DelayRandomVariance = '0'; bEnabled = 'true' } }
Write-Output ("ADD-TR: " + $tr)

Write-Output "=== 2. FIX STATE NAME (utf8 file channel) ==="
$nameJson = Get-Content 'C:\UE\Projects\DZ_Project_New\.dsh\st_work\notify_state_name.json' -Raw -Encoding UTF8
$sp = Call (++$script:id) $ot 'set_properties' @{ instance = @{ refPath = $notifyRef }; values = $nameJson.Trim() }
Write-Output ("SET-NAME: " + $sp)
$gp = Call (++$script:id) $ot 'get_properties' @{ instance = @{ refPath = $notifyRef }; properties = @('Name') }
Write-Output ("VERIFY-NAME: " + $gp)

Write-Output "=== 3. CLEAN RESIDUAL VARS ==="
foreach ($v in @('bSendOnExit_0', 'OwnerActor')) {
  $rv = Call (++$script:id) $bp 'remove_variable' @{ blueprint = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_ParallelNotify.STT_ParallelNotify' }; name = $v }
  Write-Output ("RM " + $v + ": " + $rv)
}
$lv = Call (++$script:id) $bp 'list_variables' @{ blueprint = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_ParallelNotify.STT_ParallelNotify' } }
Write-Output ("VARS: " + $lv)

Write-Output "=== 4. COMPILE BP + TREE ==="
$cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_ParallelNotify.STT_ParallelNotify' } }
Write-Output ("BP: " + $cb)
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $paTree } }
Write-Output ("TREE: " + $cp)

Write-Output "=== 5. FINAL FULL DUMP ==="
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\UE\Projects\DZ_Project_New\.agents\skills\dz-ue-tools\Tools\StateTree\st_dump_tree_full.ps1' -Session $Session -Tree $paTree | Out-File -Encoding utf8 'C:\UE\Projects\DZ_Project_New\.dsh\st_work\pa_final_dump.txt'
 Get-Content 'C:\UE\Projects\DZ_Project_New\.dsh\st_work\pa_final_dump.txt'

Write-Output "=== 6. SAVE ==="
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @('/Game/Blueprint/StateTree/Common/Task/STT_ParallelNotify.STT_ParallelNotify', $paTree) }
Write-Output ("SAVE: " + $sv)
Write-Output 'STAGE3C DONE'

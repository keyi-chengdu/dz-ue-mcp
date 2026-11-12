param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'
$netParamGuid = '6E657450-6172-614D-4354-786553746174'

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
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

$script:id = 4500

# Battle 子树距离条件 47BB03A2：InTargetActor <- ACTOR_TARGET（测距目标）
$battle = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle'
$r = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $battle }; binding = @{ sourceStructID = $netParamGuid; sourcePath = 'ACTOR_TARGET'; targetStructID = '47BB03A2-994A-2551-BCEE-620407FA0B4D'; targetPath = 'InTargetActor' } }
Write-Output ("BIND DistCond.InTargetActor: " + $r)
$c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $battle }; targetStructId = $zeroGuid }
$ok = '?'; try { $ok = (($c | ConvertFrom-Json).returnValue).bSucceeded } catch {}
Write-Output ("COMPILE: " + $ok)
$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "DIST-BIND DONE"

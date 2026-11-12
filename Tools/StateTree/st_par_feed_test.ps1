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

$script:id = 10400
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$ed = 'EditorToolset.EditorAppToolset'
$lg = 'EditorToolset.LogsToolset'
$mainTree = '/Game/ST_Test.ST_Test'
$nodeId = 'C543DE26-3E8C-9B3D-7E54-9D4C0D54C5C6'

Write-Output "=== 1. ENABLE bShouldCopyParametersOnTick ==="
$sv = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $mainTree }; nodeID = $nodeId; values = @{ bShouldCopyParametersOnTick = 'true' } }
Write-Output ("SET-COPY-ON-TICK: " + $sv)

Write-Output "=== 2. COMPILE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $mainTree } }
Write-Output ("COMPILE: " + $cp)

Write-Output "=== 3. START PIE ==="
$pi = Call (++$script:id) $ed 'StartPIE' @{ options = @{ bSimulate = $true; playMode = 'PlayMode_InViewPort'; warmupSeconds = 2 } }
Write-Output ("PIE: " + $pi)

Start-Sleep -Seconds 9

Write-Output "=== 4. READ LOGS ==="
$e = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogBlueprintUserMessages'; pattern = '.'; maxEntries = 45 }
Write-Output ("LOGS: " + $e)

Write-Output "=== 5. STOP PIE ==="
$sp = Call (++$script:id) $ed 'StopPIE' @{}
Write-Output ("STOP: " + $sp)
Write-Output "PAR-FEED-TEST DONE"

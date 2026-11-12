<#
.SYNOPSIS
StateTree 全树递归精简 dump（通用侦查工具）：每状态一行（路径/类型/EC/任务/转移/子态数）。
.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File st_dump_tree_full.ps1 -Tree '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle' -Session <sid>
#>
param(
  [string]$Session,
  [string]$Tree = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle',
  [int]$MaxDepth = 8,
  [int]$Port = 8000
)
$ErrorActionPreference = 'Continue'
$base = "http://127.0.0.1:$Port/mcp"
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
    Start-Sleep -Milliseconds 350
  }
  return $null
}

$script:id = 16000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'

function DumpState($refPath, $depth, $stack) {
  if ($depth -gt $MaxDepth) { return }
  $r = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $refPath } }
  try {
    $x = ($r | ConvertFrom-Json).returnValue
  } catch { Write-Output ("  " * $depth + "ERR: " + $refPath); return }
  $tasks = ($x.tasks | ForEach-Object {
      $nt = '?'
      try { $nt = $_.nodeType.refPath } catch {}
      if ($nt -match '/Script/([\w\.]+)\.(\w+)$') { $nt = $Matches[2] } elseif ($nt -match '/([^/]+)\.(\w+_C)$') { $nt = $Matches[2] }
      $_.name + '<' + $nt + '>' + '[' + $_.iD.Substring(0, 8) + ']'
    }) -join ' + '
  $tr = ($x.transitions | ForEach-Object {
      $tgt = '?'
      try { $tgt = $_.settings.targetState.refPath.Split('/')[-1] } catch {}
      $tagTxt = ''
      try { if ($_.settings.requiredEventTag.tagName -and $_.settings.requiredEventTag.tagName -ne 'None') { $tagTxt = '(tag=' + $_.settings.requiredEventTag.tagName + ')' } } catch {}
      $_.settings.trigger + '->' + $tgt + $tagTxt
    }) -join ' | '
  $ec = ($x.enterConditions | ForEach-Object { $_.name }) -join ','
  $link = ''
  if ($x.type -eq 'LinkedAsset') { $link = ' [LINKED]' }
  Write-Output (("  " * $depth) + $x.name + $link + " {" + $x.type + "} ec=[" + $ec + "] tasks=[" + $tasks + "] tr=[" + $tr + "]")
  foreach ($c in $x.children) {
    DumpState $c.refPath ($depth + 1) ($stack + '/' + $x.name)
  }
}

$root = $Tree + ':StateTreeEditorData_0.StateTreeState_0'
Write-Output ("===== FULL DUMP: " + $Tree + " =====")
DumpState $root 0 ''
Write-Output 'FULL-DUMP DONE'

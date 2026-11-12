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
    Start-Sleep -Milliseconds 350
  }
  return $null
}

$script:id = 19000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$zb = '00000000-0000-0000-0000-000000000000'
$npGuid = '6E657450-6172-614D-4354-786553746174'   # NetParam Context desc 固定 GUID（绑定源标识）

$dir = 'C:\UE\Projects\DZ_Project_New\DZ_Content\Content\Blueprint\StateTree'
$trees = Get-ChildItem $dir -Recurse -Filter 'ST_*.uasset' | ForEach-Object {
  $full = $_.FullName
  $rel = $full.Replace($dir + '\', '').Replace('\', '/')
  $name = [System.IO.Path]::GetFileNameWithoutExtension($full)
  "/Game/Blueprint/StateTree/" + $rel.Replace($name + '.uasset', $name + '.' + $name)
}

Write-Output ("TREE COUNT: " + $trees.Count)
$total = 0
foreach ($t in $trees) {
  $b = Call (++$script:id) $st 'GetPropertyBindings' @{ stateTree = @{ refPath = $t }; targetStructId = $zb }
  $np = 0; $tot = 0; $lines = @()
  try {
    $arr = ($b | ConvertFrom-Json).returnValue
    $tot = @($arr).Count
    foreach ($x in $arr) {
      if ($x.sourceStructId -eq $npGuid) { $np++; $total++; $lines += ("    " + $x.sourcePath + " -> " + $x.targetPath + " [tgt=" + $x.targetStructId + "]") }
    }
  } catch { Write-Output ("  ERR " + $t + ": " + $b); continue }
  if ($np -gt 0) {
    Write-Output ("== " + $t + "  netparam-bindings=" + $np + "/" + $tot)
    $lines | ForEach-Object { Write-Output $_ }
  }
}
Write-Output ("TOTAL NETPARAM-SOURCE BINDINGS: " + $total)
Write-Output 'AUDIT DONE'

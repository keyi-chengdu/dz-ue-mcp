param([string]$Session, [string]$Tree, [int]$Depth = 10)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
  $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
  $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
  $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
  if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
  return (($txt | ConvertFrom-Json).result.content[0].text)
}

$script:id = 33200
$st = 'DZStateTreeToolset.DZStateTreeEditTools'

function Walk($refPath, $pathName, $depth) {
  if ($depth -gt $Depth) { return }
  $d = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $refPath } }
  $x = $null
  try { $raw = ($d | ConvertFrom-Json).returnValue; $x = $raw } catch { return }
  if (-not $x) { return }
  $nm = $x.name
  foreach ($t in @($x.tasks)) {
    if ($t -and $t.iD) { Write-Output ("TASK| " + $pathName + "/" + $nm + " | " + $t.name + " | " + $t.iD + " | " + $t.nodeType.refPath) }
  }
  foreach ($c in @($x.children)) {
    Walk $c.refPath ($pathName + "/" + $nm) ($depth + 1)
  }
}

$rootRef = ($Tree -split ':')[0] + ':' + ($Tree -split ':')[1]
Walk $rootRef '' 0
Write-Output 'WALK DONE'

param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

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

$script:id = 5200

foreach ($tree in @('/Game/ST_Test.ST_Test', '/Game/ST_Test1.ST_Test1')) {
  Write-Output ("=== {0} ===" -f $tree)

  $sum = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeStateTree' @{ stateTree = @{ refPath = $tree } }
  Write-Output ("SUMMARY: " + $sum)

  Write-Output "--- BINDINGS ---"
  $b = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'GetPropertyBindings' @{ stateTree = @{ refPath = $tree }; targetStructId = $zeroGuid }
  try {
    $binds = ($b | ConvertFrom-Json).returnValue
    Write-Output ("TOTAL: " + @($binds).Count)
    $binds | ForEach-Object {
      Write-Output ("  src='{0}' structID={1} -> dst='{2}' dstID={3}" -f $_.sourcePath, $_.sourceStructID, $_.targetPath, $_.targetStructID)
    }
  } catch { Write-Output ("BIND-PARSE-ERR: " + $b) }

  Write-Output "--- LINKED STATES ---"
  $ls = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeLinkedStates' @{ stateTree = @{ refPath = $tree } }
  try { (($ls | ConvertFrom-Json).returnValue | ForEach-Object { "LINKED: $_" }) } catch { Write-Output ("LS-ERR: " + $ls) }

  Write-Output ""
}
Write-Output "STTEST-PROBE DONE"

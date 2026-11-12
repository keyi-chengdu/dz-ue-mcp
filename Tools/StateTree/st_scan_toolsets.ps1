param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 12 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 120 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { if ($attempt -eq 2) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 300
  }
  return $null
}

$script:id = 9100
foreach ($ts in @('editor_toolset.toolsets.actor.ActorTools', 'editor_toolset.toolsets.object.ObjectTools', 'EditorToolset.EditorAppToolset')) {
  $d = Call (++$script:id) 'unused' 'unused' @{}
  $inner = @{ toolset_name = $ts }
  $payload = '{"jsonrpc":"2.0","id":' + $script:id + ',"method":"tools/call","params":{"name":"describe_toolset","arguments":' + ($inner | ConvertTo-Json -Compress) + '}}'
  try {
    $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 120 -UseBasicParsing
    $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
    if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
    $j = ($txt | ConvertFrom-Json).result.content[0].text
    Write-Output ("===== {0} =====" -f $ts)
    ($j -split '"name":"' | ForEach-Object { if ($_ -match '^([A-Za-z_][A-Za-z0-9_.]+)"') { $Matches[1] } }) | Sort-Object -Unique
  } catch { Write-Output ("{0} DESCRIBE-ERR: {1}" -f $ts, $_.Exception.Message) }
}
Write-Output "TOOLSET-SCAN DONE"

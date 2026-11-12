param([string]$OutFile = 'C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt')
$base = 'http://127.0.0.1:8000/mcp'
$payload = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"dz-agent","version":"1.0"}}}'
try {
  $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 60 -UseBasicParsing
  $sid = $r.Headers['mcp-session-id']
  if (-not $sid) { Write-Output "NO SID in response headers"; exit 1 }
  Set-Content -Path $OutFile -Value $sid -Encoding UTF8
  Write-Output ("SID: " + $sid)
  # notifications/initialized
  $n = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $sid } -Body ([Text.Encoding]::UTF8.GetBytes($n)) -TimeoutSec 30 -UseBasicParsing | Out-Null
  Write-Output 'INITIALIZED'
} catch { Write-Output ("ERR: " + $_.Exception.Message); exit 1 }

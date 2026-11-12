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

$script:id = 30000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$pkg = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack'
$obj = $pkg + '.ST_Sub_05002102_ParallelAttack'

Write-Output "=== 0. STATE BEFORE DELETE ==="
$d0 = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
if ($d0.Length -gt 600) { Write-Output ("DESCRIBE(HEAD): " + $d0.Substring(0,600)) } else { Write-Output ("DESCRIBE: " + $d0) }

Write-Output "=== 1. SAVE FIRST (fallback snapshot) ==="
$sv0 = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($obj) }
Write-Output ("SAVE0: " + $sv0)

Write-Output "=== 2. DELETE (package path) ==="
$d1 = Call (++$script:id) $at 'delete' @{ path = $pkg }
Write-Output ("DEL-PKG: " + $d1)
Start-Sleep -Seconds 2

Write-Output "=== 3. VERIFY ==="
$v1 = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
if ($v1.Length -gt 400) { Write-Output ("VERIFY-PKG(HEAD): " + $v1.Substring(0,400)) } else { Write-Output ("VERIFY-PKG: " + $v1) }

Write-Output "=== 4. RETRY DELETE (object path) ==="
$d2 = Call (++$script:id) $at 'delete' @{ path = $obj }
Write-Output ("DEL-OBJ: " + $d2)
Start-Sleep -Seconds 2

Write-Output "=== 5. FINAL VERIFY ==="
$v2 = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
if ($v2.Length -gt 400) { Write-Output ("VERIFY-FINAL(HEAD): " + $v2.Substring(0,400)) } else { Write-Output ("VERIFY-FINAL: " + $v2) }

Write-Output 'PA-DELETE-STEP DONE'

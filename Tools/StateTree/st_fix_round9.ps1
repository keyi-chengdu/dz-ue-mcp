param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -and $txt.Trim()) {
        if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
        return (($txt | ConvertFrom-Json).result.content[0].text)
      }
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 600
  }
  return $null
}

$id = 1700
$treePath = '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'

# 1) 树资产的 Schema 实例引用
$s1 = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'get_properties' @{ instance = @{ refPath = $treePath }; properties = @('Schema') }
Write-Output ("Tree.Schema: " + $s1)

$schemaRef = $null
try { $o = ($s1 | ConvertFrom-Json).returnValue; $schemaRef = $o.schema.refPath; if (-not $schemaRef) { $schemaRef = $o.Schema.refPath } } catch {}
Write-Output ("SchemaRef: " + $schemaRef)

if ($schemaRef) {
  # 2) 读 Schema 实例当前 AIControllerClass
  $g = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'get_properties' @{ instance = @{ refPath = $schemaRef }; properties = @('AIControllerClass') }
  Write-Output ("Schema AIControllerClass before: " + $g)
  # 3) 写入蓝图控制器类
  $set = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'set_properties' @{ instance = @{ refPath = $schemaRef }; values = '{"AIControllerClass":{"refPath":"/Game/Core/BP_DZAIController.BP_DZAIController_C"}}' }
  Write-Output ("SET: " + $set)
  $g2 = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'get_properties' @{ instance = @{ refPath = $schemaRef }; properties = @('AIControllerClass') }
  Write-Output ("Schema AIControllerClass after: " + $g2)
}

# 4) 编译
$c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $treePath }; targetStructId = $zeroGuid }
Write-Output ("COMPILE: " + $c)

Write-Output "ROUND9 DONE"

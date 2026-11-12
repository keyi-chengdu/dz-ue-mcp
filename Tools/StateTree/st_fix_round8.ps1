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

$id = 1600
$treePath = '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'

# 1) 拿 EditorData 子对象路径
$ed = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'get_properties' @{ instance = @{ refPath = $treePath }; properties = @('EditorData') }
Write-Output ("EditorData: " + $ed)

# EditorData 引用里推出 Schema 实例路径（:StateTreeEditorData_0 下的 Schema 子对象）
$edPath = $null
try { $edPath = (($ed | ConvertFrom-Json).returnValue.editorData.refPath) } catch {}
if (-not $edPath) { try { $edPath = (($ed | ConvertFrom-Json).returnValue.EditorData.refPath) } catch {} }
Write-Output ("EditorDataPath: " + $edPath)

if ($edPath) {
  # 2) 列 Schema 属性找实例名
  $props = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'list_properties' @{ instance = @{ refPath = $edPath } }
  Write-Output ("EditorData props: " + $props)

  # Schema 是 EditorData 的内嵌属性，试常见子对象路径
  $schemaCandidates = @(
    ($edPath + '.Schema'),
    ($treePath + ':' + ($edPath -replace '^[^:]*:','') + '.Schema')
  )
  foreach ($sp in $schemaCandidates) {
    $set = Call (++$id) 'editor_toolset.toolsets.object.ObjectTools' 'set_properties' @{ instance = @{ refPath = $sp }; values = '{"AIControllerClass":{"refPath":"/Game/Core/BP_DZAIController.BP_DZAIController_C"}}' }
    Write-Output ("SET on ${sp}: " + $set)
    if ($set -match 'true') { break }
  }
}

# 3) 编译 ST_05004101
$c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $treePath }; targetStructId = $zeroGuid }
Write-Output ("COMPILE 05004101: " + $c)

# 4) 全部保存
$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "ROUND8 DONE"

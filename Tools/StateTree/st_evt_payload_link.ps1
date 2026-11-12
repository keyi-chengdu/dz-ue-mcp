<#
.SYNOPSIS
并行树/子树事件 Payload 数据级闭环一键建链配方（2026-11-08 ST_Test 首役沉淀）。

.DESCRIPTION
对"已有 Tag 事件闭环"的 StateTree 测试台增配 Payload 数据通道（S1-S3）：
  S1 发送侧：SetNodeProperties 给发送任务节点实例注入带类型的 EventToSend（节点实例层，勿写 CDO——蓝图任务实例属性初始化自 InstanceObject）。
  S2 接收侧：接收状态 bHasRequiredEventToEnter=true + RequiredEventToEnter(Tag+PayloadStruct) →
              动态取 "Enter Event"(StateEvent) 绑定源 → 任务绑定 InInt <- Payload.X（TransitionEvent 源对任务禁闭，勿用）。
  S3 判定：可选 PIE 跑 9 秒抓 LogBlueprintUserMessages 比对载荷值。
全程 MCP HTTP 直驱（编辑器须在运行），每步回读验证。

.PARAMETER Session
MCP session id；缺省读 .dsh/st_work/mcp_sid_new.txt。

.PARAMETER SendTree / SendNodeID
发送侧树 refPath 与任务节点 ID（GetNodeProperties 可见的那只）。

.PARAMETER RecvTree / RecvStateRefPath / RecvTaskID
接收侧树、接收状态 refPath（UStateTreeState）、接收任务绑定视图 ID（GetBindableSources 的 Task 源 ID / GetNodeProperties 同源）。

.PARAMETER Tag / PayloadStructPath
事件 Tag（须已注册）；载荷结构对象路径（短名优先：Vector/Rotator/LinearColor——UHT 注册名无 F 前缀；FIntPoint 无反射注册不可用）。

.PARAMETER PayloadText
完整 FStateTreeEvent 文本（缺省按 Tag+PayloadStructPath 拼 Vector(X=222,Y=0,Z=0)；自定义结构体请直接传全文）。

.PARAMETER BindTargetPath
接收任务绑定目标路径（无空格 FName，如 InInt）。

.EXAMPLE
powershell -NoProfile -ExecutionPolicy Bypass -File st_evt_payload_link.ps1 -SkipPIE
#>

param(
  [string]$Session,
  [string]$SendTree = '/Game/ST_ParTest.ST_ParTest',
  [string]$SendNodeID = 'BF94AEA4-F9AC-DEA5-804E-A96BB0FDB173',
  [string]$RecvTree = '/Game/ST_Test.ST_Test',
  [string]$RecvStateRefPath = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_0',
  [string]$RecvTaskID = '4B9E96C6-47AC-A993-D8D3-FFA2E44E781C',
  [string]$Tag = 'StateTree.ParTest.Done',
  [string]$PayloadStructPath = 'Vector',
  [string]$PayloadText = '',
  [string]$BindTargetPath = 'InInt',
  [switch]$SkipPIE
)

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

$script:id = 14000
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$ed = 'EditorToolset.EditorAppToolset'
$lg = 'EditorToolset.LogsToolset'

if (-not $PayloadText) {
  $PayloadText = '(Tag=(TagName="' + $Tag + '"),Payload=/Script/CoreUObject.' + $PayloadStructPath + '(X=222,Y=0,Z=0),Origin="")'
}

Write-Output "=== S1. INJECT EventToSend ON SENDER NODE INSTANCE ==="
$sv = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $SendTree }; nodeID = $SendNodeID; values = @{ EventToSend = $PayloadText } }
Write-Output ("SET: " + $sv)
$gp = Call (++$script:id) $st 'GetNodeProperties' @{ stateTree = @{ refPath = $SendTree }; nodeID = $SendNodeID }
Write-Output ("VERIFY: " + $gp)

Write-Output "=== S2a. CONFIG RECEIVER STATE RequiredEventToEnter ==="
$sp = Call (++$script:id) $ot 'set_properties' @{ instance = @{ refPath = $RecvStateRefPath }; values = ('{"bHasRequiredEventToEnter": "true", "RequiredEventToEnter": "(Tag=' + $Tag + ',PayloadStruct=' + $PayloadStructPath + ')"}') }
Write-Output ("SET-REQ: " + $sp)
$gp2 = Call (++$script:id) $ot 'get_properties' @{ instance = @{ refPath = $RecvStateRefPath }; properties = @('bHasRequiredEventToEnter', 'RequiredEventToEnter') }
Write-Output ("VERIFY-REQ: " + $gp2)

Write-Output "=== S2b. RESOLVE 'Enter Event' SOURCE (StateEvent) ==="
$bs = Call (++$script:id) $st 'GetBindableSources' @{ stateTree = @{ refPath = $RecvTree }; targetStructId = $RecvTaskID }
$ee = ''
try {
  foreach ($s in (($bs | ConvertFrom-Json).returnValue)) { if ($s.source -eq 'StateEvent') { $ee = $s.iD } }
} catch {}
Write-Output ("ENTER-EVENT-ID: " + $ee)
if (-not $ee) { Write-Output "ABORT: no Enter Event source (check bHasRequiredEventToEnter + tag)"; exit 1 }

Write-Output "=== S2c. BIND BindTargetPath <- Enter Event.Payload.X ==="
$bd = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $RecvTree }; binding = @{ sourceStructID = $ee; sourcePath = 'Payload.X'; targetStructID = $RecvTaskID; targetPath = $BindTargetPath } }
Write-Output ("BIND: " + $bd)

Write-Output "=== S2d. COMPILE BOTH TREES ==="
$c1 = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $SendTree } }
Write-Output ("COMPILE-SEND: " + $c1)
$c2 = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $RecvTree } }
Write-Output ("COMPILE-RECV: " + $c2)

if ($SkipPIE) { Write-Output "PAYLOAD-LINK DONE (PIE skipped)"; exit 0 }

Write-Output "=== S3. PIE VERDICT (9s, expect payload X in receiver prints) ==="
$pi = Call (++$script:id) $ed 'StartPIE' @{ options = @{ bSimulate = $true; playMode = 'PlayMode_InViewPort'; warmupSeconds = 2 } }
Start-Sleep -Seconds 9
$e1 = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogBlueprintUserMessages'; pattern = '222'; maxEntries = 10 }
Write-Output ("HITS-222: " + $e1)
$e2 = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogBlueprintUserMessages'; pattern = 'STT_Test1'; maxEntries = 12 }
Write-Output ("RECV-PRINTS: " + $e2)
$spx = Call (++$script:id) $ed 'StopPIE' @{}
Write-Output ("STOP: " + $spx)

<#
坑（2026-11-08 全 PIE 实证，详见 dz-st-split references/implementation-pitfalls.md「Payload 数据级闭环四坑」）：
1. 蓝图 set_pin_value 注入 FInstancedStruct 文本静默解析失败（编译无警告，运行时 payload 空）——
   一律走 SetNodeProperties（节点实例）或 ObjectTools.set_properties（UObject 属性）。
2. PayloadStruct 与到达事件 payload 类型不匹配 = 目标状态静默拒选（无 Error 日志）——
   诊断时先把 PayloadStruct 清成 None 验证 Tag-only 能否进入。
3. 蓝图任务实例属性初始化自资产节点实例（InstanceObject）而非 CDO——改 CDO 默认值对 PIE 无效。
4. FInstancedStruct 文本导入对象名无 F 前缀（Vector ✓ / FVector ✗）；FIntPoint 无 TBaseStructure 注册不可用。
5. 蓝图任务 Input 属性强制要求绑定（编译器 "expected to have a binding"）——摘旧绑定时同步补占位绑定。
6. StateTree 编辑器资产内存态改动 PIE 直读；正式落盘须 AssetTools.save_assets（另调）。
#>
Write-Output "PAYLOAD-LINK DONE"

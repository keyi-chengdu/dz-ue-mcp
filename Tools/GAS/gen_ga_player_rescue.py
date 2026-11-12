# -*- coding: utf-8 -*-
"""GA_Player_Rescue 救援 GA 图表 DSL 生成器（V1）
服务器流程：取目标 → 校验（Downed 且无 Rescuing）→ 给目标加 Rescuing LooseTag →
施加 GE_Character_Rescuing（Duration=救援曲线）到目标 ASC → 监听到期（发 BeRescued 事件+清 Tag）
与目标状态消失（取消清理）。
注：按住可取消（松手清零）留待后续（需输入绑定重构或 C++ ServerRPC），V1 救援开始后不中断。
"""

def emit(node, indent=0):
    sp = '  ' * indent
    if isinstance(node, str):
        return sp + node
    parts = [sp + '(' + node[0]]
    for b in node[1:]:
        parts.append(emit(b, indent + 1))
    parts.append(sp + ')')
    return '\n'.join(parts)

def emit_seq(stmts, indent=0):
    return '\n'.join(emit(s, indent) for s in stmts)

ATTR_COUNT = ('(AttributeName=\\"DownedCount\\",Attribute=/Script/DZProject.DZAttributeSet:'
              'DownedCount,AttributeOwner=\\"/Script/CoreUObject.Class\'/Script/DZProject.DZAttributeSet\'\\")')
ATTR_RMOD = ('(AttributeName=\\"DownReviveTime_Modifier\\",Attribute=/Script/DZProject.DZAttributeSet:'
             'DownReviveTime_Modifier,AttributeOwner=\\"/Script/CoreUObject.Class\'/Script/DZProject.DZAttributeSet\'\\")')
GE_RESCUING = "/Game/Blueprint/System/Death/GE_Character_Rescuing.GE_Character_Rescuing_C"
SBC = "DZ.GE.SetByCaller_Params.Param1"
T_DOWNED = "DZ.State.Character.Downed"
T_RESCUING = "DZ.State.Character.Rescuing"
T_RESCUED_EV = "DZ.Event.System.Downed.BeRescued"
RESCUING_CONTAINER = '(GameplayTags|MakeGameplayTagContainerfromTag "%s")' % T_RESCUING
END = ['Ability|EndAbility']

CLEANUP = [  # 取消清理：移除目标身上的 Rescuing GE + LooseTag
    ['GameplayEffects|RemoveActiveGameplayEffect', ':self', 'targetASC',
     ':Handle', '(Variables|Default|GetRescuingGEHandle)'],
    ['Ability|GameplayEffect|RemoveLooseGameplayTags', 'target', RESCUING_CONTAINER, 'true'],
    END,
]

BODY = [
    # 目标 ASC + 校验
    ['bind', 'targetASC', '(Class|DZCharacterBase|GetDZAbilitySystemComponent target)'],
    ['if', '(and (GameplayTags|HasMatchingGameplayTag :self targetASC :TagToCheck "%s") (not (GameplayTags|HasMatchingGameplayTag :self targetASC :TagToCheck "%s")))' % (T_DOWNED, T_RESCUING),
     # ===== 校验通过：开始救援 =====
     ['Ability|GameplayEffect|AddLooseGameplayTags', 'target', RESCUING_CONTAINER, 'true'],
     ['bind', 'tCount', '(Ability|Attribute|GetFloatAttribute target "%s")' % ATTR_COUNT],
     ['bind', 'tMod', '(Ability|Attribute|GetFloatAttribute target "%s")' % ATTR_RMOD],
     ['bind', 'rBase', '(DZ|倒地救援|EvalDownReviveTimeCurve :self (Class|DZSetting|DZSettings) :DownedCount tCount)'],
     ['bind', 'rRaw', '(* rBase (- 1.0 tMod))'],
     ['bind', 'rescueTime', '(select (< rRaw 0.5) 0.5 rRaw)'],
     ['bind', 'specR', '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_RESCUING],
     ['Ability|GameplayEffect|AssignTagSetbyCallerMagnitude', ':SpecHandle', 'specR', ':DataTag', '"%s"' % SBC, ':Magnitude', 'rescueTime'],
     ['bind', 'rH', '(GameplayEffects|ApplyGameplayEffectSpecToTarget :self (Ability|GetAbilitySystemComponentfromActorInfo) :SpecHandle specR :Target targetASC)'],
     ['Variables|Default|SetRescuingGEHandle', 'rH'],
     # 监听A：Rescuing GE 到期 → 完成：发 BeRescued + 清 Tag
     ['Ability|Tasks|WaitforGameplayEffectRemoved', ':Handle', '(Variables|Default|GetRescuingGEHandle)',
      [':OnRemoved',
       ['if', '(not (Variables|Default|GetCancelled))',
        ['Ability|SendGameplayEventtoActor', ':Actor', 'target', ':EventTag', '"%s"' % T_RESCUED_EV],
        ['Ability|GameplayEffect|RemoveLooseGameplayTags', 'target', RESCUING_CONTAINER, 'true'],
        END]],
      [':InvalidHandle'],
      [':then',
       # 监听B：目标 Downed 消失（被救/死亡）→ 取消清理
       ['Ability|Tasks|WaitGameplayTagRemovefromActor', ':TargetActor', 'target', ':Tag', '"%s"' % T_DOWNED, ':OnlyTriggerOnce', 'false',
        [':Removed',
         ['Variables|Default|SetCancelled', 'true']] + CLEANUP]]],
     # ===== 校验失败 =====
     ['else'] + [END],
    ],
]

DSL = """(event Ability|EventActivateAbility
  (if (Ability|HasAuthority)
    (bind rescuerAvatar (Ability|GetAvatarActorFromActorInfo))
    (bind rescuerCh (Utilities|Casting|CastToDZPlayerCharacter :Object rescuerAvatar)
      (:then
        (bind target (DZ|Downed|GetPendingRescueTarget rescuerCh))
        (Utilities|IsValid :InputObject target
          (:"Is Valid"
{BODY})
          (:"Is Not Valid"
            (Ability|EndAbility)))))))""".format(BODY=emit_seq(BODY, 7))

if __name__ == '__main__':
    import io
    out = r'C:\Users\02\AppData\Local\Temp\ga_rescue.dsl'
    with io.open(out, 'w', encoding='utf-8') as f:
        f.write(DSL)
    print('written', out, len(DSL))

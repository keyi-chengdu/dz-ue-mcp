# -*- coding: utf-8 -*-
"""GA_Player_Down 生命周期 DSL 生成器（V2）
V2 变更：GE GrantedTags 无法持久化 → Downed Tag 改由 GA activationOwnedTags 授予（已配 CDO）；
GE_Character_Downed 仅作 Duration 计时与 UI 剩余时间源；到期检测用 WaitforGameplayEffectRemoved(Handle)；
救援暂停 = PausebyRescue 标记（GE 照常流逝，仅 UI 展示），救援取消时若 GE 已耗尽则立即死亡。
Rescuing Tag 由救援 GA 用 AddLooseGameplayTags 给目标（T4 实现）。
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

ATTR_MODIFIER = ('(AttributeName=\\"DownLifeTime_Modifier\\",Attribute=/Script/DZProject.DZAttributeSet:'
                 'DownLifeTime_Modifier,AttributeOwner=\\"/Script/CoreUObject.Class\'/Script/DZProject.DZAttributeSet\'\\")')
ATTR_COUNT = ('(AttributeName=\\"DownedCount\\",Attribute=/Script/DZProject.DZAttributeSet:'
              'DownedCount,AttributeOwner=\\"/Script/CoreUObject.Class\'/Script/DZProject.DZAttributeSet\'\\")')
GE_DOWNED = "/Game/Blueprint/System/Death/GE_Character_Downed.GE_Character_Downed_C"
GE_DOWNED_COUNT = "/Game/Blueprint/System/Death/GE_Character_DownedCount.GE_Character_DownedCount_C"
GE_INV = "/Game/Blueprint/System/Death/GE_Character_Invincible.GE_Character_Invincible_C"
GE_REVIVE = "/Game/Blueprint/System/Death/GE_Character_Revive.GE_Character_Revive_C"
GE_SHIELD_BLOCK = "/Game/Blueprint/System/Shield/GE_System_ShieldRecoveryBlock.GE_System_ShieldRecoveryBlock_C"
SBC = "DZ.GE.SetByCaller_Params.Param1"
T_RESCUING = "DZ.State.Character.Rescuing"
T_RESCUED_EV = "DZ.Event.System.Downed.BeRescued"
T_SPECTATE = "DZ.Ability.ManualGA.Player.Spectate"
END = ['Ability|EndAbility']

# 彻底死亡：PS 标记 + 激活观战 GA + 结束
DEAD_STMTS = [
    ['DZ|倒地|MarkEliminated', '{PS}'],
    ['Abilities|TryActivateAbilitiesbyTag', ':self', '(Ability|GetAbilitySystemComponentfromActorInfo)',
     ':GameplayTagContainer', '(GameplayTags|MakeGameplayTagContainerfromTag "%s")' % T_SPECTATE,
     ':bAllowRemoteActivation', 'false'],
    END,
]

def dead_block(var):
    return [[x.replace('{PS}', var) for x in s] for s in DEAD_STMTS]

def ps_cast(prefix, then_stmts):
    var = prefix + 'Ps'
    return [
        ['bind', prefix + 'PsObj', '(Ability|GetOwningActorfromActorInfo)'],
        ['bind', var,
         ['Utilities|Casting|CastToDZPlayerState', ':Object', prefix + 'PsObj'],
         [':then'] + then_stmts],
    ]

# 监听4：被救起事件 → 无敌 GE + End
W4 = ['Ability|Tasks|WaitGameplayEvent', ':EventTag', '"%s"' % T_RESCUED_EV,
      ':OnlyTriggerOnce', 'false', ':OnlyMatchExact', 'true',
      [':EventReceived',
       ['Variables|Default|SetRescued', 'true'],
       ['bind', 'specH3', '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_INV],
       ['Ability|GameplayEffect|AssignTagSetbyCallerMagnitude', ':SpecHandle', 'specH3', ':DataTag', '"%s"' % SBC, ':Magnitude', '1.0'],
       ['Ability|ApplyGameplayEffectSpecToOwner', ':EffectSpecHandle', 'specH3'],
       ['bind', 'specRV', '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_REVIVE],
       ['Ability|GameplayEffect|AssignTagSetbyCallerMagnitude', ':SpecHandle', 'specRV', ':DataTag', '"%s"' % SBC, ':Magnitude', '(Class|DZSetting|Get复活生命值 (Class|DZSetting|DZSettings))'],
       ['Ability|ApplyGameplayEffectSpecToOwner', ':EffectSpecHandle', 'specRV'],
       ['Ability|ApplyGameplayEffectSpecToOwner', ':EffectSpecHandle', '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_SHIELD_BLOCK],
       END]]

# 监听3：Rescuing 移除 → 清暂停；未救起 → 按冻结剩余重挂倒地 GE（SetByCaller 修订值）并重挂到期监听（async 节点重入）
W3 = ['Ability|Tasks|WaitGameplayTagRemovefromActor', ':TargetActor', 'avatar',
      ':Tag', '"%s"' % T_RESCUING, ':OnlyTriggerOnce', 'false',
      [':Removed',
       ['Variables|Default|SetPausebyRescue', 'false'],
       ['if', '(not (Variables|Default|GetRescued))',
        ['bind', 'specH2', '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_DOWNED],
        ['bind', 'specH2D', '(Ability|GameplayEffect|SetDuration :SpecHandle specH2 :Duration (Variables|Default|GetPausedRemaining))'],
        ['Variables|Default|SetDownedGEHandle', '(Ability|ApplyGameplayEffectSpecToOwner :EffectSpecHandle specH2D)'],
        ['Ability|Tasks|WaitforGameplayEffectRemoved', ':Handle', '(Variables|Default|GetDownedGEHandle)',
         [':OnRemoved',
          ['if', '(and (not (Variables|Default|GetPausebyRescue)) (not (Variables|Default|GetRescued)))',
           ['bind', 'r3PsObj', '(Ability|GetOwningActorfromActorInfo)'],
           ['bind', 'r3Ps',
            ['Utilities|Casting|CastToDZPlayerState', ':Object', 'r3PsObj'],
            [':then'] + dead_block('r3Ps')]]],
         [':InvalidHandle']]]],
      [':then', W4]]

# 监听2：Rescuing 添加 → 真·暂停：记冻结剩余（修订值）+ 移除倒地 GE（W1 随 GE 移除触发，被暂停标记挡下）
W2 = ['Ability|Tasks|WaitGameplayTagAddtoActor', ':TargetActor', 'avatar',
      ':Tag', '"%s"' % T_RESCUING, ':OnlyTriggerOnce', 'false',
      [':Added',
       ['Variables|Default|SetPausebyRescue', 'true'],
       ['Variables|Default|SetPausedRemaining',
        '(Ability|GameplayEffect|GetActiveGameplayEffectRemainingDuration :ActiveHandle (Variables|Default|GetDownedGEHandle))'],
       ['Ability|RemoveGameplayEffectFromOwnerWithHandle', ':Handle', '(Variables|Default|GetDownedGEHandle)']],
      [':then', W3]]

# 监听1：倒地 GE 移除（到期）→ 非暂停非救起 → 死亡
W1 = ['Ability|Tasks|WaitforGameplayEffectRemoved', ':Handle', '(Variables|Default|GetDownedGEHandle)',
      [':OnRemoved',
       ['if', '(and (not (Variables|Default|GetPausebyRescue)) (not (Variables|Default|GetRescued)))',
        ['bind', 'd1PsObj', '(Ability|GetOwningActorfromActorInfo)'],
        ['bind', 'd1Ps',
         ['Utilities|Casting|CastToDZPlayerState', ':Object', 'd1PsObj'],
         [':then'] + dead_block('d1Ps')]]],
      [':InvalidHandle'],
      [':then', W2]]

MULTI_STMTS = ps_cast('down', [
    ['Ability|ApplyGameplayEffectSpecToOwner', ':EffectSpecHandle',
     '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_DOWNED_COUNT],
    ['bind', 'specH', '(Ability|MakeOutgoingGameplayEffectSpec :GameplayEffectClass "%s" :Level 1)' % GE_DOWNED],
    ['bind', 'geH', '(Ability|ApplyGameplayEffectSpecToOwner :EffectSpecHandle specH)'],
    ['Variables|Default|SetDownedGEHandle', 'geH'],
    W1,
])

SINGLE_STMTS = ps_cast('single', dead_block('singlePs'))

DSL = """(event Ability|EventActivateAbility
  (if (Ability|HasAuthority)
    (bind avatar (Ability|GetAvatarActorFromActorInfo))
    (if (<= (Game|GetNumPlayerControllers) 1)
{SINGLE}
      (else
{MULTI}))))""".format(
    SINGLE=emit_seq(SINGLE_STMTS, 6),
    MULTI=emit_seq(MULTI_STMTS, 8),
)

if __name__ == '__main__':
    import io
    out = r'C:\Users\02\AppData\Local\Temp\ga_down3.dsl'
    with io.open(out, 'w', encoding='utf-8') as f:
        f.write(DSL)
    print('written', out, len(DSL))

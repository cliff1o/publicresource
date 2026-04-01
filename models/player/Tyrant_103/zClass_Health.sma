#include <amxmodx>
#include <reapi>
#include <legend_monster>

new g_classid
new Float:g_NextSkillUse[33]

#define TASK_RAGE_END 5000

new const ZbiEffectList[][] = {
    "legend/Zombie_GBoost.wav",
    "legend/Zombie_Pain1.wav",
    "legend/Zombie_Pain2.wav",
    "legend/Zombie_Dead1.wav",
    "legend/Zombie_Dead2.wav"
}

new Float:g_RageOldSpeed[33]
new bool:g_RageSpeedSaved[33]

public plugin_init()
{
    register_plugin("Monster Health Zombie", "1.0", "LG")

    register_clcmd("drop", "cmd_use_skill")

    g_classid = lg_mclass_register("tank_zombie", "坦克殭屍", MT_SMALL)
}

public plugin_precache()
{
	for (new i = 0; i <sizeof ZbiEffectList;i ++) precache_sound(ZbiEffectList[i])

}
public lg_monster_on_assign(id, classid, phase)
{
    if (classid != g_classid)
        return

    g_NextSkillUse[id] = 0.0
}
public lg_monster_on_snd_pain(id, classid, phase)
{
    if (classid != g_classid)
        return   

    
	emit_sound(id, CHAN_VOICE, ZbiEffectList[random_num(1, 2)], 1.0, ATTN_NORM, 0, PITCH_NORM)
}
public lg_monster_on_snd_death(id, classid, phase)
{
    if (classid != g_classid)
        return   

    
	emit_sound(id, CHAN_VOICE, ZbiEffectList[random_num(3, 4)], 1.0, ATTN_NORM, 0, PITCH_NORM)
}
public lg_monster_on_death(id, classid, phase)
{
    if (classid != g_classid)
        return

    g_NextSkillUse[id] = 0.0
}
public cmd_use_skill(id)
{
    if (!is_user_alive(id))
        return PLUGIN_CONTINUE

    if (!lg_mclass_is_player_monster(id))
        return PLUGIN_CONTINUE

    if (lg_mclass_get_player_class(id) != g_classid)
        return PLUGIN_CONTINUE

    new phase = lg_mclass_get_player_phase(id)
    new slot = find_skill_slot_by_code(g_classid, phase, "painfree")
    if (slot == -1)
        return PLUGIN_HANDLED

    new Float:gametime = get_gametime()
    if (gametime < g_NextSkillUse[id])
        return PLUGIN_HANDLED

    new Float:cooldown = lg_mclass_get_skill_cooldown(g_classid, phase, slot)
    new Float:duration = lg_mclass_get_skill_duration(g_classid, phase, slot)
    new Float:power    = lg_mclass_get_skill_value1(g_classid, phase, slot)

    use_rageskill(id, duration, power)

    g_NextSkillUse[id] = gametime + cooldown
    lg_mclass_update_skill_cooldown(id, g_classid, phase, slot, g_NextSkillUse[id])
    return PLUGIN_HANDLED
}


stock use_rageskill(id, Float:duration, Float:power)
{
    if (!is_user_alive(id))
        return 0;

    // 開狀態
    lg_status_add(id, STATUS_PAINFREE);

    // 先清舊 task，避免重覆開技計時錯亂
    remove_task(id + TASK_RAGE_END);
    
    // 記低原本速度
    new Float:curSpeed = get_entvar(id, var_maxspeed)
    g_RageOldSpeed[id] = curSpeed
    g_RageSpeedSaved[id] = true

    // power 當作加成值，例如 +30.0 / +50.0
    set_entvar(id, var_maxspeed, curSpeed - power)

    // duration 秒後結束
    set_task(duration, "task_rage_end", id + TASK_RAGE_END);

    // 即時效果可以喺呢度做
    emit_sound(id, CHAN_BODY, ZbiEffectList[0], 1.0, ATTN_NORM, 0, PITCH_NORM);

    // Render 
    set_entvar(id, var_renderfx, kRenderFxGlowShell);
    set_entvar(id, var_rendercolor, Float:{0.0, 255.0, 0.0});
    set_entvar(id, var_rendermode, kRenderNormal);
    set_entvar(id, var_renderamt, 10.0);

    // fov 
    set_member( id, m_iFOV, 110 );

    return 1
}
public task_rage_end(taskid)
{
    new id = taskid - TASK_RAGE_END

    if (id < 1 || id > MaxClients)
        return


    // 回復原本速度
    if (g_RageSpeedSaved[id])
    {
        set_entvar(id, var_maxspeed, g_RageOldSpeed[id])
        g_RageSpeedSaved[id] = false
    }

    // remove 狀態
    lg_status_remove(id, STATUS_PAINFREE);
    set_entvar(id, var_renderfx, kRenderFxNone);
    set_entvar(id, var_rendercolor, Float:{255.0, 255.0, 255.0});
    set_entvar(id, var_rendermode, kRenderNormal);
    set_entvar(id, var_renderamt, 255.0);

    // fov 
    set_member( id, m_iFOV, 90 );

}
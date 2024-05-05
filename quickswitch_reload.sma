#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>

#if AMXX_VERSION_NUM < 190
	#define CSW_ALL_PISTOLS      (1<<CSW_P228  | 1<<CSW_ELITE | 1<<CSW_FIVESEVEN | 1<<CSW_USP | 1<<CSW_GLOCK18 | 1<<CSW_DEAGLE)
	#define CSW_ALL_SMGS         (1<<CSW_MAC10 | 1<<CSW_UMP45 | 1<<CSW_MP5NAVY | 1<<CSW_TMP  | 1<<CSW_P90)
	#define CSW_ALL_RIFLES       (1<<CSW_AUG   | 1<<CSW_GALIL | 1<<CSW_FAMAS   | 1<<CSW_M4A1 | 1<<CSW_AK47 | 1<<CSW_SG552)
	#define CSW_ALL_SNIPERRIFLES (1<<CSW_SCOUT | 1<<CSW_AWP   | 1<<CSW_G3SG1   | 1<<CSW_SG550)
	#define CSW_ALL_MACHINEGUNS  (1<<CSW_M249)
	#define MAX_NAME_LENGTH 32
	#define MAX_PLAYERS 32
	#define CSW_LAST_WEAPON CSW_P90
#endif

const m_fInReload = 54
const m_pPlayer = 41
const m_iId = 43
const m_flNextAttack = 83

const XoWeapon = 4
const XoPlayer = 5

const GUNS = (CSW_ALL_PISTOLS | CSW_ALL_SMGS | CSW_ALL_RIFLES | CSW_ALL_SNIPERRIFLES | CSW_ALL_MACHINEGUNS)
new HamHook:weapon_hook[CSW_LAST_WEAPON + 1]
new Float:reload[MAX_PLAYERS + 1]

enum weaponData
{
	weapon_clip,
	Float:reload_required
}
new Float:weapon_data[CSW_LAST_WEAPON + 1][weaponData] =
{
	{ 0,	0.00 }, // id weapon_name reload_time
	{ 13,	1.82 }, // 1 weapon_p228 2.701339
	{ 0,	0.00 },
	{ 10,	1.43 }, // 3 weapon_scout 2.000015
	{ 0,	0.00 },
	{ 7,	0.00 },
	{ 0,	0.00 },
	{ 30,	1.97 }, // 7 weapon_mac10 3.156738
	{ 30,	2.27 }, // 8 weapon_aug 3.325
	{ 0,	0.00 },
	{ 30,	3.93 }, // 10 weapon_elite 4.491786
	{ 20,	2.16 }, // 11 weapon_fiveseven 2.700866
	{ 25,	2.03 }, // 12 weapon_ump45 3.501037
	{ 30,	2.17 }, // 13 weapon_sg550 3.349830
	{ 35,	1.34 }, // 14 weapon_galil 2.449691
	{ 25,	1.63 }, // 15 weapon_famas 3.309921
	{ 12,	1.59 }, // 16 weapon_usp 2.692481
	{ 20,	1.48 }, // 17 weapon_glock18 2.208679
	{ 10,	2.16 }, // 18 weapon_awp 2.93
	{ 30,	1.40 }, // 19 weapon_mp5navy 2.634353
	{ 100,	3.40 }, // 20 weapon_m249 4.705093
	{ 8,	0.00 },
	{ 30,	1.81 }, // 22 weapon_m4a1 3.045242
	{ 30,	1.44 }, // 23 weapon_tmp 2.126342
	{ 20,	2.96 }, // 24 weapon_g3sg1 3.501327
	{ 0,	0.00 },
	{ 7,	1.46 }, // 26 weapon_deagle 2.206604
	{ 30,	1.81 }, // 27 weapon_sg552 2.999481
	{ 30,	1.78 }, // 28 weapon_ak47 2.45
	{ 0,	0.00 },
	{ 50,	2.25 } // 30 weapon_p90 3.4
}

public plugin_init()
{
	register_plugin("Quick-switch Reload", "1.0", "big")
	new weapon_name[MAX_NAME_LENGTH]
	for(new i = CSW_P228; i <= CSW_LAST_WEAPON; i++) 
	{
		if(GUNS & (1 << i))
		{
			get_weaponname(i, weapon_name, charsmax(weapon_name))
			weapon_hook[i] = RegisterHam(Ham_Item_PostFrame, weapon_name, "weapon_postframe")
			DisableHamForward(weapon_hook[i])
			RegisterHam(Ham_Item_Holster , weapon_name, "weapon_holster")
			RegisterHam(Ham_Weapon_Reload, weapon_name, "weapon_reload", 1)
		}
	}
}

public weapon_reload(const entity)
{
	if(pev_valid(entity))
	{
		if(get_pdata_int(entity, m_fInReload, XoWeapon))
		{
			new id = get_pdata_cbase(entity, m_pPlayer, XoWeapon)
			reload[id] = get_gametime()
			new weapon_id = get_pdata_int(entity, m_iId, XoWeapon)
			EnableHamForward(weapon_hook[weapon_id])
		}
	}
}

public weapon_postframe(const entity)
{
	if(pev_valid(entity))
	{
		if(get_pdata_int(entity, m_fInReload, XoWeapon))
		{
			new id = get_pdata_cbase(entity, m_pPlayer, XoWeapon)
			if(get_pdata_float(id, m_flNextAttack, XoPlayer) <= 0.0)
			{
				new	weapon_id = get_pdata_int(entity, m_iId, XoWeapon)
				DisableHamForward(weapon_hook[weapon_id])
			}
		}
	}
}

public weapon_holster(entity)
{
	if(pev_valid(entity))
	{
		if(get_pdata_int(entity, m_fInReload, XoWeapon))
		{
			new id = get_pdata_cbase(entity, m_pPlayer, XoWeapon)
			if (is_user_alive(id))
			{
				new weapon_id = get_pdata_int(entity, m_iId, XoWeapon)
				DisableHamForward(weapon_hook[weapon_id])
				if ((get_gametime() - reload[id]) >= weapon_data[weapon_id][reload_required])
					reload_weapon(id, entity, weapon_id)
			}
		}
	}
}

public reload_weapon(id, entity, weapon_id)
{
	new clip, ammo
	get_user_ammo(id, weapon_id, clip, ammo)

	if (ammo > clip)
	{
		ammo -= (weapon_data[weapon_id][weapon_clip] - clip)
		clip = weapon_data[weapon_id][weapon_clip]
	}

	else
	{
		if (ammo >= (weapon_data[weapon_id][weapon_clip] - clip))
		{
			ammo -= (weapon_data[weapon_id][weapon_clip] - clip)
			clip = weapon_data[weapon_id][weapon_clip]
		}

		else
		{
			clip = min(clip + ammo, weapon_data[weapon_id][weapon_clip])
			ammo = 0
		}

	}

	cs_set_weapon_ammo(entity, clip)
	cs_set_user_bpammo(id, weapon_id, ammo)
}

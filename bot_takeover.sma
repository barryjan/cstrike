#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_Util>
#include <engine>

#tryinclude <cstrike_pdatas>

#if !defined _cbaseentity_included
		#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
				1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
				2. Put it into amxmodx/scripting/include/ folder   \
				3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
				4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

const MAX_PLAYERS = 32
new g_iBotIndex[ MAX_PLAYERS + 1 ]

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Bot Takeover",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	register_clcmd( "drop", "clcmd_Drop" )
	RegisterHam( Ham_Spawn, "player", "forward_Spawn_Post", .Post = 1 )
}

public clcmd_Drop( id )
{
	if ( is_user_alive( id ) )
	{	
		return PLUGIN_CONTINUE
	}
	
	new iTarget = pev( id, pev_iuser2 )
	
	if ( is_user_alive( iTarget ) && is_user_bot( iTarget ) && get_user_team( id ) == get_user_team( iTarget ) )
	{
		g_iBotIndex[ id ] = iTarget
		ExecuteHamB( Ham_CS_RoundRespawn, id )
	}
	return PLUGIN_HANDLED
	
}

public forward_Spawn_Post( id )
{
	if ( !is_user_alive( id ) || !g_iBotIndex[ id ] )
	{	
		return HAM_IGNORED
	}
	
	new iTarget = g_iBotIndex[ id ]
	new Float:flHealth, Float:flArmorValue, iArmorType
	pev( iTarget, pev_health, flHealth ) 
	pev( iTarget, pev_armorvalue, flArmorValue ) 
	pev( iTarget, pev_armortype, iArmorType ) 
	
	set_pev( id, pev_health, flHealth )
	set_pev( id, pev_armorvalue, flArmorValue )
	set_pev( id, pev_armortype, iArmorType )

	new const Float:VEC_DUCK_HULL_MIN[ 3 ] = { -16.0, -16.0, -18.0 }
	new const Float:VEC_DUCK_HULL_MAX[ 3 ] = { 16.0, 16.0, 32.0 }
	new const Float:VEC_NULL[ 3 ] = { 0.0, 0.0, 0.0 }
	
	new Float:flOrigin[ 3 ],flAngles[ 3 ]
	pev( iTarget, pev_origin, flOrigin )
	pev( iTarget, pev_angles, flAngles )
	
	set_pev( id, pev_angles, flAngles )
	set_pev( id, pev_v_angle, VEC_NULL )
	set_pev( id, pev_fixangle, 1 )
	set_pev( id, pev_flags, pev( id, pev_flags ) | FL_DUCKING )
	engfunc( EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX )
	engfunc( EngFunc_SetOrigin, id, flOrigin )
	
	if ( get_pdata_bool( iTarget, m_bHasDefuser ) )
	{
		cs_set_user_defuse( id )
	}
	
	fm_strip_user_weapons( id )
	
	new iWeapons = pev( iTarget, pev_weapons ) & ~( 1<<CSW_VEST )
	new szWeapon[ 32 ], iWeaponEnt
	
	for ( new wIndex = CSW_P228; wIndex <= CSW_P90; wIndex++ )
	{
		if ( iWeapons & ( 1<<wIndex ) )
		{
			get_weaponname( wIndex, szWeapon, charsmax( szWeapon ) )
			iWeaponEnt = fm_give_item( id, szWeapon )
			set_pdata_float( iWeaponEnt, m_flNextPrimaryAttack, 0.0, 4 )
		}
	}
	
	set_pdata_float( id, m_flNextAttack, 0.0, 5 )
	set_pev( id, pev_weaponanim, 0 )
	
	const MAX_AMMO_SLOTS = 15
	new iBpAmmo[ MAX_AMMO_SLOTS ]
	for ( new rgAmmoSlot = 1; rgAmmoSlot < MAX_AMMO_SLOTS; rgAmmoSlot++ )
	{
	    iBpAmmo[ rgAmmoSlot ] = get_pdata_int( iTarget, m_rgAmmo_CBasePlayer[ rgAmmoSlot ] )
	    set_pdata_int( id, m_rgAmmo_CBasePlayer[ rgAmmoSlot ], iBpAmmo[ rgAmmoSlot ] )
	}
		
	engfunc( EngFunc_SetOrigin, iTarget, Float:{ 0.0, 0.0, -4096.0 } )
	user_silentkill( iTarget )
	g_iBotIndex[ id ] = 0
	
	return HAM_IGNORED
}

stock ham_give_weapon( id, weapon[] )
{
    if(!equal(weapon,"weapon_",7)) return 0;

    new wEnt = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,weapon));
    if(!pev_valid(wEnt)) return 0;

    set_pev(wEnt,pev_spawnflags,SF_NORESPAWN);
    dllfunc(DLLFunc_Spawn,wEnt);
    
    if(!ExecuteHamB(Ham_AddPlayerItem,id,wEnt))
    {
        if(pev_valid(wEnt)) set_pev(wEnt,pev_flags,pev(wEnt,pev_flags) | FL_KILLME);
        return 0;
    }

    ExecuteHamB(Ham_Item_AttachToPlayer,wEnt,id)
    return 1;
}
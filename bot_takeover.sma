#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_Util>
#include <dhudmessage>

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
new g_iBotTakeoverCount[ MAX_PLAYERS + 1 ]

new g_pCvar_Enable
new g_pCvar_MaxTakeovers
new g_pCvar_AdminOnly

new g_iMsgId_ScoreAttrib

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Bot Takeover",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	g_pCvar_Enable 		= register_cvar( "amx_bottakeover", "1" )
	g_pCvar_AdminOnly 	= register_cvar( "amx_bottakeover_adminonly", "0" )
	g_pCvar_MaxTakeovers 	= register_cvar( "amx_bottakeover_max", "0" )
	
	register_event( "SpecHealth2", "event_SpecHealth2", "bd", "2>0" )
	register_event("HLTV", "event_hltv", "a", "1=0", "2=0")
	
	register_clcmd( "drop", "clcmd_Drop" )
	
	RegisterHam( Ham_Spawn, "player", "forward_Spawn_Post", .Post = 1 )
	
	g_iMsgId_ScoreAttrib = get_user_msgid( "ScoreAttrib" )
}

public event_SpecHealth2( id )
{
	new iTarget = read_data( 2 )
	
	if ( is_user_alive( iTarget ) && is_user_bot( iTarget ) && get_user_team( id ) == get_user_team( iTarget ) )
	{
		set_dhudmessage( 0, 160, 0, _, _, 0, 0.0 )
		show_dhudmessage( id, "Press Drop [G] to takeover bot" )
	}
}

public event_hltv()
{
	new iPlayers[ MAX_PLAYERS ], iCount
	
	get_players( iPlayers, iCount, "c" )
	
	for( new iIndex = 0; iIndex < iCount; iIndex++ )
	{
		g_iBotTakeoverCount[ iPlayers[ iIndex ] ] = 0
	}
}

public clcmd_Drop( id )
{
	if ( is_user_alive( id ) || !get_pcvar_num( g_pCvar_Enable ) )
	{	
		return PLUGIN_CONTINUE
	}
	
	if ( get_pcvar_num( g_pCvar_AdminOnly ) && !is_user_admin( id ) )
	{
		return PLUGIN_CONTINUE	
	}
	
	new iMaxTakeovers = get_pcvar_num( g_pCvar_MaxTakeovers )
	
	if ( iMaxTakeovers > 0 && iMaxTakeovers >= g_iBotTakeoverCount[ id ] )
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
	new Float:flOrigin[ 3 ],flAngles[ 3 ]
	
	pev( iTarget, pev_origin, flOrigin )
	pev( iTarget, pev_angles, flAngles )
	
	set_pev( id, pev_angles, flAngles )
	set_pev( id, pev_v_angle, { 0.0, 0.0, 0.0 } )
	set_pev( id, pev_fixangle, 1 )
	set_pev( id, pev_flags, pev( id, pev_flags ) | FL_DUCKING )
	engfunc( EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX )
	engfunc( EngFunc_SetOrigin, id, flOrigin )
	engfunc( EngFunc_SetOrigin, iTarget, Float:{ 0.0, 0.0, -4096.0 } )
	
	fm_strip_user_weapons( id )
	
	const MAX_AMMO_SLOTS = 15
	new iBpAmmo[ MAX_AMMO_SLOTS ]
	
	for ( new rgAmmoSlot = 1; rgAmmoSlot < MAX_AMMO_SLOTS; rgAmmoSlot++ )
	{
	    iBpAmmo[ rgAmmoSlot ] = get_pdata_int( iTarget, m_rgAmmo_CBasePlayer[ rgAmmoSlot ] )
	    set_pdata_int( id, m_rgAmmo_CBasePlayer[ rgAmmoSlot ], iBpAmmo[ rgAmmoSlot ] )
	}
	
	new iItem, iSlot
	
	for ( iSlot = 1; iSlot <= 3; iSlot++ )
	{
		while( ( iItem = get_pdata_cbase( iTarget, m_rgpPlayerItems_CBasePlayer[ iSlot ] ) ) > 0 )
		{
			ExecuteHamB( Ham_RemovePlayerItem, iTarget, iItem )
			
			if ( ExecuteHamB( Ham_AddPlayerItem, id, iItem ) )
			{
				ExecuteHamB( Ham_Item_AttachToPlayer, iItem, id )			
			}
		}
	}
	
	new const EQUIP_LIST[] = { CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE, CSW_C4 }
	new const EQUIP_NAME[][] = { "weapon_hegrenade", "weapon_flashbang", "weapon_smokegrenade", "weapon_c4" }
	new iIndex, iWeapons = pev( iTarget, pev_weapons )
	
	for ( iIndex = 0; iIndex < sizeof( EQUIP_LIST ); iIndex++ )
	{
		if ( iWeapons & ( 1 << EQUIP_LIST[ iIndex ] ) )
		{
			fm_give_item( id, EQUIP_NAME[ iIndex ] )
		}
	}
	
	cs_set_user_defuse( id, cs_get_user_defuse( iTarget ) )
	cs_set_user_nvg( id, cs_get_user_nvg( iTarget ) )
	set_pdata_float( id, m_flNextAttack, 0.0, 5 )
	set_pev( id, pev_weaponanim, 0 )
	set_pev( iTarget, pev_deadflag, DEAD_DEAD )
	
	message_begin( MSG_BROADCAST, g_iMsgId_ScoreAttrib )
	write_byte( iTarget )
	write_byte( ( 1 << 0 ) )
	message_end()
	
	g_iBotIndex[ id ] = 0
	g_iBotTakeoverCount[ id ] += 1
	
	return HAM_IGNORED
}
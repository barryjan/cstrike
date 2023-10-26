#include < amxmodx >
#include < cstrike > 
#include < fakemeta >
#include < hamsandwich >
#include < fun >

#tryinclude <cstrike_pdatas>

#if !defined _cbaseentity_included
	#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
		1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
		2. Put it into amxmodx/scripting/include/ folder   \
		3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
		4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

#define MAX_PLAYERS 32

new const PICKUP_SOUND[] = "items/9mmclip1.wav"

new bool:g_bAlive[ MAX_PLAYERS + 1 ]
new bool:g_bFreezeTime
new Float:g_flStartTime
new g_iMaxPlayers
new g_pCvar_MaxGrenades
new g_iMsg_BlinkAcct
new g_iMsg_AmmoPickup
new g_iMsg_TextMsg

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Grenade Belt",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	g_pCvar_MaxGrenades = register_cvar( "amx_maxgrenades", "4" )
	
	register_menucmd( register_menuid( "BuyItem", -1 ),( 1<<3 ),"cmd_heBuy" )
	register_menucmd( register_menuid( "BuyItem", -1 ),( 1<<2 ),"cmd_fbBuy" )
	register_menucmd( register_menuid( "BuyItem", -1 ),( 1<<4 ),"cmd_sgBuy" )
	
	register_menucmd( -34,( 1<<3 ),"cmd_heBuy" )
	register_menucmd( -34,( 1<<2 ),"cmd_fbBuy" )
	register_menucmd( -34,( 1<<4 ),"cmd_sgBuy" )
	
	register_clcmd( "hegren", "cmd_heBuy" )
	register_clcmd( "flash",  "cmd_fbBuy" )
	register_clcmd( "sgren",  "cmd_sgBuy" )
	
	register_event( "HLTV", "event_NewRound", "a", "1=0", "2=0" )
	register_event( "ResetHUD", "event_ResetHUD", "be" )
	register_event( "Health", "event_Health", "bd", "1=0" )
	
	register_logevent( "logevent_RoundStart", 2, "0=World triggered", "1=Round_Start" )
	
	register_forward( FM_Touch, "forward_Touch" )
	
	g_iMsg_BlinkAcct = get_user_msgid( "BlinkAcct" )
	g_iMsg_AmmoPickup = get_user_msgid( "AmmoPickup" )
	g_iMsg_TextMsg = get_user_msgid( "TextMsg" )
	
	g_iMaxPlayers = get_maxplayers()
}

public event_ResetHUD( id )
{
	g_bAlive[ id ] = true
}

public event_Health( id )
{
	if ( !g_bAlive[ id ] )
	{
		return
	}

	g_bAlive[ id ] = false
	
	new iGrenade, iAmmoId, iAmount
	new i, iRandDiff, iEnt
	new Float:flOrigin[ 3 ]
	new Float:flAngles[3 ]
	new Float:flVelocity[ 3 ]

	static const iDiffDist[ 3 ] = { 14, 0, -14 } 

	enum _:
	{
		CSG_FB = 11, CSG_HE, CSG_SG
	}
	
	static ipszArmouryEnt
	
	if ( !ipszArmouryEnt )
	{
		ipszArmouryEnt = engfunc( EngFunc_AllocString, "armoury_entity" )
	}
	
	for ( iGrenade = CSG_FB; iGrenade <= CSG_SG; iGrenade++ )
	{	
		iAmount = get_pdata_int( id, m_rgAmmo_CBasePlayer[ iGrenade ], 5 )
		iAmount -= iGrenade == CSG_FB ? 2 : 1
	
		pev( id, pev_origin, flOrigin )
		pev( id, pev_angles, flAngles )
		pev( id, pev_velocity, flVelocity )
		
		for ( i = 0; i < iAmount; i++ )
		{
			iRandDiff = random( 2 )
		
			flOrigin[0] += floatcos( flAngles[ 1 ], degrees ) * 8 + floatcos( flAngles[ 1 ] + 90, degrees) * iDiffDist[iRandDiff]
			flOrigin[1] += floatsin( flAngles[ 1 ], degrees ) * 8 + floatsin( flAngles[ 1 ] + 90, degrees) * iDiffDist[iRandDiff]
			
			if ( ( iEnt = engfunc( EngFunc_CreateNamedEntity, ipszArmouryEnt ) ) > 0 )
			{	
				engfunc( EngFunc_SetOrigin, iEnt, flOrigin )
				
				flAngles[ 0 ] = 0.0, flAngles[ 1 ] += 45.0
				
				set_pev( iEnt, pev_angles, flAngles )
				set_pev( iEnt, pev_velocity, flVelocity )
				
				switch ( iGrenade )
				{
					case CSG_FB: iAmmoId = 14
					case CSG_HE: iAmmoId = 15
					case CSG_SG: iAmmoId = 18
				}
				
				set_pdata_int( iEnt, m_iItem, iAmmoId, 4 )
				set_pdata_int( iEnt, m_iCount, 1, 4 )
				
				dllfunc( DLLFunc_Spawn, iEnt )
			}
		}
	}
}

public forward_Touch( iEnt, id ) 
{
	if ( !( 1 <= id <= g_iMaxPlayers ) || iEnt < g_iMaxPlayers )
	{
		return FMRES_IGNORED
	}
	
	static szClassname[ 32 ]
	
	pev( iEnt, pev_classname, szClassname, charsmax( szClassname ) )
	
	if ( !equal( szClassname, "armoury_entity" ) && !equal( szClassname, "weaponbox" ) )
	{
		return FMRES_IGNORED
	}
	
	if ( ! ( pev( iEnt, pev_flags ) & FL_ONGROUND ) )
	{
		return FMRES_SUPERCEDE
	}
	
	if ( pev( iEnt, pev_effects ) & EF_NODRAW )
	{
		engfunc( EngFunc_RemoveEntity, iEnt )
		
		return FMRES_SUPERCEDE
	}

	static iGrenade, szModel[ 32 ]
	
	pev( iEnt, pev_model, szModel, charsmax( szModel ) )
	
	if ( equal( szModel, "models/w_hegrenade.mdl" ) )
	{
		iGrenade = CSW_HEGRENADE
	}
	else if ( equal( szModel, "models/w_flashbang.mdl" ) )
	{
		iGrenade = CSW_FLASHBANG
	}
	else if ( equal( szModel, "models/w_smokegrenade.mdl" ) )
	{
		iGrenade = CSW_SMOKEGRENADE
	}
	else
	{
		return FMRES_IGNORED
	}
	
	new iMaxGrenades = get_pcvar_num( g_pCvar_MaxGrenades )
	new iTotalGrenades = cs_get_user_bpammo( id, CSW_HEGRENADE )
	
	iTotalGrenades += cs_get_user_bpammo( id, CSW_FLASHBANG )
	iTotalGrenades += cs_get_user_bpammo( id, CSW_SMOKEGRENADE )
	
	if ( iTotalGrenades >= iMaxGrenades )
	{
		return FMRES_SUPERCEDE
	}
	
	new iGrenadeCount = cs_get_user_bpammo( id, iGrenade )
	
	if ( iGrenadeCount > 0 )
	{
		engfunc( EngFunc_RemoveEntity, iEnt )
		
		message_begin( MSG_ONE_UNRELIABLE, g_iMsg_AmmoPickup, _, id )
		switch ( iGrenade )
		{
			case CSW_HEGRENADE: write_byte( 12 )
			case CSW_FLASHBANG: write_byte( 11 )
			case CSW_SMOKEGRENADE: write_byte( 13 )
		}
		write_byte( 1 )
		message_end()
		
		cs_set_user_bpammo( id, iGrenade, iGrenadeCount + 1 )
		emit_sound( id, CHAN_WEAPON, PICKUP_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM )
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public plugin_precache()
{
	precache_sound( PICKUP_SOUND )
}

public cmd_heBuy( id )
{
	handle_BuyGrenade( id, CSW_HEGRENADE )
	
	return PLUGIN_HANDLED_MAIN
}

public cmd_fbBuy( id )
{
	handle_BuyGrenade( id, CSW_FLASHBANG )
	
	return PLUGIN_HANDLED_MAIN
}

public cmd_sgBuy( id )
{
	handle_BuyGrenade( id, CSW_SMOKEGRENADE )
	
	return PLUGIN_HANDLED_MAIN
}

public event_NewRound() 
{
	g_bFreezeTime = true
}

public logevent_RoundStart()
{
	g_bFreezeTime = false
	g_flStartTime = get_gametime()
}

public handle_BuyGrenade( id, iGrenade )
{
	if ( !is_user_alive( id ) || !cs_get_user_buyzone( id ) )
	{
		return PLUGIN_CONTINUE
	}
	
	new iMaxGrenades = get_pcvar_num( g_pCvar_MaxGrenades )
	new iTotalGrenades = cs_get_user_bpammo( id, CSW_HEGRENADE )
	
	iTotalGrenades += cs_get_user_bpammo( id, CSW_FLASHBANG )
	iTotalGrenades += cs_get_user_bpammo( id, CSW_SMOKEGRENADE )
	
	if ( iTotalGrenades >= iMaxGrenades )
	{
		client_print( id, print_center, "#Cstrike_TitlesTXT_Cannot_Carry_Anymore" )
		
		return PLUGIN_CONTINUE
	}
	
	new Float:flBuyTime = get_cvar_float( "mp_buytime" ) * 60
	
	if ( !g_bFreezeTime && ( get_gametime() - g_flStartTime ) > flBuyTime )
	{
		new szBuyTime[ 3 ]
		
		float_to_str( flBuyTime, szBuyTime, charsmax( szBuyTime ) )

		message_begin( MSG_ONE_UNRELIABLE, g_iMsg_TextMsg, _, id )
		write_byte( 4 )
		write_string( "#Cant_buy" )
		write_string( szBuyTime  )
		message_end()

		return PLUGIN_CONTINUE
	}
	
	new iMoney = cs_get_user_money( id ) - ( ( iGrenade == CSW_FLASHBANG ) ? 200 : 300 )
	
	if ( iMoney < 0 )
	{
		client_print( id, print_center, "#Cstrike_TitlesTXT_Not_Enough_Money" )
		
		message_begin( MSG_ONE_UNRELIABLE, g_iMsg_BlinkAcct, _, id )
		write_byte( 2 )
		message_end()
		
		return PLUGIN_CONTINUE
	}
	else
	{
		cs_set_user_money( id, iMoney )
	}

	new iGrenadeCount = cs_get_user_bpammo( id, iGrenade )

	if ( iGrenadeCount < 1 )
	{
		switch ( iGrenade )
		{
			case CSW_HEGRENADE: give_item( id, "weapon_hegrenade" )
			case CSW_FLASHBANG: give_item( id, "weapon_flashbang" )
			case CSW_SMOKEGRENADE: give_item( id, "weapon_smokegrenade" )
		}
	}
	else
	{
		message_begin( MSG_ONE_UNRELIABLE, g_iMsg_AmmoPickup, _, id )
		{
			switch ( iGrenade )
			{
				case CSW_HEGRENADE: write_byte( 12 )
				case CSW_FLASHBANG: write_byte( 11 )
				case CSW_SMOKEGRENADE: write_byte( 13 )
			}
			write_byte( 1 )
		}
		message_end()
		
		cs_set_user_bpammo( id, iGrenade, iGrenadeCount + 1 )
		emit_sound( id, CHAN_WEAPON, PICKUP_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM )
	}
	return PLUGIN_CONTINUE
}

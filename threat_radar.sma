#include < amxmodx >
#include < cstrike >
#include < fakemeta >
#include < hamsandwich >

#define MAX_PLAYERS 32

new const g_szGunsEvents[][] = 
{
    "events/awp.sc", "events/g3sg1.sc", "events/ak47.sc", "events/scout.sc", "events/m249.sc",
    "events/m4a1.sc", "events/sg552.sc", "events/aug.sc", "events/sg550.sc", "events/m3.sc",
    "events/xm1014.sc", "events/usp.sc", "events/mac10.sc", "events/ump45.sc", "events/fiveseven.sc",
    "events/p90.sc", "events/deagle.sc", "events/p228.sc", "events/glock18.sc", "events/mp5n.sc",
    "events/tmp.sc", "events/elite_left.sc", "events/elite_right.sc", "events/galil.sc", "events/famas.sc"
}

new const g_iGunsWeaponId[] =
{
    0, CSW_AWP, CSW_G3SG1, CSW_AK47, CSW_SCOUT, CSW_M249, CSW_M4A1, CSW_SG552, CSW_AUG, CSW_SG550,
    CSW_M3, CSW_XM1014, CSW_USP, CSW_MAC10, CSW_UMP45, CSW_FIVESEVEN, CSW_P90, CSW_DEAGLE,
    CSW_P228, 0, CSW_GLOCK18, CSW_MP5NAVY, CSW_TMP, CSW_ELITE, CSW_ELITE, 0, 0, CSW_GALIL, CSW_FAMAS
}

new g_registerId_PrecacheEvent
new g_bitGunEventIds
new g_pCvar_TreatEnable
new g_pCvar_AllyEnable
new g_pCvar_Delay
new g_pCvar_MaxDistance
new g_pCvar_ShowSuppresedWeapon
new g_iMsgId_HostagePos
new g_iMsgId_HostageK
new g_iMsgId_SendAudio
new g_iMaxPlayers
new Float:g_flEnemyDelay[ MAX_PLAYERS + 1 ]
new Float:g_flAllyDelay[ MAX_PLAYERS + 1 ]

public plugin_precache() 
{
	g_registerId_PrecacheEvent = register_forward( FM_PrecacheEvent, "forward_PrecacheEvent", ._post = 1 )
}

public plugin_init()
{
	register_plugin
	(
		.plugin_name 	= "Threat Radar",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	unregister_forward( FM_PrecacheEvent, g_registerId_PrecacheEvent, .post = 1 )
	
	register_forward( FM_PlaybackEvent , "forward_PlaybackEvent" )
	
	register_clcmd( "say /test", "Test" )
	
	g_pCvar_TreatEnable = register_cvar( "amx_treatradar", "1" )
	g_pCvar_AllyEnable = register_cvar( "amx_allyradar", "1" )
	g_pCvar_Delay = register_cvar( "amx_treatradar_delay", "0.5" )
	g_pCvar_MaxDistance = register_cvar( "amx_treatradar_maxdistance", "3500" )
	g_pCvar_ShowSuppresedWeapon = register_cvar( "amx_treatradar_showsuppressed", "0" )

	g_iMsgId_HostagePos = get_user_msgid( "HostagePos" )
	g_iMsgId_HostageK = get_user_msgid( "HostageK" )
	g_iMsgId_SendAudio = get_user_msgid("SendAudio")
	
	g_iMaxPlayers = get_maxplayers()
}

public forward_PrecacheEvent( iType , const szName[] ) 
{
	for ( new i = 0; i < sizeof( g_szGunsEvents ); i++ ) 
	{
		if ( equal( g_szGunsEvents[ i ] , szName ) )
		{
			g_bitGunEventIds |= ( 1 << get_orig_retval() )
			
			return FMRES_HANDLED
		}
	}	
	return FMRES_IGNORED
}

public forward_PlaybackEvent( bitFlags, iInvoker, iEventId )
{
	if ( !( g_bitGunEventIds & ( 1 << iEventId ) ) || !( 1 <= iInvoker <= g_iMaxPlayers ) )
	{
		return FMRES_IGNORED
	}
	
	static Float:flGameTime
	static Float:pCvar_Delay
	
	flGameTime = get_gametime()
	pCvar_Delay = get_pcvar_float( g_pCvar_Delay )
	
	if ( get_pcvar_num( g_pCvar_AllyEnable ) )
	{
		if ( flGameTime >= g_flAllyDelay[ iInvoker ] )
		{
			message_begin( MSG_BROADCAST, g_iMsgId_SendAudio )
			write_byte( iInvoker )
			write_string( "" )
			message_end()
			
			g_flAllyDelay[ iInvoker ] = flGameTime + pCvar_Delay
		}
	}
	
	if ( !get_pcvar_num( g_pCvar_TreatEnable ) )
	{
		return FMRES_IGNORED
	}

	if ( !get_pcvar_num( g_pCvar_ShowSuppresedWeapon ) )
	{
		const bitSuppressedWeapons = ( 1 << CSW_M4A1 ) | ( 1 << CSW_USP ) | ( 1 << CSW_TMP )
		
		if ( bitSuppressedWeapons & ( 1 << g_iGunsWeaponId[ iEventId ] ) )
		{
			const m_pActiveItem = 373
			static pActiveItem
			
			pActiveItem = get_pdata_cbase( iInvoker, m_pActiveItem )
			
			if ( pActiveItem && cs_get_weapon_silen( pActiveItem ) )
			{
				return FMRES_IGNORED
			}
			else if ( ( 1 << CSW_TMP ) & ( 1 << g_iGunsWeaponId[ iEventId ] ) )
			{
				return FMRES_IGNORED
			}
		}
	}
	
	if ( flGameTime >= g_flEnemyDelay[ iInvoker ] )
	{	
		g_flEnemyDelay[ iInvoker ] = flGameTime + pCvar_Delay
	}
	else
	{
	 	return FMRES_IGNORED
	}
	
	static iVecOrigin[ 2 ][ 3 ]
	static iPlayers[ 32 ], iNum, id
	static const szEnemyTeam[][] = { "", "CT", "TERRORIST" }

	get_players( iPlayers, iNum, "aceh", szEnemyTeam[ _:cs_get_user_team( iInvoker ) ] )

	get_user_origin( iInvoker, iVecOrigin[ 0 ] )

	for ( new i = 0; i < iNum; i++ )
	{
		id = iPlayers[ i ]
	
		get_user_origin( id, iVecOrigin[ 1 ] )
		
		if ( get_distance( iVecOrigin[ 0 ], iVecOrigin[ 1 ] ) >= get_pcvar_num( g_pCvar_MaxDistance ) )
		{
			continue
		}
		
		const iHostageOffset = 4
		
		message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_HostagePos, _, .player = id )
		write_byte( 1 )	// Flag
		write_byte( iInvoker + iHostageOffset ) // HostageID
		write_coord( iVecOrigin[ 0 ][ 0 ] ) // CoordX
		write_coord( iVecOrigin[ 0 ][ 1 ] ) // CoordY
		write_coord( iVecOrigin[ 0 ][ 2 ] ) // CoordZ
		message_end()
		
		message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_HostageK, _, .player = id )
		write_byte( iInvoker + iHostageOffset ) // HostageID
		message_end()
	}
	return FMRES_HANDLED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

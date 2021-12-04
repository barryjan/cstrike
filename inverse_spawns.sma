#include < amxmodx >
#include < fakemeta >
#include < hamsandwich >

new const CLASSNAME_LIST[][] = { "info_player_deathmatch", "info_player_start", "func_buyzone" }
new g_iForward_Spawn, g_szMapName[ 2 ]

public plugin_precache() 
{
	register_plugin
	(
		.plugin_name 	= "Inverse Spawns",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	get_mapname( g_szMapName, sizeof ( g_szMapName ) )

	if ( g_szMapName[ 0 ] == 'c' && g_szMapName[ 1 ] == 's' )
	{
		g_iForward_Spawn = register_forward( FM_Spawn, "forward_Spawn" )
		register_forward( FM_Touch, "forward_Touch" )
	}
}

public plugin_init() 
{
	if ( g_szMapName[ 0 ] == 'c' && g_szMapName[ 1 ] == 's' )
	{
		unregister_forward( FM_Spawn, g_iForward_Spawn )
	}
}

public forward_Spawn( iEnt )
{
	static szClassname[ 23 ]
	
	pev( iEnt, pev_classname, szClassname, charsmax ( szClassname ) )
	
	if ( !strcmp( szClassname, CLASSNAME_LIST[ 0 ] ) )
	{
		set_pev( iEnt, pev_classname, CLASSNAME_LIST[ 1 ] )
		
		return FMRES_OVERRIDE
	}
	else if ( !strcmp( szClassname, CLASSNAME_LIST[ 1 ] ) )
	{
		set_pev( iEnt, pev_classname, CLASSNAME_LIST[ 0 ] )
		
		return FMRES_OVERRIDE
	}
	else if ( !strcmp( szClassname, CLASSNAME_LIST[ 2 ] ) )
	{
		set_pev( iEnt, pev_team, pev( iEnt, pev_team ) == 1 ? 2 : 1 )
		
		return FMRES_OVERRIDE
	}
	return FMRES_IGNORED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

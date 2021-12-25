#include < amxmodx >
#include < fakemeta >
#include < fakemeta_util >
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
	}
}

public plugin_init() 
{
	if ( g_iForward_Spawn )
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
		static iTeam
		
		iTeam = pev( iEnt, pev_team )
		
		set_pev( iEnt, pev_team, iTeam == 1 ? 2 : 1 )
		
		return FMRES_OVERRIDE
	}
	return FMRES_IGNORED
}

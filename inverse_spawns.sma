#include < amxmodx >
#include < fakemeta >

new const TE_SPAWN_CLASSNAME[] = "info_player_deathmatch"
new const CT_SPAWN_CLASSNAME[] = "info_player_start"

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
	server_print(g_szMapName)
	
	if ( g_szMapName[ 0 ] == 'c' && g_szMapName[ 1 ] == 's' )
	{
		g_iForward_Spawn = register_forward( FM_Spawn, "forward_Spawn" )
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
	static szClassname[ 33 ]
	
	pev( iEnt, pev_classname, szClassname, charsmax ( szClassname ) )
	
	if ( !strcmp( szClassname, TE_SPAWN_CLASSNAME ) )
	{
		set_pev( iEnt, pev_classname, CT_SPAWN_CLASSNAME )
		
		return FMRES_OVERRIDE
	}
	else if ( !strcmp( szClassname, CT_SPAWN_CLASSNAME ) )
	{
		set_pev( iEnt, pev_classname, TE_SPAWN_CLASSNAME )
		
		return FMRES_OVERRIDE
	}
	return FMRES_IGNORED
}
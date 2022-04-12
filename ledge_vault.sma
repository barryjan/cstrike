#include <amxmodx>
#include <fakemeta>
#include <xs>

enum _:VarList
{
	Float:flOrigin[ 3 ],
	Float:flTraceStart[ 3 ],
	Float:flTraceEnd[ 3 ],
	Float:flEndPosition[ 3 ],
	Float:flPlaneNormal[ 3 ],
	Float:flVelocity[ 3 ],
	Float:flForward[ 3 ],
	Float:flFraction,
	Float:flFallVelocity,
	Float:pCvarMaxDistance,
	iWaterLevel,
	iButton,
	iOldButtons,
	iFlags,
	pLedgeTrace
}

new g_pCvar_Enable
new g_pCvar_MaxDistance

public plugin_init()
{
	register_plugin
	(
		.plugin_name 	= "Ledge Vault",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	g_pCvar_Enable = register_cvar( "amx_ledgevault", "1" )
	g_pCvar_MaxDistance = register_cvar( "amx_ledgevault_maxdistance", "36" )
	
	register_forward( FM_PlayerPostThink, "forward_PlayerPostThink" )
}

public forward_PlayerPostThink( id )
{
	if ( !is_user_alive( id ) || !get_pcvar_num( g_pCvar_Enable ) )
	{
		return FMRES_IGNORED
	}

	static eVar[ VarList ]
	
	eVar[ iFlags ] = pev( id, pev_flags )
	eVar[ iButton ] = pev( id, pev_button )
	eVar[ iOldButtons ] = pev( id, pev_oldbuttons )
	eVar[ iWaterLevel ] = pev( id, pev_waterlevel )
	eVar[ pLedgeTrace ] = 0
	eVar[ pCvarMaxDistance ] = _:float( get_pcvar_num( g_pCvar_MaxDistance ) )

	pev( id, pev_origin, eVar[ flOrigin ] )
	pev( id, pev_flFallVelocity, eVar[ flFallVelocity ] )

	global_get( glb_v_forward, eVar[ flForward ] )
	
	if ( !( eVar[ iButton ] & IN_JUMP ) || eVar[ iFlags ] & FL_ONGROUND
	|| eVar[ flFallVelocity ] <= 0.0 || eVar[ iWaterLevel ] >= 2 )
	{
		return FMRES_IGNORED 
	}
		
	xs_vec_mul_scalar( eVar[ flForward ], 20.0, eVar[ flForward ] )
	xs_vec_add( eVar[ flOrigin ], eVar[ flForward ], eVar[ flTraceStart ] )
	xs_vec_copy( eVar[ flTraceStart ], eVar[ flTraceEnd ] )
	
	eVar[ flTraceStart ][ 2 ] += eVar[ iFlags ] & FL_DUCKING ? eVar[ pCvarMaxDistance ] : eVar[ pCvarMaxDistance ] - 18.0
	//eVar[ flTraceEnd ][ 2 ] -= ( eVar[ iFlags ] & FL_DUCKING ? 18.0 : 36.0 ) - 17.0 // min offset
	
	engfunc( EngFunc_TraceLine, eVar[ flTraceStart ], eVar[ flTraceEnd ], DONT_IGNORE_MONSTERS, id, eVar[ pLedgeTrace ] )
	
	get_tr2( eVar[ pLedgeTrace ], TR_flFraction, eVar[ flFraction ]  )
	get_tr2( eVar[ pLedgeTrace ], TR_vecEndPos, eVar[ flEndPosition ] )
	get_tr2( eVar[ pLedgeTrace ], TR_vecPlaneNormal, eVar[ flPlaneNormal ] )
	
	if ( eVar[ flFraction ] < 1.0 && eVar[ flPlaneNormal ][ 2 ] > 0.7 )
	{
		global_get( glb_v_forward, eVar[ flForward ] )
		
		xs_vec_mul_scalar( eVar[ flForward ], 5.0, eVar[ flForward ] )
		xs_vec_add( eVar[ flOrigin ], eVar[ flForward ], eVar[ flTraceStart ] )
		
		eVar[ flTraceStart ][ 2 ] = _:( eVar[ flEndPosition ][ 2 ] + 18.0 )
	
		engfunc( EngFunc_TraceHull, eVar[ flTraceStart ], eVar[ flTraceStart ], DONT_IGNORE_MONSTERS, HULL_HEAD, id, eVar[ pLedgeTrace ] )
		
		get_tr2( eVar[ pLedgeTrace ], TR_flFraction, eVar[ flFraction ] )
		get_tr2( eVar[ pLedgeTrace ], TR_vecEndPos, eVar[ flEndPosition ] )
		get_tr2( eVar[ pLedgeTrace ], TR_vecPlaneNormal, eVar[ flPlaneNormal ] )
		
		//xs_vec_mul_scalar( eVar[ flPlaneNormal ], 10.0, eVar[ flPlaneNormal ] )
		xs_vec_add( eVar[ flEndPosition ], eVar[ flPlaneNormal ], eVar[ flEndPosition ] )
		
		if ( 	!get_tr2( eVar[ pLedgeTrace ], TR_StartSolid )
		&& 	!get_tr2( eVar[ pLedgeTrace ], TR_AllSolid )
		&& 	 get_tr2( eVar[ pLedgeTrace ], TR_InOpen )	)
		{
			set_pev( id, pev_fuser2, 1300.0 )
			set_pev( id, pev_flags, eVar[ iFlags ] | FL_DUCKING )

			engfunc( EngFunc_SetSize, id, Float:{ -16.0, -16.0, -18.0 }, Float:{ 16.0, 16.0, 18.0 } )
			engfunc( EngFunc_SetOrigin, id, eVar[ flEndPosition ] )
		}
	}
	free_tr2( eVar[ pLedgeTrace ] )
	
	return FMRES_IGNORED
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

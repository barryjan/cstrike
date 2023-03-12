#include < amxmodx >
#include < amxmisc >
#include < fakemeta >
#include < hamsandwich >
#include < xs >

#tryinclude < cstrike_pdatas >

#if !defined _cbaseentity_included
		#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
				1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
				2. Put it into amxmodx/scripting/include/ folder   \
				3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
				4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

#define IsValidPrivateData(%1) 	( pev_valid( %1 ) == 2 )
#define IsPlayer(%1) 		( 1 <= %1 <= g_iMaxPlayers )
#define IsCSGrenade(%1)  	( pev( %1, pev_iuser2 ) == 18956 )
#define SetCSGrenade(%1) 	set_pev( %1, pev_iuser2, 18956 )

new g_szCoughSounds[][] =
{
	"player/cough1.wav",
	"player/cough2.wav",
	"player/cough3.wav",
	"player/cough4.wav",
	"player/cough5.wav",
	"player/cough6.wav"
}

new g_szSmokeSprite[] = "sprites/large_smoke_01_ind.spr"

new g_iSmokeSprite
new g_iMaxPlayers
new g_iEventId_CreateSmoke

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "CS Grenade",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	register_event( "HLTV", "event_NewRound", "a", "1=0", "2=0" )
	
	register_forward( FM_PlaybackEvent, "forward_PlaybackEvent" )
	register_forward( FM_EmitSound, "forward_EmitSound" )
	
	RegisterHam( Ham_Touch, "trigger_hurt", "forward_Touch" )
	RegisterHam( Ham_Think, "trigger_hurt", "forward_Think" )

	g_iEventId_CreateSmoke = engfunc( EngFunc_PrecacheEvent, 1, "events/createsmoke.sc" )
	g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
	g_iSmokeSprite = precache_model( g_szSmokeSprite )
	
	for ( new i = 0; i < sizeof g_szCoughSounds; i++ )
	{
		precache_sound( g_szCoughSounds[ i ] )
	}
}

public event_NewRound()
{
	new iEnt = -1
	
	while ( ( iEnt = engfunc( EngFunc_FindEntityByString, iEnt, "classname", "trigger_hurt" ) ) > 0 )
	{
		set_pev( iEnt, pev_nextthink, get_gametime() )
	}
}

public forward_Touch( iEnt, id )
{
	if ( IsValidPrivateData( iEnt ) && IsCSGrenade( iEnt ) && IsPlayer( id ) )
	{
		const Float:flSlowdownSpeed = 1315.789428

		static Float:flGametime
		static Float:flDelay

		flGametime = get_gametime()
		pev( id, pev_fuser3, flDelay )
		
		set_pev( id, pev_fuser2, flSlowdownSpeed )
	
		if ( flDelay < flGametime )
		{
			emit_sound( id, CHAN_VOICE, g_szCoughSounds[ random( charsmax( g_szCoughSounds ) ) ], 1.0, ATTN_NORM, 0, PITCH_NORM )
			
			set_pev( id, pev_fuser3, flGametime + 1.0 )
		}
	}
}

public forward_EmitSound( iEnt, iChannel, const szSample[], Float:flVolume, Float:flAttn, iFlags, iPitch )
{
	if ( szSample[ 0 ] != 'w' || !IsCSGrenade( iEnt ) )
	{
		return FMRES_IGNORED
	}
	
	static Float:flOrigin[ 3 ]
	
	pev( iEnt, pev_origin, flOrigin )
	
	if ( contain( szSample, "grenade_hit" ) != -1 )
	{
		static pTrace, Float:flTraceEnd[ 3 ], Float:flPlaneNormal[ 3 ], Float:flFraction
		
		xs_vec_copy( flOrigin, flTraceEnd )
		flTraceEnd[ 2 ] -= 2.0

		engfunc( EngFunc_TraceLine, flOrigin, flTraceEnd, DONT_IGNORE_MONSTERS, iEnt, pTrace )
		
		get_tr2( pTrace, TR_flFraction, flFraction )
		get_tr2( pTrace, TR_vecPlaneNormal, flPlaneNormal )
		free_tr2( pTrace )
		
		if ( flFraction < 1.0 && flPlaneNormal[ 2 ] > 0.7 )
		{
			set_pev( iEnt, pev_flags, FL_ONGROUND )
			set_pev( iEnt, pev_dmgtime, get_gametime() )
			set_pev( iEnt, pev_nextthink, get_gametime() )
		}
	}
	else if ( contain( szSample, "sg_explode" ) != -1 )
	{
		const Float:flGasRadius = 100.0
		const Float:flDuration = 7.0
		
		static iOrigin[ 3 ]

		FVecIVec( flOrigin, iOrigin )
	
		message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
		write_byte( TE_FIREFIELD )
		write_coord( iOrigin[ 0 ] )			// origin.x
		write_coord( iOrigin[ 1 ] )			// origin.y
		write_coord( iOrigin[ 2 ] + 50 )			// origin.z
		write_short( floatround( flGasRadius ) ) 	// radius
		write_short( g_iSmokeSprite ) 			// modelindex
		write_byte( 100 ) 				// count
		write_byte( TEFIRE_FLAG_ALPHA )			// flags
		write_byte( floatround( flDuration ) * 10 )	// duration (in seconds) * 10
		message_end()
		
		new iSmokeEnt = engfunc( EngFunc_CreateNamedEntity , engfunc( EngFunc_AllocString, "trigger_hurt" ) )
		
		if (iSmokeEnt )
		{
			static Float:flMins[ 3 ], Float:flMaxs[ 3 ]
			
			dllfunc( DLLFunc_Spawn, iSmokeEnt )
			
			xs_vec_set( flMins, -flGasRadius, -flGasRadius, -flGasRadius )
			xs_vec_set( flMaxs, flGasRadius, flGasRadius, flGasRadius )
			
			engfunc( EngFunc_SetSize , iSmokeEnt , flMins , flMaxs )
			engfunc( EngFunc_SetOrigin, iSmokeEnt, flOrigin )

			set_pev( iSmokeEnt, pev_spawnflags, SF_TRIGGER_HURT_NO_CLIENTS )
			set_pev( iSmokeEnt, pev_nextthink, get_gametime() + flDuration )

			SetCSGrenade( iSmokeEnt )
			
			set_pev( iEnt, pev_effects, EF_NODRAW ) 
		}
	}
	return FMRES_IGNORED
}

public forward_PlaybackEvent( iFlags, iInvoker, iEventIndex ) 
{
	if ( iEventIndex == g_iEventId_CreateSmoke )
	{
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public forward_Think( iEnt )
{
	if ( IsCSGrenade( iEnt ) )
	{
		engfunc( EngFunc_RemoveEntity, iEnt )
	}
}

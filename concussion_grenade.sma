#include < amxmodx >
#include < cstrike >
#include < hamsandwich >
#include < fakemeta >
#include < xs >

#define MAX_PLAYERS 		32
#define MAX_FILELEN 		64
#define MAX_ENTSARRAY_SIZE 	64
#define XO_CBASEPLAYERITEM	4
#define m_pPlayer 		41
#define IsValidPrivateData(%1) 	( pev_valid( %1 ) == 2 )
#define IsPlayer(%1) 		( 1 <= %1 <= g_iMaxPlayers )
#define IsConcGrenade(%1) 	( pev( %1, pev_iuser2 ) == 324665 )
#define SetConcGrenade(%1) 	set_pev( %1, pev_iuser2, 324665 )
#define SetStunTime(%1,%2) 	set_pev( %1, pev_fuser3, %2 )
#define GetStunTime(%1) 	pev( %1, pev_fuser3 )

new const g_szWeaponName[][] 	= { "Flashbang", "Concussion Grenade" }
new const Float:CONC_RADIUS 	= 500.0 	// blast radius
new const CONC_AMOUNT[]		= { 5, 10 } 	// min, max
new const Float:SLOWDOWN_SHOCK 	= 1316.0 	// slow down modifier
new const Float:DUR_MODIFIER 	= 0.6 		// stun duration modifier
new const Float:MAX_DELAY	= 10.0 		// max detonation delay
new const COLOR[] 		= { 200, 200, 200 } // flash color (rgb)
new const MAX_ALPHA 		= 160 		// flash alpha

enum _:GrenadeData
{
	Owner,
	GrenadeEnt,
	Float:ExplodeTime
}

enum _:Resources
{
	vModel[ MAX_FILELEN ],
	pModel[ MAX_FILELEN ],
	wModel[ MAX_FILELEN ],
	 Sound[ MAX_FILELEN ]
}

new g_eConcGrenadeFiles[ Resources ] =
{
	"models/v_concussiongrenade.mdl",
	"models/p_concussiongrenade.mdl",
	"models/w_concussiongrenade.mdl",
	"weapons/concussiongrenade-1.wav"
}

new g_bGrenadeExplode[ MAX_ENTSARRAY_SIZE ]
new g_eConcGrenadeEntData[ GrenadeData ]
new bool:g_bPlayerConcMode[ MAX_PLAYERS + 1 ]
new g_iMsgId_Concuss
new g_pCvar_FriendlyFire
new g_iMaxPlayers

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Concussion Grenade",
		.version	= "1.1",
		.author 	= "BARRY."
	)
	
	register_message( get_user_msgid( "ScreenFade" ), "message_ScreenFade" )
	
	RegisterHam( Ham_Think, "grenade", "forward_Think" )
	RegisterHam( Ham_Item_Deploy, "weapon_flashbang", "forward_Item_Deploy_Post", .Post = 1 )
	RegisterHam( Ham_Weapon_SecondaryAttack, "weapon_flashbang", "forward_SecondaryAttack" )
	
	register_forward( FM_FindEntityInSphere, "forward_FindEntityInSphere" )
	register_forward( FM_PlayerPreThink, "forward_PlayerPreThink" )
	register_forward( FM_EmitSound, "forward_EmitSound" )
	register_forward( FM_SetModel, "forward_SetModel_Post", ._post = 1 )
	
	g_iMsgId_Concuss = engfunc( EngFunc_RegUserMsg, "Concuss", -1 )
	g_pCvar_FriendlyFire = get_cvar_pointer( "mp_friendlyfire" )
	g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
	precache_model( g_eConcGrenadeFiles[ vModel ] )
	precache_model( g_eConcGrenadeFiles[ pModel ] )
	precache_model( g_eConcGrenadeFiles[ wModel ] )
	precache_sound( g_eConcGrenadeFiles[ Sound ] )
}

public client_putinserver( id )
{
	g_bPlayerConcMode[ id ] = false
}

public message_ScreenFade( iMsgID, iDest, iPlayer )
{
	if ( get_msg_arg_int( 4 ) != 255 || get_msg_arg_int( 5 ) != 255 || get_msg_arg_int( 6 ) != 255 )
	{
		return PLUGIN_CONTINUE
	}
	
	if ( g_eConcGrenadeEntData[ ExplodeTime ] == get_gametime()
	&& IsConcGrenade( g_eConcGrenadeEntData[ GrenadeEnt ] ) )
	{
		new Float:flStunDuration = ( float( get_msg_arg_int( 1 ) ) / 4096.0 ) * DUR_MODIFIER
		new iAlpha = get_msg_arg_int( 7 )

		set_msg_arg_int( 4, ARG_BYTE, COLOR[ 0 ] ) // red
		set_msg_arg_int( 5, ARG_BYTE, COLOR[ 1 ] ) // green
		set_msg_arg_int( 6, ARG_BYTE, COLOR[ 2 ] ) // blue
		set_msg_arg_int( 7, ARG_BYTE, iAlpha > MAX_ALPHA ? MAX_ALPHA : iAlpha )
		
		engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_iMsgId_Concuss, Float:{ 0.0, 0.0, 0.0 }, iPlayer )
		write_byte( random_num( CONC_AMOUNT[ 0 ], CONC_AMOUNT[ 1 ] ) ) // amount
		message_end()
		
		SetStunTime( iPlayer, get_gametime() + flStunDuration )
	}
	return PLUGIN_CONTINUE
}

public forward_Think( iEnt )
{
	if ( !IsValidPrivateData( iEnt ) || !IsConcGrenade( iEnt ) )
	{
		return HAM_IGNORED
	}
	
	static Float:flGameTime, Float:flDmgTime, Float:flVelocity[ 3 ], iOwner
	
	flGameTime = get_gametime()
	
	pev( iEnt, pev_dmgtime, flDmgTime )
	pev( iEnt, pev_velocity, flVelocity )
	
	if ( flVelocity[ 0 ] == 0.0 && flVelocity[ 1 ] == 0.0 && flVelocity[ 2 ] == 0.0 )
	{
		flDmgTime = flGameTime
	}
	
	if ( flDmgTime <= flGameTime && IsPlayer( ( iOwner = pev( iEnt, pev_owner ) ) ) )
	{
		#define SetGrenadeExplode(%1) 	g_bGrenadeExplode[ %1>>5 ] |= 1<<( %1 & 31 )
		#define ClearGrenadeExplode(%1) g_bGrenadeExplode[ %1>>5 ] &= ~( 1 << ( %1 & 31 ) )
		#define WillGrenadeExplode(%1) 	g_bGrenadeExplode[ %1>>5 ] & 1<<( %1 & 31 )
		
		if( ~WillGrenadeExplode( iEnt ) )
		{
			SetGrenadeExplode( iEnt ) // will explode on next think
		}
		else
		{
			ClearGrenadeExplode( iEnt )
	
			g_eConcGrenadeEntData[ Owner ] = iOwner
			g_eConcGrenadeEntData[ GrenadeEnt ] = iEnt
			g_eConcGrenadeEntData[ ExplodeTime ] = _:flGameTime
		}
	}
	return HAM_IGNORED
}

public forward_SecondaryAttack( iEnt )
{	
	new id = get_pdata_cbase( iEnt, m_pPlayer, XO_CBASEPLAYERITEM )

	if ( cs_get_user_shield( id ) || ( pev( id, pev_button ) & IN_ATTACK ) )
	{
		return HAM_IGNORED
	}
	
	const iDeloyAnim = 3
	
	g_bPlayerConcMode[ id ] = ( g_bPlayerConcMode[ id ] == true ) ? false : true

	client_print( id, print_center, "Switched to %s", g_szWeaponName[ g_bPlayerConcMode[ id ] ] )
		
	#if AMXX_VERSION_NUM > 182
	ExecuteHamB( Ham_CS_Weapon_SendWeaponAnim, iEnt, iDeloyAnim, 0, pev( id, pev_body ) )
	#else
	ExecuteHamB( Ham_Weapon_SendWeaponAnim, iEnt, iDeloyAnim, 0, pev( id, pev_body ) )
	#endif

	ExecuteHamB( Ham_Item_Deploy, iEnt )
	
	return HAM_IGNORED
}

public forward_Item_Deploy_Post( iEnt )
{
	new id = get_pdata_cbase( iEnt, m_pPlayer, XO_CBASEPLAYERITEM )
	
	if ( cs_get_user_shield( id ) )
	{
		client_print( id, print_center, "%s", g_szWeaponName[ g_bPlayerConcMode[ id ] ] )
	}
	else if ( g_bPlayerConcMode[ id ] )
	{
		set_pev( id, pev_viewmodel2, g_eConcGrenadeFiles[ vModel ] )
		set_pev( id, pev_weaponmodel2, g_eConcGrenadeFiles[ pModel ] )
	}
	return HAM_IGNORED
}

public forward_FindEntityInSphere( iStartEnt, Float:flOrigin[ 3 ], Float:flRadius )
{ 
	const Float:FLASHBANG_RADIUS = 1500.0

	if ( flRadius == FLASHBANG_RADIUS && g_eConcGrenadeEntData[ ExplodeTime ] == get_gametime() )
	{ 
		new id = iStartEnt
		new iCurrentFlasher = g_eConcGrenadeEntData[ Owner ]
		new iCurrentFlashbang = g_eConcGrenadeEntData[ GrenadeEnt ]
		
		if ( !IsValidPrivateData( iCurrentFlashbang ) || !IsConcGrenade( iCurrentFlashbang ) )
		{
			return FMRES_IGNORED
		}

		while ( IsPlayer( ( id = engfunc( EngFunc_FindEntityInSphere, id, flOrigin, CONC_RADIUS ) ) > 0 ) )
		{ 
			if ( is_user_alive( id ) && is_user_visible( iCurrentFlashbang, id ) )
			{
				if ( id != iCurrentFlasher && !get_pcvar_num( g_pCvar_FriendlyFire )
				&& get_user_team( id ) == get_user_team( iCurrentFlasher ) )
				{
					continue
				}
				
				forward_return( FMV_CELL, id )

				return FMRES_SUPERCEDE
			}
		}
		forward_return( FMV_CELL, 0 )
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED 
}

public forward_SetModel_Post( iEnt, const szModel[] )
{
	if ( !IsValidPrivateData( iEnt ) || contain( szModel, "flashbang" ) == -1 )
	{
		return FMRES_IGNORED
	}
	
	static Float:flGravity
	
	pev( iEnt, pev_gravity, flGravity )
	
	if ( flGravity > 0.0 && g_bPlayerConcMode[ pev( iEnt, pev_owner ) ] )
	{
		SetConcGrenade( iEnt )
		
		set_pev( iEnt, pev_dmgtime, get_gametime() + MAX_DELAY )
		engfunc( EngFunc_SetModel, iEnt, g_eConcGrenadeFiles[ wModel ] )
				
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public forward_PlayerPreThink( id )
{
	if ( !is_user_alive( id ) )
	{
		return FMRES_IGNORED
	}
	
	if ( GetStunTime( id ) > get_gametime() )
	{
		set_pev( id, pev_fuser2, SLOWDOWN_SHOCK )
	}
	else
	{
		if ( GetStunTime( id ) != 0.0 )
		{
			SetStunTime( id, 0.0 )
			
			engfunc( EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_iMsgId_Concuss, Float:{ 0.0, 0.0, 0.0 }, id )
			write_byte( 0 ) // amount
			message_end()
		}
	}
	return FMRES_IGNORED
}

public forward_EmitSound( iEnt, iChannel, const szSample[], Float:flVolume, Float:flAttn, iFlags, iPitch )
{
	if ( szSample[ 0 ] != 'w' || !IsConcGrenade( iEnt ) )
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
			set_pev( iEnt, pev_dmgtime, get_gametime() + 0.1 )
			set_pev( iEnt, pev_nextthink, get_gametime() + 0.1 )
		}
	}
	else if ( contain( szSample, "flashbang" ) != -1  )
	{
		static iOrigin[ 3 ]
		
		FVecIVec( flOrigin, iOrigin )

		message_begin( MSG_BROADCAST, SVC_TEMPENTITY )
		write_byte( TE_ARMOR_RICOCHET )
		write_coord( iOrigin[ 0 ] )
		write_coord( iOrigin[ 1 ] )
		write_coord( iOrigin[ 2 ] )
		write_byte( 100 )
		message_end()
		
		emit_sound( iEnt, iChannel, g_eConcGrenadeFiles[ Sound ], flVolume, flAttn, iFlags, iPitch )
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

bool:is_user_visible( iEnt, iPlayer )
{
	if ( !iEnt || !iPlayer )
	{
		return false
	}

	if ( pev_valid( iEnt ) && pev_valid( iPlayer ) )
	{
		new iFlags = pev( iEnt, pev_flags )
		
		if ( iFlags & EF_NODRAW || iFlags & FL_NOTARGET )
		{
			return false
		}

		static Float:flLookerOrigin[ 3 ]
		static Float:flTargetBaseOrigin[ 3 ]
		static Float:flTargetOrigin[ 3 ]
		static Float:flTemp[ 3 ]
		static Float:flFraction
		
		pev( iEnt, pev_origin, flLookerOrigin )
		pev( iEnt, pev_view_ofs, flTemp )
		xs_vec_add( flLookerOrigin, flTemp, flLookerOrigin )
		
		pev( iPlayer, pev_origin, flTargetBaseOrigin )
		pev( iPlayer, pev_view_ofs, flTemp )
		xs_vec_add( flTargetBaseOrigin, flTemp, flTargetOrigin )
	
		engfunc( EngFunc_TraceLine, flLookerOrigin, flTargetOrigin, DONT_IGNORE_MONSTERS, iEnt, 0 ) //  checks the head of seen player
        
		if ( get_tr2( 0, TR_InOpen ) && get_tr2( 0, TR_InWater ) )
		{
			return false
		}
		else 
		{
			get_tr2( 0, TR_flFraction, flFraction )
			
			if ( flFraction == 1.0 || get_tr2( 0, TR_pHit ) == iPlayer )
			{
				return true
			}
			else
			{
				xs_vec_copy( flTargetBaseOrigin, flTargetOrigin )
				
				engfunc( EngFunc_TraceLine, flLookerOrigin, flTargetOrigin, DONT_IGNORE_MONSTERS, iEnt, 0 ) //  checks the body of seen player
				get_tr2( 0, TR_flFraction, flFraction )
				
				if ( flFraction == 1.0 || get_tr2( 0, TR_pHit ) == iPlayer )
				{
					return true
				}
				else
				{
					flTargetOrigin[ 2 ] = flTargetBaseOrigin[ 2 ] - 17.0
					
					engfunc( EngFunc_TraceLine, flLookerOrigin, flTargetOrigin, DONT_IGNORE_MONSTERS, iEnt, 0) //  checks the legs of seen player
					get_tr2( 0, TR_flFraction, flFraction )

					if ( flFraction == 1.0 || get_tr2( 0, TR_pHit ) == iPlayer )
					{
						return true
					}
				}
			}
		}
	}
	return false
}

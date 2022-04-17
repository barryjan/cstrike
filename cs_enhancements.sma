#include < amxmodx >
#include < cstrike > 
#include < hamsandwich >
#include < fakemeta >
#include < xs >

#tryinclude < cstrike_pdatas >

#if !defined _cbaseentity_included
		#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
				1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
				2. Put it into amxmodx/scripting/include/ folder   \
				3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
				4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

#define MAX_PLAYERS 		32
#define m_iUserPrefs 		510
#define USERPREFS_HAS_SHIELD 	(1<<24)
#define FIRE_RATE_GLOCK 	0.0545
#define MAX_INACCURACY 		1

new g_iMsgId_CurWeapon
new g_iMsgId_TextMsg
new g_iOldClip
new g_iResetDuckFlag
new g_iResetZoom
new g_bInZoom[ MAX_PLAYERS + 1 ]
new g_iForward_Spawn
new g_iRegisteredCZBots

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "CS Enhancements",
		.version	= "1.0",
		.author 	= "BARRY."
	)

	RegisterHam( Ham_Weapon_PrimaryAttack,	"weapon_elite", "forward_AutoPrimaryAttack" )
	RegisterHam( Ham_Weapon_PrimaryAttack,	"weapon_fiveseven", "forward_AutoPrimaryAttack" )
	RegisterHam( Ham_Weapon_PrimaryAttack,	"weapon_elite", "forward_AutoPrimaryAttack_Post", .Post = 1 )
	RegisterHam( Ham_Weapon_PrimaryAttack,	"weapon_fiveseven", "forward_AutoPrimaryAttack_Post", .Post = 1 )
	
	RegisterHam( Ham_Weapon_PrimaryAttack,	"weapon_glock18", "forward_GlockPrimaryAttack_Post", .Post = 1 )	
	RegisterHam( Ham_Weapon_SecondaryAttack,"weapon_glock18", "forward_GlockSecondaryAttack" )
	RegisterHam( Ham_Item_Deploy, 		"weapon_glock18", "forward_GlockDeploy_Post", .Post = 1 )
	RegisterHam( Ham_Item_PostFrame, 	"weapon_glock18", "forward_GlockPostFrame" )
	
	RegisterHam( Ham_Item_PostFrame, 	"weapon_famas",	  "forward_FamasPostFrame_Post", .Post = 1 )
	
	new const szSniperWeapons[][] = { "weapon_sg550", "weapon_g3sg1", "weapon_scout" }
	
	for ( new i = 0; i < sizeof ( szSniperWeapons ); i++ )
	{
		RegisterHam( Ham_Weapon_PrimaryAttack,	szSniperWeapons[ i ], "forward_SnprPrimaryAttack" )
		RegisterHam( Ham_Weapon_PrimaryAttack,	szSniperWeapons[ i ], "forward_SnprPrimaryAttack_Post", .Post = 1 )
	}

	new const szAccurateWeapons[][] = { "weapon_m249", "weapon_sg550", "weapon_mp5navy", 
					    "weapon_p90", "weapon_mac10", "weapon_tmp", "weapon_ump45" }

	for ( new i = 0; i < sizeof ( szAccurateWeapons ); i++ )
	{				
		RegisterHam( Ham_Weapon_PrimaryAttack, 	szAccurateWeapons[ i ], "forward_PrimaryAttack_Post", .Post = 1 )
	}
	
	new const szAutoWeapons[][] = { 	"weapon_tmp", "weapon_mac10", "weapon_mp5navy", "weapon_ump45", "weapon_p90", "weapon_m249", 
					"weapon_galil", "weapon_famas", "weapon_ak47", "weapon_m4a1", "weapon_sg552", "weapon_aug" }
					
	for ( new i = 0; i < sizeof ( szAutoWeapons ); i++ )
	{
		RegisterHam( Ham_Weapon_PlayEmptySound,  szAutoWeapons[ i ], "forward_WeaponPlayEmptySound" )
	}
	
	RegisterHam( Ham_Item_Deploy, "weapon_knife", "forward_KnifeDeploy_Post", .Post = 1 )
	
	RegisterHam( Ham_TakeDamage, "player", "forward_TakeDamage" )
	RegisterHam( Ham_TraceAttack, "player", "forward_TraceAttack" )
 
	register_event( "CurWeapon", "event_CurWeapon", "be", "1=1" )
	register_event( "SetFOV", "event_SetFOV", "be" )

	if ( g_iForward_Spawn )
	{
		unregister_forward( FM_Spawn, g_iForward_Spawn )
	}
	
	new szModName[ 6 ]
	
	get_modname( szModName, charsmax( szModName ) )
	
	if ( !equal( szModName, "czero" ) || cvar_exists( "pb_version" ) )
	{
		g_iRegisteredCZBots = -1
	}

	g_iMsgId_CurWeapon = get_user_msgid( "CurWeapon" )
	g_iMsgId_TextMsg = get_user_msgid( "TextMsg" )
}

public plugin_precache()
{
	g_iForward_Spawn = register_forward( FM_Spawn, "forward_Spawn" )
}

public forward_Spawn( iEnt )
{
	static szClassname[ 32 ]
	
	pev( iEnt, pev_classname, szClassname, charsmax( szClassname ) )
	
	if ( equal( szClassname, "func_door_rotating" ) 
	||   equal( szClassname, "func_door" ) )
	{
		engfunc( EngFunc_RemoveEntity, iEnt )

		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public forward_KnifeDeploy_Post( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static Float:flOrigin[ 3 ], Float:flEndOrigin[ 3 ]
	static pTrace
	
	pev( id, pev_origin, flOrigin )
	velocity_by_aim( id, 31, flEndOrigin )
	xs_vec_add( flEndOrigin, flOrigin, flEndOrigin )
	
	engfunc( EngFunc_TraceHull, flEndOrigin, flEndOrigin, DONT_IGNORE_MONSTERS, HULL_HEAD, id, pTrace )
	
	if ( get_tr2( pTrace, TR_pHit ) > 0 )
	{	
		set_pdata_float( id, m_flNextAttack, 0.0, 5 )
		ExecuteHamB( Ham_Weapon_SecondaryAttack, iEnt )
		
		set_task( 0.65, "task_LastWeapon", id )
	}
	
	free_tr2( pTrace )
}

public task_LastWeapon( id )
{
	if ( !is_user_alive( id ) )
	{
		return
	}
	
	new iEnt = get_pdata_cbase( id, m_pLastItem, 5 )
	
	if ( pev_valid( iEnt ) )
	{
		set_pdata_cbase( id, m_pActiveItem, iEnt )
		ExecuteHamB( Ham_Item_Deploy, iEnt )
	}
}

public client_putinserver( id )
{
	if ( !g_iRegisteredCZBots && is_user_bot( id ) )
	{
		set_task( 0.1, "register_bots", id )
	}
}

public register_bots( id )
{
	if ( !g_iRegisteredCZBots && is_user_connected( id ) )
	{
		g_iRegisteredCZBots = 1
		
		RegisterHamFromEntity( Ham_TakeDamage, id, "forward_TakeDamage" )
		RegisterHamFromEntity( Ham_TraceAttack, id, "forward_TraceAttack" )
	}
}

public forward_TakeDamage( id, iInflictor, iAttacker, Float:flDamage )
{
	if ( is_user_alive( iAttacker ) && get_user_weapon( iAttacker ) == CSW_KNIFE )
	{
		if ( flDamage >= 65.0 )
		{
			SetHamParamFloat( 4, 195.0 )
		}
		
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public forward_TraceAttack( id, iAttacker, Float:flDamage, Float:flDirection[ 3 ], pTrace, bitDamageBits )
{
	if ( !( bitDamageBits & DMG_BULLET ) || get_user_weapon( iAttacker) == CSW_KNIFE )
	{
		return HAM_IGNORED
	}
	
	const bitsBodyArmor = ( 1 << HIT_CHEST | 1 << HIT_STOMACH )
	
	if ( ( 1 << get_tr2( pTrace, TR_iHitgroup ) ) & bitsBodyArmor )
	{
		static Float:flArmor
		flArmor = float( pev( id, pev_armorvalue ) ) - flDamage

		if ( flArmor > 0.0 )
		{
			
			#define HIT_SHIELD 8 
			set_tr2( pTrace, TR_iHitgroup, HIT_SHIELD )
			set_pev( id, pev_armorvalue, floatmax( 0.0, flArmor ) )
			//SetHamParamFloat( 3, 0.0 )
		}
	}
	return HAM_IGNORED
}

public forward_SnprPrimaryAttack( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static bitFlags; bitFlags = pev( id, pev_flags )
	static iFOV; iFOV = get_pdata_int( id, m_iFOV, 5 )

	g_iResetDuckFlag = ( bitFlags & FL_DUCKING ) ? 0 : 1
	g_iResetZoom = iFOV >= 90 ? 1 : 0
	set_pev( id, pev_flags, ( bitFlags | FL_DUCKING ) )
	
	if ( iFOV )
	{ 
		set_pdata_int( id, m_iFOV, 15, 5 )
		set_pdata_int( id, m_iClientFOV, 15, 5 )
		set_pdata_int( id, m_iLastZoom, 15, 5 )
	}
	
	if ( get_pdata_int( iEnt, m_iId, 4 ) == CSW_SG550 )
	{
		set_pdata_float( iEnt, m_flAccuracy, 1.0, 4 )
	}
}

public forward_SnprPrimaryAttack_Post( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	
	if ( g_iResetDuckFlag )
	{
		set_pev( id, pev_flags, ( pev( id, pev_flags ) & ~FL_DUCKING ) )
	}
	
	if ( g_iResetZoom )
	{ 
		set_pdata_int( id, m_iFOV, 90, 5 )
	}
	
	if ( get_pdata_int( iEnt, m_iId, 4 ) == CSW_SCOUT )
	{
		set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.95, 4 )
	}
}

public forward_WeaponPlayEmptySound( iEnt )
{
	new iSecWeapon
	
	if ( ( iSecWeapon = get_pdata_cbase( get_pdata_cbase( iEnt, m_pPlayer, 4 ), m_rgpPlayerItems_CBasePlayer[ 2 ] ) ) > 0 )
	{
		if ( get_pdata_int( iEnt, m_iShotFired, 4 ) > 4 )
		{
			ExecuteHamB( Ham_Weapon_RetireWeapon, iEnt )
			ExecuteHamB( Ham_Item_Deploy, iSecWeapon )
		}
	}
}

public forward_PrimaryAttack_Post( iEnt )
{
	if ( get_pdata_int( iEnt, m_iShotFired, 4 ) > MAX_INACCURACY )
	{
		set_pdata_int( iEnt, m_iShotFired, 0, 4 )
	}
}

public forward_FamasPostFrame_Post( iEnt ) 
{
	set_pdata_float( iEnt, m_flFamasBurstSpread, 0.0, 4 )
}

public forward_AutoPrimaryAttack( iEnt )
{
	g_iOldClip = get_pdata_int( iEnt, m_iClip, 4 )
}

public forward_AutoPrimaryAttack_Post( iEnt )
{
	if ( g_iOldClip > get_pdata_int( iEnt, m_iClip, 4 ) )
	{
		static Float:flPunchAngle[ 3 ]
		
		pev( get_pdata_cbase( iEnt, m_pPlayer, 4 ), pev_punchangle, flPunchAngle )
		
		flPunchAngle[ 0 ] *= 0.65
		
		set_pev( get_pdata_cbase( iEnt, m_pPlayer, 4 ), pev_punchangle, flPunchAngle )
	}
	
	set_pdata_int( iEnt, m_iShotFired, 0, 4 )
	set_pdata_float( iEnt, m_flAccuracy, 1.0, 4 )
}

public forward_GlockDeploy_Post( iEnt )
{
	emessage_begin( MSG_ONE, g_iMsgId_TextMsg, _, get_pdata_cbase( iEnt, m_pPlayer, 4 ) )
	ewrite_byte( print_center )
	if ( get_pdata_int( iEnt, m_fWeaponState, 4 ) & WEAPONSTATE_GLOCK18_BURST_MODE )
	{
		ewrite_string( "#Switch_To_FullAuto" )
	}
	else
	{
		ewrite_string( "#Switch_To_SemiAuto" )
	}
	emessage_end()
}

public forward_GlockPostFrame( iEnt )
{
	if ( get_pdata_int( iEnt, m_fWeaponState, 4 ) & WEAPONSTATE_GLOCK18_BURST_MODE )
	{
		if ( get_pdata_float( iEnt, m_flNextPrimaryAttack, 4 ) <= 0.0
		&& !get_pdata_int( iEnt, m_fInReload, 4 ) 
		&& get_pdata_int( iEnt, m_iClip, 4 ) <= 0 )
		{
			static s_iPlrId
			s_iPlrId = get_pdata_cbase( iEnt, m_pPlayer, 4 )
			
			if ( pev( s_iPlrId, pev_button ) & IN_ATTACK )
			{
				set_pdata_int( s_iPlrId, m_bIsPrimaryFireAllowed, 0, 5 )
			}
		}
	}
}

public forward_GlockSecondaryAttack( iEnt )
{
	if ( get_pdata_int( get_pdata_cbase( iEnt, m_pPlayer, 4 ), m_iUserPrefs, 5 ) & USERPREFS_HAS_SHIELD )
	{
		return HAM_IGNORED
	}
	
	static s_iWpnState
	s_iWpnState = get_pdata_int( iEnt, m_fWeaponState, 4 )
	
	if ( ~s_iWpnState & WEAPONSTATE_GLOCK18_BURST_MODE )
	{
		s_iWpnState |= WEAPONSTATE_GLOCK18_BURST_MODE
		
		set_pdata_int( iEnt, m_fWeaponState, s_iWpnState, 4 )
		set_pdata_float( iEnt, m_flNextSecondaryAttack, 0.3, 4 )
		
		emessage_begin( MSG_ONE, g_iMsgId_TextMsg, _, get_pdata_cbase( iEnt, m_pPlayer, 4 ) )
		ewrite_byte( print_center )
		ewrite_string( "#Switch_To_FullAuto" )
		emessage_end()
		
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public forward_GlockPrimaryAttack_Post( iEnt )
{
	if ( get_pdata_int( iEnt, m_fWeaponState, 4 ) & WEAPONSTATE_GLOCK18_BURST_MODE )
	{
		if ( get_pdata_int( iEnt, m_iGlock18ShotsFired, 4 ) != 0 )
		{
			set_pdata_int( iEnt, m_iGlock18ShotsFired, 0, 4 )
			set_pdata_float( iEnt, m_flGlock18Shoot, 0.0, 4 )
			set_pdata_float( iEnt, m_flNextPrimaryAttack, FIRE_RATE_GLOCK, 4 )
			set_pdata_float( iEnt, m_flNextSecondaryAttack, FIRE_RATE_GLOCK, 4 )
		}
	}
}

public event_CurWeapon( id )
{
	new iCurWeapon = read_data( 2 )
	
	const bitSniperWeapons = ( 1 << CSW_SG550 | 1 << CSW_G3SG1 | 1 << CSW_SCOUT )
	
	if ( !g_bInZoom[ id ] && bitSniperWeapons & ( 1 << iCurWeapon ) )
	{
		message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_CurWeapon, _, id )
		write_byte( 1 )
		write_byte( ( iCurWeapon == CSW_SG550 ) ? CSW_GALIL : CSW_AK47 )
		write_byte( read_data( 3 ) )
		message_end()
	}
}

public event_SetFOV( id )
{
	g_bInZoom[ id ] = ( 0 < read_data( 1 ) < 55 )
}

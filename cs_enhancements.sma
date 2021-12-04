#include < amxmodx >
#include < cstrike > 
#include < hamsandwich >
#include < fakemeta >

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
#define MAX_INACCURACY 		2

new g_iMsgId_CurWeapon
new g_iMsgId_TextMsg

new g_bInZoom[ MAX_PLAYERS + 1 ]

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "CS Enhancements",
		.version	= "1.0",
		.author 	= "BARRY."
	)

	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_m249", 	"forward_WeaponPrimaryAttack" )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_mac10", 	"forward_WeaponPrimaryAttack" )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_tmp", 	"forward_WeaponPrimaryAttack" )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_sg550",	"forward_WeaponPrimaryAttack" )

	RegisterHam( Ham_Item_PostFrame,	"weapon_m249", 	   "forward_ItemPostFrame_Post", .Post = 1 )
	RegisterHam( Ham_Item_PostFrame,       	"weapon_mac10",    "forward_ItemPostFrame_Post", .Post = 1 )
	RegisterHam( Ham_Item_PostFrame,       	"weapon_tmp", 	   "forward_ItemPostFrame_Post", .Post = 1 )
	RegisterHam( Ham_Item_PostFrame,       	"weapon_sg550",    "forward_ItemPostFrame_Post", .Post = 1 )
	
	RegisterHam( Ham_Weapon_PrimaryAttack, 	 "weapon_glock18", "forward_GlockPrimaryAttack_Post", .Post = 1 )
	RegisterHam( Ham_Weapon_SecondaryAttack, "weapon_glock18", "forward_GlockSecondaryAttack" )
	RegisterHam( Ham_Item_Deploy, 		 "weapon_glock18", "forward_GlockDeploy_Post", .Post = 1 )
	RegisterHam( Ham_Item_PostFrame, 	 "weapon_glock18", "forward_GlockPostFrame" )
	
	
	new const szPrimaryWeapons[][] = { "weapon_tmp", "weapon_mac10", "weapon_mp5navy", "weapon_ump45", "weapon_p90", "weapon_m249", 
					"weapon_galil", "weapon_famas", "weapon_ak47", "weapon_m4a1", "weapon_sg552", "weapon_aug" }
					
	for ( new i = 0; i < sizeof ( szPrimaryWeapons ); i++ )
	{
		RegisterHam( Ham_Weapon_PlayEmptySound,  szPrimaryWeapons[ i ], "forward_WeaponPlayEmptySound" )
	}
	
	register_event( "CurWeapon", 	"event_CurWeapon", 	"be", "1=1" )
	register_event( "SetFOV", 	"event_SetFOV", 	"be" )

	g_iMsgId_CurWeapon = get_user_msgid( "CurWeapon" )
	g_iMsgId_TextMsg = get_user_msgid( "TextMsg" )
}

public forward_WeaponPlayEmptySound( iEnt )
{
	new iSecWeapon = get_pdata_cbase( get_pdata_cbase( iEnt, m_pPlayer, 4 ), m_rgpPlayerItems_CBasePlayer[ 2 ] )
	if ( iSecWeapon )
	{
		if ( get_pdata_int( iEnt, m_iShotFired, 4 ) > 4 )
		{
			ExecuteHamB( Ham_Weapon_RetireWeapon, iEnt )
			ExecuteHamB( Ham_Item_Deploy, iSecWeapon )
		}
	}
}

public forward_WeaponPrimaryAttack( iEnt )
{
	switch ( get_pdata_int( iEnt, m_iId, 4 ) )
	{
		case CSW_SG550: set_pdata_float( iEnt, m_flAccuracy, 1.0, 4 )
		default: set_pdata_float( iEnt, m_flAccuracy, 0.0, 4 )
	}
	
}

public forward_ItemPostFrame_Post( iEnt )
{
	if ( get_pdata_int( iEnt, m_iShotFired, 4 ) > MAX_INACCURACY )
	{
		set_pdata_int( iEnt, m_iShotFired, MAX_INACCURACY, 4 )
	}
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
	
	if ( !g_bInZoom[ id ] && ( iCurWeapon == CSW_SG550 || iCurWeapon == CSW_G3SG1 ) )
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

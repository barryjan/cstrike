#include <amxmodx>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>

#tryinclude <cstrike_pdatas>

#if !defined _cbaseentity_included
		#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \
				1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   \
				2. Put it into amxmodx/scripting/include/ folder   \
				3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
				4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif

#define MAX_SEMIAUTO_INACCURACY 3 // level of maximum inaccuracy and recoil for semi-auto
#define WEAPONSTATE_GLOCK18_BURST_MODE (1<<1)

#define setWeaponInReload(%1) 	set_pev( %1, pev_euser1, 1 )
#define clearWeaponInReload(%1) set_pev( %1, pev_euser1, 0 )
#define isWeaponInReload(%1) 	( pev( %1, pev_euser1 ) == 1 )
#define setBulletsNum(%1,%2)	set_pev( %1, pev_euser2, %2 )
#define getBulletsNum(%1)	pev( %1, pev_euser2 )

new g_iMsgId_TextMsg


public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Semi Auto AK-47",
		.version	= "1.0",
		.author 	= "BARRY."
	)

	RegisterHam( Ham_Weapon_PrimaryAttack,	"weapon_ak47", "forward_WeaponPrimaryAttack" )
	RegisterHam( Ham_Item_Deploy,          	"weapon_ak47", "forward_ItemDeploy_Post", .Post = 1 )
	RegisterHam( Ham_Item_PostFrame,       	"weapon_ak47", "forward_ItemPostFrame" )
	RegisterHam( Ham_Item_PostFrame,       	"weapon_ak47", "forward_ItemPostFrame_Post", .Post = 1 )
	
	g_iMsgId_TextMsg = get_user_msgid( "TextMsg" )
}

public forward_WeaponPrimaryAttack( iEnt )
{
	if ( isWeaponInReload( iEnt ) )
	{
		clearWeaponInReload( iEnt )
		setBulletsNum( iEnt, get_pdata_int( iEnt, m_iClip, 4 ) )
	}
}

public forward_ItemDeploy_Post( iEnt )
{
	emessage_begin ( MSG_ONE, g_iMsgId_TextMsg, _, get_pdata_cbase( iEnt, m_pPlayer, 4 ) )
	ewrite_byte( print_center )
	ewrite_string( ( get_pdata_int( iEnt, m_fWeaponState, 4 ) & WEAPONSTATE_GLOCK18_BURST_MODE ) ? "#Switch_To_SemiAuto" : "#Switch_To_FullAuto" )
	emessage_end()
}

public forward_ItemPostFrame( iEnt )
{
	clearWeaponInReload( iEnt )
	
	if ( get_pdata_int( iEnt, m_fWeaponState, 4 ) & WEAPONSTATE_GLOCK18_BURST_MODE )
	{
		if ( get_pdata_int( iEnt, m_fInReload, 4 ) )
		{
			setWeaponInReload( iEnt )
			setBulletsNum( iEnt, 0 )
		}
		else
		{
			static s_iPlrId
			s_iPlrId = get_pdata_cbase( iEnt, m_pPlayer, 4 )
			setBulletsNum( iEnt, get_pdata_int( iEnt, m_iClip, 4 ) )

			if ( !getBulletsNum( iEnt ) )
			{
				if ( get_pdata_float( iEnt, m_flNextPrimaryAttack, 4 ) <= 0.0 )
				{
				    setBulletsNum( iEnt, -1 )
				}
			}
			
			if ( ~pev( s_iPlrId, pev_button ) & IN_ATTACK )
			{
				set_pdata_int( iEnt, m_iGlock18ShotsFired, 0, 4 )
			}
			else if ( get_pdata_int( iEnt, m_iGlock18ShotsFired, 4 ) > 0 )
			{
				set_pdata_int( s_iPlrId, m_bIsPrimaryFireAllowed, 0, 5 )
			}
			return HAM_IGNORED
		}
	}
	
	setBulletsNum( iEnt, 0 )
	
	return HAM_IGNORED
}

public forward_ItemPostFrame_Post( iEnt )
{
	clearWeaponInReload( iEnt )
	
	static s_iPlrId, s_iButtons, s_iWpnState, bool:s_bInSemi, s_iBulletsNum
	s_iPlrId = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	s_iButtons = pev( s_iPlrId, pev_button )
	s_iWpnState = get_pdata_int( iEnt, m_fWeaponState, 4 )
	s_bInSemi = ( ( s_iWpnState & WEAPONSTATE_GLOCK18_BURST_MODE ) ? true : false )
	s_iBulletsNum = getBulletsNum( iEnt )
	
	if ( s_bInSemi && s_iBulletsNum && s_iBulletsNum != get_pdata_int( iEnt, m_iClip, 4 ) && s_iButtons & IN_ATTACK )
	{
		set_pdata_int( iEnt, m_iGlock18ShotsFired, 1, 4 )
	}
	
	if ( get_pdata_float( iEnt, m_flNextSecondaryAttack, 4 ) <= 0.0 )
	{
		if ( get_pdata_float( s_iPlrId, m_flNextAttack, 5 ) <= 0.0 )
		{
			if ( ~s_iButtons & IN_ATTACK && pev( s_iPlrId, pev_oldbuttons ) & IN_ATTACK2 )
			{
				switch ( s_bInSemi )
				{
				    case true: s_iWpnState &= ~WEAPONSTATE_GLOCK18_BURST_MODE
				    case false: s_iWpnState |= WEAPONSTATE_GLOCK18_BURST_MODE
				}
	
				emessage_begin( MSG_ONE, g_iMsgId_TextMsg, _, s_iPlrId )
				ewrite_byte( print_center )
				ewrite_string( s_bInSemi ? "#Switch_To_FullAuto" : "#Switch_To_SemiAuto" )
				emessage_end()
				
				set_pdata_int( iEnt, m_fWeaponState, s_iWpnState, 4 )
				set_pdata_float( iEnt, m_flNextSecondaryAttack, 0.3, 4 )
			}
		}
	}
	
	if ( s_bInSemi && !get_pdata_int( iEnt, m_iGlock18ShotsFired, 4 ) && get_pdata_int( iEnt, m_iShotFired, 4 ) > MAX_SEMIAUTO_INACCURACY )
	{
		set_pdata_int( iEnt, m_iShotFired, MAX_SEMIAUTO_INACCURACY, 4 )
	}
	
	setBulletsNum( iEnt, 0 )
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

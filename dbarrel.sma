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

#define m_fKnown	44
#define MAX_FILELEN 	64

const MAX_CLIP 			= 2
const DEFAULT_CLIP 		= 7
const AMMO_BUCKSHOT 		= 6
const Float:RELOAD_DELAY 	= 1.3
const WEAPONANIM_AFTER_RELOAD 	= 4

enum _:Resources
{
	pModel[ MAX_FILELEN ],
	vModel[ MAX_FILELEN ],
	wModel[ MAX_FILELEN ],
	SoundFile1[ MAX_FILELEN ],
	SoundFile2[ MAX_FILELEN ]
}

new g_eDBarrelFiles[ Resources ] =
{
	"models/p_dbarrel.mdl",
	"models/v_dbarrel.mdl",
	"models/w_dbarrel.mdl",
	"weapons/dbarrel/barreldown.wav",
	"weapons/dbarrel/barrelup.wav"
}

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Double Barrel Replacement",
		.version	= "1.0",
		.author 	= "BARRY."
	)

	RegisterHam( Ham_Item_Deploy, "weapon_m3", "forward_ItemDeploy_Post", .Post = 1 )
	RegisterHam( Ham_Item_AttachToPlayer, "weapon_m3", "forward_ItemAttachToPlayer" )
	RegisterHam( Ham_Weapon_Reload, "weapon_m3", "forward_WeaponReload" )
	RegisterHam( Ham_Weapon_Reload, "weapon_m3", "forward_WeaponReload_Post", .Post = 1 )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_m3", "forward_PrimaryAttack_Post", .Post = 1 )
	RegisterHam( Ham_Weapon_WeaponIdle, "weapon_m3", "forward_WeaponIdle" )
	
	register_forward( FM_SetModel, "forward_SetModel" )
}

public plugin_precache()
{
	precache_model( g_eDBarrelFiles[ pModel ] )
	precache_model( g_eDBarrelFiles[ vModel ] )
	precache_model( g_eDBarrelFiles[ wModel ] )
	
	precache_sound( g_eDBarrelFiles[ SoundFile1 ] )
	precache_sound( g_eDBarrelFiles[ SoundFile2 ] )
}

public forward_SetModel( iEnt, const szModel[] )
{
	if ( equal( szModel, "models/w_m3.mdl" ) )
	{
		engfunc(EngFunc_SetModel, iEnt, g_eDBarrelFiles[ wModel ] )
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public forward_ItemDeploy_Post( iEnt )
{
	new id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	
	set_pev( id, pev_viewmodel2, g_eDBarrelFiles[ vModel ] )
	set_pev( id, pev_weaponmodel2, g_eDBarrelFiles[ pModel ] )
	
	set_pdata_int( iEnt, m_fInReload, 0, 4 )
	set_pdata_int( iEnt, m_fInSpecialReload, 0, 4 )
	set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.9, 4 )
	set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.9, 4 )
}

public forward_ItemAttachToPlayer( iEnt, id )
{
	if ( !get_pdata_int( iEnt, m_fKnown, 4 ) )
	{
		set_pdata_int( iEnt, m_iClip, MAX_CLIP, 4 )
	}
}

public forward_WeaponReload( iEnt )
{ 
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static iBpAmmo ; iBpAmmo = get_pdata_int( id, 381, 4 )
	static iClip; iClip = get_pdata_int( iEnt, m_iClip, 4 )

	if ( iBpAmmo > 0 && iClip >= MAX_CLIP )
	{
		set_pdata_int( iEnt, m_fInSpecialReload, 0, 4 )
		//set_pdata_float( iEnt, m_flTimeWeaponIdle, 1.5, 4 )
		
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public forward_WeaponReload_Post( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static iBpAmmo ; iBpAmmo = get_pdata_int( id, 381, 4 )
	static iClip; iClip = get_pdata_int( iEnt, m_iClip, 4 )
	
	if ( iBpAmmo <= 0 )
	{
		return
	}
	
	switch ( get_pdata_int( iEnt, m_fInSpecialReload ) )
	{
		case 1:
		{
			set_pdata_float( id, m_flNextAttack, RELOAD_DELAY, 5 )
			set_pdata_float( iEnt, m_flNextPrimaryAttack, RELOAD_DELAY, 4 )
			set_pdata_float( iEnt, m_flTimeWeaponIdle, RELOAD_DELAY, 4 )
		}
		case 2:
		{
			new j = min( MAX_CLIP - iClip, iBpAmmo )
			
			set_pdata_int( iEnt, m_iClip, iClip + j, 4 )
			set_pdata_int( id, 381, iBpAmmo - j, 5 )
			
			set_pdata_int( iEnt, m_fInSpecialReload, 0, 4 )
		
			set_pdata_float( id, m_flNextAttack, 0.9, 5 )
			set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.9, 4 )
			set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.9, 4 )
		
			
			set_pev( id, pev_weaponanim, WEAPONANIM_AFTER_RELOAD )
			
			message_begin( MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id )
			write_byte( WEAPONANIM_AFTER_RELOAD )
			write_byte( pev( id, pev_body) )
			message_end()
		}
	}
}

public forward_PrimaryAttack_Post( iEnt )
{
	//static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	//set_pdata_float( id, m_flNextAttack, 0.01, 5 )
	set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.05,4 )
}

public forward_WeaponIdle( iEnt )
{
	if ( get_pdata_float( iEnt, m_flTimeWeaponIdle, 4 ) > 0.0 )
	{
		return
	}

	static iClip; iClip = get_pdata_int( iEnt, m_iClip, 4 )
	static fInSpecialReload; fInSpecialReload = get_pdata_int( iEnt, m_fInSpecialReload, 4 )

	if( !iClip && !fInSpecialReload )
	{
		return
	}

	if( fInSpecialReload && iClip >= MAX_CLIP )
	{
		set_pdata_int( iEnt, m_fInSpecialReload, 0, 4 )
		set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.55, 4 )
	}
	return
}

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

const MAX_CLIP 			= 7
const DEFAULT_CLIP 		= 7
const AMMO_BUCKSHOT 		= 6
const Float:RELOAD_DELAY 	= 1.3
const WEAPONANIM_AFTER_RELOAD 	= 4

enum _:eResources
{
	pModel[ MAX_FILELEN ],
	vModel[ MAX_FILELEN ],
	wModel[ MAX_FILELEN ],
	SoundFile1[ MAX_FILELEN ],
	SoundFile2[ MAX_FILELEN ],
	SoundFile3[ MAX_FILELEN ],
	SoundFile4[ MAX_FILELEN ]
}

new g_szSaigaFiles[ eResources ] =
{
	"models/p_saiga12.mdl",
	"models/v_saiga12.mdl",
	"models/w_saiga12.mdl",
	"weapons/SAIGA_clipin.wav",
	"weapons/SAIGA_clipout.wav",
	"weapons/SAIGA_zatvor.wav",
	"weapons/SAIGA-1.wav"//not used
}

new g_iResetDuckFlag

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Saiga-12 Replacement",
		.version	= "1.0",
		.author 	= "BARRY."
	)

	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_xm1014", "forward_PrimaryAttack" )
	RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_xm1014", "forward_PrimaryAttack_Post", .Post = 1 )	
	RegisterHam( Ham_Item_Deploy, "weapon_xm1014", "forward_ItemDeploy_Post", .Post = 1 )
	RegisterHam( Ham_Item_AttachToPlayer, "weapon_xm1014", "forward_ItemAttachToPlayer" )
	RegisterHam( Ham_Item_PostFrame, "weapon_xm1014", "forward_ItemPostFrame" )
	RegisterHam( Ham_Weapon_Reload, "weapon_xm1014", "forward_WeaponReload_Post", .Post = 1 )
	RegisterHam( Ham_Weapon_Reload, "weapon_xm1014", "forward_WeaponReload" )
	
	register_forward( FM_SetModel, "forward_SetModel" )
}

public forward_PrimaryAttack( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static bitFlags; bitFlags = pev( id, pev_flags )

	g_iResetDuckFlag = ( bitFlags & FL_DUCKING ) ? 0 : 1
	set_pev( id, pev_flags, ( bitFlags | FL_DUCKING ) )
}

public forward_PrimaryAttack_Post( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	
	if ( g_iResetDuckFlag )
	{
		set_pev( id, pev_flags, ( pev( id, pev_flags ) & ~FL_DUCKING ) )
	}	
}

public plugin_precache()
{
	precache_model( g_szSaigaFiles[ pModel ] )
	precache_model( g_szSaigaFiles[ vModel ] )
	precache_model( g_szSaigaFiles[ wModel ] )
	
	precache_sound( g_szSaigaFiles[ SoundFile1 ] )
	precache_sound( g_szSaigaFiles[ SoundFile2 ] )
	precache_sound( g_szSaigaFiles[ SoundFile3 ] )
	precache_sound( g_szSaigaFiles[ SoundFile4 ] )
}

public forward_SetModel( iEnt, const szModel[] )
{
	if ( equal( szModel, "models/w_xm1014.mdl" ) )
	{
		engfunc(EngFunc_SetModel, iEnt, g_szSaigaFiles[ wModel ] )
		
		return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public forward_ItemDeploy_Post( iEnt )
{
	new id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	
	set_pev( id, pev_viewmodel2, g_szSaigaFiles[ vModel ] )
	set_pev( id, pev_weaponmodel2, g_szSaigaFiles[ pModel ] )
	
	set_pdata_int( iEnt, m_fInReload, 0, 4 )
	set_pdata_int( iEnt, m_fInSpecialReload, 0, 4 )
	set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.55, 4 )
	set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.55, 4 )
}

public forward_ItemAttachToPlayer( iEnt, id )
{
	if ( !get_pdata_int( iEnt, m_fKnown, 4 ) )
	{
		set_pdata_int( iEnt, m_iClip, MAX_CLIP, 4 )
	}
}

public forward_ItemPostFrame( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static iBpAmmo; iBpAmmo = get_pdata_int( id, 381, 4 )
	static iClip; iClip = get_pdata_int( iEnt, m_iClip, 4 )
	static iButton; iButton = pev( id, pev_button )

	if ( get_pdata_int( iEnt, m_fInReload, 4 ) && get_pdata_float( id, m_flNextAttack, 5 ) <= 0.0 )
	{
		new j = min( MAX_CLIP - iClip, iBpAmmo )
		
		set_pdata_int( iEnt, m_iClip, iClip + j, 4 )
		set_pdata_int( id, 381, iBpAmmo - j, 5 )
		set_pdata_int( iEnt, m_fInReload, 0, 4 )
		
		return HAM_IGNORED
	}
	
	if ( iButton & IN_ATTACK )
	{
		if ( get_pdata_float( iEnt, m_flNextPrimaryAttack, 5 ) <= 0.0 )
		{
			set_pdata_int( iEnt, m_iShotFired, 1, 4 )
		}
		
		if ( get_pdata_int( iEnt, m_fInSpecialReload, 4 ) )
		{
			set_pev( id, pev_button, iButton & ( IN_RELOAD | ~IN_ATTACK ) )
			
			return HAM_SUPERCEDE
		}
	}

	if ( iButton & IN_RELOAD )
	{
		if ( iClip >= MAX_CLIP )
		{
			set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.5, 4 )
			set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.5, 4 )
			set_pev( id, pev_button, iButton & ( ~IN_RELOAD | IN_ATTACK ) )
			
			return HAM_SUPERCEDE
		}
		else if ( iClip == DEFAULT_CLIP )
		{
			if ( iBpAmmo  )
			{	
				set_pdata_int( iEnt, m_iClip, 0, 4 )
				set_pdata_int( iEnt, m_fInReload, 1, 4 )
				ExecuteHamB( Ham_Weapon_Reload, iEnt )
				set_pdata_int( iEnt, m_iClip, 7, 4 )
			}
		}
		
	}
	return HAM_IGNORED
}

public forward_WeaponReload( iEnt )
{
	static id; id = get_pdata_cbase( iEnt, m_pPlayer, 4 )
	static iClip; iClip = get_pdata_int( iEnt, m_iClip, 4 )
	static iButton; iButton = pev( id, pev_button )
	
	if ( iClip >= MAX_CLIP )
	{
		set_pev( id, pev_button, iButton & ( ~IN_RELOAD | IN_ATTACK ) )
		
		set_pdata_float( id, m_flNextAttack, 0.5, 5 )
		
		set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.5, 4 )
		set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.5, 4 )
		set_pdata_int( iEnt, m_fInSpecialReload, 0, 4 )
		
		return HAM_IGNORED
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
		return HAM_IGNORED
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
		
			set_pdata_float( id, m_flNextAttack, 0.55, 5 )
			set_pdata_float( iEnt, m_flNextPrimaryAttack, 0.55, 4 )
			set_pdata_float( iEnt, m_flTimeWeaponIdle, 0.55, 4 )
		
			set_pev( id, pev_weaponanim, WEAPONANIM_AFTER_RELOAD )
			
			message_begin( MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id )
			write_byte( WEAPONANIM_AFTER_RELOAD )
			write_byte( pev( id, pev_body) )
			message_end()
		}
	}
	return HAM_IGNORED
}

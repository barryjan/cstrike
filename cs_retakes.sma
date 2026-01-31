#include < amxmodx >
#include < fakemeta >
#include < hamsandwich >
#include < cstrike >
#include < xs >

// cstrike_pdatas
stock const XO_CBASEPLAYERITEM  = 4
stock const XO_CGRENADE         = 5
stock const XO_CBASEPLAYERWEAPON= 4
stock const XO_CBASEPLAYER      = 5

stock const m_pPlayer           = 41
stock const m_flDefuseCountDown = 99
stock const m_fClientMapZone    = 235
stock const m_bIsC4             = 385
stock const m_bStartedArming    = 320
stock const m_flArmedTime2      = 81
stock const m_rgpPlayerItems_CBasePlayer[ 6 ] = { 367, 368, 369, 370, 371, 372 }

stock const SHORT_BYTES         = 2
stock const INT_BYTES           = 4
stock const BYTE_BITS           = 8

#if !defined get_pdata_bool
stock bool:get_pdata_bool( ent, charbased_offset, intbase_linuxdiff = 20 )
{
    return !!( get_pdata_int( ent, charbased_offset / INT_BYTES, intbase_linuxdiff )
        & ( 0xFF << ( ( charbased_offset % INT_BYTES ) * BYTE_BITS ) ) )
}
#endif

#if !defined set_pdata_char
stock set_pdata_char( ent, charbased_offset, value, intbase_linuxdiff = 20 )
{
    value &= 0xFF

    new int_offset_value = get_pdata_int( ent, charbased_offset / INT_BYTES, intbase_linuxdiff )
    new bit_decal = ( charbased_offset % INT_BYTES ) * BYTE_BITS
    
    int_offset_value &= ~( 0xFF << bit_decal ) // clear byte
    int_offset_value |= value << bit_decal

    set_pdata_int( ent, charbased_offset / INT_BYTES, int_offset_value, intbase_linuxdiff )
    
    return 1
}
#endif
    
#if !defined set_pdata_bool
stock set_pdata_bool( ent, charbased_offset, bool:value, intbase_linuxdiff = 20 )
{
    set_pdata_char( ent, charbased_offset, _:value, intbase_linuxdiff )
}
#endif

//#define DEBUG_NAV // Enable this to print NAV loading

#define MAX_BOMBSITE_LAYERS     12

#define TASKID_ROUNDSTART       53412
#define TASKID_ROUNDTIME        12439
#define TASKID_BUYTIME          62144

#define __ArrayDestroy(%1) if( %1 ) ArrayDestroy( %1 )

enum _:RetakesFlags
{
    RETAKES_AUTOPLANT           = ( 1<<0 ), // a
    RETAKES_INSTAPLANT          = ( 1<<1 ), // b
    RETAKES_DEFUSEKIT           = ( 1<<2 ), // c
    RETAKES_INSTADEFUSE         = ( 1<<3 ), // d
    RETAKES_INSTADEFUSE_ELIM    = ( 1<<4 ), // e
    RETAKES_SHOWTIMER           = ( 1<<5 ), // f
    RETAKES_TEAMROTATION        = ( 1<<6 ), // g
}

const Float:flHalfHumanHeight   = 36.0
const Float:flHumanHeight       = 72.0
const Float:flHumanWidth        = 32.0

new Array:g_aPlaceNames
new Array:g_aAreaID
new Array:g_aAreaAttrs
new Array:g_aAreaExtents        // Float[ 6 ]
new Array:g_aTempNeighborIDs
new Array:g_aAdjacency          // Array of Array
new Array:g_aAreaPlaceEntry
new Array:g_aAreaSpawnable
new Array:g_aSpawnCandidates
new Array:g_aBombsiteAreas[ 2 ] // 0 = A, 1 = B
new Array:g_aBombsiteLayers[ 2 ]// Array of Array for each site
new Array:g_aLOSToBombsite[ 2 ] // 0 = A, 1 = B
new Array:g_aAreaVisible
new Array:g_aAreaUsed

new bool:g_bRetakesEnabled
new g_iRetakesFlagsCache
new g_iRetakesStateBuffer
new g_iRandomSite
new g_iLastSite
new g_iSiteStreak
new g_iBombSpawnOwner
new g_iRoundCount
new g_iMaxPlayers

new g_iEventId_DecalReset
new g_iMsgId_ShowTimer
new g_iMsgId_BombDrop
new g_iMsgId_RoundTime
new g_iMsgId_BarTime2

new Float:g_flNewRoundTime
new g_iBombsiteEnt[ 2 ]
new g_iBuyzoneEnt
new g_iForward_PlayerPostThink

new g_pCvar_Enable
new g_pCvar_C4Timer
new g_pCvar_BuyTime
new g_pCvar_ForceSite
new g_pCvar_SiteStreak
new g_pCvar_RotateRound
new g_pCvar_StateBuffer
new g_pCvar_MaxPlayers
new g_pCvar_RetakesFlags

public plugin_init()
{
    register_plugin
    (
        .plugin_name    = "CS Retakes",
        .version        = "1.1",
        .author         = "BARRY."
    )
    
    new szMapname[ 4 ]
    get_mapname( szMapname, charsmax( szMapname ) )
    
    // Only run on de_ maps
    if( !equali( szMapname, "de_", 3 ) )
    {
        pause( "ad" )
        return
    }
    
    new iResult = nav_Load( szMapname )
    
    switch ( iResult )
    {
        case -2: server_print( "[NAV] Unable to open navigation file for %s", szMapname )
        case -1: server_print( "[NAV] Invalid navigation file, %s", szMapname )
        case  0: server_print( "[NAV] Unsupported navigation file version for %s", szMapname )
        default:
        {
            spawn_InitArrays()
            spawn_FilterSpawnableAreas()

            bombsite_InitArrays()
            bombsite_Establish()
            bombsite_BuildLayers( MAX_BOMBSITE_LAYERS )
            bombsite_PrecomputeLOS()
        }
    }
    
    if( iResult != 1 )
        return
    
    register_event( "HLTV", "round_OnHLTVNewRound", "a", "1=0", "2=0" )
    register_event( "CurWeapon", "msg_OnCurWeapon", "be", "2=6" ) // CSW_C4
    register_event( "TextMsg", "retakes_onRestart", "a", "2&#Game_C", "2&#Game_W" )

    register_logevent( "round_OnRoundStart", 2, "1=Round_Start" )
    register_logevent( "round_OnRoundEnd", 2, "1=Round_End" )
    register_logevent( "round_OnBombPlanted", 3, "2=Planted_The_Bomb" )
    register_logevent( "c4_OnSpawnedWithTheBomb", 3, "2=Spawned_With_The_Bomb" )
    
    register_message( get_user_msgid( "SendAudio" ), "msg_OnSendAudio" )
    register_message( get_user_msgid( "TextMsg" ), "msg_OnTextMsg" )
    
    register_forward( FM_PlaybackEvent, "round_OnDecalReset" )
    
    RegisterHam( Ham_Weapon_PrimaryAttack, "weapon_c4", "c4_OnPrimaryAttack" )
    RegisterHam( Ham_Use, "grenade", "c4_OnUse" )
    
    // CVARs
    g_pCvar_Enable      = register_cvar( "amx_retakes_enable", "1" )
    g_pCvar_BuyTime     = register_cvar( "amx_retakes_buytime", "5.0" )
    g_pCvar_ForceSite   = register_cvar( "amx_retakes_forcesite", "0" )
    g_pCvar_SiteStreak  = register_cvar( "amx_retakes_sitestreak", "2" )
    g_pCvar_RotateRound = register_cvar( "amx_retakes_rotateround", "5" )
    g_pCvar_StateBuffer = register_cvar( "amx_retakes_statebuffer", "4" )
    g_pCvar_MaxPlayers  = register_cvar( "amx_retakes_maxplayers", "12" )
    g_pCvar_RetakesFlags= register_cvar( "amx_retakes_flags", "abcdefgh" )
    
    g_pCvar_C4Timer     = get_cvar_pointer( "mp_c4timer" )
    
    // Initial state
    g_bRetakesEnabled   = get_pcvar_num( g_pCvar_Enable ) ? true : false
    g_iMaxPlayers       = get_maxplayers()
    
    // Message IDs
    g_iMsgId_ShowTimer  = get_user_msgid( "ShowTimer" )
    g_iMsgId_RoundTime  = get_user_msgid( "RoundTime" )
    g_iMsgId_BombDrop   = get_user_msgid( "BombDrop" )
    g_iMsgId_BarTime2   = get_user_msgid( "BarTime2" )
    
    // Buyzone entity
    retakes_CreateGlobalBuyzone()
    
    // Decal reset event
    g_iEventId_DecalReset = engfunc( EngFunc_PrecacheEvent, 1, "events/decal_reset.sc" )
}

public plugin_end()
{
    nav_DestroyArrays()
    spawn_DestroyArrays()
    bombsite_DestroyArrays()
}

// ============================================================================
// RETAKES CORE SUBSYSTEM
// Responsible for: enable/disable state, flags, round-state buffer,
// max-player enforcement, and semantic helpers.
// ============================================================================


// ---------------------------------------------------------------------------
// Core: Enable / Disable
// ---------------------------------------------------------------------------

public retakes_IsEnabled()
{
    return g_bRetakesEnabled
}


public retakes_SetEnabled( bool:bEnabled )
{
    g_bRetakesEnabled    = bEnabled
    g_iRetakesFlagsCache = 0   // force refresh next access
}


// ---------------------------------------------------------------------------
// Core: Flags (cached)
// ---------------------------------------------------------------------------

retakes_RefreshFlags()
{
    new szFlags[ 16 ]
    get_pcvar_string( g_pCvar_RetakesFlags, szFlags, charsmax( szFlags ) )
    
    g_iRetakesFlagsCache = read_flags( szFlags )
}

retakes_GetFlags()
{
    if ( !g_iRetakesFlagsCache )
        retakes_RefreshFlags()
    
    return g_iRetakesFlagsCache
}

bool:retakes_HasFlag( iFlag )
{
    return ( retakes_GetFlags() & iFlag ) ? true : false
}


// ---------------------------------------------------------------------------
// Core: Player-count state buffer
// ---------------------------------------------------------------------------

bool:retakes_UpdateState()
{
    new iPlayers[ 32 ], iNum
    get_players( iPlayers, iNum, "h" )
    
    const iMinBuffer = 2
    
    new iMaxAllowed = get_pcvar_num( g_pCvar_MaxPlayers )
    new iStateBuffer = get_pcvar_num( g_pCvar_StateBuffer )
    iStateBuffer = max( iStateBuffer, iMinBuffer ) // clamp to iMinBuffer
    
    // Too many players -> begin disabling
    if ( iNum > iMaxAllowed )
    {
        if ( g_iRetakesStateBuffer < iStateBuffer )
        {
            g_iRetakesStateBuffer++

            new iRoundsLeft = iStateBuffer - g_iRetakesStateBuffer
            new szText[ 32 ]
            
            switch ( iRoundsLeft )
            {
                case 0: 
                {
                    g_iRoundCount = 0
		    
                    client_print
                    ( 
                        0, print_chat,
                        "[RETAKES] Mode is disabled!",
                        szText
                    )
                }
                default:
                {
                    formatex
                    (
                        szText, charsmax( szText ),
                        iRoundsLeft == 1 ? "next round." : "in %d rounds.",
                        iRoundsLeft
                    )
		    
                    client_print
                    ( 
                        0, print_chat,
                        "[RETAKES] Too many players. Disabling %s",
                        szText
                    )
                }
            }
        }

        // Fully disabled
        if ( g_iRetakesStateBuffer >= iStateBuffer )
            return false

        // Still counting down
        return true
    }

    // Player count normal -> count down buffer
    if ( g_iRetakesStateBuffer > 0 )
    {
        g_iRetakesStateBuffer--

        if ( g_iRetakesStateBuffer == 1 )
        {
            client_print
            ( 
                0, print_chat,
                "[RETAKES] Low player count. Enabling next round."
            )
        }
    }

    return ( g_iRetakesStateBuffer <= 0 )
}


// ---------------------------------------------------------------------------
// Core: Round restart reset
// ---------------------------------------------------------------------------

public retakes_onRestart()
{
    if ( !retakes_IsEnabled() )
        return
    
    g_iRoundCount         = 0
    g_iRetakesStateBuffer = 0
    g_iRetakesFlagsCache  = 0
}


// ---------------------------------------------------------------------------
// Core: Create global buyzone so players can buy anywhere
// ---------------------------------------------------------------------------

retakes_CreateGlobalBuyzone()
{
    g_iBuyzoneEnt = engfunc
    ( 
        EngFunc_CreateNamedEntity,
        engfunc( EngFunc_AllocString, "func_buyzone" )
    )

    if ( !g_iBuyzoneEnt )
       return

    dllfunc( DLLFunc_Spawn, g_iBuyzoneEnt )

    engfunc
    (
        EngFunc_SetSize,
        g_iBuyzoneEnt,
        Float:{ -8192.0, -8192.0, -8192.0 },
        Float:{ -8192.0, -8192.0, -8192.0 }
    )
}


// ============================================================================
// C4 SUBSYSTEM
// Handles: instaplant, instadefuse, bomb owner tracking,
// entity lookup, auto-plant orchestration, repositioning.
// ============================================================================


// ---------------------------------------------------------------------------
// C4: Capture the player who spawned with the bomb
// ---------------------------------------------------------------------------
public c4_OnSpawnedWithTheBomb()
{
    if ( !retakes_IsEnabled() )
        return

    new szLogUser[ 80 ], szName[ 32 ]
    read_logargv( 0, szLogUser, charsmax( szLogUser ) )
    parse_loguser( szLogUser, szName, charsmax( szName ) )

    g_iBombSpawnOwner = get_user_index( szName )
}


// ---------------------------------------------------------------------------
// C4: Ham forwards (instaplant / instadefuse)
// ---------------------------------------------------------------------------

public c4_OnPrimaryAttack( iEntC4 )
{
    if ( !retakes_IsEnabled() )
        return
    
    if ( !retakes_HasFlag( RETAKES_INSTAPLANT ) )
        return
        
    new iPlayer = get_pdata_cbase( iEntC4, m_pPlayer, XO_CBASEPLAYERITEM )

    if ( get_pdata_bool( iEntC4, m_bStartedArming, XO_CBASEPLAYERWEAPON ) )
    {
        message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_BarTime2, _, iPlayer )
        write_short( 1 )
        write_short( 90 )
        message_end()
        
        set_pdata_float( iEntC4, m_flArmedTime2, 0.0, XO_CBASEPLAYERWEAPON )
    }
}

public c4_OnUse( iEnt, iPlayer )
{
    if ( !retakes_IsEnabled() )
        return

    if ( !retakes_HasFlag( RETAKES_INSTADEFUSE ) )
        return
        
    if ( retakes_HasFlag( RETAKES_INSTADEFUSE_ELIM ) )
    {
        new iPlayers[ 32 ], iNum
        get_players( iPlayers, iNum, "ae", "TERRORIST" )
        
        if ( iNum > 0 )
            return
    }

    if ( !get_pdata_bool( iEnt, m_bIsC4, XO_CGRENADE ) )
        return
  
    const Float:flDefuseTime = 1.0
    
    message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_BarTime2, _, iPlayer )
    write_short( floatround( flDefuseTime ) )
    write_short( 90 )
    message_end()

    set_pdata_float( iEnt, m_flDefuseCountDown, flDefuseTime, XO_CGRENADE )
}


// ---------------------------------------------------------------------------
// C4: Entity lookup helpers
// ---------------------------------------------------------------------------

c4_FindWeaponBox()
{
    new iEnt = engfunc( EngFunc_FindEntityByString, -1, "classname", "weapon_c4" )
    
    return ( iEnt > 0 ) ? pev( iEnt, pev_owner ) : 0
}

c4_FindOwner()
{
    if ( is_user_alive( g_iBombSpawnOwner ) )
        return g_iBombSpawnOwner
        
    new iEnt = engfunc( EngFunc_FindEntityByString, -1, "classname", "weapon_c4" )

    if ( iEnt > 0 )
    {
        new iOwner = pev( iEnt, pev_owner )
        
        if ( 1 <= iOwner <= g_iMaxPlayers )
            return iOwner
    }
    
    return 0
}

c4_FindPlanted()
{
    new iEnt = engfunc( EngFunc_FindEntityByString, -1, "model" , "models/w_c4.mdl" )

    return iEnt
}


// ---------------------------------------------------------------------------
// C4: Auto-plant orchestration
// ---------------------------------------------------------------------------

c4_AutoPlant( iSite )
{
    new iBsEnt = g_iBombsiteEnt[ iSite ]
    if ( !pev_valid( iBsEnt ) )
        return

    new Float:flAbsMin[ 3 ], Float:flAbsMax[ 3 ]
    pev( iBsEnt, pev_absmin, flAbsMin )
    pev( iBsEnt, pev_absmax, flAbsMax )

    new iC4, iOwner = c4_FindOwner()

    // -----------------------------------------------------------------------
    // 1. Auto-plant from owner
    // -----------------------------------------------------------------------
    if ( iOwner > 0 )
    {
        iC4 = get_pdata_cbase( iOwner, m_rgpPlayerItems_CBasePlayer[ 5 ], XO_CBASEPLAYER )
        if ( iC4 > 0 )
        {
            set_pev( iOwner, pev_flags, pev( iOwner, pev_flags ) | FL_ONGROUND )

            new iZone = get_pdata_int( iOwner, m_fClientMapZone, XO_CBASEPLAYER )
            set_pdata_int( iOwner, m_fClientMapZone, iZone | CS_MAPZONE_BOMBTARGET, XO_CBASEPLAYER )

            set_pdata_bool( iC4, m_bStartedArming, true, XO_CBASEPLAYERWEAPON )
            set_pdata_float( iC4, m_flArmedTime2, 0.0, XO_CBASEPLAYERWEAPON )

            ExecuteHam( Ham_Weapon_PrimaryAttack, iC4 )

            set_pev( iOwner, pev_weapons, pev( iOwner, pev_weapons ) & ~( 1 << CSW_C4 ) )
        }
    }

    // -----------------------------------------------------------------------
    // 2. If planted, reposition inside bombsite
    // -----------------------------------------------------------------------
    if ( ( iC4 = c4_FindPlanted() ) > 0 )
    {
        c4_RepositionPlanted( iC4, flAbsMin, flAbsMax, iSite )
        return
    }

    // -----------------------------------------------------------------------
    // 3. If dropped, give to random T and auto-plant
    // -----------------------------------------------------------------------
    if ( ( iC4 = c4_FindWeaponBox() ) > 0 )
    {
        new iPlayers[ 32 ], iNum
        get_players( iPlayers, iNum, "ae", "TERRORIST" )

        iOwner = ( iNum > 0 ) ? iPlayers[ random( iNum ) ] : 0

        if ( iOwner )
        {
            set_pev( iC4, pev_flags, pev( iC4, pev_flags ) | FL_ONGROUND )
            dllfunc( DLLFunc_Touch, iC4, iOwner )

            iC4 = get_pdata_cbase( iOwner, m_rgpPlayerItems_CBasePlayer[ 5 ], XO_CBASEPLAYER )
            if ( iC4 > 0 )
            {
                set_pev( iOwner, pev_flags, pev( iOwner, pev_flags ) | FL_ONGROUND )

                new iZone = get_pdata_int( iOwner, m_fClientMapZone, XO_CBASEPLAYER )
                set_pdata_int( iOwner, m_fClientMapZone, iZone | CS_MAPZONE_BOMBTARGET, XO_CBASEPLAYER )

                set_pdata_bool( iC4, m_bStartedArming, true, XO_CBASEPLAYERWEAPON )
                set_pdata_float( iC4, m_flArmedTime2, 0.0, XO_CBASEPLAYERWEAPON )

                ExecuteHam( Ham_Weapon_PrimaryAttack, iC4 )

                set_pev( iOwner, pev_weapons, pev( iOwner, pev_weapons ) & ~( 1 << CSW_C4 ) )

                if ( ( iC4 = c4_FindPlanted() ) > 0 )
                {
                    c4_RepositionPlanted( iC4, flAbsMin, flAbsMax, iSite )
                }
            }
        }
    }
}


// ---------------------------------------------------------------------------
// C4: Reposition planted bomb
// ---------------------------------------------------------------------------

c4_RepositionPlanted( iC4, const Float:flAbsMin[ 3 ], const Float:flAbsMax[ 3 ], iSite )
{
    new Float:flOrigin[ 3 ]

    const iMaxAttempts = 30

    for ( new iAttempt = 0; iAttempt < iMaxAttempts; iAttempt++ )
    {
        // Fallback to NAV mesh on last attempt
        if ( iAttempt == iMaxAttempts - 1 )
        {
            spawn_BuildCandidates( iSite, 0 )

            new iArea = spawn_SelectRandomArea()
            if ( iArea != -1 )
            {
                util_AreaCenter( iArea, flOrigin )
                break
            }
            return
        }

        flOrigin[ 0 ] = random_float( flAbsMin[ 0 ], flAbsMax[ 0 ] )
        flOrigin[ 1 ] = random_float( flAbsMin[ 1 ], flAbsMax[ 1 ] )
        flOrigin[ 2 ] = random_float( flAbsMin[ 2 ], flAbsMax[ 2 ] )

        if ( util_TraceHullClear( flOrigin ) )
            break
    }

    engfunc( EngFunc_SetOrigin, iC4, flOrigin )
    engfunc( EngFunc_DropToFloor, iC4 )

    #define write_coord_f(%1) write_coord( floatround( %1 ) )

    message_begin( MSG_BROADCAST, g_iMsgId_BombDrop )
    write_coord_f( flOrigin[ 0 ] )
    write_coord_f( flOrigin[ 1 ] )
    write_coord_f( flOrigin[ 2 ] )
    write_byte( 1 ) // planted
    message_end()
}


// ============================================================================
// ROUND SUBSYSTEM
// Handles: round start, round end, site selection, team rotation, 
// buytime logic, timer HUD scheduling, and state machine transitions.
// ============================================================================


// ---------------------------------------------------------------------------
// Round: HLTV new round (engine-level round start)
// ---------------------------------------------------------------------------

public round_OnHLTVNewRound()
{
    retakes_SetEnabled( get_pcvar_num( g_pCvar_Enable ) ? true : false )
    
    // Apply player-count state buffer
    if ( retakes_IsEnabled() )
        retakes_SetEnabled( retakes_UpdateState() )
    
    if ( !retakes_IsEnabled() )
        return

    retakes_RefreshFlags()

    g_flNewRoundTime = get_gametime()

    round_SelectSite()

    // Reset spawn subsystem state
    spawn_ResetUsed()
    spawn_ResetTVisibility()

    // Clear pending tasks
    remove_task( TASKID_ROUNDSTART )
    remove_task( TASKID_ROUNDTIME )
    remove_task( TASKID_BUYTIME )

    // Temporary buyzone touch forward
    g_iForward_PlayerPostThink = register_forward( FM_PlayerPostThink, "round_OnPlayerPostThink" )

    // Schedule buytime end
    set_task( get_pcvar_float( g_pCvar_BuyTime ), "round_OnBuytimeEnd", TASKID_BUYTIME )
}


// ---------------------------------------------------------------------------
// Round: Select bombsite (A/B) with streak logic
// ---------------------------------------------------------------------------

round_SelectSite()
{
    const iMinStreak = 2

    new iForce = get_pcvar_num( g_pCvar_ForceSite )
    new iMaxStreak = get_pcvar_num( g_pCvar_SiteStreak )
    iMaxStreak = max( iMaxStreak, iMinStreak ) //clamp to iMinStreak
    
    new iSite = random( 2 )

    switch ( iForce )
    {
        case 0:
        {
            // Streak logic: avoid 2+ same site in a row
            g_iSiteStreak = ( iSite == g_iLastSite ) ? g_iSiteStreak + 1 : 1

            if ( g_iSiteStreak > iMaxStreak )
            {
                iSite = 1 - g_iLastSite
                g_iSiteStreak = 1
            }

            g_iRandomSite = iSite
            g_iLastSite = iSite
        }

        default:
        {
            // Force A or B
            iSite = ( iForce == 1 ) ? 0 : 1
            g_iRandomSite = iSite
            g_iLastSite = iSite
        }
    }
}


// ---------------------------------------------------------------------------
// Round: Restart (TextMsg "Game_C" / "Game_W")
// ---------------------------------------------------------------------------

public round_OnRestart()
{
    if ( !retakes_IsEnabled() )
        return

    g_iRoundCount         = 0
    g_iRetakesStateBuffer = 0
    g_iRetakesFlagsCache  = 0
}


// ---------------------------------------------------------------------------
// Round: Round Start (logevent Round_Start)
// ---------------------------------------------------------------------------

public round_OnRoundStart()
{
    if ( !retakes_IsEnabled() )
        return

    if ( !retakes_HasFlag( RETAKES_AUTOPLANT ) )
        return

    // Add delay if mp_freezetime < 1.0
    if ( ( get_gametime() - g_flNewRoundTime ) <= 1.0 )
    {
        set_task( 1.0, "round_OnRoundStart", TASKID_ROUNDSTART )
        return
    }

    // Delegate autoplant to C4 subsystem
    c4_AutoPlant( g_iRandomSite )
}


// ---------------------------------------------------------------------------
// PlaybackEvent: Spawn Assignment Trigger (Decal Reset)
// ---------------------------------------------------------------------------

public round_OnDecalReset( iFlags, iEnt, iEvent )
{
    if ( !retakes_IsEnabled() )
        return

    if ( iEvent != g_iEventId_DecalReset )
        return

    if ( floatcmp( get_gametime(), g_flNewRoundTime ) )
        return

    // -----------------------------------------------------------------------
    // T SPAWNS
    // -----------------------------------------------------------------------

    new iPlayers[ 32 ], iNum
    get_players( iPlayers, iNum, "ae", "TERRORIST" )
    util_ShuffleIntArray( iPlayers, iNum )

    for ( new i = 0; i < iNum; i++ )
    {
        spawn_BuildCandidates( g_iRandomSite, 0 )

        new iArea = spawn_SelectRandomArea()
        if ( iArea != -1 )
            spawn_TeleportPlayer( iPlayers[ i ], iArea )
    }

    // -----------------------------------------------------------------------
    // CT SPAWNS
    // -----------------------------------------------------------------------

    get_players( iPlayers, iNum, "ae", "CT" )
    util_ShuffleIntArray( iPlayers, iNum )

    const iMinLayer = 4
    new iMaxLayer = ArraySize( g_aBombsiteLayers[ g_iRandomSite ] )

    // Adjust max layer based on CT count
    iMaxLayer = max( iMinLayer, ( iMaxLayer - iNum - 1 ) )
    
    for ( new i = 0; i < iNum; i++ )
    {
        if ( retakes_HasFlag( RETAKES_DEFUSEKIT ) )
            cs_set_user_defuse( iPlayers[ i ], 1 )

        new iLayer = spawn_FindValidLayer( g_iRandomSite, iMinLayer, iMaxLayer )

        spawn_BuildCandidates( g_iRandomSite, iLayer )

        new iArea = spawn_SelectRandomArea()
        if ( iArea != -1 )
            spawn_TeleportPlayer( iPlayers[ i ], iArea )
    }

    return
}


// ---------------------------------------------------------------------------
// Round: Round End (logevent Round_End)
// ---------------------------------------------------------------------------

public round_OnRoundEnd()
{
    if ( !retakes_IsEnabled() )
        return

    if ( !retakes_HasFlag( RETAKES_TEAMROTATION ) )
        return

    g_flNewRoundTime = 0.0
    g_iRoundCount++

    new const Float:flDelays[] = { 0.1, 0.2, 0.3, 0.4 }

    // Team rotation
    if ( g_iRoundCount >= get_pcvar_num( g_pCvar_RotateRound ) )
    {
        new iPlayers[ 32 ], iNum
        get_players( iPlayers, iNum )

        for ( new i = 0; i < iNum; i++ )
        {
            new id = iPlayers[ i ]

            new iGroup = ( id - 1 ) / 8
            iGroup = min( iGroup, ( sizeof flDelays - 1 ) )

            set_task( flDelays[ iGroup ], "round_ChangeTeam", id )
        }

        g_iRoundCount = 0

        client_print( 0, print_chat, "[RETAKES] Switching Teams..." )
    }
}


// ---------------------------------------------------------------------------
// Round: Change team (scheduled)
// ---------------------------------------------------------------------------

public round_ChangeTeam( id )
{
    switch ( cs_get_user_team( id ) )
    {
        case CS_TEAM_CT: cs_set_user_team( id, CS_TEAM_T )
        case CS_TEAM_T:  cs_set_user_team( id, CS_TEAM_CT )
    }
}


// ---------------------------------------------------------------------------
// Round: Buytime end (remove temporary buyzone touch)
// ---------------------------------------------------------------------------

public round_OnBuytimeEnd()
{
    if ( g_iForward_PlayerPostThink )
        unregister_forward( FM_PlayerPostThink, g_iForward_PlayerPostThink )
}


// ---------------------------------------------------------------------------
// Round: PlayerPostThink (temporary buyzone touch)
// ---------------------------------------------------------------------------

public round_OnPlayerPostThink( id )
{
    if ( is_user_alive( id ) )
        dllfunc( DLLFunc_Touch, g_iBuyzoneEnt, id )
}


// ---------------------------------------------------------------------------
// Round: Bomb planted (start HUD timer)
// ---------------------------------------------------------------------------

public round_OnBombPlanted()
{
    if ( !retakes_IsEnabled() )
        return

    if ( !retakes_HasFlag( RETAKES_SHOWTIMER ) )
        return

    if ( g_flNewRoundTime > 0.0 )
        set_task( 1.0, "round_UpdateTimerHUD", TASKID_ROUNDTIME )
}


// ---------------------------------------------------------------------------
// Round: Timer HUD update (delegates to messaging subsystem)
// ---------------------------------------------------------------------------

public round_UpdateTimerHUD()
{
    msg_BroadcastTimerHUD()
}


// ============================================================================
// MESSAGING SUBSYSTEM
// Handles: TextMsg suppression, SendAudio suppression, and C4 visibility
// ============================================================================


// ---------------------------------------------------------------------------
// TextMsg: suppress "#Bomb_Planted" when autoplant is active
// ---------------------------------------------------------------------------

public msg_OnTextMsg( iMsgId, iDest, iPlayer )
{
    if ( !retakes_IsEnabled() )
        return PLUGIN_CONTINUE

    if ( !retakes_HasFlag( RETAKES_AUTOPLANT ) )
        return PLUGIN_CONTINUE

    new const szBombPlanted[] = "#Bomb_Planted"

    new szMessage[ 32 ]
    get_msg_arg_string( 2, szMessage, charsmax( szMessage ) )

    return equal( szMessage, szBombPlanted ) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}


// ---------------------------------------------------------------------------
// SendAudio: suppress "%!MRAD_BOMBPL" when autoplant is active
// ---------------------------------------------------------------------------

public msg_OnSendAudio( iMsgId, iDest, iPlayer )
{
    if ( !retakes_IsEnabled() )
        return PLUGIN_CONTINUE

    if ( !retakes_HasFlag( RETAKES_AUTOPLANT ) )
        return PLUGIN_CONTINUE

    new const szBombAudio[] = "%!MRAD_BOMBPL"

    new szAudio[ 32 ]
    get_msg_arg_string( 2, szAudio, charsmax( szAudio ) )

    return equal( szAudio, szBombAudio ) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}


// ---------------------------------------------------------------------------
// CurWeapon: force C4 visibility when autoplant is active
// ---------------------------------------------------------------------------

public msg_OnCurWeapon( id )
{
    if ( !retakes_IsEnabled() )
        return

    if ( !retakes_HasFlag( RETAKES_AUTOPLANT ) )
        return

    // Force C4 to appear in weapon list
    new iWeapons = pev( id, pev_weapons )
    set_pev( id, pev_weapons, iWeapons | ( 1 << CSW_C4 ) )
}


// ---------------------------------------------------------------------------
// HUD Timer Trigger (called by round subsystem)
// ---------------------------------------------------------------------------

public msg_ShowTimerHUD( id, iTimer )
{
    // ShowTimer
    message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_ShowTimer, _, id )
    message_end()

    // RoundTime
    message_begin( MSG_ONE_UNRELIABLE, g_iMsgId_RoundTime, _, id )
    write_short( iTimer )
    message_end()
}


// ---------------------------------------------------------------------------
// Broadcast HUD Timer to all players
// ---------------------------------------------------------------------------

msg_BroadcastTimerHUD()
{
    new iPlayers[ 32 ], iNum
    get_players( iPlayers, iNum )

    new iTimer = get_pcvar_num( g_pCvar_C4Timer )

    for ( new i = 0; i < iNum; i++ )
    {
        msg_ShowTimerHUD( iPlayers[ i ], iTimer )
    }
}


// ============================================================================
// SPAWN SUBSYSTEM
// Handles: spawn candidate building, random selection,
// teleporting players to NAV areas, visibility quota, area usage tracking.
// ============================================================================


// ---------------------------------------------------------------------------
// Create spawn arrays
// ---------------------------------------------------------------------------

spawn_InitArrays()
{
    g_aAreaSpawnable    = ArrayCreate()
    g_aSpawnCandidates  = ArrayCreate()
    g_aAreaVisible      = ArrayCreate()
    g_aAreaUsed         = ArrayCreate()
}


// ---------------------------------------------------------------------------
// Destroy spawn arrays
// ---------------------------------------------------------------------------

spawn_DestroyArrays()
{
    __ArrayDestroy( g_aAreaSpawnable )
    __ArrayDestroy( g_aAreaVisible )
    __ArrayDestroy( g_aAreaUsed )
}


// ---------------------------------------------------------------------------
// Spawn: filter NAV areas that are valid for spawning
// Applies NAV attribute checks, size checks, and hull clearance checks.
// ---------------------------------------------------------------------------

spawn_FilterSpawnableAreas()
{
    for ( new i = 0; i < ArraySize( g_aAreaAttrs ); i++ )
    {
        new iAttrs = ArrayGetCell( g_aAreaAttrs, i )
        new bool:bSpawnable = true

        enum
        {
            NAV_CROUCH  = ( 1<<0 ), // Must crouch to use this area
            NAV_JUMP    = ( 1<<1 ), // Must jump to traverse this area
            NAV_PRECISE = ( 1<<2 )  // Tight movement, no obstacle adjustment
        }

        const NAV_SPAWN_BLOCK_MASK = ( NAV_CROUCH | NAV_JUMP | NAV_PRECISE )

        // Attribute-based rejection
        if ( iAttrs & NAV_SPAWN_BLOCK_MASK )
        {
            bSpawnable = false
        }
        else
        {
            new Float:flExt[ 6 ]
            ArrayGetArray( g_aAreaExtents, i, flExt )

            new Float:flWidth = flExt[ 3 ] - flExt[ 0 ]
            new Float:flDepth = flExt[ 4 ] - flExt[ 1 ]

            if ( flWidth < flHumanWidth || flDepth < flHumanWidth )
            {
                bSpawnable = false
            }
            else
            {
                new Float:flCenter[ 3 ]
                flCenter[ 0 ] = ( flExt[ 0 ] + flExt[ 3 ] ) * 0.5
                flCenter[ 1 ] = ( flExt[ 1 ] + flExt[ 4 ] ) * 0.5
                flCenter[ 2 ] = ( flExt[ 2 ] + flExt[ 5 ] ) * 0.5
                flCenter[ 2 ] += flHalfHumanHeight

                if ( !util_TraceHullClear( flCenter ) )
                    bSpawnable = false
            }
        }

        ArrayPushCell( g_aAreaSpawnable, bSpawnable )
    }

    #if defined DEBUG_NAV
    server_print
    (
        "[SPAWN] Spawnable areas: %d / %d",
        spawn_CountSpawnableAreas(),
        ArraySize( g_aAreaSpawnable )
    )
    #endif
}


// ---------------------------------------------------------------------------
// Spawn: count how many NAV areas are marked spawnable
// ---------------------------------------------------------------------------

#if defined DEBUG_NAV
spawn_CountSpawnableAreas()
{
    new iCount = 0

    for ( new i = 0; i < ArraySize( g_aAreaSpawnable ); i++ )
    {
        if ( ArrayGetCell( g_aAreaSpawnable, i ) )
            iCount++
    }

    return iCount
}
#endif


// ---------------------------------------------------------------------------
// Build spawn candidates for a given site + layer
// ---------------------------------------------------------------------------

spawn_BuildCandidates( iSite, iLayer )
{
    if ( iLayer == -1 )
        return

    ArrayClear( g_aSpawnCandidates )

    new Array:aLayer = ArrayGetCell( g_aBombsiteLayers[ iSite ], iLayer )

    for ( new i = 0; i < ArraySize( aLayer ); i++ )
    {
        new iArea = ArrayGetCell( aLayer, i )

        // Must be spawnable
        if ( !ArrayGetCell( g_aAreaSpawnable, iArea ) )
            continue

        // Layer 0 ignores LOS/visibility restrictions
        if ( iLayer != 0 )
        {
            // Must NOT have LOS to bombsite
            if ( ArrayGetCell( g_aLOSToBombsite[ iSite ], iArea ) )
                continue

            // Must NOT be visible from T spawns
            if ( ArrayGetCell( g_aAreaVisible, iArea ) )
                continue
        }

        // Must NOT be used already
        if ( ArrayGetCell( g_aAreaUsed, iArea ) )
            continue

        ArrayPushCell( g_aSpawnCandidates, iArea )
    }
}


// ---------------------------------------------------------------------------
// Select a random spawn area from built candidates
// ---------------------------------------------------------------------------

spawn_SelectRandomArea()
{
    new iCount = ArraySize( g_aSpawnCandidates )
    if ( iCount == 0 )
        return -1

    return ArrayGetCell( g_aSpawnCandidates, random( iCount ) )
}


// ---------------------------------------------------------------------------
// Teleport player to NAV area
// ---------------------------------------------------------------------------

spawn_TeleportPlayer( id, iArea )
{
    // Mark visibility + usage
    if ( cs_get_user_team( id ) == CS_TEAM_T )
        spawn_MarkTVisibility( iArea )

    spawn_MarkUsed( iArea )

    new Float:flCenter[ 3 ]
    util_AreaCenter( iArea, flCenter, flHalfHumanHeight )

    new Float:flTotalLift
    new Float:flEnd[ 3 ], Float:flFraction
    
    util_TraceHullClear( flCenter, flEnd, flFraction )

    while ( flFraction < 1.0 )
    {
        flCenter[ 2 ] += 8.0
        flTotalLift   += 8.0

        if ( flTotalLift > flHumanHeight )
            return

        util_TraceHullClear( flCenter, flEnd, flFraction )
    }

    // Teleport
    set_pev( id, pev_flags, pev( id, pev_flags ) | FL_DUCKING )
    
    new const Float:flVecDuckHullMin[] = { -16.0, -16.0, -18.0 }
    new const Float:flVecDuckHullMax[] = {  16.0,  16.0,  32.0 }

    engfunc( EngFunc_SetSize, id, flVecDuckHullMin, flVecDuckHullMax )
    engfunc( EngFunc_SetOrigin, id, flEnd )
    //engfunc( EngFunc_DropToFloor, id )

    set_pev( id, pev_velocity, Float:{ 0.0, 0.0, 0.0 } )
}


// ---------------------------------------------------------------------------
// Reset area usage
// ---------------------------------------------------------------------------

spawn_ResetUsed()
{
    ArrayClear( g_aAreaUsed )

    for ( new i = 0; i < ArraySize( g_aAreaID ); i++ )
        ArrayPushCell( g_aAreaUsed, false )
}

spawn_MarkUsed( iArea )
{
    ArraySetCell( g_aAreaUsed, iArea, true )
}


// ---------------------------------------------------------------------------
// Reset T visibility quota
// ---------------------------------------------------------------------------

spawn_ResetTVisibility()
{
    ArrayClear( g_aAreaVisible )

    for ( new i = 0; i < ArraySize( g_aAreaID ); i++ )
        ArrayPushCell( g_aAreaVisible, false )
}


// ---------------------------------------------------------------------------
// Mark areas visible from a newly used T spawn
// ---------------------------------------------------------------------------

spawn_MarkTVisibility( iAreaUsed )
{
    for ( new i = 0; i < ArraySize( g_aAreaID ); i++ )
    {
        if ( util_AreaLOS_Multi( i, iAreaUsed ) )
            ArraySetCell( g_aAreaVisible, i, true )
    }
}


// ---------------------------------------------------------------------------
// Find first valid layer with at least one spawn candidate
// ---------------------------------------------------------------------------

spawn_FindValidLayer( iSite, iMinLayer, iMaxLayer )
{
    new iLayerCount = ArraySize( g_aBombsiteLayers[ iSite ] )
    if ( iLayerCount == 0 )
        return -1

    // Clamp max layer to available layers
    iMaxLayer = min( iMaxLayer, ( iLayerCount - 1 )  )

    new iLayer = random_num( iMinLayer, iMaxLayer )

    // Scan forward from random layer -> outward
    for ( ; iLayer < iLayerCount; iLayer++ )
    {
        spawn_BuildCandidates( iSite, iLayer )

        if ( ArraySize( g_aSpawnCandidates ) == 0 )
            continue

        new iArea = spawn_SelectRandomArea()
        if ( iArea != -1 )
            return iLayer
    }

    return -1
}


// ============================================================================
// BOMBSITE SUBSYSTEM
// Handles: bombsite detection, NAV area assignment,
// BFS layer building, LOS precomputation.
// ============================================================================


// ---------------------------------------------------------------------------
// Create bombsite arrays
// ---------------------------------------------------------------------------

bombsite_InitArrays()
{
    for ( new iSite = 0; iSite < 2; iSite++ )
    {
        g_aBombsiteAreas[ iSite ]  = ArrayCreate()
        g_aBombsiteLayers[ iSite ] = ArrayCreate()
        g_aLOSToBombsite[ iSite ]  = ArrayCreate()
    }
}


// ---------------------------------------------------------------------------
// Create bombsite arrays
// ---------------------------------------------------------------------------

bombsite_DestroyArrays()
{
    for ( new iSite = 0; iSite < 2; iSite++ )
    {
        if ( g_aBombsiteLayers[ iSite ] )
        {
            // Destroy layer sub-arrays
            for ( new i = 0; i < ArraySize( g_aBombsiteLayers[ iSite ] ); i++ )
            {
                new Array:aLayer = ArrayGetCell( g_aBombsiteLayers[ iSite ], i )
                __ArrayDestroy( aLayer )
            }

            __ArrayDestroy( g_aBombsiteLayers[ iSite ] )
        }

        // Destroy top-level arrays
        __ArrayDestroy( g_aBombsiteAreas[ iSite ] )
        __ArrayDestroy( g_aLOSToBombsite[ iSite ] )
    }
}


// ---------------------------------------------------------------------------
// Detect bombsite entities and assign NAV areas
// ---------------------------------------------------------------------------

bombsite_Establish()
{
    new const szClasses[][] =
    {
        "info_bomb_target",
        "func_bomb_target"
    }

    new iSite = -1

    for ( new iClass = 0; iClass < sizeof szClasses; iClass++ )
    {
        new iEnt = -1

        while ( ( iEnt = engfunc( EngFunc_FindEntityByString, iEnt, "classname", szClasses[ iClass ] ) ) )
        {
            new Float:flAbsMin[ 3 ], Float:flAbsMax[ 3 ]
            pev( iEnt, pev_absmin, flAbsMin )
            pev( iEnt, pev_absmax, flAbsMax )

            new iArea = bombsite_FindAreaByBounds( flAbsMin, flAbsMax )
            if ( iArea == -1 )
                continue

            new iPlace = ArrayGetCell( g_aAreaPlaceEntry, iArea )

            new szPlace[ 32 ]
            if ( iPlace > 0 )
                ArrayGetString( g_aPlaceNames, iPlace - 1 , szPlace, charsmax( szPlace ) )

            // Determine site index
            switch ( iSite )
            {
                case -1: iSite = equali( szPlace, "BombsiteA" ) ? 0 : 1
                default: iSite = equali( szPlace, "BombsiteB" ) ? 1 : 0
            }

            // Only assign the first brush entity for each site
            if ( !g_iBombsiteEnt[ iSite ] )
            {
                g_iBombsiteEnt[ iSite ] = iEnt

                bombsite_AssignAreas( iSite, flAbsMin, flAbsMax )
        }

            #if defined DEBUG_NAV
            server_print
            (
                "[BOMBSITE] Bombsite %c detected at area %d (Place %d: %s)",
                'A' + iSite,
                iArea,
                iPlace,
                szPlace
            )

            server_print
            (
                "[BOMBSITE] Bombsite %c contains %d NAV areas",
                'A' + iSite,
                ArraySize( g_aBombsiteAreas[ iSite ] )
            )
            #endif
        }
    }
}


// ---------------------------------------------------------------------------
// Assign NAV areas to bombsite by bounding box + place ID
// ---------------------------------------------------------------------------

bombsite_AssignAreas( iSite, const Float:flAbsMin[ 3 ], const Float:flAbsMax[ 3 ] )
{
    new Float:flExt[ 6 ]
    new iPlace = -1

    // First pass: bounding box intersection
    for ( new iArea = 0; iArea < ArraySize( g_aAreaID ); iArea++ )
    {
        ArrayGetArray( g_aAreaExtents, iArea, flExt )

        if (    flAbsMax[ 0 ] >= flExt[ 0 ]
             && flAbsMin[ 0 ] <= flExt[ 3 ]
             && flAbsMax[ 1 ] >= flExt[ 1 ]
             && flAbsMin[ 1 ] <= flExt[ 4 ]
             && flAbsMax[ 2 ] >= flExt[ 2 ]
             && flAbsMin[ 2 ] <= flExt[ 5 ] )
        {
            ArrayPushCell( g_aBombsiteAreas[ iSite ], iArea )
            iPlace = ArrayGetCell( g_aAreaPlaceEntry, iArea )
        }
    }

    if ( iPlace <= 0 )
        return

    // Second pass: include all areas with same place ID
    for ( new iArea = 0; iArea < ArraySize( g_aAreaID ); iArea++ )
    {
        if ( bombsite_ArrayContains( g_aBombsiteAreas[ iSite ], iArea ) )
            continue

        if ( ArrayGetCell( g_aAreaPlaceEntry, iArea ) == iPlace )
                ArrayPushCell( g_aBombsiteAreas[ iSite ], iArea )
    }
}


// ---------------------------------------------------------------------------
// Build Breadth-First Search (BFS)-style outward layers for each bombsite
// ---------------------------------------------------------------------------

bombsite_BuildLayers( iMaxDepth )
{
    for ( new iSite = 0; iSite < 2; iSite++ )
    {
        // Layer 0 = bombsite areas
        new Array:aLayer0 = ArrayCreate()
        for ( new i = 0; i < ArraySize( g_aBombsiteAreas[ iSite ] ); i++ )
        {
            ArrayPushCell( aLayer0, ArrayGetCell( g_aBombsiteAreas[ iSite ], i ) )
        }
        ArrayPushCell( g_aBombsiteLayers[ iSite ], aLayer0 )

        // Build outward layers
        for ( new iDepth = 1; iDepth <= iMaxDepth; iDepth++ )
        {
            new Array:aPrev = ArrayGetCell( g_aBombsiteLayers[ iSite ], iDepth - 1 )
            new Array:aCurr = ArrayCreate()

            for ( new i = 0; i < ArraySize( aPrev ); i++ )
            {
                new iArea = ArrayGetCell( aPrev, i )
                new Array:aNeighbors = ArrayGetCell( g_aAdjacency, iArea )

                for ( new n = 0; n < ArraySize( aNeighbors ); n++ )
                {
                    new iNeighbor = ArrayGetCell( aNeighbors, n )

                    // Skip bombsite areas
                    if ( bombsite_ArrayContains( g_aBombsiteAreas[ iSite ], iNeighbor ) )
                        continue

                    // Skip if already in any previous layer
                    if ( bombsite_AreaInAnyLayer( g_aBombsiteLayers[ iSite ], iNeighbor ) )
                        continue

                    ArrayPushCell( aCurr, iNeighbor )
                }
            }

            ArrayPushCell( g_aBombsiteLayers[ iSite ], aCurr )

            #if defined DEBUG_NAV
            server_print
            (
                "[BOMBSITE] Bombsite %c Layer %d count: %d",
                'A' + iSite,
                iDepth,
                ArraySize( aCurr )
            )
            #endif
        }
    }
}


// ---------------------------------------------------------------------------
// Precompute LOS -> bombsite (for spawn filtering)
// ---------------------------------------------------------------------------

bombsite_PrecomputeLOS()
{
    new iAreaCount = ArraySize( g_aAreaID )

    for ( new iSite = 0; iSite < 2; iSite++ )
    {
        new Array:aLayer0 = ArrayGetCell( g_aBombsiteLayers[ iSite ], 0 )
        new iL0Count = ArraySize( aLayer0 )

        for ( new iArea = 0; iArea < iAreaCount; iArea++ )
        {
            new bool:bVisible = false

            for ( new j = 0; j < iL0Count; j++ )
            {
                new iL0Area = ArrayGetCell( aLayer0, j )

                if ( util_AreaLOS_Multi( iArea, iL0Area ) )
                {
                    bVisible = true
                    break
                }
            }

            ArrayPushCell( g_aLOSToBombsite[ iSite ], bVisible )
        }
    
    #if defined DEBUG_NAV
    server_print
    (
        "[BOMBSITE] LOS->Bombsite %c computed (%d areas)",
        'A' + iSite,
        iAreaCount
    )
    #endif
    
   }
}


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool:bombsite_ArrayContains( Array:aArray, iValue )
{
    for ( new i = 0; i < ArraySize( aArray ); i++ )
    {
        if ( ArrayGetCell( aArray, i ) == iValue )
            return true
    }
    return false
}

bool:bombsite_AreaInAnyLayer( Array:aLayers, iArea )
{
    for ( new iLayer = 0; iLayer < ArraySize( aLayers ); iLayer++ )
    {
        new Array:aLayer = ArrayGetCell( aLayers, iLayer )

        for ( new i = 0; i < ArraySize( aLayer ); i++ )
        {
            if ( ArrayGetCell( aLayer, i ) == iArea )
                return true
        }
    }
    return false
}

bombsite_FindAreaByBounds( const Float:flMin[ 3 ], const Float:flMax[ 3 ] )
{
    new Float:flExt[ 6 ]

    for ( new i = 0; i < ArraySize( g_aAreaExtents ); i++ )
    {
        ArrayGetArray( g_aAreaExtents, i, flExt )
        if ( flMax[ 0 ] >= flExt[ 0 ] &&
             flMin[ 0 ] <= flExt[ 3 ] &&
             flMax[ 1 ] >= flExt[ 1 ] &&
             flMin[ 1 ] <= flExt[ 4 ] &&
             flMax[ 2 ] >= flExt[ 2 ] &&
             flMin[ 2 ] <= flExt[ 5 ] ) 
        {
             return i
        }
    }

    return -1
}


// ============================================================================
// UTILITY SUBSYSTEM
// Stateless helpers: shuffle, geometry, and trace wrappers.
// ============================================================================


// ---------------------------------------------------------------------------
// Shuffle array of player IDs
// ---------------------------------------------------------------------------

util_ShuffleIntArray( iIds[], iCount )
{
    for ( new iIndex = iCount - 1; iIndex > 0; iIndex-- )
    {
        new iSwapIndex = random_num( 0, iIndex )

        new iTemp = iIds[ iIndex ]
        iIds[ iIndex ] = iIds[ iSwapIndex ]
        iIds[ iSwapIndex ] = iTemp
    }
}


// ---------------------------------------------------------------------------
// Trace: hull check (returns true if hull is free)
// ---------------------------------------------------------------------------

bool:util_TraceHullClear
( 
    const Float:flOrigin[ 3 ],
    Float:flEndPos[ 3 ] = { 0.0, 0.0, 0.0 },
    &Float:flFraction = 1.0
)
{
    new iTrace = create_tr2()

    engfunc
    ( 
        EngFunc_TraceHull,
        flOrigin,
        flOrigin,
        IGNORE_MONSTERS,
        HULL_HUMAN,
        0,
        iTrace
    )

    get_tr2( iTrace, TR_vecEndPos, flEndPos )
    get_tr2( iTrace, TR_flFraction, flFraction )

    new bool:bClear =
    (
        !get_tr2( iTrace, TR_AllSolid ) &&
        !get_tr2( iTrace, TR_StartSolid ) &&
        flFraction >= 1.0
    )

    free_tr2( iTrace )
    return bClear
}


// ---------------------------------------------------------------------------
// Geometry: compute NAV area center from extents
// ---------------------------------------------------------------------------

util_AreaCenter( iArea, Float:flOut[ 3 ], Float:flZoffset = flHumanHeight )
{
    new Float:flExt[ 6 ]
    ArrayGetArray( g_aAreaExtents, iArea, flExt )

    flOut[ 0 ] = ( flExt[ 0 ] + flExt[ 3 ] ) * 0.5
    flOut[ 1 ] = ( flExt[ 1 ] + flExt[ 4 ] ) * 0.5
    flOut[ 2 ] = ( flExt[ 2 ] + flExt[ 5 ] ) * 0.5
    flOut[ 2 ] += flZoffset
}


// ---------------------------------------------------------------------------
// Trace: multi-sample LOS test between two NAV areas
// Returns true if any sample have clear line-of-sight.
// ---------------------------------------------------------------------------

bool:util_AreaLOS_Multi( iAreaA, iAreaB )
{
    // Compute centers
    new Float:flCenterA[ 3 ], Float:flCenterB[ 3 ]
    util_AreaCenter( iAreaA, flCenterA )
    util_AreaCenter( iAreaB, flCenterB )
    
    const Float:flOffset = flHumanWidth

    // Multi-sample offsets (center + 4 edge samples)
    static const Float:flOffsets[ 5 ][ 3 ] =
    {
        {  0.0,       0.0,  0.0 },   // center
        {  flOffset,  0.0,  0.0 },   // east
        { -flOffset,  0.0,  0.0 },   // west
        {  0.0,  flOffset,  0.0 },   // north
        {  0.0, -flOffset,  0.0 }    // south
    }

    new Float:flFrom[ 3 ], Float:flTo[ 3 ]

    // Test all samples
    for ( new i = 0; i < sizeof flOffsets; i++ )
    {
        xs_vec_add( flCenterA, flOffsets[ i ], flFrom )
        xs_vec_add( flCenterB, flOffsets[ i ], flTo )

        if ( util_HasLineOfSight( flFrom, flTo ) )
            return true
    }

    return false
}


// ---------------------------------------------------------------------------
// Trace: single-sample LOS test between two points
// Returns true if the trace reaches the end point with no obstruction.
// ---------------------------------------------------------------------------

bool:util_HasLineOfSight( const Float:flFrom[ 3 ], const Float:flTo[ 3 ] )
{
    new iTrace = create_tr2()

    engfunc( EngFunc_TraceLine, flFrom, flTo, IGNORE_MONSTERS, 0, iTrace )

    new Float:flFraction
    get_tr2( iTrace, TR_flFraction, flFraction )

    free_tr2( iTrace )

    return ( flFraction >= 1.0 )
}


/// ============================================================================
// NAV SUBSYSTEM
// Handles: NAV file loading, header validation, area extents,
// adjacency graph, place IDs, area centers, LOS checks.
// ============================================================================


// ---------------------------------------------------------------------------
// Create NAV arrays
// ---------------------------------------------------------------------------

nav_InitArrays()
{
    g_aAreaExtents      = ArrayCreate( 6 )
    g_aAdjacency        = ArrayCreate()
    g_aAreaPlaceEntry   = ArrayCreate()
    g_aPlaceNames       = ArrayCreate( 32 )
    g_aTempNeighborIDs  = ArrayCreate()
    g_aAreaID           = ArrayCreate()
    g_aAreaAttrs        = ArrayCreate()
}


// ---------------------------------------------------------------------------
// Destroy NAV arrays
// ---------------------------------------------------------------------------

nav_DestroyArrays()
{
    // Destroy adjacency sub-arrays
    for ( new i = 0; i < ArraySize( g_aAdjacency ); i++ )
    {
        new Array:aNeighbors = ArrayGetCell( g_aAdjacency, i )
        __ArrayDestroy( aNeighbors )
    }

    // Destroy temp neighbor ID arrays
    for ( new i = 0; i < ArraySize( g_aTempNeighborIDs ); i++ )
    {
        new Array:aTemp = ArrayGetCell( g_aTempNeighborIDs, i )
        __ArrayDestroy( aTemp )
    }

    __ArrayDestroy( g_aAreaExtents )
    __ArrayDestroy( g_aAdjacency )
    __ArrayDestroy( g_aAreaPlaceEntry )
    __ArrayDestroy( g_aPlaceNames )
    __ArrayDestroy( g_aTempNeighborIDs )
    __ArrayDestroy( g_aAreaID )
    __ArrayDestroy( g_aAreaAttrs )
}


// ---------------------------------------------------------------------------
// Load NAV for a given map name
// ---------------------------------------------------------------------------

nav_Load( const szMapName[] )
{
    new szNavPath[ 128 ]
    formatex( szNavPath, charsmax( szNavPath ), "maps/%s.nav", szMapName )

    new iFile = fopen( szNavPath, "rb" )
    if ( !iFile )
        return -2

    new iHeader = nav_ParseHeader( iFile )
    if ( iHeader != 1 )
    {
        fclose( iFile )
        return iHeader
    }

    nav_InitArrays()
    nav_ParsePlaces( iFile )
    nav_ParseAreas( iFile )

    fclose( iFile )
    return 1
}


// ---------------------------------------------------------------------------
// Header parsing
// ---------------------------------------------------------------------------

nav_ParseHeader( iFile )
{
    const NAV_MAGIC_NUMBER = 0xFEEDFACE
    const NAV_VERSION = 5 // CS:CZ

    new iMagic, iVersion

    fread( iFile, iMagic, BLOCK_INT )
    if ( iMagic != NAV_MAGIC_NUMBER )
        return -1

    fread( iFile, iVersion, BLOCK_INT )
    if ( iVersion != NAV_VERSION )
        return 0

    fseek( iFile, 4, SEEK_CUR ) // Skip bsp file size

    return 1
}


// ---------------------------------------------------------------------------
// Parse place names
// ---------------------------------------------------------------------------

nav_ParsePlaces( iFile )
{
    new iPlaceCount
    fread( iFile, iPlaceCount, BLOCK_SHORT )

    new szPlaceName[ 256 ]

    for ( new i = 0; i < iPlaceCount; i++ )
    {
        new iLen
        fread( iFile, iLen, BLOCK_SHORT )

        new iRead = min( iLen, charsmax( szPlaceName ) )

        if ( iRead > 0 )
        {
            fread_blocks( iFile, szPlaceName, iRead, BLOCK_CHAR )

            szPlaceName[ iRead - 1 ] = 0
        }

        if ( iLen > iRead )
            fseek( iFile, iLen - iRead, SEEK_CUR )

        ArrayPushString( g_aPlaceNames, szPlaceName )
    }
}


// ---------------------------------------------------------------------------
// Area parser: reads ID, attributes, extents, raw neighbor IDs,
// and skips all hide/approach/encounter data.
// ---------------------------------------------------------------------------

nav_ParseAreas( iFile )
{
    new iAreaCount
    fread( iFile, iAreaCount, BLOCK_INT )

    for ( new iArea = 0; iArea < iAreaCount; iArea++ )
    {
        // ID
        new iAreaID
        fread( iFile, iAreaID, BLOCK_INT )

        ArrayPushCell( g_aAreaID, iAreaID )

        // Attribute flags
        new iAttrs
        fread( iFile, iAttrs, BLOCK_CHAR )
        iAttrs &= 0xFF

        ArrayPushCell( g_aAreaAttrs, iAttrs )

        // Extent of area
        new iBits[ 6 ]
        fread_raw( iFile, iBits, sizeof iBits, BLOCK_INT )

        new Float:flExt[ 6 ]
        for ( new j = 0; j < sizeof flExt; j++ )
            flExt[ j ] = Float:iBits[ j ]

        ArrayPushArray( g_aAreaExtents, flExt )

        // Skip heights of implicit corners (NEZ/SWZ)
        fseek( iFile, 4, SEEK_CUR )
        fseek( iFile, 4, SEEK_CUR )

        // Neighbor IDs (temp)
        new Array:aTemp = ArrayCreate()

        // Load connections (IDs) to adjacent areas
        // In the order NORTH, EAST, SOUTH, WEST
        for ( new d = 0; d < 4; d++ )
        {
            // Number of connections for this direction
            new iConnCount
            fread( iFile, iConnCount, BLOCK_INT )

            for ( new c = 0; c < iConnCount; c++ )
            {
                new iNeighborID
                fread( iFile, iNeighborID, BLOCK_INT )

                ArrayPushCell( aTemp, iNeighborID )
            }
        }

        ArrayPushCell( g_aTempNeighborIDs, aTemp )

        /*struct connectionData_t {
           unsigned int count;             4
           unsigned int AreaIDs[ count ];  4
        }*/

        // Skip rest of area (hides, approaches, encounters)

        new iHideCount
        fread( iFile, iHideCount, BLOCK_CHAR )
        iHideCount &= 0xFF

        fseek( iFile, iHideCount * ( 4 + 12 + 1 ), SEEK_CUR )
	
        /*struct hidingSpot_t {
           unsigned int ID;            4
           float position[ 3 ];        4 * 3
           unsigned char Attributes;   1
        }*/

        new iApproachCount
        fread( iFile, iApproachCount, BLOCK_CHAR )
        iApproachCount &= 0xFF

        fseek( iFile, iApproachCount * ( 4 + 4 + 1 + 4 + 1 ), SEEK_CUR )
	
        /*struct approachSpot_t {
           uint approachHereId;    4
           uint approachPrevId;    4
           byte approachType;      1
           uint approachNextId;    4
           byte approachHow;       1
        }*/

        new iEncounterCount
        fread( iFile, iEncounterCount, BLOCK_INT )

        for ( new e = 0; e < iEncounterCount; e++ )
        {
            fseek( iFile, ( 4 + 1 + 4 + 1 ), SEEK_CUR )

            new iSpotCount
            fread( iFile, iSpotCount, BLOCK_CHAR )
            iSpotCount &= 0xFF

            fseek( iFile, iSpotCount * ( 4 + 1 ), SEEK_CUR )

            /*struct encounterPath_t {
                unsigned int EntryAreaID;           4
                unsigned byte EntryDirection;       1
                unsigned int DestAreaID;            4
                unsigned byte DestDirection;        1

                unsigned char encounterSpotCount;   1
                encounterSpot_t encounterSpots[ encounterSpotCount ];
            }

            struct encounterSpot_t {
                unsigned int AreaID;                4
                unsigned char ParametricDistance;   1
            }*/
        }

        // Place entry
        new iPlaceEntry
        fread( iFile, iPlaceEntry, BLOCK_SHORT )

        ArrayPushCell( g_aAreaPlaceEntry, iPlaceEntry )
    }

    nav_PostLoad()
}


// ---------------------------------------------------------------------------
// Resolve neighbor IDs -> area indices
// ---------------------------------------------------------------------------

nav_PostLoad()
{
    new iAreaCount = ArraySize( g_aAreaID )
    
    for ( new iArea = 0; iArea < iAreaCount; iArea++ )
    {
        new Array:aTemp = ArrayGetCell( g_aTempNeighborIDs, iArea )
        new Array:aNeighbors = ArrayCreate()

        for ( new i = 0; i < ArraySize( aTemp ); i++ )
        {
            new iNeighborID = ArrayGetCell( aTemp, i )

            // Find index of this ID
            new iIndex = nav_FindAreaIndexByID( iNeighborID )

            if ( iIndex != -1 )
                ArrayPushCell( aNeighbors, iIndex )
        }

        ArrayPushCell( g_aAdjacency, aNeighbors )
    }
}


// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

nav_FindAreaIndexByID( iAreaID )
{
    for ( new i = 0; i < ArraySize( g_aAreaID ); i++ )
    {
        if ( ArrayGetCell( g_aAreaID, i ) == iAreaID )
            return i
    }
    return -1
}

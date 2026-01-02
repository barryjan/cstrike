#include < amxmodx >
#include < fakemeta >
#include < hamsandwich >
#include < engine >
#include < cstrike >
#include < xs >

#define TASKID_ROUNDTIME 12439
#define TASKID_BUYTIME 	 62144
#define MAX_BOMBSITE_LAYERS 12
#define RETAKE_AUTOPLANT   (1 << 0) // a
#define RETAKE_DEFUSE (1 << 1) // b
#define DEBUG_NAV

// --------------------
// NAV dynamic storage
// --------------------

new Array:g_aPlaceNames
new Array:g_aAreaID
new Array:g_aAreaAttrs
new Array:g_aAreaExtents // Float[ 6 ]
new Array:g_aTempNeighborIDs
new Array:g_aAdjacency  // Array of Array
new Array:g_aAreaPlaceEntry
new Array:g_aAreaSpawnable
new Array:g_aSpawnCandidates
new Array:g_aBombsiteAreas[ 2 ]   // 0 = A, 1 = B
new Array:g_aBombsiteLayers[ 2 ]   // Array of Array for each site
new Array:g_aLOSToBombsite[ 2 ]   // 0 = A, 1 = B
new Array:g_aAreaVisible
new Array:g_aAreaUsed

new g_iRandomSite
new g_iEventId_DecalReset
new g_iMsgId_RoundTime
new Float:g_flNewRoundTime
new g_iBombsiteEnt[ 2 ]
new g_iBuyzoneEnt
new g_iForward_PlayerPostThink
new g_pCvar_C4Timer
new g_pCvar_FreezeTime
new g_pCvar_BuyTime
new g_pCvar_RetakeFlags

public plugin_init()
{
	register_plugin
	(
		.plugin_name 	= "Project Retake",
		.version	= "1.0",
		.author 	= "BARRY."
	)
	
	new szMapname[ 64 ]
	get_mapname( szMapname, charsmax( szMapname ) )
	
	if ( !equali( szMapname, "de_", 3 ) )
	{
		pause( "ad" )
		
		return
	}
	
	new szNavPath[ 128 ]
	formatex( szNavPath, charsmax( szNavPath ), "maps/%s.nav", szMapname )
	
	new iResult = Nav_ReadFile( szNavPath )
	
	switch ( iResult )
	{
		case -2: server_print( "[NAV] Unable to open '%s'", szNavPath )
		case -1: server_print( "[NAV] Invalid navigation file '%s'", szNavPath )
		case  0: server_print( "[NAV] Unsupported version in navigation file '%s'", szNavPath )
		default: Nav_Init()
	}
	
	if ( iResult != 1 ) return
	
	register_event( "HLTV", "event_HLTV_NewRound", "a", "1=0", "2=0" )
	register_event( "CurWeapon", "event_CurWeapon", "be", "2=6" ) //CSW_C4
	
	register_logevent( "logevent_Round_Start", 2, "1=Round_Start" )
	
	register_forward( FM_PlaybackEvent, "forward_PlaybackEvent" )
	
	g_pCvar_C4Timer = get_cvar_pointer( "mp_c4timer" )
	g_pCvar_FreezeTime = get_cvar_pointer( "mp_freezetime" )
	
	g_pCvar_BuyTime = register_cvar( "amx_retake_buytime", "5.0" )
	g_pCvar_RetakeFlags = register_cvar( "amx_retake_flags", "ab" )
	
	g_iMsgId_RoundTime = get_user_msgid( "RoundTime" )
	
	g_iEventId_DecalReset = engfunc( EngFunc_PrecacheEvent, 1, "events/decal_reset.sc" )
	
	g_iBuyzoneEnt = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, "func_buyzone" ) )
	dllfunc( DLLFunc_Spawn, g_iBuyzoneEnt )
	
	engfunc
	( 
		EngFunc_SetSize, 
		g_iBuyzoneEnt, 
		Float:{ -8192.0, -8192.0, -8192.0 }, 
		Float:{ -8192.0, -8192.0, -8192.0 } 
	)
}

Nav_Init()
{
	Nav_FilterSpawnableAreas()
	Nav_EstablishBombAreas()
	Nav_BuildBombsiteLayers( MAX_BOMBSITE_LAYERS )
	Nav_PrecomputeLOS_ToBombsite()
}

public forward_PlayerPostThink( id )
{
	if ( is_user_alive( id ) )
		dllfunc( DLLFunc_Touch, g_iBuyzoneEnt, id )
}

public task_Unregister_PlayerPostThink()
{
  	if ( g_iForward_PlayerPostThink )
		unregister_forward( FM_PlayerPostThink, g_iForward_PlayerPostThink )
}

public event_HLTV_NewRound()
{
	g_flNewRoundTime = get_gametime()
	g_iRandomSite = random_num( 0, 1 )
	Nav_ResetAreaUsed()
	Nav_ResetSpawnVisibility()
	
	remove_task( TASKID_ROUNDTIME )
	remove_task( TASKID_BUYTIME )
	
	g_iForward_PlayerPostThink = register_forward( FM_PlayerPostThink, "forward_PlayerPostThink" )
	set_task( get_pcvar_float( g_pCvar_BuyTime ), "task_Unregister_PlayerPostThink", TASKID_BUYTIME )
}

Retake_GetFlags()
{
	new szFlags[ 16 ]
	get_pcvar_string( g_pCvar_RetakeFlags, szFlags, charsmax( szFlags ) )
	
	return read_flags( szFlags )
}

public logevent_Round_Start()
{
	new flags = Retake_GetFlags()
	
	if ( !( flags & RETAKE_AUTOPLANT ) )
		return

	new iBsEnt = g_iBombsiteEnt[ g_iRandomSite ]
	
	if ( !pev_valid( iBsEnt ) ) return
	
	new Float:flAbsMin[ 3 ], Float:flAbsMax[ 3 ], Float:flSpawnOrigin[ 3 ]
	pev( iBsEnt, pev_absmin, flAbsMin )
	pev( iBsEnt, pev_absmax, flAbsMax )
	
	new iC4, iAttempt
	
	for ( iAttempt = 0; iAttempt < 30; iAttempt++ )
	{
		flSpawnOrigin[ 0 ] = random_float( flAbsMin[ 0 ], flAbsMax[ 0 ] )
		flSpawnOrigin[ 1 ] = random_float( flAbsMin[ 1 ], flAbsMax[ 1 ] )
		flSpawnOrigin[ 2 ] = random_float( flAbsMin[ 2 ], flAbsMax[ 2 ] )
	
		new Float:flEnd[ 3 ]
		xs_vec_copy( flSpawnOrigin, flEnd )
		flEnd[ 2 ] -= 1.0   // tiny downward trace
		
		new tr = create_tr2()
		engfunc( EngFunc_TraceHull, flSpawnOrigin, flEnd, IGNORE_MONSTERS, HULL_HUMAN, 0, tr )
		
		new Float:flFraction
		get_tr2( tr, TR_flFraction, flFraction )
		
		if ( get_tr2( tr, TR_AllSolid ) || get_tr2( tr, TR_StartSolid ) || flFraction < 1.0 )
		{
			free_tr2( tr )
			
			continue
		}
		
		free_tr2( tr )
		
		if ( ( iC4 = create_entity( "weapon_c4" ) ) )
		{	
			DispatchKeyValue( iC4, "detonatedelay", "0" )
			DispatchSpawn( iC4 )
			
			engfunc( EngFunc_SetOrigin, iC4, flSpawnOrigin )
			engfunc( EngFunc_DropToFloor, iC4 )
			
			force_use( iC4, iC4 ) 

			set_task( 1.0, "task_UpdateRoundTime", TASKID_ROUNDTIME )
			
			break
		}
	}
}

public task_UpdateRoundTime()
{
	new iPlayers[ 32 ], iNum
	get_players( iPlayers, iNum, "a" )
	
	for ( new i = 0; i < iNum; i++ )
	{
		message_begin( MSG_ONE, g_iMsgId_RoundTime, _, iPlayers[ i ] )
		write_short( get_pcvar_num( g_pCvar_C4Timer ) )
		message_end()
	}
}

public event_CurWeapon( id )
{
	new flags = Retake_GetFlags()
	
	if ( !( flags & RETAKE_AUTOPLANT ) )
		return
  
	cs_set_user_plant( id, 0, 0 )
	cs_set_user_bpammo( id, CSW_C4,0 )
	set_pev( id, pev_weapons, pev( id, pev_weapons ) & ~( 1 << CSW_C4 ) )
	set_pev( id, pev_body, 0 )
}

public forward_PlaybackEvent( iFlags, iEntId, iEventId )
{
	if ( iEventId != g_iEventId_DecalReset || floatcmp( get_gametime(), g_flNewRoundTime ) )
		return FMRES_IGNORED

	new iPlayers[ 32 ], iNum
	get_players( iPlayers, iNum, "ae", "TERRORIST" )
	
	for ( new i = 0; i < iNum; i++ )
	{
		Nav_BuildLayerSpawnCandidates( g_iRandomSite, 0 )
		new iArea = Nav_SelectRandomSpawnArea()
		if ( iArea != -1 ) 
		{
			Nav_TeleportPlayerToArea( iPlayers[ i ], iArea )
		}
	}
	
	new flags = Retake_GetFlags()

	get_players( iPlayers, iNum, "ae", "CT" )

	for ( new i = 0; i < iNum; i++ )
	{
		if ( flags & RETAKE_DEFUSE )
			cs_set_user_defuse( iPlayers[ i ] , 1 )
	  
	  
		new iLayer = Nav_FindFirstValidLayer( g_iRandomSite )
		Nav_BuildLayerSpawnCandidates( g_iRandomSite, iLayer )
		new iArea = Nav_SelectRandomSpawnArea()
		if ( iArea != -1 ) 
		{
			Nav_TeleportPlayerToArea( iPlayers[ i ], iArea )
		}
	}
	
	return FMRES_IGNORED
}

Nav_BuildLayerSpawnCandidates( iSite, iLayer )
{
    if ( iLayer == -1 ) return
  
    ArrayClear( g_aSpawnCandidates )

    new Array:aLayer = ArrayGetCell( g_aBombsiteLayers[ iSite ], iLayer )

    new iArea = -1
    for ( new i = 0; i < ArraySize( aLayer ); i++ )
    {
        iArea = ArrayGetCell( aLayer, i )

        if ( !ArrayGetCell( g_aAreaSpawnable, iArea ) )
            continue
	    
        if ( iLayer != 0 && ArrayGetCell( g_aLOSToBombsite[ iSite ], iArea ) )
	   continue

        if ( iLayer != 0 && ArrayGetCell( g_aAreaVisible, iArea ) )
            continue
	   
        if ( ArrayGetCell( g_aAreaUsed, iArea ) )
	   continue

        ArrayPushCell( g_aSpawnCandidates, iArea )
    }
}

Nav_SelectRandomSpawnArea()
{
    new count = ArraySize( g_aSpawnCandidates )
    if ( count == 0 )
        return -1

    return ArrayGetCell( g_aSpawnCandidates, random( count ) )
}

Nav_TeleportPlayerToArea( id, iArea )
{
    // Update LOS + quota
    Nav_MarkSpawnVisibility( iArea )
    Nav_MarkAreaUsed( iArea )

    // Get NAV extents
    new Float:ext[6]
    ArrayGetArray( g_aAreaExtents, iArea, ext )

    // Compute center of the area
    new Float:center[3]
    center[0] = (ext[0] + ext[3]) * 0.5
    center[1] = (ext[1] + ext[4]) * 0.5
    center[2] = ext[5]
    
    new Float:up[3]
    xs_vec_copy( center, up )
    up[2] = ext[2] + 72.0
    
    new tr = create_tr2()
    engfunc( EngFunc_TraceHull, center, up, IGNORE_MONSTERS, HULL_HUMAN, id, tr )
    
    new Float:hit[3]
    get_tr2( tr, TR_vecEndPos, hit )
    
    new Float:fraction
    get_tr2( tr, TR_flFraction, fraction )
    
    if ( fraction < 1.0 )
	center[2] = hit[2] - 72.0

    free_tr2( tr )

    engfunc( EngFunc_SetOrigin, id, hit )
    engfunc( EngFunc_DropToFloor, id )
    
    set_pev( id, pev_velocity, Float:{ 0.0, 0.0, 0.0 } )
}

Nav_PrecomputeLOS_ToBombsite()
{
    new iAreaCount = ArraySize( g_aAreaExtents )

    for ( new s = 0; s < 2; s++ )
    {
        ArrayClear( g_aLOSToBombsite[ s ] )

        new Array:aLayer0 = ArrayGetCell( g_aBombsiteLayers[ s ], 0 )
        new iL0Count = ArraySize( aLayer0 )

        for ( new i = 0; i < iAreaCount; i++ )
        {
            new bool:bVisible = false

            for ( new j = 0; j < iL0Count; j++ )
            {
                new iL0Area = ArrayGetCell( aLayer0, j )

                if ( Nav_AreaLOS_Multi( i, iL0Area ) )
                {
                    bVisible = true
                    break
                }
            }

            ArrayPushCell( g_aLOSToBombsite[ s ], bVisible )
        }

        #if defined DEBUG_NAV
        server_print(
            "[NAV] LOS->Bombsite %c computed (%d areas)",
            'A' + s,
            iAreaCount
        )
        #endif
    }
}

Nav_BuildBombsiteLayers( iMaxDepth )
{
	for ( new iSite = 0; iSite < 2; iSite++ )
	{
		ArrayClear( g_aBombsiteLayers[ iSite ] )
	
		// --- LAYER 0: bombsite areas ---
		new Array:aLayer0 = ArrayCreate()
		for ( new i = 0; i < ArraySize( g_aBombsiteAreas[ iSite ] ); i++ )
		{
			ArrayPushCell( aLayer0, ArrayGetCell( g_aBombsiteAreas[ iSite ], i ) )
		}
		ArrayPushCell( g_aBombsiteLayers[ iSite ], aLayer0 )

		// --- Build outward layers ---
		for ( new depth = 1; depth <= iMaxDepth; depth++ )
		{
			new Array:aPrev = ArrayGetCell( g_aBombsiteLayers[ iSite ], depth - 1 )
			new Array:aCurr = ArrayCreate()
			
			for ( new i = 0; i < ArraySize( aPrev ); i++ )
			{
				new iArea = ArrayGetCell( aPrev, i )
				new Array:aNeighbors = ArrayGetCell( g_aAdjacency, iArea )
				
				for ( new n = 0; n < ArraySize( aNeighbors ); n++ )
				{
					new iNeighbor = ArrayGetCell( aNeighbors, n )
					
					// dont include bombsite areas in outer layers
					if ( Nav_ArrayContains( g_aBombsiteAreas[ iSite ], iNeighbor ) )
						continue
					
					// Skip if already in any previous layer
					if ( Nav_AreaInAnyLayer( g_aBombsiteLayers[ iSite ], iNeighbor ) )
						continue
					
					ArrayPushCell( aCurr, iNeighbor )
				}
			}
			
			ArrayPushCell( g_aBombsiteLayers[ iSite ], aCurr )
			
			#if defined DEBUG_NAV
			server_print
			(
				"[NAV] Bombsite %c Layer %d count: %d",
				'A' + iSite,
				depth,
				ArraySize( aCurr )
			)
			#endif
		}
	}
}

Nav_AssignBombsiteAreas( iSite, const Float:bsMin[ 3 ], const Float:bsMax[ 3 ] )
{
	new Float:flExt[ 6 ]
	new iPlace = -1

	for ( new i = 0; i < ArraySize( g_aAreaExtents ); i++ )
	{
		ArrayGetArray( g_aAreaExtents, i, flExt )
	
		// Bounding-box intersection test
		if ( 	bsMax[ 0 ] >= flExt[ 0 ] &&
			bsMin[ 0 ] <= flExt[ 3 ] &&
			bsMax[ 1 ] >= flExt[ 1 ] &&
			bsMin[ 1 ] <= flExt[ 4 ] &&
			bsMax[ 2 ] >= flExt[ 2 ] &&
			bsMin[ 2 ] <= flExt[ 5 ] )
		{
			// Add area index
			ArrayPushCell( g_aBombsiteAreas[ iSite ], i )
			
			iPlace = ArrayGetCell( g_aAreaPlaceEntry, i )
		}
	}
	
	if ( iPlace <= 0 )
		return
	
	
	// --- SECOND PASS: add areas with the same place ID ---
	for ( new j = 0; j < ArraySize( g_aAreaID ); j++ )
	{
		new bool:bFound = false
		for( new e = 0; e < ArraySize( g_aBombsiteAreas[ iSite ] ); e++ ) 
		{
			if ( ArrayGetCell( g_aBombsiteAreas[ iSite ], e ) == j )
			{
				bFound = true
				break
			}
		}
		
		if ( bFound ) continue
		
		if ( ArrayGetCell( g_aAreaPlaceEntry, j ) == iPlace )
			ArrayPushCell( g_aBombsiteAreas[ iSite ], j )
	}
}

Nav_EstablishBombAreas()
{
	new const szBombClasses[][] = 
	{ 
		"info_bomb_target",
		"func_bomb_target"
	}

	new iEnt = -1
	new iSite = -1

	for ( new c = 0; c < sizeof szBombClasses; c++ )
	{
		iEnt = -1
	
		while ( ( iEnt = engfunc( EngFunc_FindEntityByString, iEnt, "classname", szBombClasses[ c ] ) ) )
		{
			new Float:flAbsMin[ 3 ], Float:flAbsMax[ 3 ]
			pev( iEnt, pev_absmin, flAbsMin )
			pev( iEnt, pev_absmax, flAbsMax )
	
			new iBombArea = Nav_FindAreaByBounds( flAbsMin, flAbsMax )
			if ( iBombArea == -1 ) continue
	
			new iPlace = ArrayGetCell( g_aAreaPlaceEntry, iBombArea )
			new szPlace[ 32 ]
			
			if ( iPlace > 0 )
				ArrayGetString( g_aPlaceNames, iPlace - 1, szPlace, charsmax( szPlace ) )
			
			switch ( iSite )
			{
				case -1: iSite = equali( szPlace, "BombsiteA" ) ? 0 : 1
				default: iSite = equali( szPlace, "BombsiteB" ) ? 1 : 0
			}
			
			g_iBombsiteEnt[ iSite ] = iEnt
		
			Nav_AssignBombsiteAreas( iSite, flAbsMin, flAbsMax )
	
			#if defined DEBUG_NAV
			server_print
			(
				"[NAV] Bombsite %c detected at area %d (Place %d: %s)",
				'A' + iSite,
				iBombArea,
				iPlace,
				szPlace
			)
			
			server_print
			(
				"[NAV] Bombsite %c contains %d NAV areas",
				'A' + iSite,
				ArraySize( g_aBombsiteAreas[ iSite ] )
			)
			#endif
		}
	}
}

Nav_FilterSpawnableAreas()
{
	ArrayClear( g_aAreaSpawnable )
	
	for ( new i = 0; i < ArraySize( g_aAreaAttrs ); i++ )
	{
		new iAttrs = ArrayGetCell( g_aAreaAttrs, i )
	
		new bool:bSpawnable = true
	
		enum
		{
			NAV_CROUCH = (1 << 0), // must crouch to use this area
			NAV_JUMP = (1 << 1), // must jump to traverse this area
			NAV_PRECISE = (1 << 2)  // tight movement, no obstacle adjustment
		}
	
		const NAV_SPAWN_BLOCK_MASK = ( NAV_CROUCH | NAV_JUMP | NAV_PRECISE )
	
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
			
			if ( flWidth < 32.0 || flDepth < 32.0 )
			{
				bSpawnable = false
			}
		}
		ArrayPushCell( g_aAreaSpawnable, bSpawnable )
	}
	
	#if defined DEBUG_NAV
	server_print
	(
		"[NAV] Spawnable areas: %d / %d",
		Nav_CountSpawnableAreas(),
		ArraySize( g_aAreaSpawnable )
	)
	#endif
}

Nav_Clear()
{
	if ( g_aPlaceNames 	) ArrayDestroy( g_aPlaceNames 		)
	if ( g_aAreaID 		) ArrayDestroy( g_aAreaID 		)
	if ( g_aAreaAttrs 	) ArrayDestroy( g_aAreaAttrs 		)
	if ( g_aAreaExtents 	) ArrayDestroy( g_aAreaExtents 		)
	if ( g_aAreaPlaceEntry 	) ArrayDestroy( g_aAreaPlaceEntry 	)
	if ( g_aAreaSpawnable 	) ArrayDestroy( g_aAreaSpawnable 	)
	if ( g_aSpawnCandidates 	) ArrayDestroy( g_aSpawnCandidates	)
	if ( g_aAreaUsed 	) ArrayDestroy( g_aAreaUsed	 	)
	if (g_aAreaVisible	) ArrayDestroy( g_aAreaVisible 		)


	if ( g_aAdjacency )
	{
		for ( new i = 0; i < ArraySize( g_aAdjacency ); i++ )
		{
			new Array:aNeighbors = ArrayGetCell( g_aAdjacency, i )
			ArrayDestroy( aNeighbors )
		}
	
		ArrayDestroy( g_aAdjacency )
	}
	
	for ( new i = 0; i < 2; i++ )
	{
		if ( g_aBombsiteAreas[ i ] )
			ArrayDestroy( g_aBombsiteAreas[ i ] )

		if ( g_aBombsiteLayers[ i ] )
			ArrayDestroy( g_aBombsiteLayers[ i ] )	
			
		if ( g_aLOSToBombsite[ i ] )
			ArrayDestroy( g_aLOSToBombsite[ i ] )
		
		g_aBombsiteAreas[ i ] = ArrayCreate()
		g_aBombsiteLayers[ i ] = ArrayCreate()
		g_aLOSToBombsite[ i ] = ArrayCreate()
	}
	
	g_aPlaceNames		= ArrayCreate( 32 )
	g_aAreaID		= ArrayCreate()
	g_aAreaAttrs 		= ArrayCreate()
	g_aAreaExtents		= ArrayCreate( 6 )
	g_aTempNeighborIDs 	= ArrayCreate()
	g_aAdjacency		= ArrayCreate()
	g_aAreaPlaceEntry 	= ArrayCreate()
	g_aAreaSpawnable 	= ArrayCreate()
	g_aSpawnCandidates 	= ArrayCreate()
	g_aAreaUsed	 	= ArrayCreate()
	g_aAreaVisible 		= ArrayCreate()
}

Nav_ReadFile( const szFilename[] )
{
	const NAV_MAGIC_NUMBER = 0xFEEDFACE
	const NAV_VERSION = 5 // CS:CZ Version

	Nav_Clear()

	new hFile = fopen( szFilename, "rb" )
	if ( !hFile ) return -2

	new iMagic
	new iVersion
	
	fread( hFile, iMagic, BLOCK_INT )
	if ( iMagic != NAV_MAGIC_NUMBER )
	{
		
		fclose( hFile )
		return -1
	}
	
	fread( hFile, iVersion, BLOCK_INT )
	if ( iVersion != NAV_VERSION )
	{
		fclose( hFile )
		return 0
	}
	
	new iBspSize
	fread( hFile, iBspSize, BLOCK_INT )
	
	new iPlaceCount
	fread( hFile, iPlaceCount, BLOCK_SHORT )
	
	for ( new i = 0; i < iPlaceCount; i++ )
	{
		new iStrLen
		fread( hFile, iStrLen, BLOCK_SHORT )
		
		new szBuffer[ 256 ]
		new iRead = min( iStrLen, charsmax( szBuffer ) )
		
		if ( iRead > 0 )
		{
			fread_blocks( hFile, szBuffer, iRead, BLOCK_CHAR )
			szBuffer[ iRead - 1 ] = 0
		}
		
		if ( iStrLen > iRead )
			fseek( hFile, iStrLen - iRead, SEEK_CUR )
		
		ArrayPushString( g_aPlaceNames, szBuffer )
	}
	
	new iAreaCount
	fread( hFile, iAreaCount, BLOCK_INT )
	
	for ( new i = 0; i < iAreaCount; i++ )
	{
		new iAreaID, iAttrs
		fread( hFile, iAreaID, BLOCK_INT )  // ID
		fread( hFile, iAttrs, BLOCK_CHAR )  // attribute flags
		
		ArrayPushCell( g_aAreaID, iAreaID )
		ArrayPushCell( g_aAreaAttrs, iAttrs )

		new floatBits[ 6 ]
		fread_raw( hFile, floatBits, 6, BLOCK_INT )

		new Float:flAreaExtents[ 6 ]
		for ( new j = 0; j < 6; j++ ) 
			flAreaExtents[ j ] = Float:floatBits[ j ] // re-tag each element
			
		ArrayPushArray( g_aAreaExtents, flAreaExtents )
		
		// Skip NEZ & SWZ
		fseek( hFile, 4, SEEK_CUR )
		fseek( hFile, 4, SEEK_CUR )
		
		// TEMP neighbor ID list
		new Array:aTempIDs = ArrayCreate()
	
		for ( new d = 0; d < 4; d++ )
		{
		    new iConnCount
		    fread( hFile, iConnCount, BLOCK_INT )
	
		    for ( new c = 0; c < iConnCount; c++ )
		    {
			new iNeighborID
			fread( hFile, iNeighborID, BLOCK_INT )
	
			ArrayPushCell( aTempIDs, iNeighborID )
		    }
		}
	
		ArrayPushCell( g_aTempNeighborIDs, aTempIDs )
		
		    /*struct connectionData_t {
			unsigned int count;             4
			unsigned int AreaIDs[ count ];  4
		    }*/


		// Skip rest of area (hides, approaches, encounters)
		
		new iHideCount
		fread( hFile, iHideCount, BLOCK_CHAR )
		iHideCount &= 0xFF
		fseek( hFile, iHideCount * ( 4 + 12 + 1 ), SEEK_CUR )
		
		/*struct hidingSpot_t {
			unsigned int ID;            4
			float position[ 3 ];        4 * 3
			unsigned char Attributes;   1
		}*/
	
		new iApproachCount
		fread( hFile, iApproachCount, BLOCK_CHAR )
		iApproachCount &= 0xFF
		fseek( hFile, iApproachCount * ( 4 + 4 + 1 + 4 + 1 ), SEEK_CUR )
	
		/*struct approachSpot_t {
			uint approachHereId;    4
			uint approachPrevId;    4
			byte approachType;      1
			uint approachNextId;    4
			byte approachHow;       1
		}*/
	
		new iEncCount
		fread( hFile, iEncCount, BLOCK_INT )
		
		for ( new e = 0; e < iEncCount; e++ )
		{
			fseek( hFile, 4 + 1 + 4 + 1, SEEK_CUR )
		
			new iSpotCount
			fread( hFile, iSpotCount, BLOCK_CHAR )
			iSpotCount &= 0xFF
			fseek( hFile, iSpotCount * ( 4 + 1 ), SEEK_CUR )
			
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
		
		new iPlaceEntry
		fread( hFile, iPlaceEntry, BLOCK_SHORT )
		ArrayPushCell( g_aAreaPlaceEntry, iPlaceEntry )
	}
	
	fclose( hFile )
	
	// Resolve neighbor IDs -> indices
	Nav_PostLoad()
	
	return 1
}

Nav_PostLoad()
{
	for ( new i = 0; i < ArraySize( g_aAreaID ); i++ )
	{
		new Array:aNeighbors = ArrayCreate()
	
		new Array:aTempIDs = ArrayGetCell( g_aTempNeighborIDs, i )
	
		for ( new t = 0; t < ArraySize( aTempIDs ); t++ )
		{
			new iNeighborID = ArrayGetCell( aTempIDs, t )
			new iIndex = Nav_FindAreaIndexByID( iNeighborID )
		
			if ( iIndex != -1 )
			ArrayPushCell( aNeighbors, iIndex )
		}
		
		ArrayPushCell( g_aAdjacency, aNeighbors )
	}
	
	// Destroy temp ID lists
	for ( new i = 0; i < ArraySize( g_aTempNeighborIDs ); i++ )
	{
		new Array:aTemp = ArrayGetCell( g_aTempNeighborIDs, i )
		ArrayDestroy( aTemp )
	}
	
	ArrayDestroy( g_aTempNeighborIDs )
}

// Helpers

bool:Nav_AreaInAnyLayer( Array:aLayers, iArea )
{
    for ( new d = 0; d < ArraySize( aLayers ); d++ )
    {
        new Array:aLayer = ArrayGetCell( aLayers, d )

        for ( new i = 0; i < ArraySize( aLayer ); i++ )
        {
            if ( ArrayGetCell( aLayer, i ) == iArea )
                return true
        }
    }
    return false
}

bool:Nav_ArrayContains( Array:aArray, value )
{
    for ( new i = 0; i < ArraySize( aArray ); i++ )
    {
        if ( ArrayGetCell( aArray, i ) == value )
            return true
    }
    return false
}

Nav_FindAreaIndexByID( iAreaID )
{
    for ( new i = 0; i < ArraySize( g_aAreaID ); i++ )
    {
        if ( ArrayGetCell( g_aAreaID, i ) == iAreaID )
            return i
    }
    return -1
}

Nav_CountSpawnableAreas()
{
    new count = 0

    for ( new i = 0; i < ArraySize( g_aAreaSpawnable ); i++ )
    {
        if ( ArrayGetCell( g_aAreaSpawnable, i ) )
            count++
    }

    return count
}

Nav_FindAreaByBounds( const Float:flMin[ 3 ], const Float:flMax[ 3 ] )
{
	new Float:flExt[ 6 ]
	
	for ( new i = 0; i < ArraySize( g_aAreaExtents ); i++ )
	{
		ArrayGetArray( g_aAreaExtents, i, flExt )
		if ( 	flMax[ 0 ] >= flExt[ 0 ] &&
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

bool:Nav_HasLineOfSight( const Float:from[ 3 ], const Float:to[ 3 ] )
{
    new tr = create_tr2()

    engfunc( EngFunc_TraceLine, from, to, IGNORE_MONSTERS, 0, tr )

    new Float:fraction
    get_tr2( tr, TR_flFraction, fraction )

    free_tr2( tr )

    return ( fraction >= 0.9999 )
}

Nav_AreaCenter( iArea, Float:out[ 3 ] )
{
    new Float:ext[ 6 ]
    ArrayGetArray( g_aAreaExtents, iArea, ext )

    out[ 0 ] = ( ext[ 0 ] + ext[ 3 ] ) * 0.5
    out[ 1 ] = ( ext[ 1 ] + ext[ 4 ] ) * 0.5
    out[ 2 ] =   ext[ 2 ] + 16.0
}

bool:Nav_AreaLOS_Multi( iFrom, iTo )
{
    new Float:baseFrom[ 3 ], Float:baseTo[ 3 ]
    Nav_AreaCenter( iFrom, baseFrom )
    Nav_AreaCenter( iTo, baseTo )
    
    const Float:OFFSET = 32.0

    // 5-sample pattern: center + 4 edges
    new Float:offsets[ 5 ][ 3 ] =
    {
        {  0.0,     0.0,     0.0 },
        {  OFFSET,  0.0,     0.0 },
        { -OFFSET,  0.0,     0.0 },
        {  0.0,     OFFSET,  0.0 },
        {  0.0,    -OFFSET,  0.0 }
    }

    new Float:from[ 3 ], Float:to[ 3 ]

    for ( new i = 0; i < sizeof offsets; i++ )
    {
        xs_vec_add( baseFrom, offsets[ i ], from )
        xs_vec_add( baseTo, offsets[ i ], to )

        if ( Nav_HasLineOfSight( from, to ) )
            return true
    }

    return false
}

Nav_ResetAreaUsed()
{
    ArrayClear( g_aAreaUsed )

    new iCount = ArraySize( g_aAreaID )
    for ( new i = 0; i < iCount; i++ )
	ArrayPushCell( g_aAreaUsed, 0 )
}

Nav_MarkAreaUsed( iArea )
{
    ArraySetCell( g_aAreaUsed, iArea, 1 )
}

Nav_FindFirstValidLayer( iSite )
{
    new iLayerCount = ArraySize( g_aBombsiteLayers[ iSite ] )

    for ( new iLayer = random_num(4,5); iLayer < iLayerCount; iLayer++ )
    {
        Nav_BuildLayerSpawnCandidates( iSite, iLayer )

        if ( ArraySize( g_aSpawnCandidates ) > 0 )
            return iLayer
    }

    return -1
}

Nav_ResetSpawnVisibility()
{
    ArrayClear( g_aAreaVisible )

    new count = ArraySize( g_aAreaExtents )
    for ( new i = 0; i < count; i++ )
        ArrayPushCell( g_aAreaVisible, false )
}

Nav_MarkSpawnVisibility( iAreaUsed )
{
    new iAreaCount = ArraySize( g_aAreaExtents )

    for ( new i = 0; i < iAreaCount; i++ )
    {
        if ( Nav_AreaLOS_Multi( i, iAreaUsed ) )
            ArraySetCell( g_aAreaVisible, i, true )
    }
}

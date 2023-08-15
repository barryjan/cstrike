#include < amxmodx >
#include < amxmisc >

#define TASKID_SENDAUDIO 23532

enum
{
	MRAD_NONE = 0,
	MRAD_TERWIN,
	MRAD_CTWIN,
	MRAD_GO,
	MRAD_LETSGO,
	MRAD_LOCKNLOAD,
	MRAD_MOVEOUT,
	MRAD_BOMBPL,
	MRAD_BOMBDEF,
	MRAD_ELIM,
	MRAD_STORMFRONT,
	MRAD_STICKTOG,
	MRAD_REGROUP,
	MRAD_REPORTIN,
	MRAD_CLEAR,
	MRAD_POSITION,
	MRAD_BACKUP,
	MRAD_BLOW
}

static const g_szAudioList[][] = 
{
	"",
	"%!MRAD_terwin",
	"%!MRAD_ctwin",
	"%!MRAD_GO",
	"%!MRAD_LETSGO",
	"%!MRAD_LOCKNLOAD",
	"%!MRAD_MOVEOUT",
	"%!MRAD_BOMBPL",
	"%!MRAD_BOMBDEF",
	"%!MRAD_ELIM",
	"%!MRAD_STORMFRONT",
	"%!MRAD_STICKTOG",
	"%!MRAD_REGROUP",
	"%!MRAD_REPORTIN",
	"%!MRAD_CLEAR",
	"%!MRAD_POSITION",
	"%!MRAD_BACKUP",
	"%!MRAD_BLOW"
}

new g_iMsgId_SendAudio
new g_iScoreTally[ 3 ]
new Float:g_flBombDefuseTime
new Float:g_flStartRoundTime
new g_pCvar_c4timer

public plugin_init() 
{
	register_plugin
	(
		.plugin_name 	= "Active Radio",
		.version	= "1.0",
		.author 	= "BARRY."
	)

	g_iMsgId_SendAudio = get_user_msgid( "SendAudio" )
	
	register_message( g_iMsgId_SendAudio, "message_SendAudio" )
	
	register_event( "TeamScore", "event_TeamScore", "a" )
	register_event( "TextMsg", "event_TextMsgReset", "a", 
			"2=#Game_will_restart_in", 
			"2=#Game_Commencing" )
	register_event( "HLTV", "event_NewRound", "a", "1=0", "2=0" )
	
	register_logevent( "logevent_RoundStart", 2, "1=Round_Start" ) 
			
	g_pCvar_c4timer = get_cvar_pointer( "mp_c4timer" )
}

public event_TextMsgReset()
{
	g_iScoreTally[ 1 ] = 0
	g_iScoreTally[ 2 ] = 0
}

public event_NewRound()
{
	new iPlayers[ 32 ], iNum
	
	get_players( iPlayers, iNum, "ch" )
	
	for ( new i = 0; i < iNum; i++ )
	{
		remove_task( TASKID_SENDAUDIO + iPlayers[ i ] )
	}
	
	remove_task( TASKID_SENDAUDIO )

	
}

public logevent_RoundStart()
{
	g_flStartRoundTime = get_gametime()
}

public event_TeamScore()
{
	static szTeam[ 2 ]
	
	read_data( 1, szTeam, 1 )

	switch ( szTeam[ 0 ] )
	{
		case 'T': g_iScoreTally[ 1 ] = read_data( 2 )
		case 'C': g_iScoreTally[ 2 ] = read_data( 2 )
	}
}

public message_SendAudio( iMsgID, iDest, iPlayer )
{
	new szAudio[ 32 ], iAudio, iNewRadio[ 3 ], iParams[ 2 ], iPlayers[ 32 ], iNum, i
	
	get_msg_arg_string( 2, szAudio, charsmax( szAudio ) )

	for ( i = 0; i < sizeof ( g_szAudioList ); i++ )
	{
		if ( equal( szAudio, g_szAudioList[ i ] ) )
		{	
			iAudio = i
			
			break	
		}
	}

	switch ( iAudio )
	{
		case MRAD_TERWIN, MRAD_CTWIN: 
		{
			if ( iAudio == MRAD_CTWIN && g_flBombDefuseTime == get_gametime() )
			{
				set_msg_arg_string( 2, g_szAudioList[ MRAD_BOMBDEF ] )
				
				iParams[ 0 ] = 0
				iParams[ 1 ] = MRAD_CTWIN
				
				remove_task( TASKID_SENDAUDIO )
				remove_task( TASKID_SENDAUDIO + iPlayer )

				set_task( 2.0, "task_SendAudio", TASKID_SENDAUDIO + iPlayer, iParams, sizeof ( iParams ) )
				
				return PLUGIN_CONTINUE
			}
			
			get_players( iPlayers, iNum, "ae", iAudio == MRAD_TERWIN ? "CT" : "TERRORIST" )
			
			if ( iNum < 1 )
			{
				set_msg_arg_string( 2, g_szAudioList[ MRAD_CLEAR ] )
				
				remove_task( TASKID_SENDAUDIO )
				remove_task( TASKID_SENDAUDIO + iPlayer )
				
				iParams[ 0 ] = iPlayer
				iParams[ 1 ] = iAudio
			
				set_task( 2.0, "task_SendAudio", TASKID_SENDAUDIO + iPlayer, iParams, sizeof ( iParams ) )
			}
		}
		case MRAD_GO, MRAD_LETSGO, MRAD_LOCKNLOAD, MRAD_MOVEOUT: 
		{
			if ( iAudio == MRAD_GO && g_flStartRoundTime != get_gametime() )
			{
				return PLUGIN_CONTINUE
			}
			
			const iConsecutiveWins = 3
			
			if ( g_iScoreTally[ 1 ] >= ( g_iScoreTally[ 2 ] + iConsecutiveWins ) )
			{
				iNewRadio[ 0 ] = 1
				iNewRadio[ 1 ] = random_num( 0, 1 ) == 1 ? MRAD_ELIM : MRAD_STORMFRONT
				iNewRadio[ 2 ] = random_num( 0, 1 ) == 1 ? MRAD_STICKTOG : MRAD_REGROUP
			}
			else if ( g_iScoreTally[ 2 ] >= ( g_iScoreTally[ 1 ] + iConsecutiveWins ) )
			{
				iNewRadio[ 0 ] = 1
				iNewRadio[ 1 ] = random_num( 0, 1 ) == 1 ? MRAD_STICKTOG : MRAD_REGROUP
				iNewRadio[ 2 ] = random_num( 0, 1 ) == 1 ? MRAD_ELIM : MRAD_STORMFRONT 
			}
		}
		case MRAD_BOMBPL: 
		{
			get_players( iPlayers, iNum, "ch" )
			
			for ( i = 0; i < iNum; i++ )
			{
				iPlayer = iPlayers[ i ]
		
				remove_task( TASKID_SENDAUDIO + iPlayer )
				
				iNewRadio[ 1 ] = random_num( 0, 1 ) == 1 ? MRAD_POSITION : MRAD_BACKUP
				iNewRadio[ 2 ] = random_num( 0, 1 ) == 1 ? MRAD_ELIM : MRAD_REGROUP
				
				iParams[ 0 ] = iPlayer
				iParams[ 1 ] = iNewRadio[ get_user_team( iPlayer ) ]
			
				set_task( 2.0, "task_SendAudio", TASKID_SENDAUDIO + iPlayer, iParams, sizeof ( iParams ) )
			}
			
			new Float:flC4timer = float( get_pcvar_num( g_pCvar_c4timer ) - 5 )
			
			iParams[ 0 ] = 0
			iParams[ 1 ] = MRAD_BLOW
				
			set_task( flC4timer, "task_SendAudio", TASKID_SENDAUDIO, iParams, sizeof ( iParams ) )
		}
		case MRAD_BOMBDEF:
		{
			g_flBombDefuseTime = get_gametime()
		}
		case MRAD_NONE: {}
	}
	
	if ( iNewRadio[ 0 ] )
	{
		set_msg_arg_string( 2 , g_szAudioList[ iNewRadio[ get_user_team( iPlayer ) ] ] )
	}
	return PLUGIN_CONTINUE
}

public task_SendAudio( iParams[] )
{
	new id = iParams[ 0 ]
	new iAudioCode = iParams[ 1 ]

	message_begin( is_user_connected( id ) ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, 
	g_iMsgId_SendAudio, _, is_user_connected( id ) ? id : 0 )
	write_byte( 0 )
	write_string( g_szAudioList[ iAudioCode ] )
	write_short( 100 )
	message_end()
}

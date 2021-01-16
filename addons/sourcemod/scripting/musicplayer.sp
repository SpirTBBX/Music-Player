#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "SpirT"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

char musicStyleConfigDir[256];
char musicStyleConfigFile[256];
char styleCfgFile[64][64];
char styleName[64][64];
char playingSong[MAXPLAYERS + 1][128];

bool musicPlaying[MAXPLAYERS + 1];

char playerVolume[MAXPLAYERS + 1][5];

Handle volumeCookie;

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[SpirT] Music and Sound Player",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	BuildPath(Path_SM, musicStyleConfigDir, sizeof(musicStyleConfigDir), "configs/SpirT/Music-Player/");
	BuildPath(Path_SM, musicStyleConfigFile, sizeof(musicStyleConfigFile), "configs/SpirT/Music-Player/music-styles.txt");
	
	if(!DirExists(musicStyleConfigDir))
	{
		SetFailState("Could not find config file directory \"%s\"", musicStyleConfigDir);
	}
	else
	{
		if(!FileExists(musicStyleConfigFile))
		{
			SetFailState("Could not find config file \"%s\"", musicStyleConfigFile);
		}
	}
	
	volumeCookie = RegClientCookie("spirt_player_volume", "Player Volume", CookieAccess_Public);
	RegConsoleCmd("sm_music", Command_Music);
	RegConsoleCmd("sm_stop", Command_StopMusic);
	RegConsoleCmd("sm_playervol", Command_PlayerVol);
	
	//Just to keep the cookies information up to date
	for (int i = 1; i < MaxClients; i++)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }
        
        OnClientCookiesCached(i);
    }
}

public Action Command_Music(int client, int args)
{
	if(!IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	if(musicPlaying[client])
	{
		PrintToChat(client, "[SpirT - MUSIC PLAYER] You already have a music already playing. Please use !stop to stop the current playing song.");
		return Plugin_Handled;
	}
	
	StylesMenu(client);
	return Plugin_Handled;
}

Menu StylesMenu(int client)
{
	Menu menu = new Menu(StylesHandle, MENU_ACTIONS_ALL);
	menu.SetTitle("Music Styles");
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	
	int menuIndex;
	
	KeyValues kv = new KeyValues("MusicStyles");
	kv.ImportFromFile(musicStyleConfigFile);
	
	if(!kv.GotoFirstSubKey())
	{
		delete kv;
	}
	
	menuIndex = 0;
	char sectionBuffer[64];
	do
	{
		kv.GetSectionName(sectionBuffer, sizeof(sectionBuffer));
		KvGetString(kv, "cfgfile", styleCfgFile[menuIndex], sizeof(styleCfgFile[]));
		//PrintToChat(client, "For %s, the config file is %s", sectionBuffer, styleCfgFile[menuIndex]);
		styleName[menuIndex] = sectionBuffer;
		menuIndex++;
		AddMenuItem(menu, sectionBuffer, sectionBuffer);
	} while (kv.GotoNextKey());
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return menu;
}

public int StylesHandle(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char choice[64];
		menu.GetItem(item, choice, sizeof(choice));
		
		KeyValues kv = new KeyValues("MusicStyles");
		kv.ImportFromFile(musicStyleConfigFile);
	
		if (kv.JumpToKey(choice))
		{
			for (int x = 0; x < MaxClients; x++)
			{
				if(StrEqual(choice, styleName[x]))
				{
					kv.JumpToKey(styleName[x]);
					KvGetString(kv, "cfgFile", styleCfgFile[x], sizeof(styleCfgFile[]));
					char styleMusicListFile[256];
					BuildPath(Path_SM, styleMusicListFile, sizeof(styleMusicListFile), "configs/SpirT/Music-Player/%s", styleCfgFile[x]);
					CreateMusicsMenu(client, styleMusicListFile, x);
				}
			}
		}
		
		delete kv;
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

Menu CreateMusicsMenu(int client, const char[] musicListFile, int index)
{
	Menu menu = new Menu(MusicsHandle, MENU_ACTIONS_ALL);
	
	char menuTitle[128];
	Format(menuTitle, sizeof(menuTitle), "Select a Music - %s", styleName[index]);
	menu.SetTitle(menuTitle);
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
		
	KeyValues kv = new KeyValues(styleName[index]);
	kv.ImportFromFile(musicListFile);
	
	if(!kv.GotoFirstSubKey())
	{
		delete kv;
	}
	
	char sectionBuffer[64];
	do
	{
		kv.GetSectionName(sectionBuffer, sizeof(sectionBuffer));
		AddMenuItem(menu, sectionBuffer, sectionBuffer);
	} while (kv.GotoNextKey());
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return menu;
}

public int MusicsHandle(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char menuTitle[128], kvHandle[128];
		GetMenuTitle(menu, menuTitle, sizeof(menuTitle));
		strcopy(kvHandle, sizeof(kvHandle), menuTitle);
		ReplaceString(kvHandle, sizeof(kvHandle), "Select a Music - ", "");
		
		char choice[64];
		menu.GetItem(item, choice, sizeof(choice));
		
		KeyValues kv = new KeyValues(kvHandle);
		kv.ImportFromFile(musicStyleConfigFile);
		
		kv.JumpToKey(kvHandle);
		char currentFile[64];
		KvGetString(kv, "cfgfile", currentFile, sizeof(currentFile));
		
		char fullPath[256];
		BuildPath(Path_SM, fullPath, sizeof(fullPath), "configs/SpirT/Music-Player/%s", currentFile);
		
		KeyValues kvMusic = new KeyValues(kvHandle);
		kvMusic.ImportFromFile(fullPath);
		
		if(!kvMusic.GotoFirstSubKey())
		{
			delete kvMusic;
		}
		do
		{
			char sectionName[64];
			KvGetSectionName(kvMusic, sectionName, sizeof(sectionName));
			if(StrEqual(sectionName, choice))
			{
				char selectedSong[128];
				KvGetString(kvMusic, "file", selectedSong, sizeof(selectedSong));
				char songPath[256];
				Format(songPath, sizeof(songPath), "sound/SpirT/%s", selectedSong);
				if(!FileExists(songPath))
				{
					PrintToChat(client, "[SpirT - MUSIC PLAYER] We're sorry, but the song you're trying to play is misconfigured or the sound file is not available at the server. Please select another song.");
					delete kvMusic;
				}
				else
				{
					char correctSound[128];
					strcopy(correctSound, sizeof(correctSound), songPath);
					ReplaceString(correctSound, sizeof(correctSound), "sound/", "");
					PrecacheSound(correctSound);
					EmitSoundToClient(client, correctSound, -2, 0, 0, 0, StringToFloat(playerVolume[client]), 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
					playingSong[client] = correctSound;
					PrintToChat(client, "[SpirT - MUSIC PLAYER] Playing song: %s", selectedSong);
					musicPlaying[client] = true;
					delete kvMusic;
					delete menu;
				}
			}
		} while (KvGotoNextKey(kvMusic));
		
		delete kv;
	}
}

public Action Command_StopMusic(int client, int args)
{
	if(!musicPlaying[client])
	{
		PrintToChat(client, "[SpirT - MUSIC PLAYER] You are not listening to any song.");
		return Plugin_Handled;
	}
	
	StopSound(client, SNDCHAN_AUTO, playingSong[client]);
	musicPlaying[client] = false;
	char musicFile[128];
	strcopy(musicFile, sizeof(musicFile), playingSong[client]);
	ReplaceString(musicFile, sizeof(musicFile), "SpirT/", "");
	PrintToChat(client, "[SpirT - MUSIC PLAYER] Stopped playing music: %s", musicFile);
	return Plugin_Handled;
}

public Action Command_PlayerVol(int client, int args)
{	
	if(args < 1)
	{
		PrintToChat(client, "[SpirT - MUSIC PLAYER] You forgot to type a volume");
		PrintToChat(client, "[SpirT - MUSIC PLAYER] Use: sm_playervol <volume>");
		return Plugin_Handled;
	}
	
	char cookieValue[5];
	GetCmdArg(1, cookieValue, sizeof(cookieValue));
	
	if(StrEqual(cookieValue, playerVolume[client]))
	{
		PrintToChat(client, "[SpirT - MUSIC PLAYER] You did type the current player volume!");
		return Plugin_Handled;
	}
	
	playerVolume[client] = cookieValue;
	SetClientCookie(client, volumeCookie, playerVolume[client]);
	PrintToChat(client, "[SpirT - MUSIC PLAYER] Player volume has been changed to %s", playerVolume[client]);
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	GetClientCookie(client, volumeCookie, playerVolume[client], sizeof(playerVolume[]));
}
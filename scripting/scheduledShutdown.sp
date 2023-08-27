/* 
*     Scheduled Shutdown/Restart
*     By [BR5DY]
* 
*    This plugin could not have been made without the help of MikeJS's plugin and darklord1474's plugin.
* 
*     Automatically shuts down the server at the specified time, warning all players ahead of time.
*    Will restart automatically if you run some type of server checker or batch script :-)
* 
*     Very basic commands - it issues the "_restart" command to SRCDS at the specified time
* 
*   Cvars:
*    sm_scheduledshutdown_hintsay 1        // Sets whether messages are shown in the hint area
*    sm_scheduledshutdown_chatsay  1        // Sets whether messages are shown in chat
*    sm_scheduledshutdown_centersay 1    // Sets whether messages are shown in the center of the screen
*    sm_scheduledshutdown_time 05:00        // Sets the time to shutdown the server
*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#define PLUGIN_VERSION "1.2"
#define CVAR_FLAGS    FCVAR_NOTIFY

ConVar g_hEnabled = null;
ConVar g_hTime = null;
ConVar g_cShutdownTime;
ConVar g_cEnableRoundEnd;

bool g_bEnabled;
bool g_bCancelShutdown;
bool g_bDuringShutdown;
bool g_bEnableRoundEndShutdown;
bool g_bShutdownOnRoundEnd;
int g_iShutdown;
int g_iShutdownTime;
int g_iTime;

Handle h_ShutdownTimer;

public Plugin myinfo = 
{
    name = "ScheduledShutdown",
    author = "BR5DY, Dosergen, faketuna",
    description = "Shutsdown SRCDS (with options). Special thanks to MikeJS and darklord1474.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=161932"
};

public void OnPluginStart() 
{
    PrintToServer("ScheduledShutdown loaded successfully.");
    
    CreateConVar("sm_scheduledshutdown_version", PLUGIN_VERSION, "ScheduledShutdown version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
    g_hEnabled = CreateConVar("sm_scheduledshutdown", "1", "Enable ScheduledShutdown.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hTime = CreateConVar("sm_scheduledshutdown_time", "05:00", "Time to shutdown server.", CVAR_FLAGS);
    g_cShutdownTime = CreateConVar("sm_scheduledshutdown_seconds", "30", "How long to take shutdown in seconds.", CVAR_FLAGS, true, 0.0, true, 100.0);
    g_cEnableRoundEnd = CreateConVar("sm_scheduledshutdown_round_end", "1", "Shutdown in end round instead of countdown.", CVAR_FLAGS, true, 0.0, true, 1.0);
    
    LoadTranslations("scheduledshutodwn.phrases");
    AutoExecConfig(true, "ScheduledShutdown");
    
    GetCvars();

    RegAdminCmd("sm_cancel_shutdown", CommandCancelShutdown, ADMFLAG_RCON, "Cancel the scheduled shutdown.");
    RegAdminCmd("sm_start_shutdown", CommandStartShutdown, ADMFLAG_RCON, "Start the countdowned shutdown.");

    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);

    g_cShutdownTime.AddChangeHook(ConVarChanged_Cvars);
    g_hEnabled.AddChangeHook(ConVarChanged_Cvars);
    g_hTime.AddChangeHook(ConVarChanged_Cvars);
    g_cEnableRoundEnd.AddChangeHook(ConVarChanged_Cvars);
}

public void OnConfigsExecuted()
{
    GetCvars();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

void GetCvars()
{
    char iTime[8];
    GetConVarString(g_hTime, iTime, sizeof(iTime));
    g_iTime = StringToInt(iTime);
    
    g_bEnabled = g_hEnabled.BoolValue;
    g_iShutdownTime = g_cShutdownTime.IntValue;
    g_bEnableRoundEndShutdown = g_cEnableRoundEnd.BoolValue;
}

public void OnMapStart()
{
    CreateTimer(60.0, CheckTime, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    if(g_bShutdownOnRoundEnd) {
        LogAction(0, -1, "Server shutdown.");
        ServerCommand("quit");
    }
}

public Action CheckTime(Handle timer, any useless)
{
    if (g_bEnabled)
    {
        int gettime = GetTime();

        char strtime[8];
        FormatTime(strtime, sizeof(strtime), "%H:%M", gettime);
        gettime -= (StringToInt(strtime) / 100) * 3600;
        
        int time = StringToInt(strtime);
        if (time >= g_iTime && time <= g_iTime)
        {
            if (g_bEnableRoundEndShutdown) {
                DisplayTranslatedHTMLHud(5, "shutdown in round end");
                g_bShutdownOnRoundEnd = true;
                return Plugin_Handled;
            }

            LogAction(0, -1, "Server shutdown warning.");
            g_iShutdown = g_iShutdownTime;

            h_ShutdownTimer = CreateTimer(1.0, ShutdownCountdown, _, TIMER_REPEAT);
            
        }
    }
    
    return Plugin_Stop;
}

public Action ShutdownCountdown(Handle timer) {
    if (g_bCancelShutdown) {
        CPrintToChatAll("[SM] Shutdown cancelled.");
        g_bCancelShutdown = false;
        KillTimer(h_ShutdownTimer);
        h_ShutdownTimer = null;
        g_bDuringShutdown = false;
        return Plugin_Stop;
    }
    if (!g_bDuringShutdown) {
        DisplayTranslatedCountdownHTMLHud(5, "shutdown in seconds", g_iShutdown);
        g_bDuringShutdown = true;
        LogAction(0, -1, "Server shutdown countdown started.");
    }
    if (g_iShutdown <= 30 && g_iShutdown > 5) {
        DisplayTranslatedCountdownHTMLHud(1, "shutdown in seconds", g_iShutdown);
    }
    if (g_iShutdown <= 5 && g_iShutdown > 0) {
        DisplayTranslatedCountdownHTMLHud(1, "shutdown in seconds", g_iShutdown);
    }
    g_iShutdown--;
    if (g_iShutdown <= 0) {
        LogAction(0, -1, "Server shutdown.");
        ServerCommand("quit");
        KillTimer(h_ShutdownTimer);
        h_ShutdownTimer = null;
        g_bDuringShutdown = false;
        return Plugin_Stop;
    }
    return Plugin_Handled;
}

public Action CommandCancelShutdown(int client, int args) {
    if (g_bShutdownOnRoundEnd) {
        g_bShutdownOnRoundEnd = false;
        CReplyToCommand(client, "[SM] Shutdown cancelled.");
        return Plugin_Handled;
    }
    if (!g_bDuringShutdown) {
        CReplyToCommand(client, "[SM] There is no ongoing shutdown process!");
        return Plugin_Handled;
    }
    CReplyToCommand(client, "[SM] Cancelling shutdown...");
    g_bCancelShutdown = true;
    return Plugin_Handled;
}

public Action CommandStartShutdown(int client, int args) {
    if (g_bDuringShutdown || g_bShutdownOnRoundEnd) {
        CReplyToCommand(client, "[SM] Shutdown in process!");
        return Plugin_Handled;
    }
    if (args == 0) {
        CReplyToCommand(client, "[SM] Starting shutdown...");
        DisplayTranslatedHTMLHud(5, "shutdown in round end");
        g_bShutdownOnRoundEnd = true;
    }

    if (args == 1) {
        
        CReplyToCommand(client, "[SM] Starting shutdown...");
        g_iShutdown = GetCmdArgInt(1);
        h_ShutdownTimer = CreateTimer(1.0, ShutdownCountdown, _, TIMER_REPEAT);
    }


    return Plugin_Handled;
}

public void DisplayTranslatedHTMLHud(int holdTime, const char[] translationKey) {
    for (int i = 1; i < MAXPLAYERS; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)){
            SetGlobalTransTarget(i);
            showHTMLHudMessage(i, holdTime, "%t", translationKey);
        }
    }
}

public void DisplayTranslatedCountdownHTMLHud(int holdTime, const char[] translationKey, int seconds) {
    char buffer[2048];
    for (int i = 1; i < MAXPLAYERS; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)){
            SetGlobalTransTarget(i);
            Format(buffer, sizeof(buffer), "%T", "shutdown in seconds", i, seconds);
            showHTMLHudMessage(i, holdTime, buffer);
        }
    }
}

void showHTMLHudMessage(const int client, int holdTime, const char[] message, any ...) {
    char buffer[2048];
    VFormat(buffer, sizeof(buffer), message, 4);
    Event hud = CreateEvent("show_survival_respawn_status", true);

    if(hud != null)
    {
        hud.SetInt("duration", holdTime);
        hud.SetInt("userid", -1);
        hud.SetString("loc_token", buffer);
        SetGlobalTransTarget(client);
        hud.FireToClient(client);

        hud.Cancel();
    }
}
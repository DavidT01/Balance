#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta>
#include <reapi>

#define PLUGIN "ReBalance"
#define VERSION "1.0"
#define AUTHOR "treachery, fckn A."

#define UNASSIGNED	 	0
#define TS 			1
#define CTS			2
#define SPEC                    3
#define AUTO_TEAM 		5
#define UNDEFINED               6

#define AUTO_TEAM_JOIN_DELAY 0.1
#define TEAM_SELECT_VGUI_MENU_ID 2

enum Player {
	kills,
	deaths,
	team,
	score
}

new Players[33][Player]
new canSwitchTeam[33], playerImm[33]
new numCTS, numTS

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	//register_event("SendAudio","roundEnd","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw") // Round End
	register_event("HLTV", "new_round", "a", "1=0", "2=0"); // Round Start
	register_event("TeamInfo", "updateTeam", "a"); // Team Change
	register_event("DeathMsg", "onDeath", "a"); // Player Death
	
	//RegisterHam(Ham_Spawn, "player", "onSpawn", 1); // Player Spawn
	
	// Default Menus
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	RegisterHookChain(RG_ShowMenu, "OldMenuHook");
	RegisterHookChain(RG_ShowVGUIMenu, "VGUIMenuHook");
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "jointeamHook");
	RegisterHookChain(RG_HandleMenu_ChooseAppearance, "joinclassHook");
	
	register_clcmd("chooseteam", "blockChooseteam");
	
	register_clcmd("amx_transfer", "transferCmd");
	
	for(new i = 0; i < 33; i++) {
		playerSetData(i, 0, 0, UNDEFINED, 0);
		canSwitchTeam[i] = 1;
		playerImm[i] = 0;
	}
	numCTS = 0;
	numTS = 0;
}

public blockChooseteam(id){
	if(canSwitchTeam[id] == 0){
		client_printc(id, "!gMenjanje tima je zabranjeno.");
		return PLUGIN_HANDLED;
	}
	else return PLUGIN_CONTINUE;
}

public transferCmd(id){
	new ac = read_argc();
	if(ac != 2){
		client_print(id, print_console, "Greska.");
		return PLUGIN_HANDLED;
	}
	new argv[32], arg;
	read_argv(1, argv, sizeof(argv));
	arg = str_to_num(argv);
	if(arg > 0 && arg < 4){
		change_player_team(id, arg);
		return PLUGIN_HANDLED;
	}
	else {
		client_print(id, print_console, "Greska.");
		return PLUGIN_HANDLED;
	}
}

public OldMenuHook(id, const bitsSlots, const iDisplayTime, const iNeedMore, pszText[]){
	if(containi(pszText, "Team") != -1 || containi(pszText, "Select") != -1){
		if(playerImm[id] == 0 && canSwitchTeam[id] == 0){
			client_printc(id, "!gMenjanje tima je zabranjeno.");
			menu_cancel(id);
			return HC_SUPERCEDE;
		}
		else if(playerImm[id] == 0 && canSwitchTeam[id] == 1){
			return HC_CONTINUE;
		}
		else {
			if(canSwitchTeam[id] == 0){
				client_printc(id, "!gMenjanje tima je zabranjeno.");
				menu_cancel(id);
				return HC_SUPERCEDE;
			}
			else return HC_CONTINUE;
		}
	}
	else return HC_CONTINUE;
}

public VGUIMenuHook(id, VGUIMenu:menuType){
	if(menuType != VGUIMenu:TEAM_SELECT_VGUI_MENU_ID)
		return HC_CONTINUE;
	if(playerImm[id] == 0  && canSwitchTeam[id] == 0){
		client_printc(id, "!gMenjanje tima je zabranjeno.");
		return HC_SUPERCEDE;
	}
	else if(playerImm[id] == 0 && canSwitchTeam[id] == 1){
		return HC_CONTINUE;
	}
	else {
		if(canSwitchTeam[id] == 0){
			client_printc(id, "!gMenjanje tima je zabranjeno.");
			return HC_SUPERCEDE;
		}
		else return HC_CONTINUE;
	}
}

public jointeamHook(id){
	if(playerImm[id] == 0 && canSwitchTeam[id] == 0){
		client_printc(id, "!gMenjanje tima je zabranjeno.");
		return HC_SUPERCEDE;
	}
	else if(playerImm[id] == 0 && canSwitchTeam[id] == 1){
		return HC_CONTINUE;
	}
	else {
		if(canSwitchTeam[id] == 0){
			client_printc(id, "!gMenjanje tima je zabranjeno.");
			return HC_SUPERCEDE;
		}
		else return HC_CONTINUE;
	}
}

public joinclassHook(id){
	if(playerImm[id] == 0 && canSwitchTeam[id] == 0){
		client_printc(id, "!gMenjanje tima je zabranjeno.");
		return HC_SUPERCEDE;
	}
	else if(playerImm[id] == 0 && canSwitchTeam[id] == 1){
		canSwitchTeam[id] = 0;
		return HC_CONTINUE;
	}
	else {
		if(canSwitchTeam[id] == 0){
			client_printc(id, "!gMenjanje tima je zabranjeno.");
			return HC_SUPERCEDE;
		}
		else {
			//client_printc(id, "!gIzabrao si tim.");
			canSwitchTeam[id] = 0;
			return HC_CONTINUE;
		}
	}
}

public onDeath() {
	new killer = read_data(1);
	new victim = read_data(2);

	if (killer > 0 && killer <= 32 && killer != victim)
		Players[killer][kills]++;

	if (victim > 0 && victim <= 32)
		Players[victim][deaths]++;
}

public onSpawn(id) {
	//canSwitchTeam[id] = 1;
	return HAM_IGNORED;
}

public new_round() {
	for(new i = 1; i < 33; i++)
		if(playerImm[i] == 1)
			canSwitchTeam[i] = 1;
	client_print(0, print_chat, "CTS: %d,  TS: %d", numCTS, numTS);
}

public updateTeam() {
	new id = read_data(1)
	new teamStr[2];
	read_data(2, teamStr, charsmax(teamStr));
	
	client_print(id, print_chat, "%s", teamStr);
	
	if(Players[id][team] == TS)
		numTS--;
	else if(Players[id][team] == CTS)
		numCTS--;
	switch(teamStr[0]) {
		case 'T': Players[id][team] = TS;
		case 'C': Players[id][team] = CTS;
		case 'S': Players[id][team] = SPEC;
		default: Players[id][team] = UNASSIGNED;
	}
	if(Players[id][team] == TS)
		numTS++;
	else if(Players[id][team] == CTS)
		numCTS++;
}

public roundEnd() {
	for(new i = 0; i < 33; i++)
		if(is_user_connected(i))
			client_print(i, print_chat, "[%d] kills: %d,  deaths: %d", i, Players[i][kills], Players[i][deaths]);
}

public playerSetData(id, k, d, t, s) {
	Players[id][kills] = k;
	Players[id][deaths] = d;
	Players[id][team] = t;
	Players[id][score] = s;
}

public client_authorized(id) {
	playerSetData(id, 0, 0, UNASSIGNED, 0);
	canSwitchTeam[id] = 1;
	if(flagCheck(id, "a"))
		playerImm[id] = 1;
}

public client_disconnected(id) {
	if(Players[id][team] == CTS)
		numCTS--;
	else if(Players[id][team] == TS)
		numTS--;
	playerSetData(id, 0, 0, UNDEFINED, 0);
	canSwitchTeam[id] = 1;
	playerImm[id] = 0;
}

public client_death(killer, victim, wpnindex) {
	if(wpnindex == 6) {
		new killerName[32], victimName[32];
		get_user_name(killer, killerName, 32);
		get_user_name(victim, victimName, 32);
		
		//client_print(0, print_chat, "killer: [%d] %s, victim: [%d] %s", killer, killerName, victim, victimName);
		
		if (killer > 0 && killer <= 32 && killer != victim)
			Players[killer][kills]++;
	
		if (victim > 0 && victim <= 32)
			Players[victim][deaths]++;
	}		
}

/*

		AUTO-JOIN

*/

public message_show_menu(msgid, dest, id) {

	/*static team_select[] = "#Team_Select"
	static menu_text_code[sizeof team_select]
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1)
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE*/
	static buffer[32];
	get_msg_arg_string(4, buffer, charsmax(buffer));
	if(containi(buffer, "Team") != -1 || containi(buffer, "Select") != -1){
		if(playerImm[id] == 0) {
			set_force_team_join_task(id, msgid)
			return PLUGIN_HANDLED;
		}
		else return PLUGIN_CONTINUE;
	}
	else return PLUGIN_CONTINUE;
}

public message_vgui_menu(msgid, dest, id) {
	if (get_msg_arg_int(1) == TEAM_SELECT_VGUI_MENU_ID) {
		if(playerImm[id] == 0) {
			set_force_team_join_task(id, msgid)
			return PLUGIN_HANDLED;
		}
		else return PLUGIN_CONTINUE;
	}
	else return PLUGIN_CONTINUE;
}

set_force_team_join_task(id, menu_msgid) {
	static param_menu_msgid[2]
	param_menu_msgid[0] = menu_msgid
	set_task(AUTO_TEAM_JOIN_DELAY, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid)
}

public task_force_team_join(menu_msgid[], id) {
	if (get_user_team(id))
		return

	force_team_join(id, menu_msgid[0], "5")
}

stock force_team_join(id, menu_msgid, /* const */ class[] = "0") {
	static jointeam[] = "jointeam"
	if (class[0] == '0') {
		engclient_cmd(id, jointeam, "5")
		return
	}

	static msg_block, joinclass[] = "joinclass"
	msg_block = get_msg_block(menu_msgid)
	set_msg_block(menu_msgid, BLOCK_SET)
	if(numCTS > numTS)
		engclient_cmd(id, jointeam, "1");
	else if (numTS > numCTS)
		engclient_cmd(id, jointeam, "2");
	else
		engclient_cmd(id, jointeam, "5");
	engclient_cmd(id, joinclass,"5")
	set_msg_block(menu_msgid, msg_block)
}

stock change_player_team(id, playerTeam)
{
	static g_pMsgTeamInfo;
	if(!g_pMsgTeamInfo)
		g_pMsgTeamInfo = get_user_msgid("TeamInfo");

	cs_set_user_team(id, playerTeam);
	emessage_begin(MSG_BROADCAST, g_pMsgTeamInfo);
	ewrite_byte(id);
	switch(playerTeam){
		case 0:ewrite_string("UNASSIGNED");
		case 1:ewrite_string("TERRORIST");
		case 2:ewrite_string("CT");
		case 3:ewrite_string("SPECTATOR");
	}
	emessage_end();
}

bool:flagCheck(id, flag[]) {
	if(get_user_flags(id) & read_flags(flag))
		return true;
	return false;
}

stock client_printc(const id, const input[]) {
	new count = 1, players[32];
	static msg[191];
	vformat(msg, 190, input, 3);
	
	replace_all(msg, 190, "!g", "^x04"); // Green Color
	replace_all(msg, 190, "!n", "^x01"); // Default Color
	replace_all(msg, 190, "!t", "^x03"); // Team Color
	
	if (id)
		players[0] = id;
	else
		get_players(players, count, "ch");

	for (new i = 0; i < count; i++)
		if (is_user_connected(players[i])) {
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), {0,0,0}, players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

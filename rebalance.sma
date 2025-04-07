#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta>

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
new canSwitchTeam[33]
new numCTS
new numTS

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	// Team Join
	register_clcmd("jointeam", "CmdJoinTeam");
	register_clcmd("chooseteam", "CmdJoinTeam");
	
	//register_event("SendAudio","roundEnd","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw") // Round End
	register_event("HLTV", "new_round", "a", "1=0", "2=0"); // Round Start
	register_event("TeamInfo", "updateTeam", "a"); // Team Change
	register_event("DeathMsg", "onDeath", "a"); // Player Death
	
	//RegisterHam(Ham_Spawn, "player", "onSpawn", 1); // Player Spawn
	
	// Default Menus
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	
	register_clcmd("amx_transfer", "cmdtransfer"); // Test command
	
	for(new i = 0; i < 33; i++) {
		playerSetData(i, 0, 0, UNDEFINED, 0);
		canSwitchTeam[i] = 1;
	}
	numCTS = 0;
	numTS = 0;
}

public cmdtransfer(id) {
	new ac = read_argc();
	if(ac != 4) {
		client_print(id, print_console, "Wrong usage");
		return PLUGIN_HANDLED;
	}
	new playerTeam = read_argv_int(2), playerClass = read_argv_int(3), name[64];
	read_argv(1, name, sizeof(name));
	new uid = get_user_index(name);
	if(pev_valid(uid) != 2) {
		client_print(id, print_console, "Invalid name");
		return PLUGIN_HANDLED;
	}
	if(playerTeam > 0 && playerTeam < 6 && playerClass > 0)
		transferPlayer(uid, playerTeam, playerClass);
	else client_print(id, print_console, "Bad team/class");
	return PLUGIN_HANDLED;
}

public transferPlayer(id, playerTeam, playerClass) {
	static msg_block;
	new menu_msgid = get_user_msgid("ShowMenu");
	msg_block = get_msg_block(menu_msgid);
	set_msg_block(menu_msgid, BLOCK_SET);
	
	if(playerTeam == 1 || (playerTeam == 5 && numTS < numCTS)) {
		cs_set_user_team(id, CS_TEAM_T, playerClass,true);
		Players[id][team] = TS;
		numTS++;
	}
	else if(playerTeam == 2 || (playerTeam == 5 && numCTS <= numTS)) {
		cs_set_user_team(id, CS_TEAM_CT, playerClass,true);
		Players[id][team] = CTS;
		numCTS++;
	}
	else {
		cs_set_user_team(id, CS_TEAM_SPECTATOR, 0,true);
		Players[id][team] = SPEC;
	}
	
	cs_reset_user_model(id);
	set_msg_block(menu_msgid, msg_block);
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
	canSwitchTeam[id] = 1;
	return HAM_IGNORED;
}

public new_round() {
	for(new i = 1; i < 33; i++)
		canSwitchTeam[i] = 1;
	client_print(0, print_chat, "CTS: %d,  TS: %d", numCTS, numTS);
}

public updateTeam() {
	new id = read_data(1)
	new teamStr[2];
	read_data(2, teamStr, charsmax(teamStr));
	//client_print(id, print_chat, "%d %s", id, teamStr);
	//client_print(id, print_chat, "%d %d", id, Players[id][team]);
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
	//client_print(id, print_chat, "%d %d", id, Players[id][team]);
}

public roundEnd() {
	for(new i = 0; i < 33; i++)
		if(is_user_connected(i))
			client_print(i, print_chat, "[%d] kills: %d,  deaths: %d", i, Players[i][kills], Players[i][deaths]);
}

public CmdJoinTeam(id) {
	if(!flagCheck(id,"a"))
		client_printc(id,"!g[!tFatality Family!g] Menjanje tima je zabranjeno.")
	else {
		if(canSwitchTeam[id])
			create_team_menu(id);
		else
			client_printc(id, "!g[!tFatality Family!g] Ne mozes ponovo promeniti tim.");
	}
	return PLUGIN_HANDLED;
}

public create_team_menu(id) {
	new menu = menu_create("Select a team", "team_menu_handler");

	menu_additem(menu, "Terrorist Force", "1", 0);
	menu_additem(menu, "Counter-Terrorist Force", "2", 0);
	menu_addblank2(menu);
	menu_addblank2(menu);
	menu_additem(menu, "Auto-Join", "5", 0);
	menu_additem(menu, "Spectator", "6", 0); 

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

public team_menu_handler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return;
	}

	new info[3];
	menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
    
	if(cs_get_user_defuse(id))
		cs_set_user_defuse(id, 0);
	
	static jointeam[] = "jointeam";
	static joinclass[] = "joinclass";
	
	new choice = str_to_num(info);
	if(choice == 1) {
		if(Players[id][team] == TS || numTS < numCTS || numTS == 0) {
			create_tmenu(id);
		} else {
			client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu!");
			menu_destroy(menu);
			return;
		}
	}
	else if(choice == 2) {
		if(Players[id][team] == CTS || numCTS < numTS || numCTS == 0) {
			create_ctmenu(id);
		} else {
			client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu!");
			menu_destroy(menu);
			return;
		}
	}
	else if(choice == 5) {
		engclient_cmd(id, jointeam, "5");
		engclient_cmd(id, joinclass, "5");
		canSwitchTeam[id] = 0;
	}
	else if(choice == 6)
		if(!is_user_alive(id)) {
			engclient_cmd(id,jointeam,"3");
			canSwitchTeam[id] = 0;
		}
		else client_printc(id, "!g[!tFatality Family!g] Ne mozes uci u spectate dok si ziv!");
	
	menu_destroy(menu);
}

public create_tmenu(id) {
	new menu = menu_create("Select your appearance", "tmenu_handler");

	menu_additem(menu, "Phoenix Connexion", "1", 0);
	menu_additem(menu, "Elite Crew", "2", 0);
	menu_additem(menu, "Arctic Avengers", "3", 0);
	menu_additem(menu, "Guerilla Warfare", "4", 0); 
	menu_additem(menu, "Auto-Select", "5", 0); 

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

public tmenu_handler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return;
	}

	new info[3];
	menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
	new choice = str_to_num(info);
	
	static jointeam[] = "jointeam";
	static joinclass[] = "joinclass";
	engclient_cmd(id, jointeam, "1");
	engclient_cmd(id, joinclass, "5");
	
	if(choice == 1)
		cs_set_user_model(id, "terror", false);
	else if(choice == 2)
		cs_set_user_model(id, "leet", false);
	else if(choice == 3)
		cs_set_user_model(id, "arctic", false);
	else if(choice == 4)
		cs_set_user_model(id, "guerilla", false);
	
	canSwitchTeam[id] = 0;
	Players[id][team] = TS;
	
	menu_destroy(menu);
	return;
}

public create_ctmenu(id) {
	new menu = menu_create("Select Your Class:", "ctmenu_handler");

	menu_additem(menu, "Seal Team 6", "1", 0);
	menu_additem(menu, "GSG-9", "2", 0);
	menu_additem(menu, "SAS", "3", 0);
	menu_additem(menu, "GIGN", "4", 0); 
	menu_additem(menu, "Auto-Select", "5", 0); 

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu, 0);
}

public ctmenu_handler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return;
	}

	new info[3];
	menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
	new choice = str_to_num(info);
	
	static jointeam[] = "jointeam";
	static joinclass[] = "joinclass";
	engclient_cmd(id, jointeam, "2");
	engclient_cmd(id, joinclass, "5");
	
	if(choice == 1)
		cs_set_user_model(id, "urban", false);
	else if(choice == 2)
		cs_set_user_model(id, "gsg9", false);
	else if(choice == 3)
		cs_set_user_model(id, "sas", false);
	else if(choice == 4)
		cs_set_user_model(id, "gign", false);
	
	canSwitchTeam[id] = 0;
	Players[id][team] = CTS;
	
	menu_destroy(menu);
	return;
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
		set_task(4.0, "create_team_menu", id);
}

public client_disconnected(id) {
	if(Players[id][team] == CTS)
		numCTS--;
	else if(Players[id][team] == TS)
		numTS--;
	playerSetData(id, 0, 0, UNDEFINED, 0);
	canSwitchTeam[id] = 1;
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
	if(containi(buffer, "Team") != -1 || containi(buffer, "Select") != -1)
		return PLUGIN_HANDLED;
	
	if(!flagCheck(id, "a")) {
		set_force_team_join_task(id, msgid)
		return PLUGIN_HANDLED;
	}
	else return PLUGIN_HANDLED;
}

public message_vgui_menu(msgid, dest, id) {
	if (get_msg_arg_int(1) == TEAM_SELECT_VGUI_MENU_ID)
		return PLUGIN_HANDLED;
	
	if(!flagCheck(id,"a")) {
		set_force_team_join_task(id, msgid)
		return PLUGIN_HANDLED;
	}
	else return PLUGIN_HANDLED;
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
	engclient_cmd(id, jointeam, "5")
	engclient_cmd(id, joinclass,"5")
	set_msg_block(menu_msgid, msg_block)
}

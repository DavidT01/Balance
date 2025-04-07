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

new menuID
new ctmenuID
new tmenuID

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	// Team Join
	register_clcmd("jointeam", "CmdJoinTeam");
	register_clcmd("chooseteam", "CmdJoinTeam");
	
	//register_event("SendAudio","roundEnd","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw") // Round End
	register_event("TeamInfo", "updateTeam", "a"); // Team Change
	register_event("DeathMsg", "onDeath", "a"); // Death
	
	RegisterHam(Ham_Spawn, "player", "onSpawn", 1);
	
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	
	register_clcmd("amx_transfer", "cmdtransfer");
	
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
	
	//engclient_cmd(id, jointeam, "1")
	//engclient_cmd(id, joinclass, class)
	
	cs_reset_user_model(id);
	set_msg_block(menu_msgid, msg_block);
}


public onDeath() {
	new killer = read_data(1);
	new victim = read_data(2);
	new killerName[32], victimName[32];
	get_user_name(killer, killerName, 32);
	get_user_name(victim, victimName, 32);
	
	//client_print(0, print_chat, "killer: [%d] %s, victim: [%d] %s", killer, killerName, victim, victimName);

	if (killer > 0 && killer <= 32 && killer != victim)
		Players[killer][kills]++;

	if (victim > 0 && victim <= 32)
		Players[victim][deaths]++;
}

public onSpawn(id) {
	new name[32];
	get_user_name(id, name, 32);
	canSwitchTeam[id] = 1;
	//client_print(id, print_chat, "[%d] %s in %d, kills: %d, deaths: %d", id, name, Players[id][team], Players[id][kills], Players[id][deaths]);
	return HAM_IGNORED;
}

public updateTeam() {
	new id = read_data(1)
	new teamStr[2];
	read_data(2, teamStr, charsmax(teamStr));
	//client_print(id, print_chat, "%d %s", id, teamStr);
	//client_print(id, print_chat, "%d %d", id, Players[id][team]);
	switch(teamStr[0]) {
		case 'T': Players[id][team] = TS;
		case 'C': Players[id][team] = CTS;
		case 'S': Players[id][team] = SPEC;
		default: Players[id][team] = UNASSIGNED;
	}
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
	menuID = menu_create("Select Your Team:", "team_menu_handler");

	menu_additem(menuID, "Terrorists", "1", 0);
	menu_additem(menuID, "Counter-Terrorists", "2", 0);
	menu_addblank2(menuID);
	menu_addblank2(menuID);
	menu_additem(menuID, "Auto-Join", "5", 0);
	menu_additem(menuID, "Spectate", "6", 0); 

	menu_setprop(menuID, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menuID, 0);
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

	new choice = str_to_num(info);
	static jointeam[] = "jointeam";
	static joinclass[] = "joinclass";
	if(choice == 1)
		create_tmenu(id);
	else if(choice == 2)
		create_ctmenu(id);
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
		else client_printc(id, "!g[!tFatality Family!g] Ne mozes uci u spectate dok si ziv.");
	
	menu_destroy(menu);
}

public create_tmenu(id) {
	tmenuID = menu_create("Select Your Class:", "tmenu_handler");

	menu_additem(tmenuID, "Phoenix Connexion", "1", 0);
	menu_additem(tmenuID, "Elite Crew", "2", 0);
	menu_additem(tmenuID, "Arctic Avengers", "3", 0);
	menu_additem(tmenuID, "Guerilla Warfare", "4", 0); 

	menu_setprop(menuID, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, tmenuID, 0);
}

public tmenu_handler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(tmenuID);
		return;
	}

	new info[3];
	menu_item_getinfo(tmenuID, item, _, info, charsmax(info), _, _, _);

	new choice = str_to_num(info);
	static jointeam[] = "jointeam";
	static joinclass[] = "joinclass";
	
	engclient_cmd(id, jointeam, "1");
	
	if(choice == 1)
		engclient_cmd(id, joinclass, "1");
	else if(choice == 2)
		engclient_cmd(id, joinclass, "3");
	else if(choice == 3)
		engclient_cmd(id, joinclass, "4");
	else if(choice == 4)
		engclient_cmd(id, joinclass, "8");
		
	canSwitchTeam[id] = 0;
	
	menu_destroy(tmenuID);
	return;
}

public create_ctmenu(id) {
	ctmenuID = menu_create("Select Your Class:", "ctmenu_handler");

	menu_additem(ctmenuID, "Seal Team 6", "1", 0);
	menu_additem(ctmenuID, "GSG-9", "2", 0);
	menu_additem(ctmenuID, "SAS", "3", 0);
	menu_additem(ctmenuID, "GIGN", "4", 0); 

	menu_setprop(menuID, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, ctmenuID, 0);
}

public ctmenu_handler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(ctmenuID);
		return;
	}

	new info[3];
	menu_item_getinfo(ctmenuID, item, _, info, charsmax(info), _, _, _);

	new choice = str_to_num(info);
	static jointeam[] = "jointeam";
	static joinclass[] = "joinclass";
	
	engclient_cmd(id, jointeam, "2");
	
	if(choice == 1)
		engclient_cmd(id, joinclass, "8");
	else if(choice == 2)
		engclient_cmd(id, joinclass, "5");
	else if(choice == 3)
		engclient_cmd(id, joinclass, "7");
	else if(choice == 4)
		engclient_cmd(id, joinclass, "6");
		
	canSwitchTeam[id] = 0;
	
	menu_destroy(ctmenuID);
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
		return PLUGIN_HANDLED
	
	if(!flagCheck(id,"a")){
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

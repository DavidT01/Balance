#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta>
#include <reapi>
#include <csx>
#include <fun>

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
#define VGUI_Menu_Class_T 26
#define VGUI_Menu_Class_CT 27

#define SWITCH_FREQ 0

enum Player {
	kills,
	deaths,
	multikill_count,
	damage,
	team,
	score,
	imm,
	last_transfer,
	can_switch,
	god
};

enum Team {
	num,
	tscore,
	streak,
	wins
};

enum Candidate {
	cid,
	cscore
};

new Players[33][Player];
new CT_candidates[20][Candidate], TT_candidates[20][Candidate];
new CT_cand_num, TT_cand_num;
new CT[Team], TT[Team];
new current_round;
new transfer_in_progress;

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_event("SendAudio","round_end","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw"); // Round End
	register_event("HLTV", "round_start", "a", "1=0", "2=0"); // Round Start
	register_event("TextMsg", "round_restart", "a", "2&#Game_C", "2&#Game_w"); // Round Restart
	register_event("TeamInfo", "update_team", "a"); // Team Change
	register_event("DeathMsg", "on_death", "a"); // Player Death

	register_logevent("CT_win", 6, "3=CTs_Win", "3=All_Hostages_Rescued") // CT Win
	register_logevent("TT_win" , 6, "3=Terrorists_Win", "3=Target_Bombed") // TT Win
	
	RegisterHam(Ham_TakeDamage, "player", "damage_taken", false); // Damage Tracking
	
	// Default Menus
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	
	// jointeam & chooseteam
	register_clcmd("jointeam", "cmd_jointeam");
	register_clcmd("chooseteam", "cmd_jointeam");
	
	for(new i = 0; i < 33; i++) {
		set_player_data(i, 0, 0, UNDEFINED, 0, 0, 0, 0, 1, 0);
		Players[i][imm] = 0;
	}
	CT[num] = 0; CT[tscore] = 0; CT[streak] = 0; CT[wins] = 0;
	TT[num] = 0; TT[tscore] = 0; TT[streak] = 0; TT[wins] = 0;
	current_round = 0;
	transfer_in_progress = 0;
}

public on_death() {
	new killer = read_data(1);
	new victim = read_data(2);

	if (killer > 0 && killer <= 32 && killer != victim) {
		Players[killer][kills]++;
		Players[killer][multikill_count]++;
	}

	if (victim > 0 && victim <= 32)
		Players[victim][deaths]++;
}

public round_start() {
	transfer_in_progress = 0;
	for(new i = 1; i < 33; i++) {
		Players[i][multikill_count] = 0;
		if(Players[i][imm] == 1)
			Players[i][can_switch] = 1;
		Players[i][god] = 0;
	}
	client_print(0, print_chat, "CTS: %d, TS: %d", CT[num], TT[num]);
}

public round_restart() {
	current_round = 1;
}

public damage_taken(victim, inflictor, attacker, Float:dmg, damagebits) {
	if(transfer_in_progress)
		return HAM_SUPERCEDE;

	if (attacker > 0 && attacker <= 32 && Players[victim][team] != Players[attacker][team])
		Players[attacker][damage] += floatround(dmg);

	return HAM_IGNORED;
}

public CT_win() {
	//client_printc(0, "CT won");
	CT[wins]++;
	CT[streak]++;
	TT[streak] = 0;
}

public TT_win() {
	//client_printc(0, "TT won");
	TT[wins]++;
	TT[streak]++;
	CT[streak] = 0;
}

public update_team() {
	new id = read_data(1);
	new teamStr[2];
	read_data(2, teamStr, charsmax(teamStr));
	
	//client_print(id, print_chat, "%s", teamStr);
	
	if(Players[id][team] == TS)
		TT[num]--;
	else if(Players[id][team] == CTS)
		CT[num]--;

	switch(teamStr[0]) {
		case 'T': Players[id][team] = TS;
		case 'C': Players[id][team] = CTS;
		case 'S': Players[id][team] = SPEC;
		default: Players[id][team] = UNASSIGNED;
	}

	if(Players[id][team] == TS)
		TT[num]++;
	else if(Players[id][team] == CTS)
		CT[num]++;
}

public round_end() {
	CT[tscore] = 0; TT[tscore] = 0;
	for(new i = 1; i < 33; i++) {
		update_player_score(i);
		if(Players[i][team] == CTS)
			CT[tscore] += Players[i][score];
		else if(Players[i][team] == TS)
			TT[tscore] += Players[i][score];
	}
	CT[tscore] /= CT[num]; TT[tscore] /= TT[num];
	
	client_print(0, print_console, "************* SCORES *************");
	new pls[32], n;
	get_players(pls, n, "c");
	for(new i = 0; i < n; i++) {
		new name[32];
		get_user_name(pls[i], name, 32);
		client_print(0, print_console, "%s: %d", name, Players[pls[i]][score]);
	}
	client_print(0, print_console, "**********************************")
	
	
	//client_print(0, print_chat, "Tim skorovi su azurirani!");
	set_task(2.5, "balance_number");
}

public client_authorized(id) {
	set_player_data(id, 0, 0, UNASSIGNED, 0, 0, 0, 0, 1, 0);
	if(flagCheck(id, "a")) {
		Players[id][imm] = 1;
		new data[1]; data[0] = id;
		create_team_menu(data);
	}
}

public client_disconnected(id) {
	if(Players[id][team] == CTS)
		CT[num]--;
	else if(Players[id][team] == TS)
		TT[num]--;
	set_player_data(id, 0, 0, UNDEFINED, 0, 0, 0, 0, 1, 0);
	Players[id][imm] = 0;
}

public client_death(killer, victim, wpnindex) {
	if(wpnindex == 6) {		
		if (killer > 0 && killer <= 32 && killer != victim) {
			Players[killer][kills]++;
			Players[killer][multikill_count]++;
		}
		if (victim > 0 && victim <= 32)
			Players[victim][deaths]++;
	}
}

/*

		CUSTOM TEAMMENU

*/

public cmd_jointeam(id) {
	if(!flagCheck(id,"a"))
		client_printc(id,"!g[!tFatality Family!g] Menjanje tima je zabranjeno.");
	else {
		if(Players[id][can_switch]) {
			new data[1]; data[0] = id;
			create_team_menu(data);
		}
		else
			client_printc(id, "!g[!tFatality Family!g] Ne mozes ponovo promeniti tim.");
	}
	return PLUGIN_HANDLED;
}

public create_team_menu(data[]) {
	new menu = menu_create("Select a team", "team_menu_handler");

	menu_additem(menu, "Terrorist Force", "1", 0);
	menu_additem(menu, "Counter-Terrorist Force", "2", 0);
	menu_addblank2(menu);
	menu_addblank2(menu);
	menu_additem(menu, "Auto-Join", "5", 0);
	menu_additem(menu, "Spectator", "6", 0); 

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(data[0], menu, 0);
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
		if(Players[id][team] == TS || TT[num] <= CT[num] || TT[num] == 0) {
			menu_destroy(menu);
			if((Players[id][team] == CTS || Players[id][team] == TS) && TT[num] == CT[num]) {
				client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu!");
				return;
			}
			create_tmenu(id);
			return;
		}
		else {
			client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu!");
			menu_destroy(menu);
			return;
		}
	}
	else if(choice == 2) {
		if(Players[id][team] == CTS || CT[num] <= TT[num] || CT[num] == 0) {
			menu_destroy(menu);
			if((Players[id][team] == CTS || Players[id][team] == TS) && TT[num] == CT[num]) {
				client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu!");
				return;
			}
			create_ctmenu(id);
			return;
		} else {
			client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu!");
			menu_destroy(menu);
			return;
		}
	}
	else if(choice == 5) {
		if(CT[num] < TT[num]) {
			engclient_cmd(id, jointeam, "2");
			Players[id][team] = CTS;
		}
		else if(TT[num] < CT[num]) {
			engclient_cmd(id, jointeam, "1");
			Players[id][team] = TS;
		}
		else if(Players[id][team] == CTS || Players[id][team] == TS) {
			menu_destroy(menu);
			return;
		}
		else {
			engclient_cmd(id, jointeam, "2");
			Players[id][team] = CTS;
		}
		engclient_cmd(id, joinclass, "5");
		Players[id][can_switch] = 0;
	}
	else if(choice == 6)
		if(!is_user_alive(id)) {
			engclient_cmd(id,jointeam,"3");
			Players[id][can_switch] = 0;
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
	
	Players[id][can_switch] = 0;
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
	
	Players[id][can_switch] = 0;
	Players[id][team] = CTS;
	
	menu_destroy(menu);
	return;
}

/*

		BALANCE
		
*/

public balance_number() {
	transfer_in_progress = 1;	
	while(abs(CT[num] - TT[num]) > 1)
		fix_team_numbering();
	client_print(0, print_chat, "Broj igraca je izbalansiran!");
	balance_score();
}

transfer_player(params[]) {
	if(params[2] == 1)
		Players[params[0]][last_transfer] = current_round;
	Players[params[0]][god] = 1;
	change_player_team(params[0], params[1]);
}

fix_team_numbering() {
	new sTeam, bTeam;
	if(CT[num] > TT[num]) {
		sTeam = TS;
		bTeam = CTS;
	}
	else if(TT[num] > CT[num]) {
		sTeam = CTS;
		bTeam = TS;
	}
	
	new worst_player = -1, worst_score = 1000;
	for(new i = 1; i < 33; i++)
		if(Players[i][team] == bTeam && Players[i][score] < worst_score && (current_round - Players[i][last_transfer] >= SWITCH_FREQ || Players[i][last_transfer] == 0)) {
			worst_score = Players[i][score];
			worst_player = i;
		}
	
	new params[3]; params[0] = worst_player; params[1] = sTeam; params[2] = 0;
	transfer_player(params);
	print_transfer(worst_player);
}

balance_score() {
	if(current_round < 3) {
		client_print(0, print_chat, "Ne balansiram skor u %d. rundi!", current_round);
		current_round++;
		return;
	}
	
	CT_cand_num = 0, TT_cand_num = 0;
	for(new i = 1; i < 33; i++) {
		if(/*!flagCheck(i, "l") && */(current_round - Players[i][last_transfer] >= SWITCH_FREQ || Players[i][last_transfer] == 0)) {
			if(Players[i][team] == CTS) {
				CT_candidates[CT_cand_num][cid] = i;
				CT_candidates[CT_cand_num++][cscore] = Players[i][score];
			}
			else if(Players[i][team] == TS) {
				TT_candidates[TT_cand_num][cid] = i;
				TT_candidates[TT_cand_num++][cscore] = Players[i][score];
			}
		}
	}

	current_round++;

	if(CT_cand_num == 0 || TT_cand_num == 0) {
		client_print(0, print_chat, "Nisu pronadjeni kandidati za transfer!");
		return;
	}

	if(CT[streak] >= 3) {
		client_print(0, print_chat, "CT streak previsok, izvrsavam transfer!");
		transfer_better(CTS);
		return;
	}
	else if(TT[streak] >= 3) {
		client_print(0, print_chat, "TT streak previsok, izvrsavam transfer!");
		transfer_better(TS);
		return;
	}

	if(CT[wins] != TT[wins]) {
		client_print(0, print_chat, "Razlika u skorovima veca od 5%, izvrsavam transfer!");
		find_switch(CT_candidates, TT_candidates, CT_cand_num, TT_cand_num);
	}
	return;
}

transfer_better(better_team) {
	client_print(0, print_console, "************* CT");
	for(new i = 0; i < CT_cand_num; i++)
		client_print(0, print_console, "%d", CT_candidates[i][cscore]);
	client_print(0, print_console, "************* CT");
	for(new i = 0; i < TT_cand_num; i++)
		client_print(0, print_console, "%d", TT_candidates[i][cscore]);
	sort(CT_candidates, CT_cand_num);
	sort(CT_candidates, CT_cand_num);
	client_print(0, print_console, "#########################");
	client_print(0, print_console, "************* CT");
	for(new i = 0; i < CT_cand_num; i++)
		client_print(0, print_console, "%d", CT_candidates[i][cscore]);
	client_print(0, print_console, "************* CT");
	for(new i = 0; i < TT_cand_num; i++)
		client_print(0, print_console, "%d", TT_candidates[i][cscore]);
}

find_switch(CT_candidates[][Candidate], TT_candidates[][Candidate], CT_cand_num, TT_cand_num) {
	new best_CT = 0, best_TT = 0;
	new score_diff = abs(CT[tscore] - TT[tscore]);
	for(new i = 0; i < CT_cand_num; i++) {
		for(new j = 0; j < TT_cand_num; j++) {
			new new_CT_score = (CT[tscore] * CT[num] - CT_candidates[i][cscore] + TT_candidates[j][cscore]) / CT[num];
			new new_TT_score = (TT[tscore] * TT[num] - TT_candidates[j][cscore] + CT_candidates[i][cscore]) / TT[num];
			if(abs(new_CT_score - new_TT_score) < score_diff) {
				best_CT = CT_candidates[i][cid];
				best_TT = TT_candidates[j][cid];
				score_diff = abs(new_CT_score - new_TT_score);
			}
		}
	}
	
	if(best_CT != 0 && best_TT != 0) {
		new par1[3]; par1[0] = best_CT; par1[1] = TS; par1[2] = 1;
		new par2[3]; par2[0] = best_TT; par2[1] = CTS; par2[2] = 1;
		transfer_player(par1);
		transfer_player(par2);
		print_switch(best_CT, best_TT);
	}
}

/*

		AUTO-JOIN

*/

public message_show_menu(msgid, dest, id) {

	static team_select[] = "#Team_Select"
	static menu_text_code[sizeof team_select]
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1)
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE
	/*static buffer[32];
	get_msg_arg_string(4, buffer, charsmax(buffer));
	client_print(id, print_chat, "%s", buffer);
	if(containi(buffer, "Team") != -1 || containi(buffer, "Select") != -1) {*/
	if(Players[id][imm] == 0) {
		set_force_team_join_task(id, msgid);
		return PLUGIN_HANDLED;
	}
	else {
		new data[1]; data[0] = id;
		set_task(1.0, "create_team_menu", id, data, sizeof(data));
		return PLUGIN_HANDLED;
	}
	//}
}

public message_vgui_menu(msgid, dest, id) {
	new menuid = get_msg_arg_int(1);
	if (menuid == TEAM_SELECT_VGUI_MENU_ID) {
		if(Players[id][imm] == 0) {
			set_force_team_join_task(id, msgid);
			return PLUGIN_HANDLED;
		}
		else {
			new data[1]; data[0] = id;
			set_task(1.0, "create_team_menu", id, data, sizeof(data));
			return PLUGIN_HANDLED;
		}
	}
	else if(menuid == VGUI_Menu_Class_CT || menuid == VGUI_Menu_Class_T)
		return PLUGIN_HANDLED;
	else
		return PLUGIN_CONTINUE;
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
	if(CT[num] >= TT[num])
		engclient_cmd(id, jointeam, "2");
	else
		engclient_cmd(id, jointeam, "1");
	engclient_cmd(id, joinclass,"5")
	set_msg_block(menu_msgid, msg_block)
}

stock change_player_team(id, playerTeam) {
	static g_pMsgTeamInfo;
	if(!g_pMsgTeamInfo)
		g_pMsgTeamInfo = get_user_msgid("TeamInfo");

	cs_set_user_defuse(id, 0);
	cs_set_user_team(id, playerTeam);
	emessage_begin(MSG_BROADCAST, g_pMsgTeamInfo);
	ewrite_byte(id);
	switch(playerTeam) {
		case 0:ewrite_string("UNASSIGNED");
		case 1:ewrite_string("TERRORIST");
		case 2:ewrite_string("CT");
		case 3:ewrite_string("SPECTATOR");
	}
	emessage_end();
}

/*

	HELPER FUNCTIONS

*/

stock bool:flagCheck(id, flag[]) {
	if(get_user_flags(id) & read_flags(flag))
		return true;
	return false;
}

stock set_player_data(id, k, dt, t, s, lt, mc, dmg, cswt, g) {
	Players[id][kills] = k;
	Players[id][deaths] = dt;
	Players[id][team] = t;
	Players[id][score] = s;
	Players[id][last_transfer] = lt;
	Players[id][multikill_count] = mc;
	Players[id][damage] = dmg;
	Players[id][can_switch] = cswt;
	Players[id][god] = g;
}

// score = kpr - dpr + adr
update_player_score(id) {
	Players[id][score] = (Players[id][kills] - Players[id][deaths] + Players[id][damage] / 100) / current_round;
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

stock print_transfer(id) {
	new name[64], text[256];
	get_user_name(id, name, 65);
	if(Players[id][team] == CTS)
		format(text, 255, "!g[!tFatality Family!g] !t%s !gje prebacen u !tKantere!g!", name);
	else if(Players[id][team] == TS)
		format(text, 255, "!g[!tFatality Family!g] !t%s !gje prebacen u !tTerore!g!", name);
	client_printc(0, text);
}

stock print_switch(id1, id2) {
	new name1[64], name2[64], text[256];
	get_user_name(id1, name1, 65);
	get_user_name(id2, name2, 65);
	format(text, 255, "!g[!tFatality Family!g] !t%s !gi !t%s !g su zamenjeni!", name1, name2);
	client_printc(0, text);
}

stock sort(array[][Candidate], size) {
	new swapped, tempi, temps;
	for(new i = 0; i < size - 1; i++) {
		swapped = 0;
		for(new j = 0; j < size - 1 ; j++) {
			if(array[j][cscore] > array[j + 1][cscore]) {
				tempi = array[j][cid]; temps = array[j][cscore];
				array[j][cid] = array[j + 1][cid]; array[j][cscore] = array[j + 1][cscore];
				array[j + 1][cid] = tempi; array[j + 1][cscore] = temps;
				swapped = 1;
			}
		}
		if(swapped == 0)
			break;
	}
}

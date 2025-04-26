#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta>
#include <reapi>
#include <csx>
#include <fun>

#define PLUGIN "ReBalance"
#define VERSION "2.0"
#define AUTHOR "fckn, treachery"

#define UNASSIGNED	 	0
#define TS 			1
#define CTS			2
#define SPEC                    3
#define AUTO_TEAM 		5
#define UNDEFINED               6

#define AUTO_TEAM_JOIN_DELAY 0.1
#define TEAM_SELECT_VGUI_MENU_ID 2

// 1 po mapi -> 8
#define SWITCH_FREQ 7
#define MIN_PLAYERS 8

enum Player {
	kills,
	deaths,
	multikill_count,
	damage,
	team,
	score,
	imm,
	admin,
	last_transfer,
	can_switch,
	fake_dead,
	auto_joined
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
new CT[Team], TT[Team];

new CT_candidates[20][Candidate], TT_candidates[20][Candidate];
new CT_cand_num, TT_cand_num;

new current_round;
new transfer_in_progress;

new logf[32];

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
	RegisterHam(Ham_Spawn, "player", "on_spawn", false); // Spawn

	// jointeam && chooseteam
	register_clcmd("jointeam", "block_jointeam");
	register_clcmd("chooseteam", "block_chooseteam");
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	
	// Spec-back
	register_clcmd("say", "handle_say");
 	register_clcmd("say_team", "handle_say");
	
	// Log
	logf = "balance.log";
	new map_name[32];
	get_mapname(map_name, 32);
	log_to_file(logf,"======== Map %s started ========", map_name);

	for(new i = 0; i < 33; i++) {
		set_player_data(i, 0, 0, UNASSIGNED, 0, 0, 0, 0, 1, 0);
		Players[i][imm] = 0;
		Players[i][admin] = 0;
		Players[i][auto_joined] = 0;
	}

	CT[num] = 0; CT[tscore] = 0; CT[streak] = 0; CT[wins] = 0;
	TT[num] = 0; TT[tscore] = 0; TT[streak] = 0; TT[wins] = 0;

	current_round = 0;
	transfer_in_progress = 0;
}

public handle_say(id) {
	if(!Players[id][admin])
		return;
 	new msg[192];
 	read_args(msg, charsmax(msg));
 	remove_quotes(msg);
 	strtolower(msg);

	if(equal(msg, "/spec") && Players[id][team] != SPEC) {
 		if(is_user_alive(id))
 			user_silentkill(id);
 		change_player_team(id, SPEC);
 	}
 	else if(equal(msg, "/back") && Players[id][team] == SPEC) {
 		if(CT[num] < TT[num])
 			change_player_team(id, CTS);
		else if(TT[num] < CT[num])
			change_player_team(id, TS);
		else
			change_player_team(id, random(2) + 1);
	}
}

public block_chooseteam(id) {
	if(!Players[id][imm]) {
		client_printc(id, "!g[!tFatality Family!g] Menjanje tima je zabranjeno.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public block_jointeam(id) {
	new argc = read_argc();
	if(argc != 2)
		return PLUGIN_HANDLED;
	new choice = read_argv_int(1);
	
	if(choice == 6 && is_user_alive(id))
		user_silentkill(id);

	if(!Players[id][imm]) {
		client_printc(id, "!g[!tFatality Family!g] Menjanje tima je zabranjeno.");
		return PLUGIN_HANDLED;
	}

	if((choice == 1 && TT[num] > CT[num]) || (choice == 2 && CT[num] > TT[num])) {
		client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu.");
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public on_death() {
	new killer = read_data(1);
	new victim = read_data(2);

	if (killer > 0 && killer <= 32 && killer != victim) {
		Players[killer][kills]++;
		Players[killer][multikill_count]++;
		if(Players[killer][multikill_count] > 2)
			Players[killer][kills] += 0.25;
	}

	if (victim > 0 && victim <= 32)
		Players[victim][deaths]++;
}

public on_spawn(id) {
	if(Players[id][fake_dead])
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

public round_start() {
	transfer_in_progress = 0;
	for(new i = 1; i <= 32; i++) {
		Players[i][multikill_count] = 0;
		if(Players[i][imm] == 1)
			Players[i][can_switch] = 1;
	}
	//client_print(0, print_chat, "CTS: %d, TS: %d", CT[num], TT[num]);
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
	
	if(Players[id][team] == CTS || Players[id][team] == TS)
		Players[id][can_switch] = 0;
	
	if((Players[id][team] == CTS && teamStr[0] == 'C') || (Players[id][team] == TS && teamStr[0] == 'T'))
		Players[id][can_switch] = 1;
	
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
	
	if(Players[id][team] == TS || Players[id][team] == CTS)
		Players[id][auto_joined] = 1;
}

public round_end() {
	CT[tscore] = 0; TT[tscore] = 0;
	for(new i = 1; i <= 32; i++) {
		update_player_score(i);
		if(Players[i][team] == CTS)
			CT[tscore] += Players[i][score];
		else if(Players[i][team] == TS)
			TT[tscore] += Players[i][score];
	}
	CT[tscore] = CT[num] == 0 ? 0 : CT[tscore] / CT[num];
	TT[tscore] = TT[num] == 0 ? 0 : TT[tscore] / TT[num];	

	set_task(2.5, "balance_number");
}

public client_authorized(id) {
	set_player_data(id, 0, 0, SPEC, 0, 0, 0, 0, 1, 0);

	if(flag_check(id, "a"))
		Players[id][imm] = 1;
	
	if(flag_check(id, "d"))
		Players[id][admin] = 1;
}

public client_disconnected(id) {
	if(Players[id][team] == CTS)
		CT[num]--;
	else if(Players[id][team] == TS)
		TT[num]--;

	set_player_data(id, 0, 0, UNASSIGNED, 0, 0, 0, 0, 1, 0);
	Players[id][imm] = 0;
	Players[id][admin] = 0;
	Players[id][auto_joined] = 0;
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

		BALANCE
		
*/

public balance_number() {
	transfer_in_progress = 1;	
	while(abs(CT[num] - TT[num]) > 1)
		fix_team_numbering();

	if(CT[num] + TT[num] >= MIN_PLAYERS)
		balance_score();
	else
		current_round++;
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
	for(new i = 1; i <= 32; i++)
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
		//client_print(0, print_chat, "Ne balansiram skor u %d. rundi!", current_round);
		current_round++;
		return;
	}
	
	CT_cand_num = 0, TT_cand_num = 0;
	for(new i = 1; i <= 32; i++) {
		if(!flag_check(i, "l") && (current_round - Players[i][last_transfer] >= SWITCH_FREQ || Players[i][last_transfer] == 0)) {
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
		log_to_file(logf,"[Round %d] Nisu pronadjeni kandidati za transfer.", current_round - 1);
		return;
	}

	if(CT[streak] >= 3) {
		log_to_file(logf,"[Round %d] CT streak previsok, trazim transfer.", current_round - 1);
		transfer_streak(CTS);
		return;
	}
	else if(TT[streak] >= 3) {
		log_to_file(logf,"[Round %d] TT streak previsok, trazim transfer.", current_round - 1);
		transfer_streak(TS);
		return;
	}

	if(CT[wins] != TT[wins]) {
		log_to_file(logf,"[Round %d] Razlika u pobedama, trazim transfer.", current_round - 1);
		find_switch();
	}
	return;
}

transfer_streak(better_team) {
	
	/*CT_candidates[0][cscore] = 50, CT_candidates[1][cscore] = 34, CT_candidates[2][cscore] = -20, CT_candidates[3][cscore] = 17, CT_candidates[4][cscore] = 43; CT_cand_num = 5;
	TT_candidates[0][cscore] = 23, TT_candidates[1][cscore] = -15, TT_candidates[2][cscore] = -28, TT_candidates[3][cscore] = 1, TT_candidates[4][cscore] = 67, TT_candidates[5][cscore] = 38; TT_cand_num = 6;
	
	client_print(0, print_console, "************* CT");
	for(new i = 0; i < CT_cand_num; i++)
		client_print(0, print_console, "%d", CT_candidates[i][cscore]);
	client_print(0, print_console, "************* TT");
	for(new i = 0; i < TT_cand_num; i++)
		client_print(0, print_console, "%d", TT_candidates[i][cscore]);*/

	sort(CT_candidates, CT_cand_num);
	sort(TT_candidates, TT_cand_num);
	
	/*client_print(0, print_console, "############ Bolji tim: %d", better_team);
	client_print(0, print_console, "************* CT");
	for(new i = 0; i < CT_cand_num; i++)
		client_print(0, print_console, "%d", CT_candidates[i][cscore]);
	client_print(0, print_console, "************* TT");
	for(new i = 0; i < TT_cand_num; i++)
		client_print(0, print_console, "%d", TT_candidates[i][cscore]);*/
		
	new ind;
	new params[3], params2[3];
	if(better_team == CTS) {
		if(CT_cand_num == 1)
			ind = 0;
		else if(CT_cand_num == 2)
			ind = random(2);
		else if(CT_cand_num > 2)
			ind = random(2) + 1;
		params[0] = CT_candidates[ind][cid]; params[1] = TS;
		params2[0] = TT_candidates[max(0, TT_cand_num - 1 - ind)][cid]; params2[1] = CTS;
	}
	else if(better_team == TS) {
		if(TT_cand_num == 1)
			ind = 0;
		else if(TT_cand_num == 2)
			ind = random(2);
		else if(TT_cand_num > 2)
			ind = random(2) + 1;
		params[0] = TT_candidates[ind][cid]; params[1] = CTS;
		params2[0] = CT_candidates[max(0, CT_cand_num - 1 - ind)][cid]; params2[1] = TS;
	}
	params[2] = 1; params2[2] = 1;
	transfer_player(params);
	transfer_player(params2);
	print_switch(params[0], params2[0]);
}

find_switch() {
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

transfer_player(params[]) {
	if(params[2] == 1)
		Players[params[0]][last_transfer] = current_round - 1;
	change_player_team(params[0], params[1]);
}

/*

		AUTO-JOIN

*/

public message_show_menu(msgid, dest, id) {
	static team_select[] = "#Team_Select";
	static menu_text_code[sizeof team_select];
	get_msg_arg_string(4, menu_text_code, sizeof menu_text_code - 1)
	if (!equal(menu_text_code, team_select))
		return PLUGIN_CONTINUE;

	if(!Players[id][imm] && !Players[id][auto_joined]) {
		set_force_team_join_task(id, msgid);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public message_vgui_menu(msgid, dest, id) {
	if (get_msg_arg_int(1) != TEAM_SELECT_VGUI_MENU_ID)
		return PLUGIN_CONTINUE;

	if(!Players[id][imm] && !Players[id][auto_joined]) {
		set_force_team_join_task(id, msgid);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

set_force_team_join_task(id, menu_msgid) {
	static param_menu_msgid[2];
	param_menu_msgid[0] = menu_msgid;
	set_task(AUTO_TEAM_JOIN_DELAY, "task_force_team_join", id, param_menu_msgid, sizeof param_menu_msgid);
}

public task_force_team_join(menu_msgid[], id) {
	if (get_user_team(id))
		return;

	force_team_join(id, menu_msgid[0], "5");
}

stock force_team_join(id, menu_msgid, const  class[] = "0") {
	static jointeam[] = "jointeam";
	if (class[0] == '0') {
		engclient_cmd(id, jointeam, "5");
		return;
	}

	static msg_block, joinclass[] = "joinclass";
	msg_block = get_msg_block(menu_msgid);
	set_msg_block(menu_msgid, BLOCK_SET);
	if(CT[num] > TT[num])
		engclient_cmd(id, jointeam, "1");
	else if(TT[num] > CT[num])
		engclient_cmd(id, jointeam, "2");
	else {
		new rand = random(2) + 1;
		new str[8];
		num_to_str(rand, str, 8);
		engclient_cmd(id, jointeam, str);
	}
	engclient_cmd(id, joinclass,"5");
	set_msg_block(menu_msgid, msg_block);
}

stock change_player_team(id, player_team) {
	if(id == 0)
		return;

	static g_pMsgTeamInfo;
	if(!g_pMsgTeamInfo)
		g_pMsgTeamInfo = get_user_msgid("TeamInfo");

	if(cs_get_user_defuse(id))
		cs_set_user_defuse(id, 0);
	cs_set_user_team(id, player_team);
	emessage_begin(MSG_BROADCAST, g_pMsgTeamInfo);
	ewrite_byte(id);
	switch(player_team) {
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

stock bool:flag_check(id, flag[]) {
	if(get_user_flags(id) & read_flags(flag))
		return true;
	return false;
}

stock set_player_data(id, k, dt, t, s, lt, mc, dmg, cswt, fd) {
	Players[id][kills] = k;
	Players[id][deaths] = dt;
	Players[id][team] = t;
	Players[id][score] = s;
	Players[id][last_transfer] = lt;
	Players[id][multikill_count] = mc;
	Players[id][damage] = dmg;
	Players[id][can_switch] = cswt;
	Players[id][fake_dead] = fd;
}

update_player_score(id) {
	if(current_round > 0)
		Players[id][score] = (Players[id][kills] - Players[id][deaths] / 2 + Players[id][damage] / 100) / current_round;
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
		format(text, 255, "!g[!tFatality Family!g] !t%s !gje prebacen u !tKantere!g.", name);
	else if(Players[id][team] == TS)
		format(text, 255, "!g[!tFatality Family!g] !t%s !gje prebacen u !tTerore!g.", name);
	client_printc(0, text);
}

stock print_switch(id1, id2) {
	new name1[64], name2[64], text[256];
	get_user_name(id1, name1, 65);
	get_user_name(id2, name2, 65);
	format(text, 255, "!g[!tFatality Family!g] !t%s !gi !t%s !gsu zamenjeni.", name1, name2);
	client_printc(0, text);
}

stock sort(array[][Candidate], size) {
	new swapped, tempi, temps;
	for(new i = 0; i < size - 1; i++) {
		swapped = 0;
		for(new j = 0; j < size - 1 ; j++) {
			if(array[j][cscore] < array[j + 1][cscore]) {
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

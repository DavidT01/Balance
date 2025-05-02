#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta>
#include <reapi>
#include <csx>
#include <fun>

#define PLUGIN "ReBalance"
#define VERSION "2.2"
#define AUTHOR "fckn, treachery"

#define UNASSIGNED	 	0
#define TS 			1
#define CTS			2
#define SPEC                    3
#define AUTO_TEAM 		5
#define UNDEFINED               6

#define AUTO_TEAM_JOIN_DELAY 0.1
#define TEAM_SELECT_VGUI_MENU_ID 2

#define SWITCH_FREQ 10
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
	auto_joined,
	can_be_transfered
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
new transfer_count;

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
	//RegisterHam(Ham_Spawn, "player", "on_spawn", false); // Spawn

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
	log_to_file(logf, "============ %s ============", map_name);

	for(new i = 0; i < 33; i++) {
		set_player_data(i, 0, 0, UNASSIGNED, 0, -1, 0, 0);
		Players[i][imm] = 0;
		Players[i][admin] = 0;
		Players[i][auto_joined] = 0;
		Players[i][can_be_transfered] = 1;
	}

	CT[num] = 0; CT[tscore] = 0; CT[streak] = 0; CT[wins] = 0;
	TT[num] = 0; TT[tscore] = 0; TT[streak] = 0; TT[wins] = 0;

	current_round = 1;
	transfer_count = 0;
	disable_progress();
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
	if(droga_bot(id))
		return PLUGIN_CONTINUE;

	if(!Players[id][imm]) {
		client_printc(id, "!g[!tFatality Family!g] Menjanje tima je zabranjeno.");
		return PLUGIN_HANDLED;
	}
	
	if(Players[id][can_be_transfered] && current_round - Players[id][last_transfer] < 4 && Players[id][last_transfer] > 0) {
		client_printc(id, "!g[!tFatality Family!g] Prebacen si u poslednje tri runde.");
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public block_jointeam(id) {
	new argc = read_argc();
	if(argc != 2)
		return PLUGIN_HANDLED;
	new choice = read_argv_int(1);
	
	if(choice == 6) {
		if(is_user_alive(id))
			user_silentkill(id);
		cs_set_user_team(id, Players[id][team]);
	}
	
	if(droga_bot(id))
		return PLUGIN_CONTINUE;

	if(!Players[id][imm]) {
		client_printc(id, "!g[!tFatality Family!g] Menjanje tima je zabranjeno.");
		return PLUGIN_HANDLED;
	}
	
	if(Players[id][can_be_transfered] && current_round - Players[id][last_transfer] < 4 && Players[id][last_transfer] > 0) {
		client_printc(id, "!g[!tFatality Family!g] Prebacen si u poslednje tri runde.");
		return PLUGIN_HANDLED;
	}

	/*if((choice == 1 && TT[num] > CT[num]) || (choice == 2 && CT[num] > TT[num])) {
		client_printc(id, "!g[!tFatality Family!g] Previse igraca u timu.");
		return PLUGIN_HANDLED;
	}*/

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

public round_start() {
	for(new i = 1; i <= 32; i++)
		Players[i][multikill_count] = 0;
	disable_progress();
	set_task(3.0, "disable_progress");
	//log_to_file(logf, "[Runda %d] CT: %d, TT: %d", current_round, CT[num], TT[num]);
}

public round_restart() {
	balance_number();
	current_round = 1;
	disable_progress();
	set_task(3.0, "disable_progress");
}

public damage_taken(victim, inflictor, attacker, Float:dmg, damagebits) {
	if(transfer_in_progress && attacker > 0 && attacker <= 32)
		return HAM_SUPERCEDE;

	if (attacker > 0 && attacker <= 32 && Players[victim][team] != Players[attacker][team])
		Players[attacker][damage] += floatround(dmg);

	return HAM_IGNORED;
}

/*public on_spawn() {
	transfer_in_progress = 0;
	return HAM_IGNORED;
}*/

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
	
	new max_rounds = get_cvar_num("mp_maxrounds");
	if(current_round == max_rounds && max_rounds > 0) {
		set_task(2.0, "print_nextmap");
		return;
	}
	
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

	set_task(3.5, "balance_number");
}

public client_authorized(id) {
	set_player_data(id, 0, 0, SPEC, 0, -1, 0, 0);

	if(flag_check(id, "a"))
		Players[id][imm] = 1;
	
	if(flag_check(id, "d"))
		Players[id][admin] = 1;

	new steamid[32]; get_user_authid(id, steamid, 32);

	// L flag / tea / loca
	if(flag_check(id, "l") || equal(steamid, "STEAM_0:0:216817879") || equal(steamid, "STEAM_0:0:869945501"))
		Players[id][can_be_transfered] = 0;
	// botovi
	else if(droga_bot(id))
		Players[id][can_be_transfered] = 0;
	else
		Players[id][can_be_transfered] = 1;
		
	// fckn
	if(equal(steamid, "STEAM_0:0:644303"))
		Players[id][can_be_transfered] = 1;
}

public client_disconnected(id) {
	if(Players[id][team] == CTS)
		CT[num]--;
	else if(Players[id][team] == TS)
		TT[num]--;

	set_player_data(id, 0, 0, UNASSIGNED, 0, -1, 0, 0);
	Players[id][imm] = 0;
	Players[id][admin] = 0;
	Players[id][auto_joined] = 0;
	Players[id][can_be_transfered] = 1;
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
	else
		return;

	new worst_player = -1, oldest_transfer = 1000;
	for(new i = 1; i <= 32; i++)
		if(Players[i][can_be_transfered] && Players[i][team] == bTeam && Players[i][last_transfer] < oldest_transfer)
			oldest_transfer = Players[i][last_transfer];
		
	new oldest_transfered_players[32];
	new j = 0;
	for(new i = 1; i <= 32; i++)
		if(Players[i][can_be_transfered] && Players[i][team] == bTeam && Players[i][last_transfer] == oldest_transfer)
			oldest_transfered_players[j++] = i;
	
	worst_player = oldest_transfered_players[random(j)];
	
	if(worst_player == -1) {
		log_to_file(logf, "[Runda %d] UPOZORENJE: Ne postoji validan igrac za balansiranje broja.", current_round);
		return;
	}
	
	new params[2]; params[0] = worst_player; params[1] = sTeam;
	transfer_player(params);
	print_transfer(worst_player);
}

balance_score() {
	if(current_round < 3) {
		//client_print(0, print_chat, "Ne balansiram skor u %d. rundi!", current_round);
		current_round++;
		return;
	}
	
	if(transfer_count == 2) {
		transfer_count = 0;
		current_round++;
		return;
	}
	
	CT_cand_num = 0, TT_cand_num = 0;
	for(new i = 1; i <= 32; i++) {
		if(Players[i][can_be_transfered] && (current_round - Players[i][last_transfer] >= SWITCH_FREQ || Players[i][last_transfer] == -1)) {
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
		log_to_file(logf, "[Runda %d] Nisu pronadjeni kandidati za transfer.", current_round - 1);
		return;
	}

	if(CT[streak] >= 3 && TT[wins] - CT[wins] < 3) {
		log_to_file(logf, "[Runda %d] CT streak previsok.", current_round - 1);
		transfer_streak(CTS);
		return;
	}
	else if(TT[streak] >= 3 && CT[wins] - TT[wins] < 3) {
		log_to_file(logf, "[Runda %d] TT streak previsok.", current_round - 1);
		transfer_streak(TS);
		return;
	}

	if(CT[wins] != TT[wins]) {
		log_to_file(logf, "[Runda %d] Razlika u pobedama.", current_round - 1);
		find_switch();
	}
}

transfer_streak(better_team) {
	sort(CT_candidates, CT_cand_num);
	sort(TT_candidates, TT_cand_num);
		
	new ind;
	new params[2], params2[2];
	if(better_team == CTS) {
		if(CT_cand_num == 1)
			ind = 0;
		else if(CT_cand_num == 2)
			ind = random(2);
		else if(CT_cand_num == 3)
			ind = random(2) + 1;
		else if(CT_cand_num > 3)
			ind = random(3) + 1;
		params[0] = CT_candidates[ind][cid]; params[1] = TS;
		params2[0] = TT_candidates[TT_cand_num - 1][cid]; params2[1] = CTS;
	}
	else if(better_team == TS) {
		if(TT_cand_num == 1)
			ind = 0;
		else if(TT_cand_num == 2)
			ind = random(2);
		else if(TT_cand_num == 3)
			ind = random(2) + 1;
		else if(TT_cand_num > 3)
			ind = random(3) + 1;
		params[0] = TT_candidates[ind][cid]; params[1] = CTS;
		params2[0] = CT_candidates[CT_cand_num - 1][cid]; params2[1] = TS;
	}

	transfer_player(params);
	transfer_player(params2);
	transfer_count++;
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
		new par1[2]; par1[0] = best_CT; par1[1] = TS;
		new par2[2]; par2[0] = best_TT; par2[1] = CTS;
		transfer_player(par1);
		transfer_player(par2);
		transfer_count++;
		print_switch(best_CT, best_TT);
	}
}

transfer_player(params[]) {
	if(params[0] < 1 || params[0] > 32) {
		log_to_file(logf, "[Runda %d] GRESKA: ID (%d) nije validan.", current_round - 1, params[0]);
		return;
	}

	if(params[1] != CTS && params[1] != TS) {
		log_to_file(logf, "[Runda %d] GRESKA: Tim (%d) nije validan.", current_round - 1, params[1]);
		return;
	}

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

	force_team_join(id, menu_msgid[0]);
}

stock force_team_join(id, menu_msgid) {
	static msg_block, jointeam[] = "jointeam", joinclass[] = "joinclass";
	msg_block = get_msg_block(menu_msgid);
	set_msg_block(menu_msgid, BLOCK_SET);

	if(CT[num] > TT[num])
		engclient_cmd(id, jointeam, "1");
	else if(TT[num] > CT[num])
		engclient_cmd(id, jointeam, "2");
	else {
		new str[8]; num_to_str(random(2) + 1, str, 8);
		engclient_cmd(id, jointeam, str);
	}

	engclient_cmd(id, joinclass,"5");
	set_msg_block(menu_msgid, msg_block);
}

stock change_player_team(id, player_team) {
	if(id < 1 || id > 32)
		return;
		
	cs_set_user_team(id, player_team);

	static g_pMsgTeamInfo;
	if(!g_pMsgTeamInfo)
		g_pMsgTeamInfo = get_user_msgid("TeamInfo");

	if(cs_get_user_defuse(id))
		cs_set_user_defuse(id, 0);
	cs_set_user_team(id, player_team);
	emessage_begin(MSG_BROADCAST, g_pMsgTeamInfo);
	ewrite_byte(id);
	switch(player_team) {
		case 0: ewrite_string("UNASSIGNED");
		case 1: ewrite_string("TERRORIST");
		case 2: ewrite_string("CT");
		case 3: ewrite_string("SPECTATOR");
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

stock set_player_data(id, k, dt, t, s, lt, mc, dmg) {
	Players[id][kills] = k;
	Players[id][deaths] = dt;
	Players[id][team] = t;
	Players[id][score] = s;
	Players[id][last_transfer] = lt;
	Players[id][multikill_count] = mc;
	Players[id][damage] = dmg;
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
	if(Players[id][team] == CTS) {
		format(text, 255, "!g[!tFatality Family!g] !t%s !gje prebacen u !tKantere!g.", name);
		log_to_file(logf, "[Runda %d] %s je prebacen u Kantere.", current_round - 1, name);
	}
	else if(Players[id][team] == TS) {
		format(text, 255, "!g[!tFatality Family!g] !t%s !gje prebacen u !tTerore!g.", name);
		log_to_file(logf, "[Runda %d] %s je prebacen u Terore.", current_round - 1, name);
	}
	client_printc(0, text);
}

stock print_switch(id1, id2) {
	new name1[64], name2[64], text[256];
	get_user_name(id1, name1, 65);
	get_user_name(id2, name2, 65);
	format(text, 255, "!g[!tFatality Family!g] !t%s !gi !t%s !gsu zamenjeni.", name1, name2);
	log_to_file(logf, "[Runda %d] %s i %s su zamenjeni.", current_round - 1, name1, name2);
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

stock bool:droga_bot(id) {
	new steamid[32]; get_user_authid(id, steamid, 32);
	if(equal(steamid, "STEAM_1:0:984556879") || equal(steamid, "STEAM_1:0:1619668816") || equal(steamid, "STEAM_1:0:922772504") || \
	equal(steamid, "STEAM_1:0:1858914077") || equal(steamid, "STEAM_1:1:1046450049") || equal(steamid, "STEAM_1:1:2109445265") || \
	equal(steamid, "STEAM_1:1:1063259102") || equal(steamid, "STEAM_1:0:346051284") || equal(steamid, "STEAM_1:0:2135450009"))
		return true;
	return false
}

public disable_progress() {
	transfer_in_progress = 0;
}

public print_nextmap() {
	new map[50], text[256];
	get_cvar_string("amx_nextmap", map, charsmax(map));
	format(text, 255, "!g[!tFatality Family!g] Sledeca mapa je !t%s!g.", map);
	client_printc(0, text);
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

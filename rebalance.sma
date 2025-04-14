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

#define SWITCH_FREQ 7

enum Player {
	kills,
	deaths,
	team,
	score,
	imm,
	last_transfer
};

enum Team {
	num,
	tscore,
	streak,
	wins
};

new Players[33][Player];
new canSwitchTeam[33];
new CT[Team], TT[Team];
new current_round;

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_event("SendAudio","round_end","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw"); // Round End
	register_event("HLTV", "round_start", "a", "1=0", "2=0"); // Round Start
	register_event("TextMsg", "round_restart", "a", "2&#Game_C", "2&#Game_w"); // Round Restart
	register_event("TeamInfo", "update_team", "a"); // Team Change
	register_event("DeathMsg", "on_death", "a"); // Player Death
	register_logevent("CT_win", 6, "3=CTs_Win", "3=All_Hostages_Rescued") // CT Win
	register_logevent("TT_win" , 6, "3=Terrorists_Win", "3=Target_Bombed") // TT Win
	
	// Default Menus
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	RegisterHookChain(RG_ShowMenu, "OldMenu_hook");
	RegisterHookChain(RG_ShowVGUIMenu, "VGUIMenu_hook");
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "jointeam_hook");
	RegisterHookChain(RG_HandleMenu_ChooseAppearance, "joinclass_hook");
	
	register_clcmd("chooseteam", "block_chooseteam");
	register_clcmd("jointeam", "block_jointeam")
	register_clcmd("amx_transfer", "transfer_cmd");
	
	for(new i = 0; i < 33; i++) {
		playerSetData(i, 0, 0, UNDEFINED, 0);
		canSwitchTeam[i] = 1;
		Players[i][imm] = 0;
		Players[i][last_transfer] = 0;
	}
	CT[num] = 0; CT[tscore] = 0; CT[streak] = 0; CT[wins] = 0;
	TT[num] = 0; TT[tscore] = 0; TT[streak] = 0; TT[wins] = 0;
	current_round = 0;
}

public block_chooseteam(id) {
	if(canSwitchTeam[id] == 0) {
		client_printc(id, "!gMenjanje tima je zabranjeno 1");
		return PLUGIN_HANDLED;
	}
	else return PLUGIN_CONTINUE;
}

public block_jointeam(id) {
	
}

public transfer_cmd(id) {
	new ac = read_argc();
	if(ac != 2) {
		client_print(id, print_console, "Greska.");
		return PLUGIN_HANDLED;
	}

	new argv[32], arg;
	read_argv(1, argv, sizeof(argv));
	arg = str_to_num(argv);

	if(arg > 0 && arg < 4) {
		change_player_team(id, arg);
		return PLUGIN_HANDLED;
	}
	else {
		client_print(id, print_console, "Greska.");
		return PLUGIN_HANDLED;
	}
}

public OldMenu_hook(id, const bitsSlots, const iDisplayTime, const iNeedMore, pszText[]) {
	if(containi(pszText, "Team") != -1 || containi(pszText, "Select") != -1) {
		if(Players[id][imm] == 0 && canSwitchTeam[id] == 0) {
			client_printc(id, "!gMenjanje tima je zabranjeno 2");
			return HC_SUPERCEDE;
		}
		else if(Players[id][imm] == 0 && canSwitchTeam[id] == 1) {
			return HC_CONTINUE;
		}
		else {
			if(canSwitchTeam[id] == 0) {
				client_printc(id, "!gMenjanje tima je zabranjeno 3");
				return HC_SUPERCEDE;
			}
			else return HC_CONTINUE;
		}
	}
	else return HC_CONTINUE;
}

public VGUIMenu_hook(id, VGUIMenu:menuType) {
	if(menuType != VGUIMenu:TEAM_SELECT_VGUI_MENU_ID)
		return HC_CONTINUE;

	if(Players[id][imm] == 0  && canSwitchTeam[id] == 0) {
		client_printc(id, "!gMenjanje tima je zabranjeno 4");
		return HC_SUPERCEDE;
	}
	else if(Players[id][imm] == 0 && canSwitchTeam[id] == 1) {
		return HC_CONTINUE;
	}
	else {
		if(canSwitchTeam[id] == 0) {
			client_printc(id, "!gMenjanje tima je zabranjeno 5");
			return HC_SUPERCEDE;
		}
		else return HC_CONTINUE;
	}
}

public jointeam_hook(id, slot) {
	if(Players[id][imm] == 0 && canSwitchTeam[id] == 0) {
		client_printc(id, "!gMenjanje tima je zabranjeno 6");
		return HC_SUPERCEDE;
	}
	else if(Players[id][imm] == 0 && canSwitchTeam[id] == 1) {
		return HC_CONTINUE;
	}
	else {
		if(canSwitchTeam[id] == 0) {
			client_printc(id, "!gMenjanje tima je zabranjeno 7");
			return HC_SUPERCEDE;
		}
		else {
			return HC_CONTINUE;
		}
	}
}

public joinclass_hook(id) {
	if(Players[id][imm] == 0 && canSwitchTeam[id] == 0) {
		client_printc(id, "!gMenjanje tima je zabranjeno 8");
		return HC_SUPERCEDE;
	}
	else if(Players[id][imm] == 0 && canSwitchTeam[id] == 1) {
		canSwitchTeam[id] = 0;
		return HC_CONTINUE;
	}
	else {
		if(canSwitchTeam[id] == 0) {
			client_printc(id, "!gMenjanje tima je zabranjeno 9");
			return HC_SUPERCEDE;
		}
		else {
			canSwitchTeam[id] = 0;
			return HC_CONTINUE;
		}
	}
}

public on_death() {
	new killer = read_data(1);
	new victim = read_data(2);

	if (killer > 0 && killer <= 32 && killer != victim)
		Players[killer][kills]++;

	if (victim > 0 && victim <= 32)
		Players[victim][deaths]++;
}

public round_start() {
	for(new i = 1; i < 33; i++)
		if(Players[i][imm] == 1)
			canSwitchTeam[i] = 1;
	client_print(0, print_chat, "CTS: %d, TS: %d", CT[num], TT[num]);
}

public round_restart() {
	current_round = 1;
}

public CT_win() {
	client_printc(0, "CT won");
	CT[wins]++;
	TT[streak] = 0;
}

public TT_win() {
	client_printc(0, "TT won");
	TT[wins]++;
	CT[streak] = 0;
}

public update_team() {
	new id = read_data(1)
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
	client_print(0, print_chat, "Tim skorovi su azurirani!");
	set_task(2.5, "balance_number");
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
	Players[id][last_transfer] = 0;
	if(flagCheck(id, "a"))
		Players[id][imm] = 1;
}

public client_disconnected(id) {
	if(Players[id][team] == CTS)
		CT[num]--;
	else if(Players[id][team] == TS)
		TT[num]--;
	playerSetData(id, 0, 0, UNDEFINED, 0);
	canSwitchTeam[id] = 1;
	Players[id][last_transfer] = 0;
	Players[id][imm] = 0;
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

// TODO: nova formula
public update_player_score(id) {
	if(Players[id][deaths] != 0)
		Players[id][score] = Players[id][kills] / Players[id][deaths];
	else
		Players[id][score] = Players[id][kills];
}

/*

		BALANCE
		
*/

public balance_number() {	
	while(abs(CT[num] - TT[num]) > 1)
		fix_team_numbering();
	client_print(0, print_chat, "Broj igraca je izbalansiran!");
	balance_score();
}

// TODO: Omoguciti da ga drugi ne ubijaju dok ne krene nova runda
public transfer_player(params[]) {
	if(params[2] == 1)
		Players[params[0]][last_transfer] = current_round;
	change_player_team(params[0], params[1]);
}

public fix_team_numbering() {
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
}

public balance_score() {
	if(current_round < 3) {
		client_print(0, print_chat, "Ne balansiram skor u %d. rundi!", current_round);
		current_round++;
		return;
	}
	
	new CT_candidates[17], TT_candidates[17];
	new CT_cand_num = 0, TT_cand_num = 0;
	for(new i = 1; i < 33; i++) {
		if(!flagCheck(i, "l") && (current_round - Players[i][last_transfer] >= SWITCH_FREQ || Players[i][last_transfer] == 0)) {
			if(Players[i][team] == CTS)
				CT_candidates[CT_cand_num++] = i;
			else if(Players[i][team] == TS)
				TT_candidates[TT_cand_num++] = i;
		}
	}

	current_round++;

	if(CT_cand_num != 0 && TT_cand_num != 0)
		client_print(0, print_chat, "Pronadjeni su kandidati za transfer!");
	else {
		client_print(0, print_chat, "Nisu pronadjeni kandidati za transfer!");
		return;
	}

	if(CT[streak] > 3) {
		client_print(0, print_chat, "CT streak previsok, izvrsavam transfer!");
		find_switch(CT_candidates, TT_candidates, CT_cand_num, TT_cand_num);
		return;
	}
	else if(TT[streak] > 3) {
		client_print(0, print_chat, "TT streak previsok, izvrsavam transfer!");
		find_switch(CT_candidates, TT_candidates, CT_cand_num, TT_cand_num);
		return;
	}

	if(CT[wins] != TT[wins] && (TT[tscore] > 1.05*CT[tscore] || CT[tscore] > 1.05*TT[tscore])) {
		client_print(0, print_chat, "Razlika u skorovima veca od 5%, izvrsavam transfer!");
		find_switch(CT_candidates, TT_candidates, CT_cand_num, TT_cand_num);
	}
	return;
}

public find_switch(CT_candidates[], TT_candidates[], CT_cand_num, TT_cand_num) {
	new best_CT = 0, best_TT = 0;
	new score_diff = abs(CT[tscore] - TT[tscore]);
	for(new i = 0; i < CT_cand_num; i++) {
		for(new j = 0; j < TT_cand_num; j++) {
			new new_CT_score = (CT[tscore] * CT[num] - Players[CT_candidates[i]][score] + Players[TT_candidates[j]][score]) / CT[num];
			new new_TT_score = (TT[tscore] * TT[num] - Players[TT_candidates[j]][score] + Players[CT_candidates[i]][score]) / TT[num];
			if(abs(new_CT_score - new_TT_score) <= score_diff) {
				best_CT = CT_candidates[i];
				best_TT = TT_candidates[j];
				score_diff = abs(new_CT_score - new_TT_score);
			}
		}
	}
	
	if(best_CT != 0 && best_TT != 0) {
		new par1[3]; par1[0] = best_CT; par1[1] = TS; par1[2] = 1;
		new par2[3]; par2[0] = best_TT; par2[1] = CTS; par2[2] = 1;
		transfer_player(par1);
		transfer_player(par2);
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
	if(containi(buffer, "Team") != -1 || containi(buffer, "Select") != -1) {
		if(Players[id][imm] == 0) {
			set_force_team_join_task(id, msgid)
			return PLUGIN_HANDLED;
		}
		else return PLUGIN_CONTINUE;
	}
	else return PLUGIN_CONTINUE;
}

public message_vgui_menu(msgid, dest, id) {
	if (get_msg_arg_int(1) == TEAM_SELECT_VGUI_MENU_ID) {
		if(Players[id][imm] == 0) {
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

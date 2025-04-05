#include <amxmodx>
#include <amxmisc>

#define PLUGIN "ReBalance"
#define VERSION "1.0"
#define AUTHOR "treachery, fckn A."

#define UNASSIGNED	 	0
#define TS 			1
#define CTS			2
#define SPEC                    3
#define AUTO_TEAM 		5
#define UNDEFINED               6

enum Player {
	kills,
	deaths,
	team,
	score
}

new Players[33][Player]

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	// jointeam
	register_clcmd("jointeam", "CmdJoinTeam");
	register_clcmd("chooseteam", "CmdJoinTeam");
	
	for(new i = 0; i < 33; i++){
		playerSetData(i, 0, 0, UNDEFINED, 0);
	}
}

public CmdJoinTeam(id){
	if(!flagCheck(id,"a")) {
		client_printc(id,"!g[!tFatality Family!g] Menjanje tima je zabranjeno.")
		//client_print(id,print_chat,"%d %d %d %d",Players[id][kills], Players[id][deaths], Players[id][team], Players[id][score]); test
		return PLUGIN_HANDLED;
	}
	else return PLUGIN_CONTINUE;
}

bool:flagCheck(id, flag[]) {
	if(get_user_flags(id) & read_flags(flag))
		return true;
	return false;
}

stock client_printc(const id, const input[]){
	new count = 1, players[32];
	static msg[191];
	vformat(msg, 190, input, 3);
	
	replace_all(msg, 190, "!g", "^x04"); // Green Color
	replace_all(msg, 190, "!n", "^x01"); // Default Color
	replace_all(msg, 190, "!t", "^x03"); // Team Color
	
	if (id) players[0] = id; else get_players(players, count, "ch");{
	for (new i = 0; i < count; i++){
		if (is_user_connected(players[i])){
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), {0,0,0},players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
			}
		}
	}
}

public playerSetData(id, k, d, t, s){
	Players[id][kills] = k;
	Players[id][deaths] = d;
	Players[id][team] = t;
	Players[id][score] = s;
}

public client_authorized(id){
	playerSetData(id, 0, 0, UNASSIGNED, 0);
}

public client_disconnected(id){
	playerSetData(id, 0, 0, UNDEFINED, 0);
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/

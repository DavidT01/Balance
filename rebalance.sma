#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>

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
	
	// Team Join
	register_clcmd("jointeam", "CmdJoinTeam");
	register_clcmd("chooseteam", "CmdJoinTeam");
	
	//register_event("SendAudio","roundEnd","a","2=%!MRAD_terwin","2=%!MRAD_ctwin","2=%!MRAD_rounddraw") // Round End
	register_event("TeamInfo", "updateTeam", "a"); // Team Change
	register_event("DeathMsg", "onDeath", "a"); // Death
	
	RegisterHam(Ham_Spawn, "player", "onSpawn", 1);
	
	for(new i = 0; i < 33; i++)
		playerSetData(i, 0, 0, UNDEFINED, 0);
}

public onDeath() {
	new killer = read_data(1);
	new victim = read_data(2);
	new killerName[32], victimName[32];
	get_user_name(killer, killerName, 32);
	get_user_name(victim, victimName, 32);
	client_print(0, print_chat, "killer: [%d] %s, victim: [%d] %s", killer, killerName, victim, victimName);

	if (killer > 0 && killer <= 32 && killer != victim)
		Players[killer][kills]++;

	if (victim > 0 && victim <= 32)
		Players[victim][deaths]++;
}

public onSpawn(id) {
	new name[32];
	get_user_name(id, name, 32);
	client_print(id, print_chat, "[%d] %s in %d, kills: %d, deaths: %d", id, name, Players[id][team], Players[id][kills], Players[id][deaths]);
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
	if(!flagCheck(id,"a")) {
		client_printc(id,"!g[!tFatality Family!g] Menjanje tima je zabranjeno.")
		//client_print(id,print_chat,"%d %d %d %d",Players[id][kills], Players[id][deaths], Players[id][team], Players[id][score]); test
		return PLUGIN_HANDLED;
	}
	else {
		new args[16];
		read_args(args, charsmax(args));
		remove_quotes(args);
		new newTeam = str_to_num(args);
		new ar[32];
		read_argv(0, ar, 32);
		client_print(id, print_chat, "%d", newTeam);
		client_print(id, print_chat, "%s", ar);
		return PLUGIN_CONTINUE;
	}
}

public jointeam(id) {
	new arg[2]
	read_argv(1,arg,1)
	client_print(id, print_chat, "%d", str_to_num(arg));
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
}

public client_disconnected(id) {
	playerSetData(id, 0, 0, UNDEFINED, 0);
}

public client_death(killer, victim, wpnindex) {
	if(wpnindex == 6) {
		new killerName[32], victimName[32];
		get_user_name(killer, killerName, 32);
		get_user_name(victim, victimName, 32);
		client_print(0, print_chat, "killer: [%d] %s, victim: [%d] %s", killer, killerName, victim, victimName);
		
		if (killer > 0 && killer <= 32 && killer != victim)
			Players[killer][kills]++;
	
		if (victim > 0 && victim <= 32)
			Players[victim][deaths]++;
	}		
}

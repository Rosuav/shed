/* Chat bot for Twitch.tv
See API docs:
https://github.com/justintv/Twitch-API/blob/master/IRC.md

To make this work, get yourself an oauth key here:
http://twitchapps.com/tmi/
and change your user and realname accordingly.
*/

mapping config = ([]);
array(string) channels = ({ });
object irc;

string lastchan;
int nextcolor;

mapping timezones;

string timezone_info(string tz)
{
	if (!tz || tz=="") return "Regions are: " + sort(indices(timezones))*", ";
	mapping|string region = timezones;
	foreach (lower_case(tz)/"/", string part) if (!mappingp(region=region[part])) break;
	if (undefinedp(region))
		return "Unknown region "+tz+" - use '!tz' to list";
	if (mappingp(region))
		return "Locations in region "+tz+": "+sort(indices(region))*", ";
	if (catch {return region+" - "+Calendar.Gregorian.Second()->set_timezone(region)->format_time();})
		return "Unable to figure out the time in that location, sorry.";
}

class channel_notif
{
	inherit Protocols.IRC.Channel;
	string color;
	void create() {if (++nextcolor>7) nextcolor=1; color = sprintf("\e[1;3%dm", nextcolor);}

	void not_join(object who) {write("%sJoin %s: %s\e[0m\n",color,name,who->nick);}
	void not_part(object who,string message,object executor) {write("%sPart %s: %s\e[0m\n",color,name,who->nick);}
	void not_message(object person,string msg)
	{
		lastchan = name;
		if (msg == "!hello") irc->send_message(name, "Hello, "+person->nick+"!");
		if (sscanf(msg, "!hype %s", string whatfor)) irc->send_message(name, "/me <3 gives the hype for "+whatfor+"! <3");
		if (msg == "!hostthis") irc->send_message("#"+person->nick, "/host "+name[1..]);
		if (msg == "!tz" || sscanf(msg, "!tz %s", string tz))
		{
			tz = timezone_info(tz||"");
			while (sizeof(tz) > 200)
			{
				sscanf(tz, "%200s%s %s", string piece, string word, tz);
				irc->send_message(name, sprintf("@%s: %s%s ...", person->nick, piece, word));
			}
			irc->send_message(name, sprintf("@%s: %s", person->nick, tz));
		}
		if (sscanf(msg, "\1ACTION %s\1", string slashme)) msg = person->nick+" "+slashme;
		else msg = person->nick+": "+msg;
		string pfx=sprintf("[%s] ",name);
		int wid = Stdio.stdin->tcgetattr()->columns - sizeof(pfx);
		write("%s%s\e[0m", color, sprintf("%*s%-=*s\n",sizeof(pfx),pfx,wid,msg));
	}
}

void console(object stdin, Stdio.Buffer buf)
{
	while (string line=buf->match("%s\n")) //Will usually happen exactly once, but if you type before lastchan is set, it might loop
		execcommand(line);
}

void execcommand(string line)
{
	if (sscanf(line, "/join %s", string chan))
	{
		write("%%% Joining #"+chan+"\n");
		irc->join_channel("#"+chan);
		channels += ({"#"+chan});
	}
	else if (sscanf(line, "/part %s", string chan))
	{
		write("%%% Parting #"+chan+"\n");
		irc->part_channel("#"+chan);
		channels -= ({"#"+chan});
	}
	else if (lastchan) irc->send_message(lastchan, line);
}

void reconnect()
{
	if (irc) write("%% Reconnecting\n");
	irc = Protocols.IRC.Client("irc.twitch.tv", config);
	irc->cmd->cap("REQ","twitch.tv/membership");
	irc->join_channel(channels[*]);
}

int main(int argc,array(string) argv)
{
	timezones = ([]);
	foreach (sort(Calendar.TZnames.zonenames()), string zone)
	{
		array(string) parts = lower_case(zone)/"/";
		mapping tz = timezones;
		foreach (parts[..<1], string region)
			if (!tz[region]) tz = tz[region] = ([]);
			else tz = tz[region];
		tz[parts[-1]] = zone;
	}
	if (!file_stat("twitchbot_config.txt"))
	{
		Stdio.write_file("twitchbot_config.txt",#"# twitchbot.pike config file
# Basic names
nick: <bot nickname here>
realname: <bot real name here>
# Get an OAuth2 key here: 
pass: <password>
# List the channels you want to monitor. Only these channels will
# be logged, and commands will be noticed only if they're in one
# of these channels. Any number of channels can be specified.
channels: rosuav ellalune lara_cr cookingfornoobs
");
	}
	foreach (Stdio.read_file("twitchbot_config.txt")/"\n", string l)
	{
		l = String.trim_all_whites(l);
		if (l=="" || l[0]=='#') continue;
		sscanf(l, "%s: %s", string key, string val); if (!val) continue;
		if (key=="channels") channels += "#" + (val/" ")[*];
		else config[key] = val;
	}
	if (config->pass[0] == '<')
	{
		write("Edit twitchbot_config.txt to make this bot work!\n");
		return 0;
	}
	config->channel_program = channel_notif;
	config->connection_lost = reconnect;
	reconnect();
	Stdio.stdin->set_buffer_mode(Stdio.Buffer(),0);
	Stdio.stdin->set_read_callback(console);
	if (has_value(argv,"--gui"))
	{
		GTK2.setup_gtk(argv);
		object ef=GTK2.Entry()->set_width_chars(40)->set_activates_default(1);
		object btn=GTK2.Button()->set_size_request(0,0)->set_flags(GTK2.CAN_DEFAULT);
		btn->signal_connect("clicked",lambda() {execcommand(ef->get_text()); ef->set_text("");});
		GTK2.Window(0)->add(GTK2.Vbox(0,0)->add(ef)->pack_end(btn,0,0,0))->set_title("Twitch Bot")->show_all();
		btn->grab_default();
	}
	return -1;
}

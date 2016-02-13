/* Chat bot for Twitch.tv
See API docs:
https://github.com/justintv/Twitch-API/blob/master/IRC.md

To make this work, get yourself an oauth key here:
http://twitchapps.com/tmi/
and change your user and realname accordingly.
*/

object irc;

string lastchan;
int nextcolor;

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
		if (msg == "!hostthis") irc->send_message("#"+person->nick, "/host "+name[1..]);
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
	}
	else if (sscanf(line, "/part %s", string chan))
	{
		write("%%% Parting #"+chan+"\n");
		irc->part_channel("#"+chan);
	}
	else if (lastchan) irc->send_message(lastchan, line);
}

int main(int argc,array(string) argv)
{
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
	mapping config = ([]);
	array(string) channels = ({ });
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
	irc = Protocols.IRC.Client("irc.twitch.tv", config);
	irc->cmd->cap("REQ","twitch.tv/membership");
	irc->join_channel(channels[*]);
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

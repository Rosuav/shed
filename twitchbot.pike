/* Chat bot for Twitch.tv
See API docs:
https://github.com/justintv/Twitch-API/blob/master/IRC.md

To make this work, get yourself an oauth key here:
http://twitchapps.com/tmi/
and change your user and realname accordingly.
*/

object irc;

string lastchan;

class channel_notif
{
	inherit Protocols.IRC.Channel;
	void not_join(object who) {write("Join %s: %s\n",name,who->nick);}
	void not_part(object who,string message,object executor) {write("Part %s: %s\n",name,who->nick);}
	void not_message(object person,string msg)
	{
		lastchan = name;
		if (msg == "!hello") irc->send_message(name, "Hello, "+person->nick+"!");
		if (msg == "!hostthis") irc->send_message("#"+person->nick, "/host "+name[1..]);
		if (sscanf(msg, "\1ACTION %s\1", string slashme)) msg = person->nick+" "+slashme;
		else msg = person->nick+": "+msg;
		string pfx=sprintf("[%s] ",name);
		int wid = Stdio.stdin->tcgetattr()->columns - sizeof(pfx);
		write("%*s%-=*s\n",sizeof(pfx),pfx,wid,msg);
	}
}

void reply(object stdin, Stdio.Buffer buf)
{
	if (!lastchan) return;
	while (string line=buf->match("%s\n")) //Will usually happen exactly once, but if you type before lastchan is set, it might loop
		irc->send_message(lastchan, line);
}

void generic(mixed ... args) {write("generic: %O\n",args);}

int main()
{
	irc = Protocols.IRC.Client("irc.twitch.tv", ([
		"nick": "Rosuav",
		"pass": "oauth:<put twitch oauth password here>",
		"realname": "Chris Angelico",
		"channel_program": channel_notif,
		//"generic_notify": generic,
	]));
	irc->cmd->cap("REQ","twitch.tv/membership");
	irc->join_channel("#rosuav");
	irc->join_channel("#ellalune");
	irc->join_channel("#lara_cr");
	Stdio.stdin->set_buffer_mode(Stdio.Buffer(),0);
	Stdio.stdin->set_read_callback(reply);
	return -1;
}

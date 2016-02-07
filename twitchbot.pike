/* Chat bot for Twitch.tv
See API docs:
https://github.com/justintv/Twitch-API/blob/master/IRC.md

To make this work, get yourself an oauth key here:
http://twitchapps.com/tmi/
and change your user and realname accordingly.
*/

object irc;

class channel_notif
{
	inherit Protocols.IRC.Channel;
	void not_join(object who) {write("Join %s: %s\n",name,who->nick);}
	void not_part(object who,string message,object executor) {write("Part %s: %s\n",name,who->nick);}
	void not_message(object person,string msg)
	{
		if (msg == "!hello") irc->send_message(name, "Hello, "+person->nick+"!");
		if (sscanf(msg, "\1ACTION %s\1", string slashme)) msg = person->nick+" "+slashme;
		else msg = person->nick+": "+msg;
		string pfx=sprintf("[%s] ",name);
		int wid = Stdio.stdin->tcgetattr()->columns - sizeof(pfx);
		write("%*s%-=*s\n",sizeof(pfx),pfx,wid,msg);
	}
}

void generic(mixed ... args) {write("generic: %O\n",args);}

int main()
{
	irc = Protocols.IRC.Client("irc.twitch.tv", ([
		"user": "rosuav",
		"pass": "oauth:<put twitch oauth password here>",
		"realname": "Chris Angelico",
		"channel_program": channel_notif,
		//"generic_notify": generic,
	]));
	irc->cmd->cap("REQ","twitch.tv/membership");
	irc->join_channel("#rosuav");
	irc->join_channel("#ellalune");
	//irc->send_message("#rosuav","Test");
	return -1;
}

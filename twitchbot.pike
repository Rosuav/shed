object irc;

void message(object person,string msg,string to)
{
	string pfx=sprintf("[%s] ",to);
	int wid = Stdio.stdin->tcgetattr()->columns - sizeof(pfx);
	write("%*s%-=*s\n",sizeof(pfx),pfx,wid,person->nick+": "+msg);
}

int main()
{
	irc = Protocols.IRC.Client("irc.twitch.tv", ([
		"user": "rosuav",
		"pass": "oauth:<put twitch oauth password here>",
		"realname": "Chris Angelico",
		"privmsg_notify": message,
	]));
	write("%O %O\n",irc,indices(irc));
	irc->cmd->join("#cookingfornoobs");
	return -1;
	//irc->send_message("#cookingfornoobs","");
}

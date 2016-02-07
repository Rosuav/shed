object irc;

void message(object person,string msg,string to)
{
	if (sscanf(msg, "\1ACTION %s\1", string slashme)) msg = person->nick+" "+slashme;
	else msg = person->nick+": "+msg;
	string pfx=sprintf("[%s] ",to);
	int wid = Stdio.stdin->tcgetattr()->columns - sizeof(pfx);
	write("%*s%-=*s\n",sizeof(pfx),pfx,wid,msg);
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

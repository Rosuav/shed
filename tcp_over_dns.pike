//Yes. That's what I said. TCP over DNS.
//It's a TCP/IP proxy that uses DNS in the middle.
//Honestly, it's no weirder than "TCP over HTTP", which is called WebSockets.

mapping(int:function) services=([53|HOGAN_DNS: dns, /*23|HOGAN_PLAIN: telnet*/]);

mapping dns(int portref, mapping query, mapping udp_data, function(mapping:void) cb)
{
	mapping q = query->qd[0];
	werror("Query: %O\n", q->name);
	if (q->type == Protocols.DNS.T_TXT)
	{
		array(string) parts = q->name / ".";
		if (sizeof(parts) < 2 || parts[-1] != "tod") return (["rcode": Protocols.DNS.REFUSED]); //Not for us.
		mapping conn = G->G->connections; if (!conn) conn = G->G->connections = ([]);
		mapping c = conn[parts[-1]]; if (!c) c = conn[parts[-1]] = ([]);
		string sendme = MIME.decode_base64(parts[..<2] * ""); //Everything before the connection ID is text to send.
		werror("Combined and decoded: %O\n", sendme);
		if (sendme == "")
		{
			//Wants to receive text. (We could multiplex but it'd be potentially messy.)
			//TODO.
			return (["an": (["cl": q->cl, "ttl": 1, "type": q->type, "name": q->name, "txt": ""])]);
		}
		//Otherwise, wants to send text.
		//TODO.
		return (["an": (["cl": q->cl, "ttl": 1, "type": q->type, "name": q->name, "txt": ""])]);
	}
	return (["rcode": Protocols.DNS.REFUSED]);
}

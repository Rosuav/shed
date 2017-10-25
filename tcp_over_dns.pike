//Yes. That's what I said. TCP over DNS.
//It's a TCP/IP proxy that uses DNS in the middle.
//Honestly, it's no weirder than "TCP over HTTP", which is called WebSockets.

mapping(int:function) services=([53|HOGAN_DNS: dns, 3333|HOGAN_ACTIVE: upstream, /*23|HOGAN_PLAIN: telnet*/]);

string(0..255) upstream(mapping(string:mixed) conn, string(0..255) data) {if (data) conn->rcvd += data;}

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
		if (!c->sock)
		{
			//TODO: Allow customization of destination (maybe). Or hard-code 35.160.129.187.
			G->connect(c->sock = (["_portref": 3333|HOGAN_ACTIVE, "_ip": "127.0.0.1", "rcvd": ""]));
			return (["an": (["cl": q->cl, "ttl": 1, "type": q->type, "name": q->name, "txt": "<connecting>"])]);
		}
		string sendme = MIME.decode_base64(parts[..<2] * ""); //Everything before the connection ID is text to send.
		werror("Combined and decoded: %O\n", sendme);
		if (sendme == "")
		{
			//Wants to receive text. (We could multiplex but it'd be potentially messy.)
			string sendme = "";
			if (sizeof(c->sock->rcvd) > 128)
			{
				sendme = c->sock->rcvd[..127];
				c->sock->rcvd = c->sock->rcvd[128..];
			}
			//else if (c->sock->rcvd == "") //TODO: Defer the response to save bw
			else
			{
				sendme = c->sock->rcvd;
				c->sock->rcvd = "";
			}
			return (["an": (["cl": q->cl, "ttl": 1, "type": q->type, "name": q->name, "txt": sendme])]);
		}
		//Otherwise, wants to send text.
		G->send(c->sock, sendme);
		return (["an": (["cl": q->cl, "ttl": 1, "type": q->type, "name": q->name, "txt": "<sent>"])]);
	}
	return (["rcode": Protocols.DNS.REFUSED]);
}

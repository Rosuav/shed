//Generate responses to DNS packets sent on stdin
//Python's tools for DNS management aren't all that good, so we drop to Pike for this part.

//For decode_res and low_send_reply (the latter of which is protected, so we inherit rather than instantiating)
inherit Protocols.DNS.server_base;

mapping dns_response(mapping req) {
	mapping q = req->qd[0];
	if (q->type == Protocols.DNS.T_PTR) {
		sscanf(q->name, "%x.%x.%x.%x.%s", int d, int c, int b, int a, string tail);
		//This should be the only domain that's delegated to us
		if (tail != "0.0.0.0.0.0.0.0.0.0.0.0.1.0.0.0.8.4.f.b.3.0.8.5.3.0.4.2.ip6.arpa") return (["rcode": Protocols.DNS.NXDOMAIN]);
		if (a) return (["rcode": Protocols.DNS.NXDOMAIN]);
		string ptr;
		if (b) {
			//eg ::01xx, this is a step in the chain. The last two digits are the step number, and b is the document number.
			int step = (c << 4) | d;
			//This would be where we fetch the actual text.
			ptr = "step-" + step + ".jabberwocky.";
		} else if (d) {
			//eg ::000x, this is the endpoint of a chain
			if (d == 1) ptr = "jabberwocky.rosuav.com.";
		} else {
			//It's ::0000, the DNS server itself.
			ptr = "tomfoolery.rosuav.com.";
		}
		if (!ptr) return (["rcode": Protocols.DNS.NXDOMAIN]);
		return (["an": (["cl": q->cl, "ttl": 600, "type": q->type, "name": q->name, "ptr": ptr])]);
	}
}

int main() {
	while (1) catch {
		string line = Stdio.stdin->gets();
		if (!line || !sizeof(line)) break;
		sscanf(line, "%s %d %s", string ip, int port, string pkt);
		mapping req = decode_res(MIME.decode_base64(pkt));
		pkt = low_send_reply(dns_response(req), req, ([]));
		write("%s %d %s\n", ip, port, MIME.encode_base64(pkt, 1));
		Stdio.stdout->flush();
	};
}

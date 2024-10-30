int main(int argc, array(string) argv) {
	Thread.Thread() {sleep(15); exit(1, "TIMEOUT Unable to connect to server\n");};
	//Subject Alternative Name - defined in RFC 3280 as having the ID 2.5.29.17
	object SAN = Standards.ASN1.Types.Identifier(); SAN->id = ({2, 5, 29, 17});
	if (argc < 2) exit(1, "USAGE: pike %s address [port] [domain name]\nConnects to address:port and requests domain, shows SSL cert.\n");
	string address = argv[1]; //eg "sikorsky.rosuav.com"
	int port = 443;
	string|zero domain = 0;
	foreach (argv[2..], string arg)
		if ((int)arg) port = (int)arg;
		else domain = arg;
	if (!domain) domain = address;
	object sock = Stdio.File();
	sock->open_socket();
	sock->set_nonblocking(0) {
		object ssl = SSL.File(sock, SSL.Context());
		ssl->set_nonblocking(0) {
			object cert = Standards.X509.decode_certificate(ssl->get_peer_certificates()[0]);
			int valid = cert->validity[1]->get_posix();
			if (valid < time()) write("Certificate EXPIRED at " + ctime(valid));
			else write("Certificate valid until " + ctime(valid));
			write("Subject: %s\n", cert->subject_str());
			object alt = cert->extensions[SAN];
			if (alt) write("Alternate: %s\n", alt->elements->value[*]);
			exit(0);
		};
		ssl->connect(domain);
	};
	array ip = gethostbyname(address);
	if (!ip || !sizeof(ip[1])) exit(0, "Unable to look up %s\n", address);
	sock->connect(ip[1][0], port);
	return -1;
}

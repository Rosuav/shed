//Simple reverse proxy for encrypting a service that isn't otherwise encrypted
//TODO: Parameterize for all these
int listen_port = 5544;
int connect_port = 4455; //OBS WebSocket
//int connect_port = 7654;
string connect_host = "127.0.0.1";

void handler(object mainsock) {
	object enc = mainsock->accept();
	object dec = Stdio.File();
	werror("Connected! %O %O\n", enc, dec);
	dec->connect(connect_host, connect_port);
	enc->set_nonblocking(lambda(mixed _, string data) {dec->write(data);}, 0, lambda() {dec->close();});
	dec->set_nonblocking(lambda(mixed _, string data) {enc->write(data);}, 0, lambda() {enc->close();});
}

int main() {
	string key = Stdio.read_file("privkey.pem") + Stdio.read_file("certificate.pem");
	object cert = Standards.PEM.Messages(key);
	SSL.Context ctx = SSL.Context();
	ctx->add_cert(cert->get_private_key(), cert->get_certificates(), ({"*"}));
	SSL.Port mainsock = SSL.Port(ctx);
	mainsock->bind(listen_port, handler, "::", 1);
	write("Listening.\n");
	return -1;
}

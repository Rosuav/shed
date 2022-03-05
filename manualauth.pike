#!/usr/local/bin/pike
object oldhttp, httptimer;
class Connection(object sock) {
	Stdio.Buffer buf = Stdio.Buffer();
	string token, validation;
	object http;
	protected void create() {
		sock->set_buffer_mode(buf, 0);
		sock->set_nonblocking(sockread, 0, sockclosed);
	}
	void sockclosed() {sock->close();}
	void sockread() {
		if (array ret = buf->sscanf("%s %s\n")) {
			write("GOT LINE %O %O\n", ret[0], ret[1]);
			sock->close();
			[token, validation] = ret;
			if (oldhttp && httptimer->peek() > 60) {oldhttp->close(); sleep(1);}
			oldhttp = http = Protocols->HTTP->Server->Port(handler, 80); //Not doing compile-time lookup to avoid spamming warnings in the parent
			httptimer = System.Timer();
		}
	}
	void handler(object req) {
		if (req->not_query == "/.well-known/acme-challenge/" + token) {
			req->response_and_finish((["data": validation, "type": "text/plain; charset=\"UTF-8\""]));
			call_out(http->close, 1, 0); //Dwell for one second in case there are doubled requests
			oldhttp = 0;
		}
		else req->response_and_finish((["error": 404]));
	}
}

int main(int argc, array(string) argv) {
	if (sizeof(argv) == 1) {
		//Daemon process
		Stdio.Port(800, lambda(object port) {while (object sock = port->accept()) Connection(sock);}, "127.0.0.1");
		return -1;
	}
	if (argv[1] == "-c") {
		//Invocation from ssh. Pass the message along via TCP, because mixing SSH and sudo is
		//a bizarre nightmare that won't go into the background. I do not understand why.
		Stdio.File sock = Stdio.File();
		sock->connect("127.0.0.1", 800);
		sock->write(argv[2] + "\n");
		sock->close("w");
		sleep(1); //Dwell for a second, just in case (though the above calls should block)
		return 0;
	}
	werror("Unknown args %O\n", argv);
	return 1;
}

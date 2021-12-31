#!/usr/local/bin/pike
string TOKEN, VALIDATION;

void handler(object req) {
	if (req->not_query == "/.well-known/acme-challenge/" + TOKEN) {
		req->response_and_finish((["data": VALIDATION, "type": "text/plain; charset=\"UTF-8\""]));
		call_out(exit, 1, 0); //Dwell for one second in case there are doubled requests
	}
	else req->response_and_finish((["error": 404]));
}

int main(int argc, array(string) argv) {
	if (argv[1] == "-c") {
		//Invocation from ssh. Unfortunately all SSH-supplied args come through as a single string.
		Process.Process(({"/usr/bin/sudo", argv[0]}) + argv[2] / " ");
		return 0;
	}
	TOKEN = argv[1]; VALIDATION = argv[2];
	Protocols->HTTP->Server->Port(handler, 80); //Not doing compile-time lookup to avoid spamming warnings in the parent
	call_out(exit, 60, 1); //Wait for one minute at most, then cancel
	return -1;
}

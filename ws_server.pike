//Simple websocket echo server for testing purposes
//Connect, you will get a greeting. Send any valid JSON and it will echo it back.

object httpserver;

void http_handler(Protocols.HTTP.Server.Request req) {
	//Non-WS requests: send back a simple page.
	req->response_and_finish((["data": "You requested: " + req->not_query, "type": "text/plain; charset=\"UTF-8\""]));
}

void ws_msg(Protocols.WebSocket.Frame frm, object sock) {
	mixed data;
	if (catch {data = Standards.JSON.decode(frm->text);}) return; //Ignore frames that aren't text or aren't valid JSON
	sock->send_text(Standards.JSON.encode(data));
}

void ws_handler(array(string) proto, Protocols.WebSocket.Request req) {
	Protocols.WebSocket.Connection sock = req->websocket_accept(0);
	sock->onmessage = ws_msg;
	sock->send_text(Standards.JSON.encode((["cmd": "hello", "msg": "You requested: " + req->not_query])));
}

int main() {
	int port = 4567; //TODO: Make configurable by parameter
	httpserver = Protocols.WebSocket.Port(http_handler, ws_handler, port, "::");
	write("Listening.\n");
	return -1;
}

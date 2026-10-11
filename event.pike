mapping websocket_types = (["event": (["groups": ([])])]);

void http_handler(Protocols.HTTP.Server.Request req) {
	switch (req->not_query) {
		case "/":  req->response_and_finish((["data": sprintf(#{<!DOCTYPE HTML>
<html lang=en>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Event status</title>
<script>let ws_type = "event", ws_group = "", ws_code = location.origin + "/event.js?mtime=%d";
let ws_sync = null; import('https://mustardmine.com/static/ws_sync.js').then(m => ws_sync = m);</script>
</head>
<body>
</body>
</html>
#}, file_stat("event.js")->?mtime), "type": "text/html"])); break;
		case "/event.js": req->response_and_finish((["file": Stdio.File("event.js"), "type": "text/javascript"])); break;
		default: req->response_and_finish((["data": "Not found", "error": 404, "type": "text/plain"])); break;
	}
}

void ws_msg(Protocols.WebSocket.Frame frm, mapping conn) {
	mixed data;
	if (catch {data = Standards.JSON.decode(frm->text);}) return; //Ignore frames that aren't text or aren't valid JSON
	if (!stringp(data->cmd)) return;
	if (data->cmd == "init") {
		if (conn->type) return; //Can't init twice
		if (data->type != "event" || data->group != "") return; //Only one type/group supported currently
		string group = (stringp(data->group) || intp(data->group)) ? data->group : "";
		conn->type = data->type; conn->group = group;
		websocket_types[data->type]->groups[group] += ({conn->sock});
	}
	if (!data->cmd) return; //Malformed message.
	if (function handler = this["wsmsg_" + conn->type + "_" + conn->group + "_" + data->cmd]) handler(conn, data);
	else write("Message to unknown type %O: %O\n", conn->type, data);
}

void ws_close(int reason, mapping conn) {
	if (mapping handler = websocket_types[conn->type]) handler->groups[conn->group] -= ({conn->sock});
	m_delete(conn, "sock"); //De-floop
}

void ws_handler(array(string) proto, Protocols.WebSocket.Request req) {
	if (req->not_query != "/ws") {req->response_and_finish((["error": 404, "type": "text/plain", "data": "Not found"])); return;}
	Protocols.WebSocket.Connection sock = req->websocket_accept(0);
	sock->set_id((["sock": sock])); //Minstrel Hall style floop
	sock->onmessage = ws_msg;
	sock->onclose = ws_close;
}

int main() {
	Protocols.WebSocket.Port(http_handler, ws_handler, 8085);
	return -1;
}

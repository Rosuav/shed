mapping websocket_types = (["event": (["groups": ([])])]);
mapping state = ([]); //Shared websocket state

constant index_html = #{<!DOCTYPE HTML>
<html lang=en>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Event status</title>
<script>let ws_type = "event", ws_group = "", ws_code = location.origin + "/event.js?mtime=%d";
let ws_sync = null; import('https://mustardmine.com/static/ws_sync.js').then(m => ws_sync = m);
let ws_host = location.hostname + ":" + location.port, ws_protocol_override = "ws://";
</script>
</head>
<body>
</body>
</html>
#};

class run_process {
	inherit Concurrent.Promise;
	Stdio.File stdout = Stdio.File();
	string output = "";
	protected void create(array(string) command, mapping|void modifiers) {
		modifiers = (modifiers || ([])) | (["callback": donecb, "stdout": stdout->pipe(Stdio.PROP_IPC)]);
		stdout->set_read_callback(data);
		Process.create_process(command, modifiers);
	}
	void data(mixed _, string blob) {output += blob;}
	void done(object proc) {
		if (proc->status() == 2) success((["rc": proc->wait(), "stdout": output]));
	}
	void donecb(object proc) {call_out(done, 0, proc);}
}

void send_updates_all(mapping|void sendme) {
	string text = Standards.JSON.encode((sendme || state) | (["cmd": "update"]), 4);
	foreach (websocket_types->event->groups[""], object sock)
		if (sock && sock->state == 1) sock->send_text(text);
}

void wsmsg_event__init(mapping conn, mapping msg) {
	if (conn->sock && conn->sock->state == 1) conn->sock->send_text(Standards.JSON.encode(state | (["cmd": "update"]), 4));
}

void http_handler(Protocols.HTTP.Server.Request req) {
	switch (req->not_query) {
		case "/":  req->response_and_finish((["data": sprintf(index_html, file_stat("event.js")->?mtime), "type": "text/html"])); break;
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
	else write("Unknown message to %O/%O: %O\n", conn->type, conn->group, data);
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

__async__ void rollout() {
	werror("Rolling out!\n");
	while (1) {
		//For some reason the Pike XWD decoder produces something oddly interlaced.
		//I don't have time to dig into why right now, so I'm letting imagemagick do the work for me.
		//At some point it would be worth trying to skip the unnecessary reencoding and dependency.
		//~ mapping proc = await(run_process(({"xwd", "-root"})));
		mapping proc = await(run_process(({"bash", "-c", "xwd -root | convert xwd:- png:-"})));
		werror("Proc rc %O %O\n", proc->rc, sizeof(proc->stdout));
		mixed img = Image.ANY.decode(proc->stdout);
		while (img->xsize() > 600) img = img->scale(0.5);
		write("Image %O\n", img);
		state->foo_image = "data:image/png;base64," + MIME.encode_base64(Image.PNG.encode(img), 1);
		send_updates_all((["foo_image": state->foo_image]));
		sleep(10);
	}
}

int main(int argc, array(string) argv) {
	Protocols.WebSocket.Port(http_handler, ws_handler, (argc > 1 && (int)argv[1]) || 8085);
	call_out(rollout, 1);
	return -1;
}

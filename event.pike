mapping websocket_types = (["event": (["groups": ([])])]);
mapping state = ([ //Shared websocket state
	"active": enumerate(9, 1, 1),
	"power_speed": "fast", //TODO: UI to change this
	"rollout": 1,
	"queue": ({ }),
]);

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

void update_state(mapping changes) {
	state |= changes;
	string text = Standards.JSON.encode(state | (["cmd": "update"]), 4);
	foreach (websocket_types->event->groups[""] || ({ }), object sock)
		if (sock && sock->state == 1) sock->send_text(text);
}

void wsmsg_event__enqueue(mapping conn, mapping msg) {
	//TODO: Args to the command?
	if (this["action_" + msg->action]) update_state((["queue": state->queue + ({msg->action})]));
}

void wsmsg_event__rollout(mapping conn, mapping msg) {update_state((["rollout": !state->rollout])); rollout();}
void wsmsg_event__enable(mapping conn, mapping msg) {update_state((["enabled": !state->enabled]));}
void wsmsg_event__activate(mapping conn, mapping msg) {update_state((["activate": !state->activate]));}
void wsmsg_event__active(mapping conn, mapping msg) {
	if (!intp(msg->idx) || msg->idx < 1 || msg->idx > 9) return;
	if (msg->state) state->active += ({msg->idx});
	else state->active -= ({msg->idx});
}

//TODO: Have a way to reload the server. Either rework so we can hot reload or make it dump state and bounce.
void wsmsg_event__pull(mapping conn, mapping msg) {
	run_process(({"git", "pull"}));
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

__async__ void capture(string kwd) {
	if (mixed ex = catch {
		//For some reason the Pike XWD decoder produces something oddly interlaced.
		//I don't have time to dig into why right now, so I'm letting imagemagick do the work for me.
		//At some point it would be worth trying to skip the unnecessary reencoding and dependency.
		//~ mapping proc = await(run_process(({"xwd", "-root"})));
		mapping proc = await(run_process(({"bash", "-c", "xwd -root | convert xwd:- png:-"})));
		Image.Image img = Image.ANY.decode(proc->stdout)->scale(0.5);
		//while (img->xsize() > 600) img = img->scale(0.5);
		update_state(([kwd: "data:image/png;base64," + MIME.encode_base64(Image.PNG.encode(img), 1)]));
	}) werror("Error in capture %O:\n%s\n", kwd, describe_backtrace(ex));
}

array subaction_power(int count) {
	string delay = "100";
	if (state->power_speed == "fast") delay = "50";
	if (state->power_speed == "slow") delay = "200";
	return ({"mousemove", "480", "325", "click", "--repeat", (string)count, "--delay", delay, "1"});
}

array make_upgrade(int pos, int(1bit) upg) { //Upgrade or activate - if upg is 0, will activate
	return ({"mousemove",
		(string)(480 + 650 * (pos > 4) + 150 * upg),
		(string)(325 + 150 * (pos % 5) + 50 * upg),
		"click", "1",
	});
}

array subaction_upgrades() {
	array ac = state->active;
	if (state->shuffle_upgrades) {
		ac += ({ });
		Array.shuffle(ac);
	}
	return make_upgrade(ac[*], 1) * ({ });
}

array subaction_activations() {
	return state->activate ? make_upgrade(enumerate(9, 1, 1)[*], 0) * ({ }) : ({ });
}

__async__ void action_goals() {
	await(run_process("xdotool mousemove 1850 300 click 1 sleep 0.5" / " "));
	await(capture("goals_image"));
	array cmd = ({"xdotool"});
	for (int y = 400; y <= 1000; y += 200) cmd += ({"mousemove", "900", (string)y, "click", "1"});
	await(run_process(cmd + ({"sleep", "0.1", "key", "Escape", "sleep", "0.5"})));
}

__async__ void action_angels() {
	await(run_process("xdotool mousemove 255 720 click 1 sleep 0.5" / " "));
	await(capture("angels_image"));
	await(run_process("xdotool key Escape sleep 0.5" / " "));
}

array(string) subaction_do_upgrades(string which, int qty) {
	return ({"mousemove", "255", which == "managers" ? "620" : "520", "click", "1", "sleep", "0.5"})
		+ ("mousemove 955 250 click 1" / " ") * (which == "angel")
		+ ({"mousemove", "830", "680", "click", "--repeat", (string)qty, "--delay", "50", "1", "sleep", "0.5", "key", "Escape"});
}

__async__ void action_cycle() {
	await(run_process(
		//The cycling itself
		"xdotool mousemove 255 720 click 1 sleep 0.5 mousemove 1640 710 click 1 sleep 0.5 mousemove 710 800 click 1 sleep 0.5 key --delay 0.25 Escape Escape sleep 0.25" / " "
		//Start some money moving
		+ subaction_power(1) + make_upgrade(1, 0) + subaction_power(20)
		//Upgrade everything once, and activate
		+ make_upgrade(enumerate(9, 1, 1)[*], 1) * ({ }) + subaction_power(20) + make_upgrade(enumerate(9, 1, 1)[*], 0) * ({ })
		//TODO: Power again, then managers, then power, then upgrades and (maybe) angel upgrades
	));
}

__async__ void action_batchsize() {await(run_process("xdotool mousemove 1780 75 click 1" / " "));}
__async__ void action_cash_upgrades() {await(run_process(({"xdotool"}) + subaction_do_upgrades("cash", 50)));}
__async__ void action_angel_upgrades() {await(run_process(({"xdotool"}) + subaction_do_upgrades("angel", 20)));}
__async__ void action_managers() {await(run_process(({"xdotool"}) + subaction_do_upgrades("managers", 9)));}

__async__ void rollout() {
	werror("Rolling out!\n");
	while (state->rollout) if (mixed ex = catch {
		if (await(run_process(({"xdotool", "getactivewindow", "getwindowname"})))->stdout != "AdCap!\n") {
			//TODO: Pause rather than halt, or have a way to trigger resumption
			write("Focus is gone, halting\n");
			update_state((["rollout": 0]));
			break;
		}
		capture("base_image");
		if (state->enabled) await(run_process(({"xdotool",
			@subaction_power(state->power_count || 75),
			@subaction_upgrades(),
			@subaction_activations(),
			@subaction_power(1),
		})));
		if (sizeof(state->queue)) {
			[string cmd, array rest] = Array.shift(state->queue);
			update_state((["queue": rest]));
			await(this["action_" + cmd]());
			continue;
		}
		sleep(2);
	}) {
		werror("Exception during rollout! See log.\n%s\n", describe_error(ex));
		Stdio.append_file("event-rollout.log", sprintf("%sException during rollout:\n%s\n\n", ctime(time()), describe_backtrace(ex)));
	}
}

int main(int argc, array(string) argv) {
	Protocols.WebSocket.Port(http_handler, ws_handler, (argc > 1 && (int)argv[1]) || 8085);
	call_out(rollout, 1);
	return -1;
}

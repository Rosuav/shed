//Mark out an area on your screen
//Link with OBS to crop a desktop capture

object mainwindow, sock;
string obsurl = "ws://localhost:4455/";
string obspwd = "<password>"; //Optional if obspwdhash is used
string obspwdhash;
string obsinput = "Screen Capture (XSHM)";
//Deltas between the window edges and the crop edges. Most likely, these will be equal to the window frame size in pixels.
constant FRAME_LEFT = 10, FRAME_TOP = 32, FRAME_RIGHT = 10, FRAME_BOTTOM = 10;
int MONITOR_LEFT = 1920, MONITOR_TOP = 0; //FIXME: Query which monitor is being captured, then find its position
int SCREEN_WIDTH = 1920, SCREEN_HEIGHT = 1080; //FIXME: Query the size of either the desktop or the OBS input

int nextid = 1;
mapping(int:function) obscb = ([]);
Concurrent.Future|void send_obs(string|zero type, mapping msg) {
	int id;
	if (type) msg = (["op": 6, "d": (["requestType": type, "requestId": id = nextid++, "requestData": msg])]);
	sock->send_text(Standards.JSON.encode(msg));
	if (id) {
		Concurrent.Promise prom = Concurrent.Promise();
		obscb[id] = prom->success;
		return prom->future();
	}
}

int skip_next_resize;
void resize(object win, object ev) {
	if (skip_next_resize) {skip_next_resize = 0; return;}
	mapping pos = win->get_position(), sz = win->get_size();
	write("Resize %d,%d :: %d,%d\n", pos->x, pos->y, sz->width, sz->height);

	send_obs("SetInputSettings", ([
		"inputName": obsinput,
		"inputSettings": ([
			"cut_left": pos->x + FRAME_LEFT - MONITOR_LEFT,
			"cut_top": pos->y + FRAME_TOP - MONITOR_TOP,
			"cut_right": SCREEN_WIDTH + MONITOR_LEFT - FRAME_LEFT + FRAME_RIGHT - pos->x - sz->width,
			"cut_bot": SCREEN_HEIGHT + MONITOR_TOP - FRAME_TOP + FRAME_BOTTOM - pos->y - sz->height,
		]),
	]));
}

__async__ void query_size() {
	mapping resp = await(send_obs("GetInputSettings", (["inputName": obsinput])));
	mapping pos = resp->inputSettings;
	mainwindow->move(MONITOR_LEFT - FRAME_LEFT + pos->cut_left,
		MONITOR_TOP - FRAME_TOP + pos->cut_top);
	mainwindow->resize(SCREEN_WIDTH - FRAME_RIGHT - pos->cut_right - pos->cut_left,
		SCREEN_HEIGHT - FRAME_BOTTOM - pos->cut_bot - pos->cut_top);
	call_out(lambda() {
		mainwindow->shape_combine_mask(GTK2.GdkBitmap(Image.Image(1, 1, 0, 0, 0)), 0, 0);
		skip_next_resize = 1;
		mainwindow->signal_connect("configure-event", resize, 0, "", 1);
	}, 0.125);
}

void ws_msg(Protocols.WebSocket.Frame frm) {
	mapping msg;
	if (catch {msg = Standards.JSON.decode(frm->text);}) return;
	switch (msg->op) {
		case 0: { //HELLO
			write("Connected to OBS\n");
			mapping auth = msg->d->authentication;
			if (!obspwdhash) obspwdhash = MIME.encode_base64(Crypto.SHA256.hash(obspwd + auth->salt), 1);
			send_obs(0, (["op": 1, "d": (["rpcVersion": 1,
				"authentication": MIME.encode_base64(Crypto.SHA256.hash(obspwdhash + auth->challenge), 1),
				"eventSubscriptions": 0,
			])]));
			query_size();
			break;
		}
		case 2: break;
		case 7: //RequestResponse
			if (function cb = m_delete(obscb, msg->d->requestId)) cb(msg->d->responseData);
			break;
		default: write("%O\n", msg); break;
	}
}

int main() {
	GTK2.setup_gtk();
	mainwindow = GTK2.Window((["title": "Cropper"]))->add(GTK2.Label("Loading..."));
	mainwindow->set_default_size(150, 100); //TODO: GetInputSettings and set position
	mainwindow->set_keep_above(1);
	mainwindow->signal_connect("destroy", lambda() {exit(0);});
	mainwindow->show_all();
	sock = Protocols.WebSocket.Connection();
	sock->onclose = lambda() {exit(0, "Socket closed, exiting.\n");};
	sock->onmessage = ws_msg;
	sock->connect(obsurl);
	return -1;
}

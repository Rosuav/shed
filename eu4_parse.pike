#define POLYGLOT "This script can be run as Python or Pike code and is a minimal client for the EU4 parser. \
"""
//The bulk of this code was moved directly from the main EU4 parser as part of the migration.
class ClientConnection(Stdio.File sock) {
	Stdio.Buffer incoming = Stdio.Buffer(), outgoing = Stdio.Buffer();
	inherit Concurrent.Promise;
	protected void create() {
		::create();
		sock->set_buffer_mode(incoming, outgoing);
		sock->set_nonblocking(sockread, 0, sockclosed);
	}

	int keysend_provid;
	mixed keysend_callout;
	int terminate = 0;
	void find_eu4() {
		//Check which window has focus. If it seems to be EU4, poke keys, otherwise wait.
		mapping focus = Process.run(({"xdotool", "getactivewindow", "getwindowname"}));
		if (!has_value(focus->stdout, "Europa Universalis IV")) {keysend_callout = call_out(find_eu4, 0.5); return;}
		keysend_callout = 0;
		//TODO: Allow search mode instead of the above retry loop waiting for focus
		Process.create_process(({"xdotool",
			//"search", "--name", "Europa Universalis IV",
			"key", "--delay", "125", //Hurry the typing along a bit
			"f", @((string)keysend_provid / ""), "Return", //Send "f", then type the province ID, then hit Enter
		}))->wait();
		if (terminate) exit(0);
	}
	void sockread() {
		while (array ret = incoming->sscanf("%s\n")) {
			write("%s\n", ret[0]); //good for debugging
			if (sscanf(ret[0], "provfocus %d", int provid) && provid) {
				keysend_provid = provid;
				if (keysend_callout) continue; //Already waiting. Replace the province ID with a new one.
				keysend_callout = call_out(find_eu4, 0);
			}
			if (ret[0] == "exit") terminate = 1;
		}
	}
	void sockclosed() {
		sock->close();
		success(1 + terminate);
	}
}

void establish_client_connection(string ip, string cmd, int reconnect) {
	Stdio.File sock = Stdio.File();
	string writeme;
	while (1) {
		writeme = sock->connect(ip, 1444, cmd + "\n");
		if (writeme || !reconnect) break;
		sleep(10);
	}
	if (!writeme) exit(0, "Unable to connect to %s : 1444\n", ip);
	sock->write(writeme); //TBH there shouldn't be any residual data, since it should be a single packet.
	object conn = ClientConnection(sock);
	conn->then() {if (__ARGS__[0] != 2) {
		if (reconnect) call_out(establish_client_connection, 10, ip, cmd, reconnect);
		else exit(0);
	}};
	//Single-report goto-province mode is currently broken.
}

int main(int argc, array(string) argv) {
	if (argc > 2) {
		int reconnect = has_value(argv, "--reconnect"); argv -= ({"--reconnect"});
		establish_client_connection(argv[1], argv[2..] * " ", reconnect);
		return -1;
	}
	write("USAGE: pike %s ipaddress notify province Name\n");
}
#ifdef G
#define POLYGLOT2 "End of Pike code. \
"""
# Python code follows. This should be restricted to the standard library and as broadly
# compatible as possible (currently aiming for 3.7-3.11). It should have all the basic
# client-side functionality and that is all.

import socket
import subprocess
import sys
import time
# First arg is server name/IP; the rest are joined and sent as a command.
# If the second arg is "province", then the result is fed as keys to EU4.
# Otherwise, this is basically like netcat/telnet.
# If --reconnect, will auto-retry until connection succeeds, ten-second
# retry delay. Will also reconnect after disconnection.
if len(sys.argv) < 3:
	print("USAGE: python3 %s ipaddress notify province Name")
	sys.exit(0)

def goto(provid):
	# NOTE: This is currently synchronous, unlike the Pike version, which is
	# fully asynchronous. So if you queue multiple and then switch focus to
	# EU4, it will go through all of them. Also, retries for 30 seconds max.
	for retry in range(60):
		proc = subprocess.run(["xdotool", "getactivewindow", "getwindowname"], encoding="UTF-8", capture_output=True, check=True)
		if "Europa Universalis IV" in proc.stdout:
			subprocess.run(["xdotool", "key", "--delay", "125", "f", *list(str(provid)), "Return"], check=True)
			return
		time.sleep(0.5)
	print("Unable to find game window, not jumping to province")

reconnect = "--reconnect" in sys.argv
if reconnect: sys.argv.remove("--reconnect")
def client_connection():
	while "get connection":
		try: sock = socket.create_connection((sys.argv[1], 1444))
		except (ConnectionRefusedError, socket.gaierror) if reconnect else (): pass
		else: break
		time.sleep(10)
	print("Connected, listening for province focus messages")
	sock.send(" ".join(sys.argv[2:]).encode("UTF-8") + b"\n")
	partial = b""
	while "moar data":
		data = sock.recv(1024)
		if not data: break
		[*lines, data] = (partial + data).split(b"\n")
		for line in lines:
			line = line.decode("UTF-8")
			print(line)
			if line.startswith("provfocus "): goto(int(line.split(" ")[1]))
			if line.strip() == "exit": sys.exit(0)

while "reconnect":
	client_connection()
	if not reconnect: break
	time.sleep(10)

#endif

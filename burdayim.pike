/* IP Group Telephony system based around prior art in Her Yeri Parlak

Named after a minor artifact in Soyutlanma, and before that from Turkish
"burdayım" = "I am here", this allows a moderate number of people to
communicate on a global channel, while a small number of people (or several
such groups) communicate on private channels.

Timing: All packets get usec time incorporated. On receipt, calculate offset:
your_time() - packet time
This value is the sum of two unknown quantities: the transmission latency
and the clock difference between the two computers. We assume that the clock
difference is an approximately stable quantity, and we can be confident that
the latency is a nonnegative value. Therefore we take the lowest total ever
seen and take that to be the clock offset. (Closest to negative infinity,
not closest to zero; the clock offset could be either direction.)

Having established a "best ever seen" offset, we assume that the current
packet's offset exceeds that best by a value representing only the latency.
As such, we can now discard any packets with latency in excess of some
predetermined value (eg 1500ms). In the face of clock errors or other time
discrepancies, this will either cope smoothly (if the clock offset is
lowered permanently and stably), or cause the audio to be muted (if the
offset increases permanently) or intermittent (if it fluctuates). Anyone who
hears silence can bounce the receiver to reset all time offsets and force a
recalculation; the fluctuating time issue is fundamentally unresolvable, and
the only solution is to have a latency window that exceeds the fluctuation.

The upshot of this is that the clock used does not actually need to have any
correlation to wall time. It doesn't even have to be consistent across nodes
in the group! Implementations are encouraged to use a monotonic clock if one
is available.

CJA 20170506: It appears that latency, even on a cheap pocket wifi device,
averages 1-2ms. So it would not be all that unreasonable to drop packets
aggressively - even at 10ms, and definitely at 25ms. Forget 1500ms! :)
*/
constant ADDR = "224.0.0.1"; //Multicast address: All hosts on current network.
constant PORT = 5170;
constant audio_format = ({"-t", "raw", "-f", "s16_le", "-r", "12000", "-B", "20000"});
Stdio.UDP|array(Stdio.UDP) udp = Stdio.UDP()->bind(PORT, "0.0.0.0", 1); //NOTE: *Not* enabling IPv6; this app is v4-only.
array(string) ips;
string sendchannel = "global";
array(string) recvchannels;
string transmitmode = "udp"; //or "tcp"
Stdio.Port mainsock; //Only if transmitmode=="tcp"
array(Stdio.File) tcpsocks = ({ });
constant TCP_PACKET_SIZE = 256;

void ignore() { } //Ignore anything they send us.
void accepttcp()
{
	object sock = mainsock->accept();
	sock->set_nonblocking(ignore, 0, lambda() {tcpsocks -= ({sock});});
	tcpsocks += ({sock});
}

class Sender(string ip)
{
	int expectseq;
	float active;
	int offset = UNDEFINED;
	Stdio.File pipe;
	Stdio.File sock;
	string tcpbuf = "";
	void create()
	{
		write("New voice on comms: %s\n", ip);
		Process.create_process(({"aplay"}) + audio_format, ([
			"stdin": (pipe = Stdio.File())->pipe(),
		]));
	}

	void sockread(mixed id, string data)
	{
		tcpbuf += data;
		if (sizeof(tcpbuf) < TCP_PACKET_SIZE) return; //Can't possibly have a full packet
		int pktlen = search(tcpbuf, '\n') + TCP_PACKET_SIZE;
		if (sizeof(tcpbuf) < TCP_PACKET_SIZE) return; //Don't have the headers and a packet's worth of data
		data = tcpbuf[..pktlen]; tcpbuf = tcpbuf[pktlen+1..];
		handle_packet(data, this); //TODO: Bring handle_packet in as a method
	}

	void sockgone() {sock = 0;}
	void establish_tcp()
	{
		//Establish a TCP connection, since this sender doesn't broadcast
		//its content via UDP.
		if (sock) return;
		write("Connecting to %s via TCP...\n", ip);
		sock = Stdio.File(); sock->open_socket();
		sock->set_nonblocking(sockread, 0, sockgone);
		sock->connect(ip, PORT);
	}
}
mapping(string:object) senders = ([]);
int basetime = time();

mapping(string:int) packetcount = ([]);
void showcounts() {write("%O\n", packetcount); packetcount = ([]); call_out(showcounts, 30);}

string lastsend;
string sendbuf = "";
int sequence;
void send(mixed id, string data)
{
	sendbuf += data;
	if (transmitmode == "tcp")
	{
		//In TCP mode, we always chunk to exactly TCP_PACKET_SIZE bytes.
		if (sizeof(sendbuf) < TCP_PACKET_SIZE) return;
		data = sendbuf[..TCP_PACKET_SIZE-1]; sendbuf = sendbuf[TCP_PACKET_SIZE..];
	}
	else
	{
		//In UDP mode, we send whatever we have, because a packet is a packet.
		//if (sizeof(sendbuf) < 512) return; //Always send good-sized packets, to reduce packet collisions (doesn't seem to help)
		//PROTECTION: Always send an even number of bytes. This is probably never
		//going to trigger, but if we ever do get an odd number of bytes, it'd be
		//possible for a lost UDP packet to leave us mismatched.
		//TODO: Measure this based on the audio_format above.
		if (sizeof(sendbuf) & 1) {data = sendbuf[..<1]; sendbuf = sendbuf[<0..];}
		else {data = sendbuf; sendbuf = "";}
	}
	if (sendchannel != lastsend) write("Now sending on %O\n", lastsend = sendchannel);
	packetcount["sent"]++;
	packetcount["sentbytes"] += sizeof(data);
	if (sendchannel != "")
	{
		string packet = sprintf("T%d C%s Q%d\n%s", gethrtime(), sendchannel, ++sequence, data);
		if (transmitmode == "tcp")
			tcpsocks->write(packet);
		else
			udp->send(ADDR, PORT, packet, 2);
	}
	string line = "";
	float cutoff = time(basetime) - 0.5;
	foreach (sort(indices(senders)), string ip)
		if (senders[ip]->active > cutoff) line += " " + ip;
	write(line + "\e[K\r");
}

void beacon()
{
	//When transmitting on TCP, we send out a UDP beacon periodically.
	//TCP mode uses significantly more packets per second than UDP
	//(with the possible exception that UDP might send smaller packets;
	//certainly more than UDP with an equivalent minimum packet payload),
	//but by maintaining a retry loop in low level kernel facilities
	//rather than using an application-level retry, we hopefully gain
	//enough to make it worthwhile.
	call_out(beacon, 1);
	udp->send(ADDR, PORT, "Beacon", 2);
}

void recv(mapping(string:int|string) info)
{
	string ip = info->ip;
	packetcount[""]++;
	if (info->port != PORT) return; //Not from one of us.
	object sender = senders[ip];
	if (!sender) senders[ip] = sender = Sender(ip);
	packetcount[ip]++;
	if (sscanf(info->data, "RESEND %d", int wantseq) && wantseq)
	{
		//Resend request.
		write("RESEND REQUEST - want %d, we last sent %d\n", wantseq, sequence);
		packetcount["resend ofs " + (sequence - wantseq)/10]++;
		return;
	}
	if (info->data == "Beacon")
	{
		//The other end is asking us to connect via TCP. Let's oblige.
		sender->establish_tcp();
		return;
	}
	handle_packet(info->data, sender);
}

void handle_packet(string packet, Sender sender)
{
	string ip = sender->ip;
	//NOTE: Currently the packet format is strict, but it's designed to be able to be
	//more intelligently parsed in the future, with space-delimited tokens and marker
	//letters, ending with a newline before the payload. (The payload is binary data,
	//which normally will be an audio blob; the header is ASCII text. Maybe UTF-8.)
	sscanf(packet, "T%d C%s Q%d\n%s", int packettime, string chan, int seq, string(0..255) data);
	if (!data) return; //Packet not in correct format.
	if (has_value(ips, ip)) chan = "_" + chan; //Normally ignore our loopback
	int expect = sender->expectseq || seq;
	if (seq < expect) werror("WARNING: %s seq non-monotonic! %d expected %d\n", ip, seq, expect);
	else if (seq == expect + 1)
	{
		packetcount[ip + " dropped"]++;
		//Not currently sending resend requests (they always arrive too late)
		//udp->send(ip, PORT, "RESEND " + sender->expectseq, 2);
	}
	else if (seq > expect) packetcount[ip + " gap " + (seq - expect)]++;
	sender->expectseq = seq + 1;
	packetcount[ip + " bytes"] += sizeof(data);
	if (!has_value(recvchannels, chan)) return; //Was sent to a channel we don't follow.
	int offset = gethrtime() - packettime;
	int lastofs = sender->offset;
	if (undefinedp(lastofs) || offset < lastofs) sender->offset = lastofs = offset;
	int lag = offset - lastofs;
	if (lag > 50000) {werror("%s: lag %d usec\n", ip, lag); return;} //Too old? Drop it.
	packetcount[ip + " lag " + (lag/10000) + "0ms"]++;
	sender->active = time(basetime);
	sender->pipe->write(data);
	packetcount["written"]++;
}

mapping(string:GTK2.Widget) win = ([]);

//Persistent configs
mapping(string:string|array|mapping) config = ([
	"normchan": "", "pttchan": "global",
	"recvchan": "global",
]);
void saveconfig() {Stdio.write_file(".burdayimrc", Standards.JSON.encode(config));}
void loadconfig() {catch {config = Standards.JSON.decode(Stdio.read_file(".burdayimrc")) || config;};}
void sig_mainwindow_delete_event() {exit(0);}

void sig_norm_global_clicked() {win->norm_channel->set_text("global");}
void sig_norm_mute_clicked() {win->norm_channel->set_text("");}
void sig_ptt_global_clicked() {win->ptt_channel->set_text("global");}
void sig_ptt_mute_clicked() {win->ptt_channel->set_text("");}
void sig_norm_channel_changed() {checkchan("norm");}
void sig_ptt_channel_changed() {checkchan("ptt");}
void checkchan(string mode)
{
	string chan = config[mode + "chan"] = win[mode + "_channel"]->get_text();
	object glob = chan == "global" ? win->highlight : UNDEFINED;
	object mute = chan == "" ? win->highlight : UNDEFINED;
	foreach (({GTK2.STATE_NORMAL, GTK2.STATE_ACTIVE, GTK2.STATE_SELECTED, GTK2.STATE_PRELIGHT}), int state)
	{
		win[mode + "_global"]->modify_bg(GTK2.STATE_NORMAL, glob);
		win[mode + "_mute"]->modify_bg(GTK2.STATE_NORMAL, mute);
	}
	saveconfig();
}

void sig_recv_channels_changed()
{
	//TODO: Also populate some sort of list of destination channels.
	//This would allow the SM to receive a large number of low-traffic
	//channels (eg FOH, Techs, etc), and use them for occasional calls
	//only (and the other people on the channel wouldn't have global).
	config->recvchan = win->recv_channels->get_text();
	recvchannels = (config->recvchan - " ") / ",";
	saveconfig();
}

int sig_b4_mainwindow_key_press_event(object self, object ev)
{
	if (ev->keyval != 32) return 0;
	sendchannel = config->pttchan;
	return 1;
}

int sig_b4_mainwindow_key_release_event(object self, object ev)
{
	if (ev->keyval != 32) return 0;
	sendchannel = config->normchan;
	return 1;
}

int main(int argc, array(string) argv)
{
	call_out(showcounts, 30);
	loadconfig();
	udp->set_read_callback(recv);
	ips = sort(values(Stdio.gethostip())->ips * ({ }));
	if (argc > 1 && has_value(ips, argv[1])) ips = ({argv[1]});
	write("My IP: %s\n", ips * " + ");
	//We pick the first one (after sorting textually) to be our identity.
	//Since we listen on every available IP, this won't majorly hurt,
	//and the sort ensures that it's stable, if a little arbitrary.
	//Most computers will have just one IP anyway, so none of this matters.
	udp->enable_multicast(ips[0]);
	udp->add_membership(ADDR);
	if (has_value(argv, "--send-all"))
	{
		//To avoid craziness in a multi-network situation, send via
		//every available IP address, not just the default. Note that
		//this can cause split-brain situations if there are actually
		//multiple networks using the cans, but otherwise, it means
		//you don't have to explicitly pick an IP or interface.
		udp = ({udp});
		foreach (ips[1..], string ip)
		{
			udp += ({Stdio.UDP()->bind(PORT)});
			udp[-1]->enable_multicast(ip);
		}
	}
	if (has_value(argv, "--tcp"))
	{
		//Switch to TCP transmission with UDP handshake.
		//Probably not compatible with --send-all (untested).
		transmitmode = "tcp";
		call_out(beacon, 0.01);
		mainsock = Stdio.Port(PORT, accepttcp); //Note, again, IPv4 only.
	}
	GTK2.setup_gtk();
	win->highlight = GTK2.GdkColor(0, 255, 255);
	win->mainwindow = GTK2.Window((["title": "Burdayim"]))->add(GTK2.Vbox(0, 10)
		->add(GTK2.Frame("Receive channels (commas to separate)")
			->add(win->recv_channels = GTK2.Entry()->set_text(config->recvchan))
		)
		->add(GTK2.Hbox(0, 10)
			->add(GTK2.Frame("Normal channel")->add(GTK2.Vbox(0, 10)
				->add(win->norm_channel = GTK2.Entry()->set_text(config->normchan))
				->add(GTK2.HbuttonBox()
					->add(win->norm_global = GTK2.Button("Global"))
					->add(win->norm_mute = GTK2.Button("Mute"))
				)
			))
			->add(GTK2.Frame("Push-to-talk channel")->add(GTK2.Vbox(0, 10)
				->add(win->ptt_channel = GTK2.Entry()->set_text(config->pttchan))
				->add(GTK2.HbuttonBox()
					->add(win->ptt_global = GTK2.Button("Global"))
					->add(win->ptt_mute = GTK2.Button("Mute"))
				)
			))
		)
	)->show_all();
	checkchan("norm"); checkchan("ptt"); sig_recv_channels_changed();
	sendchannel = config->normchan;
	//Lifted and simplified from Gypsum's collect_signals
	foreach (indices(this), string key) if (has_prefix(key, "sig_") && callablep(this[key]))
	{
		//Function names of format sig_x_y become a signal handler for win->x signal y.
		//(Note that classes are callable, so they can be used as signal handlers too.)
		//This may pose problems, as it's possible for x and y to have underscores in
		//them, so we scan along and find the shortest such name that exists in win[].
		//If there's none, ignore the callable (currently without any error or warning,
		//despite the explicit prefix). This can create ambiguities, but only in really
		//contrived situations, so I'm deciding not to care. :)
		array parts=(key/"_")[1..];
		int b4=(parts[0]=="b4"); if (b4) parts=parts[1..]; //sig_b4_some_object_some_signal will connect _before_ the normal action
		for (int i=0;i<sizeof(parts)-1;++i) if (mixed obj = win[parts[..i]*"_"])
		{
			if (objectp(obj) && callablep(obj->signal_connect))
			{
				obj->signal_connect(parts[i+1..]*"_", this[key], UNDEFINED, UNDEFINED, b4);
				break;
			}
		}
	}
	Stdio.File recorder = Stdio.File();
	Process.create_process(({"arecord"}) + audio_format, ([
		"stdin": Stdio.File("/dev/null"), "stdout": recorder->pipe(),
		"callback": lambda() {exit(0);},
	]));
	recorder->set_read_callback(send);
	return -1;
}

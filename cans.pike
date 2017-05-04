/* Throughput and analysis measurement for the Her Yeri Parlak Cans system */
constant PORT = 517;
Stdio.UDP udp = Stdio.UDP()->bind(PORT, "::", 1);

mapping(string:float) active = ([]);
int basetime = time();

void send()
{
	call_out(send, 0.01);
	udp->send("192.168.1.255", PORT, "Hello", 2); //TODO: Detect broadcast addr
	string line = "";
	float cutoff = time(basetime) - 0.5;
	foreach (sort(indices(active)), string ip)
		if (active[ip] > cutoff) line += " " + ip;
	write(line + "\e[K\r");
}

void recv(mapping(string:int|string) info)
{
	if (info->port != PORT) return;
	active[info->ip] = time(basetime);
}

int main()
{
	udp->set_read_callback(recv)->enable_broadcast();
	call_out(send, 0.01);
	return -1;
}

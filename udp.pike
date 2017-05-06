//Experiments with UDP transmission and packet loss
constant ADDR = "224.0.0.1"; //Multicast address: All hosts on current network.
constant PORT = 1227;
Stdio.UDP udp = Stdio.UDP()->bind(PORT);

int sequence = 0;
mapping stats = ([]), lastseq = ([]);
void send()
{
	call_out(send, 0.025);
	udp->send(ADDR, PORT, (string)++sequence);
}

void recv(mapping(string:int|string) info)
{
	int expect = lastseq[info->ip] + 1;
	int seq = (int)info->data;
	stats[info->ip + " lost"] += seq - expect;
	stats[info->ip + " rcvd"]++;
	lastseq[info->ip] = seq;
}

void showstats()
{
	call_out(showstats, 10);
	write("%O\n", stats);
	stats = ([]);
}

int main()
{
	udp->set_read_callback(recv);
	string ip = values(Stdio.gethostip())[0]->ips[0];
	write("I am: %s\n", ip);
	udp->enable_multicast(ip);
	udp->add_membership(ADDR);
	send();
	call_out(showstats, 10);
	return -1;
}

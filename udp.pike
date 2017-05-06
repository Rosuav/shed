//Experiments with UDP transmission and packet loss
constant ADDR = "224.0.0.1"; //Multicast address: All hosts on current network.
constant PORT = 12345;
Stdio.UDP udp = Stdio.UDP()->bind(PORT);

int sequence = 0;
mapping recvseq = ([]), lost = ([]);
void send()
{
	call_out(send, 0.01);
	udp->send(ADDR, PORT, (string)++sequence);
}

void recv(mapping(string:int|string) info)
{
	int expect = recvseq[info->ip] + 1;
	int seq = (int)info->data;
	lost[info->ip] += seq - expect;
	recvseq[info->ip] = seq;
}

void stats()
{
	call_out(stats, 10);
	write("Lost: %O\n", lost);
	lost = ([]);
}

int main()
{
	udp->set_read_callback(recv);
	udp->enable_multicast(values(Stdio.gethostip())[0]->ips[0]);
	udp->add_membership(ADDR);
	send();
	call_out(stats, 10);
	return -1;
}

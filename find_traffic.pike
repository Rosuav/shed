void allow(int addr, int len, string mark)
{
        string block=sprintf("%d.%d.%d.%d/%d",addr>>24,(addr>>16)&255,(addr>>8)&255,addr&255,len);
	//string block = sprintf("%d:%d", addr, addr + (1<<(16-len)) - 1);
        write("Allowing: %s\n",block);
        Process.create_process(({"iptables","-I","INPUT","--src",block,"-j","ACCEPT", "-m", "comment", "--comment", mark}))->wait();
}

int main()
{
	int count_packets = 0; //TODO: Have a command-line option to set this. 0 counts bytes, 1 counts packets.
        int addr;
	//Clean out old ones
	array(int) deleteme = ({ });
	foreach (Process.run("iptables --line-numbers -nvxL INPUT")->stdout/"\n", string line)
		if (sscanf(line, "%d %*s/* probe: %d */", int idx, int probe) == 3) deleteme += ({idx});
	foreach (reverse(deleteme), int idx) Process.create_process(({"iptables","-D","INPUT",(string)idx}))->wait();
	//TODO: Do the above on Ctrl-C too
	int size = 32; //To probe TCP or UDP port numbers, change size to 16 and adjust allow()
        for (int len=1;len<=size;++len)
        {
                allow(addr, len, "probe: 0");
                allow(addr+(1<<(size-len)), len, "probe: 1");
		array(int) idx = ({-1, -1}), pkt = ({0, 0}), bytes = ({0, 0});
		while (1)
		{
			sleep(2);
			foreach (Process.run("iptables --line-numbers -nvxL INPUT")->stdout/"\n", string line) {
				if (sscanf(line, "%d %d %d %*s/* probe: %d */", int i, int p, int b, int probe) == 5) {
					idx[probe] = i;
					pkt[probe] = p;
					bytes[probe] = b;
				}
			}
			write("%d/%d for 0, %d/%d for 1\n", bytes[0], pkt[0], bytes[1], pkt[1]);
			int traf0 = count_packets ? pkt[0] * 5 : bytes[0]; //Packet count is scaled by 5 for the sake
			int traf1 = count_packets ? pkt[1] * 5 : bytes[1]; //of the "insufficient traffic" check
			if (traf0 < 10000 && traf1 < 10000) {write("Insufficient traffic to be confident; waiting for more.\n"); continue;}
			if (traf1>traf0) addr+=(1<<(size-len));
			break;
		}
                Process.create_process(({"iptables","-D","INPUT",(string)max(idx[0], idx[1])}))->wait();
                Process.create_process(({"iptables","-D","INPUT",(string)min(idx[0], idx[1])}))->wait();
        }
	string ip=sprintf("%d.%d.%d.%d",addr>>24,(addr>>16)&255,(addr>>8)&255,addr&255);
	Process.create_process(({"whois",ip}))->wait();
	Process.create_process(({"ip","r","get",ip}))->wait();
}

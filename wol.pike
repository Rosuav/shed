/*
Trigger Wake-On-LAN based on an IPv6 address, assuming that it has the computer's MAC address encoded into it.
Parses out the MAC address by taking the appropriate octets and inverting one bit:
2001:44b8:4192:fb00:21d:9ff:fea9:319f -> 00:1d:09:a9:31:9f
*/

int main(int argc,array(string) argv)
{
	if (argc<2) exit(0,"USAGE: pike wol ipv6_address\n");
	Stdio.UDP mainsock=Stdio.UDP();
	mainsock->bind(2017)->enable_broadcast(); //Port doesn't matter.
	foreach (argv[1..],string ip)
	{
		if (ip=="yosemite") ip="00:1e:37:d8:eb:36";
		array(int) addr=Protocols.IPv6.parse_addr(ip);
		string mac;
		if (addr)
		{
			addr[4]^=0x200;
			mac=sprintf("%@2c",addr[4..]); mac=mac[..2]+mac[5..];
		}
		else mac=(string)array_sscanf(ip,"%x:%x:%x:%x:%x:%x");
		mainsock->send("192.168.0.255",2017,"\xFF"*6+mac*16);
	}
}

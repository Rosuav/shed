#!/usr/local/bin/pike
/*
Maintain /etc/hosts based on DHCP leases.

This is a simpler alternative to running a DNS server and keeping it up-to-date.

/etc/dhcp/dhcpd.conf:
# http://www.linuxquestions.org/questions/linux-networking-3/dhcpd-getting-client-provided-hostname-in-execute-script-4175451000/
set ClientHost = pick-first-value( 
        host-decl-name,
        option fqdn.hostname,
        option host-name,
        "unknown");
# http://jpmens.net/2011/07/06/execute-a-script-when-isc-dhcp-hands-out-a-new-lease/
on commit {
        set clip = binary-to-ascii(10, 8, ".", leased-address);
        set clhw = binary-to-ascii(16, 8, "-", substring(hardware, 1, 6));
        execute("/home/rosuav/shed/dhcpmon.pike", "commit", clip, clhw, ClientHost);
}

*/

int main(int argc,array(string) argv)
{
        if (argc!=5) exit(1,"Wrong number of args\n");
        [string event,string ip,string mac,string host]=argv[1..];
	string topsec=Stdio.read_file("/etc/hosts"); //If the sscanf fails, make the whole current file content into the top section
        sscanf(topsec,"%s\n# Below maintained by DHCP script\n%{%s %s %s\n%}",topsec,array(array(string)) lines);
	mapping tm=localtime(time());
	lines=filter(lines||({ }),lambda(array(string) l) {return l[0]!=ip && l[2]!=host;}) //Clean out any for this IP *or* hostname
		//Entry for the new lease. The IP address, then an adorned hostname for reverse lookups, then the main hostname.
		+ ({({ip,sprintf("%s-mac-%s-seen-%04d%02d%02d-%02d%02d%02d",host,mac,tm->year+1900,tm->mon+1,tm->mday,tm->hour,tm->min,tm->sec),host})});
	write("%O\n",lines);
	Stdio.write_file("/etc/hosts",sprintf("%s\n# Below maintained by DHCP script\n%{%s %s %s\n%}",topsec,lines));
}

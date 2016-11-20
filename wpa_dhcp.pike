#!/usr/bin/env pike
//Monitor 'wpa_cli status' and log with timestamp every time change networks
//Also forces a DHCP recheck each time.

int main(int argc, array(string) argv)
{
	//TODO: Detect device name rather than requiring a parameter
	string dev = "wlan0";
	if (argc > 1) dev = argv[1];
	string lastssid;
	while (1)
	{
		sscanf(Process.run(({"wpa_cli","status"}))->stdout,"%*s\nssid=%s\n%*s\n",string ssid);
		if (!ssid || ssid=="" || ssid==lastssid) {sleep(60); continue;}
		if (lastssid)
		{
			Process.run(({"dhclient","-r","-pf","/run/dhclient."+dev+".pid"}));
			Process.create_process(({"dhclient","-pf","/run/dhclient."+dev+".pid","-lf","/var/lib/dhcp/dhclient."+dev+".leases",dev}))->wait();
		}
		write("[%s] Connected to %s\n",ctime(time())[..<1],lastssid=ssid);
	}
}


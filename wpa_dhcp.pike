#!/usr/bin/env pike
//Monitor 'wpa_cli status' and log with timestamp every time change networks
//Also forces a DHCP recheck each time.

int main()
{
	string lastssid;
	while (1)
	{
		sscanf(Process.run(({"wpa_cli","status"}))->stdout,"%*s\nssid=%s\n%*s\n",string ssid);
		if (!ssid || ssid=="" || ssid==lastssid) {sleep(60); continue;}
		if (lastssid)
		{
			Process.run(({"dhclient","-r","-pf","/run/dhclient.wlan0.pid"}));
			Process.create_process(({"dhclient","-pf","/run/dhclient.wlan0.pid","-lf","/var/lib/dhcp/dhclient.wlan0.leases","wlan0"}))->wait();
		}
		write("[%s] Connected to %s\n",ctime(time())[..<1],lastssid=ssid);
	}
}


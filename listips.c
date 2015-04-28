/* Trying to do this in Pike or Python requires compiling code anyway. I'm
just cutting out the middle-man. */

#include <ifaddrs.h>
#include <linux/if_link.h>
#include <stdio.h>

int main()
{
	struct ifaddrs *ifaddr, *ifa;
	char addr[128];
	int cnt=0,i;
	if (getifaddrs(&ifaddr)<0) return 1;
	for (ifa=ifaddr;ifa;ifa=ifa->ifa_next) if (ifa->ifa_addr)
	{
		int family=ifa->ifa_addr->sa_family;
		if (family==AF_PACKET) continue; /* Don't care about stats */
		const unsigned char *const a=(unsigned const char *)ifa->ifa_addr->sa_data;
		const unsigned char *const m=(unsigned const char *)ifa->ifa_netmask->sa_data;
		printf("%s -> ",ifa->ifa_name);
		if (family==AF_INET)
		{
			printf("%d.%d.%d.%d %d.%d.%d.%d\n",a[2],a[3],a[4],a[5],m[2],m[3],m[4],m[5]);
		}
		else if (family==AF_INET6)
		{
			/* Displayed in a machine-readable expanded format. */
			for (i=0;i<7;++i) printf("%2.2x%2.2x:",a[i*2+6],a[i*2+7]);
			printf("%2.2x%2.2x\n",a[7*2+6],a[7*2+7]); /* Last one has no trailing colon */
			/* Not currently showing netmasks for IPv6 addresses. */
		}
		else printf("[unknown family %d]\n",family);
	}
}

float diff(float|int now, float|int last, float tm) {return (now - last) / tm;}

int main(int argc, array(string) argv)
{
	float rate = 1.0;
	if (argc > 1 && (float)argv[1] != 0.0) rate = (float)argv[1];
	mapping lastinfo=([]);
	System.Timer timer=System.Timer();
	int have_comments = 0;
	mapping lastipv6 = ([]);
	while (1)
	{
		mapping info=([]);
		string chain="???";
		float tm=timer->get();
		//Get some IPv6 stats. Then, as we go through the IPv4 stats, any corresponding stats will be put on the same line.
		mapping ipv6 = ([]);
		foreach (Process.run(({"ip6tables", "-nvxL"}))->stdout / "\n", string line) if (has_value(line, "/* stat:")) {
			array parts=line/" "-({""});
			if (sizeof(parts)<9) continue; //Invalid line
			[string pkts,string bytes,string target,string prot,string opt,string in,string out,string source,string dest]=parts[..8];
			string extra=parts[9..]*" ";
			have_comments = 1;
			sscanf(extra, "%*s/* stat: %s */", string comment);
			ipv6[comment] = ({(int)bytes, (int)pkts});
		}
		//Now get the IPv4 stats.
		foreach (Process.run(({"iptables","-nvxL"}))->stdout/"\n",string line)
		{
			if (line=="") continue;
			if (sscanf(line,"Chain %s (policy %*[A-Z] %d packets, %d bytes)", string ch, int packets, int bytes))
			{
				if (info[chain])
				{
					if (lastinfo[chain]) write("%12f/s %9f/s %s\n", @diff(info[chain][*], lastinfo[chain][*], tm), chain);
					else write("New: %11d %9d %s\n", @info[chain], chain);
				}
				chain=ch;
				if (!have_comments) info[chain] = ({bytes, packets});
				continue;
			}
			if (has_prefix(String.trim_all_whites(line),"pkts")) continue; //Column headings - ignore
			array parts=line/" "-({""});
			if (sizeof(parts)<9) continue; //Invalid line
			[string pkts,string bytes,string target,string prot,string opt,string in,string out,string source,string dest]=parts[..8];
			string extra=parts[9..]*" ";
			//Okay. Now to come up with a viable description - preferably not too long. It MUST be consistent, as it becomes the lookup key.
			string desc=chain;
			if (sscanf(extra, "%*s/* stat: %s */", string comment) && comment)
			{
				//Specially-tagged comments (created with -m comment --comment "stat: descriptive text")
				//allow administrative filtering of the displayed rows. Firewall rules can independently
				//be used for actual filtering and/or stats collection.
				have_comments = 1;
				desc = comment;
				m_delete(info, chain); //Suppress the current chain. Gives a good chance of clean display on the first iteration.
			}
			else
			{
				if (have_comments) continue; //If we have ever had any with comments, filter down to the commented ones only.
				if (source!="0.0.0.0/0") desc+=" from "+source;
				if (dest!="0.0.0.0/0") desc+=" to "+dest;
				if (in!="*" || out!="*") desc+=sprintf(" iface %s-%s,",in,out);
				if (extra=="state RELATED,ESTABLISHED") extra="estab";
				if (prot!="all" && !has_prefix(extra,prot)) extra=prot+" "+extra;
				desc+=" "+extra;
				if (target!="ACCEPT") desc+=" "+target;
				while (info[desc]) desc+="*"; //Force disambiguation. If this marker is coming up, it probably means the above info needs to be cleaned up.
			}
			info[desc] = ({(int)bytes, (int)pkts});
			string ipv4line = lastinfo[desc] ? sprintf("%12f/s %9f/s %s", @diff(info[desc][*], lastinfo[desc][*], tm), desc)
				: sprintf("New: %11d %9d %s", @info[desc], desc);
			if (ipv6[desc]) {
				string ipv6line = lastipv6[desc] ? sprintf("%12f/s %9f/s", @diff(ipv6[desc][*], lastipv6[desc][*], tm))
					: sprintf("New: %11d %9d", @ipv6[desc]);
				write("%-60s | %s\n", ipv4line, ipv6line);
			} else write("%s\n", ipv4line);
		}
		if (info[chain])
		{
			if (lastinfo[chain]) write("%12f/s %9f/s %s\n", @diff(info[chain][*], lastinfo[chain][*], tm), chain);
			else write("New: %11d %9d %s\n", @info[chain], chain);
		}
		lastinfo = info; lastipv6 = ipv6;
		write("\n");
		sleep(rate);
	}
}

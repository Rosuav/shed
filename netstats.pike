int main()
{
	mapping lastinfo=([]);
	System.Timer timer=System.Timer();
	int have_comments = 0;
	while (1)
	{
		mapping info=([]);
		string chain="???";
		float tm=timer->get();
		foreach (Process.run(({"iptables","-nvxL"}))->stdout/"\n",string line)
		{
			if (line=="") continue;
			if (sscanf(line,"Chain %s (policy %*[A-Z] %*d packets, %s bytes)",string ch,string bytes))
			{
				if (info[chain])
				{
					if (lastinfo[chain]) write("%12f/s %s\n",((int)info[chain]-(int)lastinfo[chain])/tm,chain);
					else write("New: %12s %s\n",info[chain],chain);
				}
				chain=ch;
				if (!have_comments) info[chain] = bytes;
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
			info[desc]=bytes; //Retain the string so we can easily distinguish absence from a value of "0"
			if (lastinfo[desc]) write("%12f/s %s\n",((int)bytes-(int)lastinfo[desc])/tm,desc);
			else write("New: %12s %s\n",bytes,desc);
		}
		if (info[chain])
		{
			if (lastinfo[chain]) write("%12f/s %s\n",((int)info[chain]-(int)lastinfo[chain])/tm,chain);
			else write("New: %12s %s\n",info[chain],chain);
		}
		lastinfo=info;
		write("\n");
		sleep(10);
	}
}

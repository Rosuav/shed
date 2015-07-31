int main()
{
	mapping lastinfo=([]);
	System.Timer timer=System.Timer();
	while (1)
	{
		mapping info=([]);
		string chain="???";
		float tm=timer->get();
		foreach (Process.run(({"iptables","-nvxL"}))->stdout/"\n",string line)
		{
			if (line=="") continue;
			if (sscanf(line,"Chain %s (policy %*[A-Z] %*d packets, %d bytes)",string ch,int bytes))
			{
				chain=ch;
				info[chain]=bytes;
				if (lastinfo[chain]) write("%12f/s %s\n",((int)bytes-(int)lastinfo[chain])/tm,chain);
				else write("New: %12d %s\n",bytes,chain);
				continue;
			}
			if (has_prefix(String.trim_all_whites(line),"pkts")) continue; //Column headings - ignore
			array parts=line/" "-({""});
			if (sizeof(parts)<9) continue; //Invalid line
			[string pkts,string bytes,string target,string prot,string opt,string in,string out,string source,string dest]=parts[..8];
			string extra=parts[9..]*" ";
			//Okay. Now to come up with a viable description - preferably not too long. It MUST be consistent, as it becomes the lookup key.
			string desc=chain;
			if (source!="0.0.0.0/0") desc+=" from "+source;
			if (dest!="0.0.0.0/0") desc+=" to "+dest;
			if (in!="*" || out!="*") desc+=sprintf(" iface %s-%s,",in,out);
			if (extra=="state RELATED,ESTABLISHED") extra="estab";
			if (prot!="all" && !has_prefix(extra,prot)) extra=prot+" "+extra;
			desc+=" "+extra;
			if (target!="ACCEPT") desc+=" "+target;
			while (info[desc]) desc+="*"; //Force disambiguation. If this marker is coming up, it probably means the above info needs to be cleaned up.
			info[desc]=bytes; //Retain the string so we can easily distinguish absence from a value of "0"
			if (lastinfo[desc]) write("%12f/s %s\n",((int)bytes-(int)lastinfo[desc])/tm,desc);
			else write("New: %12s %s\n",bytes,desc);
		}
		lastinfo=info;
		write("\n");
		sleep(10);
	}
}

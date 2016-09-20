int main()
{
	sscanf(Process.run(({"dpkg", "--get-selections"}))->stdout, "%{%s%*[\t]%s\n%}", array info);
	array(string) purge = ({ }), auto = ({ });
	mapping(string:int) sources = ([]), activesources = ([]);
	foreach (info; int i; [string pkg, string status])
	{
		if (status == "deinstall") {purge += ({pkg}); continue;}
		if (status != "install") {write("UNKNOWN STATUS %O %O\n", pkg, status); continue;}
		int flagged = 0;
		write("[%d/%d] %s\e[K\r", i, sizeof(info), pkg);
		foreach (Process.run(({"apt-cache", "policy", pkg}))->stdout/"\n", string line)
		{
			if (has_prefix(line, " ***")) flagged = 1;
			else if (has_prefix(line, "        "))
			{
				++sources[line];
				if (!flagged) continue;
				++activesources[line];
				if (!has_value(line, "ubuntu")) continue;
				write("%s %s\n", pkg, String.trim_all_whites(line));
				if (has_prefix(pkg, "lib")) auto += ({pkg});
			}
			else flagged = 0;
		}
	}
	write("\e[K");
	write("All sources: %O\n", sources);
	write("Active sources: %O\n", activesources);
	if (sizeof(purge)) write("sudo apt-get purge%{ %s%}\n", purge); //Don't actually do it, just give the user the option.
	if (sizeof(auto))  write("sudo apt-mark auto%{ %s%}\n", auto); //Ditto
}

int main(int argc,array(string) argv)
{
	if (argc<2) exit(1,"USAGE: pike %s package [package...]\nAttempts to reinstall the listed packages from /var/cache/apt/archives\n",argv[0]);
	array(string) allfiles=get_dir("/var/cache/apt/archives");
	array(string) extractme=({ });
	foreach (argv[1..],string pkg)
	{
		array(string) files=glob(pkg+"*.deb",allfiles);
		switch (sizeof(files))
		{
			case 0: exit(1,"Package %s not found in /var/cache/apt/archives!\n",pkg);
			case 1: extractme+=({files[0]}); break; //Easy - only one option.
			default:
				//TODO: Use "dpkg -s "+pkg to try to figure out which version was installed.
				exit(1,"Package %s has multiple versions available:\n%{%s\n%}",pkg,files);
		}
	}
	//If we get here, we should have a reliable set of extraction targets.
	string dir="/tmp/deb_reinstall";
	mkdir(dir);
	//If you run the entire script as root, sudo is not necessary. If not,
	//sudo _is_ necessary... or else the whole thing will fail anyway.
	//Running the script as a non-root user means that all steps until the
	//final extraction will be done as that non-root user.
	array(string) sudo=({"sudo"}) * !!getuid();
	foreach (extractme,string fn)
	{
		write("Reinstalling %s...\n",fn);
		Process.create_process(({"ar","x","/var/cache/apt/archives/"+fn}),(["cwd":dir]))->wait();
		Process.create_process(sudo+({"tar","xf",dir+"/data.tar.xz"}),(["cwd":"/"]))->wait();
	}
	Stdio.recursive_rm(dir);
	write("%d package(s) reinstalled.\n",sizeof(extractme));
}

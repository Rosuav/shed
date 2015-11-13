#!/usr/local/bin/pike
int main()
{
	foreach (Process.run(({"git","branch","--merged"}))->stdout/"\n",string l)
		if (sizeof(l)>2 && l[2..]!="master" && l[0]!='*')
			Process.create_process(({"git","branch","-d",l[2..]}))->wait();
	Process.create_process(({"git","push","origin","--all","--prune"}))->wait();
}

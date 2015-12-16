void allow(int addr,int len)
{
        string block=sprintf("%d.%d.%d.%d/%d",addr>>24,(addr>>16)&255,(addr>>8)&255,addr&255,len);
        write("Allowing: %s\n",block);
        Process.create_process(({"iptables","-A","INPUT","--src",block,"-j","ACCEPT"}))->wait();
}

int main()
{
        int addr;
        for (int len=1;len<=32;++len)
        {
                allow(addr+(1<<(32-len)),len);
                allow(addr,len);
		int idx0,idx1;
		while (1)
		{
			sleep(2);
			[[idx1,int traf1],[idx0,int traf0]]=array_sscanf((Process.run("iptables --line-numbers -nvxL INPUT")->stdout/"\n")[<2..<1][*],"%d %*d %d");
			write("%d for 1, %d for 0\n",traf1,traf0);
			if (traf1<10000 && traf0<10000) {write("Insufficient traffic to be confident; waiting for more.\n"); continue;}
			if (traf1>traf0) addr+=(1<<(32-len));
			break;
		}
                Process.create_process(({"iptables","-D","INPUT",(string)idx0}))->wait();
                Process.create_process(({"iptables","-D","INPUT",(string)idx1}))->wait();
        }
}


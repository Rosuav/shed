//Simple network usage graph
//Mainly for the sake of playing with the GTK2.Databox - there are
//lots of network usage graph programs around. :)

int lastrx=UNDEFINED,lasttx;
int xpos;
string iface="eth0";
GTK2.Databox db;

void netstatus()
{
	call_out(netstatus,1);
	string stdout=Process.run(({"/sbin/ifconfig",iface}))->stdout; //Shouldn't require root
	sscanf(stdout,"%*sRX bytes:%d %*sTX bytes:%d ",currx,curtx);
	if (!zero_type(lastrx))
	{
		db->data_add(1,({xpos++}),({currx-lastrx}),GTK2.GdkColor(Image.Color.red),GTK2.DataboxLines,2);
		db->rescale();
	}
	lastrx=currx; lasttx=curtx;
}

int main(int argc,array(string) argv)
{
	if (argc>1) iface=argv[1];
	GTK2.Window(GTK2.WindowToplevel)->set_title("Network usage")->add(db=GTK2.Databox())->show_all();
	call_out(netstatus,0);
	return -1;
}

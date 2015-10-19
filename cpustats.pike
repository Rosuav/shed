array(float) speeds;
int minspd,maxspd;
mapping(string:mixed) win=([]);

void update()
{
	call_out(update,1);
	int spd=(int)Process.run(({"cpufreq-info","-f"}))->stdout;
	speeds=speeds[1..]+({spd/1000.0});
	Image.Image img=Graphics.Graph.line((["data":({speeds,({maxspd/1000.0}),({minspd/1000.0})*sizeof(speeds)}),"xsize":800,"ysize":600]));
	win->img->set_from_image(GTK2.GdkImage(0,img));
}

int main()
{
	sscanf(Process.run(({"cpufreq-info","-l"}))->stdout,"%d %d",minspd,maxspd);
	speeds=({minspd/1000.0})*100;
	GTK2.setup_gtk();
	win->mainwindow=GTK2.Window(0)->set_title("CPU speed")->add(win->img=GTK2.Image(GTK2.GdkImage(0,Image.Image(800,600))))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	update();
	return -1;
}


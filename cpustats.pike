//Show CPU utilization graphs, in parallel: frequency, usage percentage, and load average

//Number of history entries to save
#define HIST_LENGTH 100
//Display dimensions
#define GRAPH_WIDTH 600
#define GRAPH_HEIGHT 200

//Tweak this to tweak what gets counted as "usage"
int usage(int user,int nice,int sys,int idle,int iowait,int irq,int softirq) {return user+nice+sys+iowait+irq+softirq;}

array(int) getstats()
{
	sscanf(Stdio.read_file("/proc/stat"),"cpu  %s\n%{cpu%*d %s\n%}",string total,array(array(string)) percore);
	array stats=({/*usage(@(array(int))(total/" "))*/}); //Uncomment to include totals as well as per-core stats
	foreach (percore,[string corestats]) stats+=({usage(@(array(int))(corestats/" "))});
	return stats;
}

array(array(float)) speeds;
int minspd,maxspd;
mapping(string:mixed) win=([]);
System.Timer tm=System.Timer();
array(int) lastusage;
array(array(float)) usages;
array(array(float)) loads=({ ({0.0})*HIST_LENGTH }) * 3;

string freqmode=getuid() ? "-fc" : "-wc"; //If we're running as root, get the hardware frequency
int skipdraw;

void add_data(string kwd,array(float) data)
{
	array(array(float)) stats=this[kwd];
	foreach (data;int i;float d) stats[i]=stats[i][1..]+({d});
	if (!skipdraw) win[kwd]->set_from_image(GTK2.GdkImage(0,Graphics.Graph.line((["data":stats,"xsize":GRAPH_WIDTH,"ysize":GRAPH_HEIGHT,"horgrid":1]))));
}

void update()
{
	call_out(update,1);

	//Usage stats. This requires getting "since boot" stats periodically and differencing.
	array(int) usage=getstats();
	if (lastusage)
		add_data("usages",(usage[*]-lastusage[*])[*]/tm->get());
	else
	{
		//Initialize the array of arrays based on the number of CPU cores we have
		usages = ({ ({0.0})*HIST_LENGTH }) * sizeof(usage) + ({({100.0})});
		add_data("usages",({ })); //Force the graph to be drawn, even though we don't have useful data yet.
	}
	lastusage=usage;

	//CPU frequency (uses usage[] for core count)
	if (!speeds) speeds=({({minspd/1000.0})*HIST_LENGTH})*sizeof(usage) + ({({minspd/1000.0})*HIST_LENGTH,({maxspd/1000.0})});
	array a=(array(string))enumerate(sizeof(usage));
	add_data("speeds",((array(float))Process.run(({"cpufreq-info",freqmode,a[*]})[*])->stdout)[*]/1000);

	//Load average (cores don't apply here)
	add_data("loads",System.getloadavg());

	if (++skipdraw>=3) skipdraw=0; //Draw only every so often - in between, save a bit of graphics effort
}

int main()
{
	sscanf(Process.run(({"cpufreq-info","-l"}))->stdout,"%d %d",minspd,maxspd);
	GTK2.setup_gtk();
	win->mainwindow=GTK2.Window(0)->set_title("CPU speed")->add(GTK2.Vbox(10,0)
		->add(GTK2.Frame("Frequency (MHz)")->add(win->speeds=GTK2.Image(GTK2.GdkImage(0,Image.Image(1,1)))))
		->add(GTK2.Frame("Usage")->add(win->usages=GTK2.Image(GTK2.GdkImage(0,Image.Image(1,1)))))
		->add(GTK2.Frame("Load average")->add(win->loads=GTK2.Image(GTK2.GdkImage(0,Image.Image(1,1)))))
	)->show_all()->signal_connect("destroy",lambda() {exit(0);});
	update();
	return -1;
}


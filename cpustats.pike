//Show CPU utilization graphs, in parallel: frequency, usage percentage, and load average

//Number of history entries to save
#define HIST_LENGTH 100
//Display dimensions
#define GRAPH_WIDTH 900
#define GRAPH_HEIGHT 300

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

void update()
{
	call_out(update,1);

	//Usage stats. This requires getting "since boot" stats periodically and differencing.
	array(int) usage=getstats();
	if (lastusage)
	{
		array(float) load=(usage[*]-lastusage[*])[*]/tm->get();
		foreach (usages;int i;array u)
			usages[i]=u[1..]+({load[i]});
	}
	else
	{
		//Initialize the array of arrays based on the number of CPU cores we have
		usages = ({ ({0.0})*HIST_LENGTH }) * sizeof(usage);
	}
	lastusage=usage;
	win->usage->set_from_image(GTK2.GdkImage(0,Graphics.Graph.line((["data":usages+({({100.0})}),"xsize":GRAPH_WIDTH,"ysize":GRAPH_HEIGHT]))));

	//CPU frequency (uses usage[] for core count)
	if (!speeds) speeds=({({minspd/1000.0})*HIST_LENGTH})*sizeof(usage);
	foreach (speeds;int i;array s)
	{
		int spd=(int)Process.run(({"cpufreq-info","-fc",(string)i}))->stdout;
		speeds[i]=s[1..]+({spd/1000.0});
	}
	win->freq->set_from_image(GTK2.GdkImage(0,Graphics.Graph.line((["data":speeds+({({maxspd/1000.0}),({minspd/1000.0})*sizeof(speeds)}),"xsize":GRAPH_WIDTH,"ysize":GRAPH_HEIGHT]))));

	//Load average (cores don't apply here)
	foreach (array_sscanf(Stdio.read_file("/proc/loadavg"),"%f %f %f");int i;float l)
		loads[i]=loads[i][1..]+({l});
	win->load->set_from_image(GTK2.GdkImage(0,Graphics.Graph.line((["data":loads,"xsize":GRAPH_WIDTH,"ysize":GRAPH_HEIGHT]))));
}

int main()
{
	sscanf(Process.run(({"cpufreq-info","-l"}))->stdout,"%d %d",minspd,maxspd);
	GTK2.setup_gtk();
	win->mainwindow=GTK2.Window(0)->set_title("CPU speed")->add(GTK2.Vbox(10,0)
		->add(GTK2.Frame("Frequency (MHz)")->add(win->freq=GTK2.Image(GTK2.GdkImage(0,Image.Image(1,1)))))
		->add(GTK2.Frame("Usage")->add(win->usage=GTK2.Image(GTK2.GdkImage(0,Image.Image(1,1)))))
		->add(GTK2.Frame("Load average")->add(win->load=GTK2.Image(GTK2.GdkImage(0,Image.Image(1,1)))))
	)->show_all()->signal_connect("destroy",lambda() {exit(0);});
	update();
	return -1;
}


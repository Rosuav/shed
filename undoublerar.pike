#!/usr/local/bin/pike
//Pretty specific... but maybe handy.
//Given a directory full of double-archived RARs, show a list of second-level
//directories in the given RAR, and give the option to extract one of them.
mapping(string:GTK2.Widget) win=([]);

//Starting RAR file
string base="/home/rosuav/Downloads/Disney.Classic.Animated.Collection.1080p.BluRay.x264-FF/Disney.Classic.Animated.Collection.1080p.BluRay.part001.rar";

void mw_destroy() {exit(0);}

void extract_clicked()
{
	[object iter,object store]=win->sel->get_selected();
	string kwd=iter && store->get_value(iter,0);
	if (kwd && kwd!="")
	{
		string path="Disney.Classic.Animated.Collection.1080p.BluRay.x264-FF/"+kwd;
		write("Selected: %O\n",kwd);
		string dir;
		for (int i=0;!mkdir(dir="/tmp/undoublerar_"+i,0700);++i)
			if (i>1000) exit(1,"Unable to find a temporary directory!");
		string cwd=getcwd();
		cd(dir);
		Process.create_process(({"unar",base,combine_path(path,"*")}))->wait();
		write("----------\n");
		array(string) files=sort(get_dir(path)); //Sorted so that if there are multiple files matching a glob (eg *.rar), the first will be used.
		foreach (({"*.rar","*.r00","*.r01"}),string tryme)
		{
			array(string) found=glob(tryme,files);
			if (!sizeof(found)) continue;
			write("Using: %s\n",found[0]);
			Process.create_process(({"unar",combine_path(path,found[0])}))->wait();
			write("Extracted!\n");
			array(string) files=glob("*.mkv",get_dir());
			if (!sizeof(files)) exit(1,"Couldn't find an mkv in the output!\n"); //And leave the temp dir there.
			string outfn=combine_path(cwd,kwd+".mkv");
			mv(files[0],outfn);
			Process.create_process(({"scp",outfn,"netbios@huix:BluRayDisney/"}))->wait();
			rm(outfn);
			outfn="/video/BluRayDisney/"+outfn;
			write("Saved to %s - %d bytes\n",outfn,file_stat(outfn)->size);
			break;
		}
		write("----------\n");
		cd(cwd);
		Stdio.recursive_rm(dir);
	}
	exit(0);
}

int main()
{
	GTK2.setup_gtk();
	multiset(string) dirs=(<>); //Prevent duplicates
	win->ls=GTK2.ListStore(({"string","string"}));
	foreach ((Process.run(({"lsar",base}))->stdout/"\n")[1..],string l)
	{
		if (l=="") continue;
		l=explode_path(l)[1];
		if (dirs[l]) continue;
		dirs[l]=1;
		object iter=win->ls->append();
		win->ls->set_value(iter,0,l);
		if (object stat=file_stat(sprintf("/video/BluRayDisney/%s.mkv",l))) win->ls->set_value(iter,1,ctime(stat->mtime)[..<1]);
	}
	if (!sizeof(dirs)) exit(0,"No directories found.\n");
	win->mw=GTK2.Window(0)->set_title("UnDoubleRAR")->add(GTK2.Vbox(0,0)
		->add(win->list=GTK2.TreeView(win->ls)
			->append_column(GTK2.TreeViewColumn("File to extract",GTK2.CellRendererText(),"text",0))
			->append_column(GTK2.TreeViewColumn("On Huix?",GTK2.CellRendererText(),"text",1))
		)
		->add(GTK2.HbuttonBox()->add(win->extract=GTK2.Button("Extract")))
	)->show_all();
	win->sel=win->list->get_selection();
	foreach (indices(this),string fn) if (sscanf(fn,"%s_%s",string obj,string sig) && win[obj] && sig) win[obj]->signal_connect(sig,this[fn]);
	return -1;
}


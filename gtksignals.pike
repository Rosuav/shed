int main()
{
	GTK2.setup_gtk();
	string path="/home/rosuav/pike/src/post_modules/GTK2/source";
	foreach (sort(get_dir(path)),string fn) catch
	{
		sscanf(Stdio.read_file(path+"/"+fn), "%*s\nclass %[A-Za-z2].%[A-Za-z];",string module,string obj);
		program pgm;
		switch (module)
		{
			case 0: break; //Ignore files we can't parse
			case "Gnome2": pgm = Gnome2[obj]; break;
			case "GTK2": pgm = GTK2[obj]; break;
			case "GDK2": pgm = GDK2[obj]; break;
			case "G": write("Ignoring G.%s\n", obj); break;
			case "Pango": pgm = Pango[obj]; break;
			default: write("Unknown module %s\n",module);
		}
		if (!catch {pgm();}) continue;
		if (!catch {pgm(0);}) continue;
		if (!catch {pgm(([]));}) continue;
		write("Unable to clone: %s\n", obj);
	};
	array sig=GTK2.list_signals();
	mapping all_params=([]);
	int i=0;
	foreach (sig,mapping info)
	{
		++i;
		foreach (info->params, string p)
			if (!all_params[p]) all_params[p] = info["class"]+"::"+info->name;
	}
	write("From %d signals: %O\n",i,all_params);
}

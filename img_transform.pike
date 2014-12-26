//GTK2.ComboBox designed for text strings. Has set_text() and get_text() methods.
//Should be able to be used like an Entry.
class SelectBox(array(string) strings)
{
	inherit GTK2.ComboBox;
	void create() {::create(""); foreach (strings,string str) append_text(str);}
	this_program set_text(string txt)
	{
		set_active(search(strings,txt));
		return this;
	}
	string get_text() //Like get_active_text() but will return 0 (not "") if nothing's selected (may not strictly be necessary, but it's consistent with entry fields and such)
	{
		int idx=get_active();
		return (idx>=0 && idx<sizeof(strings)) && strings[idx];
	}
	void set_strings(array(string) newstrings)
	{
		foreach (strings,string str) remove_text(0);
		foreach (strings=newstrings,string str) append_text(str);
	}
}

mapping(string:object) w=([]);
Image.Image orig_image;

Image.Image update_image()
{
	Image.Image img=orig_image;
	//Perform all appropriate transformations
	foreach (({"autocrop","grey","mirrorx","mirrory"}),string func)
		if (w["xfrm_"+func]->get_active()) img=img[func]();
	if (w->xfrm_threshold->get_active()) img=img->threshold((int)w->threshold_val->get_value());
	//Add more transformations here
	w->img->set_from_image(GTK2.GdkImage(0,img));
	return img;
}

void sig_format_changed()
{
	//Split the input file name into base and extension. Assumes that you don't give it a
	//file name with no extension in a directory with a dot. :)
	array parts=w->open->get_filename()/".";
	string base=parts[..<1]*".",ext=parts[-1];
	if (base=="") {base=ext; ext="";} //Files without dots are all file name, not all extension.
	string newext=lower_case(w->format->get_text());
	if (newext==ext) base+="_xfrm";
	w->outfn->set_text(base+"."+newext);
}

void sig_win_destroy() {exit(0);}

void sig_open_selection_changed()
{
	string fn=w->open->get_filename();
	if (!fn) return;
	sig_format_changed();
	orig_image=Image.ANY.decode(Stdio.read_file(fn));
	update_image();
}

void sig_save_clicked()
{
	Stdio.write_file(w->outfn->get_text(),Image[w->format->get_text()]->encode(update_image()));
}

int main()
{
	GTK2.setup_gtk();
	w->win=GTK2.Window(0)->set_title("Image transform")->add(GTK2.Vbox(0,10)
		->add(GTK2.Hbox(0,10)
			->pack_start(GTK2.Label("Input file:"),0,0,0)
			->add(w->open=GTK2.FileChooserButton("Open image",GTK2.FILE_CHOOSER_ACTION_OPEN))
		)
		//Begin transformations
		->add(w->xfrm_autocrop=GTK2.CheckButton("Crop off any border"))
		->add(w->xfrm_grey=GTK2.CheckButton("Greyscale"))
		->add(GTK2.Hbox(0,10)
			->add(w->xfrm_mirrorx=GTK2.CheckButton("Mirror horiz"))
			->add(w->xfrm_mirrory=GTK2.CheckButton("Mirror vert"))
		)
		->add(GTK2.Hbox(0,10)
			->pack_start(w->xfrm_threshold=GTK2.CheckButton("Threshold"),0,0,0)
			->add(w->threshold_val=GTK2.Hscale(0.0,255.0,1.0)->set_value_pos(GTK2.POS_LEFT))
		)
		//Add new transformations here
		->add(w->img=GTK2.Image())
		->add(GTK2.Hbox(0,10)
			->pack_start(GTK2.Label("Save as"),0,0,0)
			->pack_start(w->format=SelectBox(({"PNG","JPG","GIF"}))->set_text("PNG"),0,0,0)
			->add(w->outfn=GTK2.Label(""))
			->pack_start(w->save=GTK2.Button("Save"),0,0,0)
		)
	)->show_all();
	w->open->set_current_folder(".");
	foreach (indices(this),string key)
		if (sscanf(key,"sig_%s_%s",string obj,string sig) && sig && callablep(this[key]) && w[obj])
			w[obj]->signal_connect(sig,this[key]);
	//Deal with all the CheckButtons the easy way.
	foreach (w;string key;object obj) if (has_prefix(key,"xfrm_")) obj->signal_connect("toggled",update_image);
	w->threshold_val->signal_connect("value_changed",update_image);
	return -1;
}

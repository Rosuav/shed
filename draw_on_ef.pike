mapping(string:mixed) win=([]);

GTK2.Table GTK2Table(array(array(string|GTK2.Widget)) contents,mapping|void label_opts)
{
	if (!label_opts) label_opts=([]);
	GTK2.Table tb=GTK2.Table(sizeof(contents[0]),sizeof(contents),0);
	foreach (contents;int y;array(string|GTK2.Widget) row) foreach (row;int x;string|GTK2.Widget obj) if (obj)
	{
		int opt=0;
		if (stringp(obj)) {obj=GTK2.Label(label_opts+(["label":obj])); opt=GTK2.Fill;}
		//else if (_noexpand[obj]) _noexpand[obj]=0; //Remove it from the set so we don't hang onto references to stuff we don't need
		else opt=GTK2.Fill|GTK2.Expand;
		int xend=x+1; while (xend<sizeof(row) && !row[xend]) ++xend; //Span cols by putting 0 after the element
		tb->attach(obj,x,xend,y,y+1,opt,opt,1,1);
	}
	return tb;
}

//Derivative of GTK2Table above, specific to a two-column layout. Takes a 1D array.
//This is the most normal way to lay out labelled objects - alternate string labels and objects, or use CheckButtons without labels.
//The labels will be right justified.
GTK2.Table two_column(array(string|GTK2.Widget) contents) {return GTK2Table(contents/2,(["xalign":1.0]));}

int ef_expose(object ef,object ev,mixed arg)
{
	write("Expose %O\n",(mapping)ev);
	int show_note = win->ef1->get_text()=="n";
	if (!show_note) return 0;
	//ef->signal_stop("expose-event");
	write("sr %O\nalloc %O\n",ef->size_request(),ef->allocation());
	int width=ef->size_request()->width;
	GTK2.Style style=ef->get_style();
	object layout=ef->create_pango_layout("note");
	style->paint_layout(ef,GTK2.STATE_NORMAL,0,GTK2.GdkRectangle(0,0,width,25),ef,"",width/2,0,layout);
	return 1;
	//GTK2.Style paint_layout(GTK2.Widget window, int state, int use_text, GTK2.GdkRectangle rect, GTK2.Widget widget, string detail, int x, int y, GTK2.Pango.Layout layout)
	//style->paint_option(ef,GTK2.STATE_NORMAL,0,GTK2.GdkRectangle(0,0,width,30),ef,"",width-20,10,10,10);
}

int ef_change()
{
	if (win->ef1->get_text()=="i") win->ef2->set_icon_from_stock(GTK2.ENTRY_ICON_SECONDARY,GTK2.STOCK_EDIT);
	else win->ef2->set_icon_from_stock(GTK2.ENTRY_ICON_SECONDARY,GTK2.STOCK_FILE);
}

void iconclick(mixed ... args)
{
	write("Icon click! %O\n",args);
}

int main()
{
	GTK2.setup_gtk();
	win->mainwindow=GTK2.Window(0)->set_title("Drawing on entry fields")->add(two_column(({
		"Field 1", win->ef1=GTK2.Entry(),
		"Field 2", win->ef2=GTK2.Entry(),
		"Field 3", win->ef3=GTK2.Entry(),
	})))->show_all();
	win->mainwindow->signal_connect("destroy",lambda() {exit(0);});
	win->ef2->signal_connect("expose-event",ef_expose,0,UNDEFINED,1);
	win->ef1->signal_connect("changed",ef_change);
	win->ef2->signal_connect("icon-press",iconclick,0,UNDEFINED,1);
	return -1;
}

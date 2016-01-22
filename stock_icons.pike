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

void iconclick(object self,int which,object ev,int arg)
{
	write("Icon click! %O %d %O\n",self,which,(mapping)ev);
}

int main()
{
	GTK2.setup_gtk();
	array table=({ });
	foreach (glob("STOCK*",indices(GTK2)),string name)
	{
		object obj=GTK2.Entry()->set_icon_from_stock(GTK2.ENTRY_ICON_SECONDARY,GTK2[name]);
		obj->signal_connect("icon-press",iconclick);
		table+=({name-"STOCK_",obj});
	}
	win->mainwindow=GTK2.Window(0)->set_title("Entry fields with icons")->add(GTK2Table(table/6.0))->show_all();
	win->mainwindow->signal_connect("destroy",lambda() {exit(0);});
	return -1;
}

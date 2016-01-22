void iconclick(object self,int which,object ev,int arg)
{
	write("Icon click! %O %d %O\n",self,which,(mapping)ev);
}

int main()
{
	GTK2.setup_gtk();
	object ef=GTK2.Entry()->set_icon_from_stock(GTK2.ENTRY_ICON_SECONDARY,GTK2.STOCK_EDIT);
	ef->signal_connect("icon-press",iconclick);
	object mainwindow=GTK2.Window(0)->set_title("Entry fields with icons")->add(ef)->show_all();
	mainwindow->signal_connect("destroy",lambda() {exit(0);});
	return -1;
}

int main(int argc,array(string) argv)
{
	GTK2.setup_gtk();
	GTK2.MessageDialog(0,GTK2.MESSAGE_INFO,GTK2.BUTTONS_OK,argv[1..]*" ")->show()->signal_connect("response",lambda() {exit(0);});
	return -1;
}

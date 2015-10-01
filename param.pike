/*
Pop-up parameter prompt

Designed for a GUI launcher - will exec a program with custom
parameters. Run this with the first arg being a command line
(will be passed to /bin/sh -c); any other args will follow the
command as args to sh. Put a %* where you want the input to go;
multiple %* will all be replaced, but the prompt will show the
first one only (and others staying as %*).
*/
array(string) args;
object ef,win;

void run_program()
{
	string input=ef->get_text();
	win->destroy();
	foreach (args;int i;string arg) args[i]=replace(arg,"%*",input);
	write("Executing: /bin/sh -c%{ %O%}\n",args);
	Process.exec("/bin/sh","-c",@args);
	exit(1,"Unable to exec /bin/sh!\n");
}

int main(int argc,array(string) argv)
{
	args=argv[1..];
	GTK2.setup_gtk();
	object run,cancel;
	string before="",after;
	foreach (args,string arg)
	{
		if (after) after+=" "+arg;
		else if (sscanf(arg,"%s%%*%s",string q,string w)==2)
		{
			before+=" "+q;
			after=w;
		}
		else before+=" "+arg;
	}
	before=before[1..];
	win=GTK2.Window(GTK2.WINDOW_TOPLEVEL)->set_title("Enter parameters")->add(GTK2.Vbox(0,10)
		->add(GTK2.Hbox(0,0)
			->add(GTK2.Label(before))
			->add(ef=GTK2.Entry()->set_activates_default(1)->set_width_chars(50))
			->add(GTK2.Label(after||""))
		)
		->add(GTK2.HbuttonBox()
			->add(run=GTK2.Button("_Run")->set_use_underline(1))
			->add(cancel=GTK2.Button("_Cancel")->set_use_underline(1))
		)
	)->show_all();
	win->signal_connect("delete-event",lambda() {exit(0);});
	run->set_flags(GTK2.CAN_DEFAULT)->grab_default()->signal_connect("clicked",run_program);
	cancel->signal_connect("clicked",lambda() {exit(0);});
	return -1;
}

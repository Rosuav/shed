/*
Fire this up for your channel thus:

pike twitchviewers YourUserName

It'll show a little display of the currently-watching viewers, updated every 10ish seconds (or add
another argument to adjust update frequency). This can be loaded into OBS with window capture, or
simply left on screen as a ticking display.

The information displayed is completely public, so this needs no authentication or stream key. You
can monitor your own viewers - or anyone else's; why you'd want to, I can't say, but go ahead :)
*/
int delay = 10;
string url;
GTK2.Label info;

void load_users()
{
	while (1) catch
	{
		mapping data = Standards.JSON.decode_utf8(Protocols.HTTP.get_url_data(url));
		string output = sprintf("%d viewers", data->chatter_count);
		foreach (({"Staff", "Moderators", "Admins", "Global Mods", "Viewers"}), string category)
		{
			array peeps = data->chatters[lower_case(replace(category, " ", "_"))];
			if (sizeof(peeps))
				output += sprintf("\n\n%s:%{\n%s%}", category, peeps);
		}
		info->set_text(output);
		sleep(delay);
	};
}

void drag(object self,object ev)
{
	self->begin_move_drag(ev->button,ev->x_root,ev->y_root,ev->time);
}

int main(int argc, array(string) argv)
{
	if (argc<2) exit(1, "USAGE: pike %s username [delay]\nWill display the current viewers for username's channel\nUpdates every delay seconds - default 10.\n");
	string username = argv[1];
	if (argc>2) delay = (int)argv[2] || 10;
	//First check if there's another process doing the same job. LINUX ONLY - might work on other Unices but untested.
	foreach (get_dir("/proc"), string fn) if (fn == (string)(int)fn) catch
	{
		//This might bomb, eg if the process is owned by another user.
		//If so, we assume that process doesn't matter to us.
		array(string) other_argv = Stdio.read_file("/proc/" + fn + "/cmdline") / "\0";
		if (sizeof(other_argv) < 3) continue; //Can't be what we want.
		if (other_argv[0] != "pike" && !has_suffix(other_argv[0], "/pike")) continue; //Not Pike
		if (other_argv[2] != argv[1]) continue; //Different Twitch user
		if (other_argv[1] == argv[0]) exit(0, "Already monitoring this user [pid=%s].\n", fn); //Exact file match
		//TODO: Sloppy script path matching, as long as they refer to the same file.
	};
	url = sprintf("http://tmi.twitch.tv/group/user/%s/chatters", lower_case(username));
	GTK2.setup_gtk();
	object win = GTK2.Window((["resizable": 0, "title": "Viewers on " + username + "'s stream", "decorated": 0]))
		->add(info=GTK2.Label("Loading...")->modify_fg(GTK2.STATE_NORMAL, GTK2.GdkColor(255, 255, 255)))
		->modify_bg(GTK2.STATE_NORMAL, GTK2.GdkColor(0, 0, 0))
		->set_keep_above(1)
		->show_all()
		->add_events(GTK2.GDK_BUTTON_PRESS_MASK);
	win->signal_connect("destroy", lambda() {exit(0);});
	win->signal_connect("button_press_event", drag);
	Thread.Thread(load_users);
	return -1;
}

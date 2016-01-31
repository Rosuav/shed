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
	GTK2.setup_gtk();
	string username = argv[1];
	if (argc>2) delay = (int)argv[2] || 10;
	url = sprintf("http://tmi.twitch.tv/group/user/%s/chatters", lower_case(username));
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

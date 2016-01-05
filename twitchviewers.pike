string username = "rosuav";
int delay = 10;
string url;
GTK2.Label info;

void load_users()
{
	while (1)
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
	}
}

int main(int argc, array(string) argv)
{
	if (argc<2) exit(1, "USAGE: pike %s username [delay]\nWill display the current viewers for username's channel\nUpdates every delay seconds - default 10.\n");
	GTK2.setup_gtk();
	username = argv[1];
	if (argc>2) delay = (int)argv[2] || 10;
	url = sprintf("http://tmi.twitch.tv/group/user/%s/chatters", lower_case(username));
	GTK2.Window(0)
		->set_title("Viewers on " + username + "'s stream")
		->add(info=GTK2.Label("Loading..."))
		->show_all()
		->signal_connect("destroy", lambda() {exit(0);});
	Thread.Thread(load_users);
	return -1;
}
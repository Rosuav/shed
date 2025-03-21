/*
Fire this up for your channel thus:

pike twitchviewers YourUserName

It'll show a little display of the currently-watching viewers, updated every 10ish seconds (or add
another argument to adjust update frequency). This can be loaded into OBS with window capture, or
simply left on screen as a ticking display.

Requires moderator authentication.
*/
int delay = 10;
GTK2.Label info;
string broadcaster_id, moderator_id;
string clientid, oauth_token;
multiset(string) moderators = (<>);

void load_users()
{
	while (1) //catch
	{
		//Note that we don't paginate. Only the first page is shown (including the total though).
		mapping data = Standards.JSON.decode_utf8(Protocols.HTTP.get_url_data(
			"https://api.twitch.tv/helix/chat/chatters",
			(["broadcaster_id": broadcaster_id, "moderator_id": moderator_id]),
			([
				"Client-ID": clientid,
				"Authorization": "Bearer " + oauth_token,
			]),
		));
		string output = sprintf("%d viewers", data->total);
		//Dividing people up into categories requires extra calls and caching.
		//For now, we only count mods (and the broadcaster), and only check that on
		//script start; this may therefore be inaccurate.
		string mods = "", viewers = "";
		sort(lower_case(data->data->user_name[*]), data->data);
		foreach (data->data, mapping user) {
			if (moderators[user->user_id]) mods += "\n" + user->user_name;
			else viewers += "\n" + user->user_name;
		}
		if (mods != "") output += "\n\nModerators:" + mods;
		if (viewers != "") output += "\n\nViewers:" + viewers;
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
	//TODO: Allow a separate moderator login, and then use bcaster_token
	//Note that querying mods requires broadcaster auth so maybe better to require that instead?
	clientid = Standards.JSON.decode_utf8(Stdio.read_file("../stillebot/instance-config.json"))->clientid;
	oauth_token = Standards.JSON.decode_utf8(
		Process.run(({"psql", "stillebot", "-tc", "select credentials from stillebot.settings"}))->stdout
	)->token;
	array users = Standards.JSON.decode_utf8(Protocols.HTTP.get_url_data(
		"https://api.twitch.tv/helix/users",
		(["login": username]),
		([
			"Client-ID": clientid,
			"Authorization": "Bearer " + oauth_token,
		]),
	))->data;
	if (!sizeof(users)) exit(1, "Unrecognized channel name\n");
	broadcaster_id = moderator_id = users[0]->id;
	moderators[broadcaster_id] = 1;
	array mods = Standards.JSON.decode_utf8(Protocols.HTTP.get_url_data(
		"https://api.twitch.tv/helix/moderation/moderators",
		(["broadcaster_id": broadcaster_id]),
		([
			"Client-ID": clientid,
			"Authorization": "Bearer " + oauth_token,
		]),
	) || "{\"data\":[]}")->data;
	foreach (mods, mapping mod) moderators[mod->user_id] = 1;
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

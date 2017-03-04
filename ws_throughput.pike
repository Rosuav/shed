//WebSocket throughput test (client only)

//Load parameters
constant GAMES = 5000;
constant PLAYERS_PER_GAME = 3;
constant BYTES_PER_MOVE = 10240; //Client to server
constant BYTES_PER_UPDATE = 10240; //Server to client
constant SECONDS_BETWEEN_MOVES = 30; //per player

//Convenience
constant move_data = "<" * BYTES_PER_MOVE;
constant update_data = ">" * BYTES_PER_UPDATE;

int stats_socks, stats_moves, stats_bytes;

void game_client(string host, string gameid, int player)
{
	if (has_value(host, ':')) host = "[" + host + "]"; //IPv6 literal
	object sock = Protocols.WebSocket.Connection();
	void json(mixed obj) {sock->send_text(Standards.JSON.encode(obj));}
	//Stagger the requests a bit
	int tm = (time() - SECONDS_BETWEEN_MOVES +
		SECONDS_BETWEEN_MOVES / PLAYERS_PER_GAME * player +
		random(SECONDS_BETWEEN_MOVES / PLAYERS_PER_GAME)
	);
	sock->onmessage = lambda(object fr) {
		if (fr->text) stats_bytes += sizeof(fr->text);
	};
	int closed = 0;
	void make_move()
	{
		if (closed) return;
		call_out(make_move, (tm += SECONDS_BETWEEN_MOVES) - time());
		stats_moves++;
		sock->send_text(move_data);
	}
	sock->onopen = lambda() {
		json((["type": "login", "data": (["room": gameid, "name": (string)player])]));
		call_out(make_move, (tm += SECONDS_BETWEEN_MOVES) - time());
		stats_socks--;
	};
	sock->onclose = lambda() {closed = 1;};
	sock->connect("ws://" + host + ":8888/ws");
	stats_socks++;
}

void establish_clients(array(string) hosts)
{
	string junk = sprintf("%x", 0x10000 + random(0xeffff));
	int host = 0;
	for (int game = 0; game < GAMES; ++game)
	{
		string gameid = "throughput" + junk + game;
		for (int player = 0; player < PLAYERS_PER_GAME; ++player)
			game_client(hosts[host++ % sizeof(hosts)], gameid, player);
	}
	write("Sockets established. Ctrl-C to halt test.\n");
}

void stats()
{
	int base = time(); float tm = time(base);
	write("%6s %8s %8s (delta time)\n", "Socks", "Moves/s", "KBytes/s");
	write("%6d %8.2f %8.2f <-- expected avg\n",
		//Expected sockets
		GAMES * PLAYERS_PER_GAME,
		//Expected moves/sec
		GAMES * PLAYERS_PER_GAME / (float)SECONDS_BETWEEN_MOVES,
		//Expected KB/sec
		GAMES * PLAYERS_PER_GAME**2 * BYTES_PER_UPDATE / (float)SECONDS_BETWEEN_MOVES / 1024,
	);
	while (1)
	{
		sleep(10);
		float t = time(base); float delay = t - tm; tm = t;
		write("%6d %8.2f %8.2f %.2f\n", stats_socks, stats_moves/delay, stats_bytes/delay/1024, delay);
		stats_moves = stats_bytes = 0;
	}
}

int main(int argc, array(string) argv)
{
	Thread.Thread(stats);
	establish_clients(argv[1..]);
	return -1;
}

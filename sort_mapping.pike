class sort_mapping(mapping(mixed:mixed) base)
{
	array(mixed) i, v;
	int pos = 0, top;
	void create()
	{
		i = indices(base); v = values(base); top = sizeof(base);
		sort(i, v);
	}

	bool first() {pos = 0; return top > 0;}
	int next() {return ++pos < top;}
	mixed index() {return pos < top ? i[pos] : UNDEFINED;}
	mixed value() {return pos < top ? v[pos] : UNDEFINED;}
	int _sizeof() {return top;}
	bool `!() {return pos >= top;}
	this_program `+(int steps)
	{
		this_program clone = this_program(([]));
		clone->i = i; clone->v = v; clone->top = top;
		//Can push pos past top - I don't care. Cannot push pos below zero though.
		clone->pos = pos + max(steps, -pos);
	}
	this_program `-(int steps) {return this + (-steps);}
	this_program `+=(int steps) {pos += max(steps, -pos); return this;}
}

int main()
{
	mapping(string:mapping(string:int)) movements=([]);
	foreach (#"
Rosuav stored focus crystal on Oct  4 21:46.
Tiella stored focus crystal on Oct  4 22:17.
Tiella stored focus crystal on Oct  4 22:17.
Tiella stored focus crystal on Oct  4 22:17.
Tiella stored focus crystal on Oct  4 22:17.
Tiella stored focus crystal on Oct  4 22:17.
Wylie stored focus crystal on Oct  5 03:42.
Galpora stored focus crystal on Oct  5 17:16.
Wylie stored focus crystal on Oct  5 23:36.
Tiella stored focus crystal on Oct  6 00:53.
Tiella stored focus crystal on Oct  6 00:53.
Jibrael stored focus crystal on Oct  6 02:23.
Tiella stored focus crystal on Oct  6 02:37.
Tiella stored focus crystal on Oct  6 02:37.
Tiella stored focus crystal on Oct  6 05:27.
Tiella stored focus crystal on Oct  6 05:27.
Tiella stored focus crystal on Oct  6 05:27.
Tiella stored focus crystal on Oct  7 00:06.
Tiella stored focus crystal on Oct  7 01:48.
Tiella stored focus crystal on Oct  7 01:48.
Tiella stored focus crystal on Oct  7 03:16.
Jibrael stored focus crystal on Oct  7 18:39.
Jibrael stored focus crystal on Oct  7 18:39.
Jibrael stored focus crystal on Oct  7 18:39.
Galpora stored focus crystal on Oct  7 22:06.
Tiella stored focus crystal on Oct  8 03:54.
Tiella stored focus crystal on Oct  8 10:12.
Wylie stored focus crystal on Oct  8 14:22.
Jibrael stored focus crystal on Oct  9 02:26.
Wylie stored focus crystal on Oct  9 03:56.
Wylie stored focus crystal on Oct  9 03:56.
Wylie stored focus crystal on Oct  9 14:45.
Galpora stored focus crystal on Oct  9 18:20.
Galpora stored focus crystal on Oct  9 19:01.
Galpora stored focus crystal on Oct  9 19:22.
Jibrael stored focus crystal on Oct 10 00:57.
Wylie stored focus crystal on Oct 10 06:07.
Wylie stored focus crystal on Oct 10 21:30.
Amariah stored focus crystal on Oct 10 23:41.
Amariah stored focus crystal on Oct 10 23:41.
Amariah stored focus crystal on Oct 10 23:41.
Amariah stored focus crystal on Oct 10 23:41.
Wylie stored focus crystal on Oct 10 23:58.
Wylie stored focus crystal on Oct 11 04:39.
Wylie stored focus crystal on Oct 12 20:15.
Wylie stored focus crystal on Oct 13 21:20.
Wylie stored focus crystal on Oct 13 21:20.
Wylie stored focus crystal on Oct 13 21:20.
Wylie stored focus crystal on Oct 13 21:20.
Wylie stored focus crystal on Oct 13 21:20.
Wylie stored focus crystal on Oct 14 04:55.
Wylie stored focus crystal on Oct 14 04:55.
Wylie stored focus crystal on Oct 14 14:45.
Wylie stored focus crystal on Oct 14 21:29.
Wylie stored focus crystal on Oct 15 05:27.
Wylie stored focus crystal on Oct 15 05:27.
Wylie stored focus crystal on Oct 16 05:58.
Wylie stored focus crystal on Oct 16 05:58.
Wylie stored focus crystal on Oct 16 06:00.
Wylie stored focus crystal on Oct 16 06:00.
Wylie stored focus crystal on Oct 17 00:14.
Sekoth stored focus crystal on Oct 19 19:59.
Tiella stored focus crystal on Oct 20 01:30.
Tiella stored focus crystal on Oct 20 01:30.
Sekoth stored focus crystal on Oct 20 19:32.
Sekoth stored focus crystal on Oct 20 19:32.
Thaelos stored focus crystal on Oct 23 08:30.
Thaelos stored focus crystal on Oct 23 08:31.
Thaelos stored focus crystal on Oct 23 20:16.
Tiella stored focus crystal on Oct 26 06:50.
Wylie stored focus crystal on Oct 26 17:03.
Thaelos stored focus crystal on Oct 27 18:30.
Rosuav stored focus crystal on Oct 28 11:39.
Thaelos stored focus crystal on Oct 28 21:26.
Rosuav stored focus crystal on Oct 29 13:15.
Thaelos stored focus crystal on Oct 29 16:25.
Thaelos stored focus crystal on Oct 29 16:25.
Thaelos stored focus crystal on Oct 29 16:25.
Thaelos stored focus crystal on Oct 29 16:26.
Thaelos stored focus crystal on Oct 29 18:00.
Thaelos stored focus crystal on Oct 30 16:27.
Thaelos stored focus crystal on Oct 30 16:27.
Thaelos stored focus crystal on Oct 30 16:40.
Thaelos stored focus crystal on Oct 30 19:45.
Thaelos stored focus crystal on Oct 30 22:01.
Rosuav stored focus crystal on Oct 31 10:49.
Thaelos stored focus crystal on Oct 31 21:26.
Thaelos stored focus crystal on Oct 31 21:26.
Thaelos stored focus crystal on Nov  1 18:51.
Thaelos stored focus crystal on Nov  1 18:51.
Rosuav stored focus crystal on Nov  2 13:26.
Rosuav stored focus crystal on Nov  2 13:26.
Thaelos stored focus crystal on Nov  2 15:57.
Thaelos stored focus crystal on Nov  2 20:15.
Thaelos stored focus crystal on Nov  2 20:15.
Thaelos stored focus crystal on Nov  2 20:38.
Rosuav vaulted purified focus crystal on Oct  4 21:49.
Rosuav vaulted purified focus crystal on Oct  6 22:51.
Tiella vaulted purified focus crystal on Oct  6 22:55.
Tiella vaulted purified focus crystal on Oct  6 22:55.
Tiella vaulted purified focus crystal on Oct  6 22:55.
Tiella vaulted purified focus crystal on Oct  6 23:09.
Tiella vaulted purified focus crystal on Oct  6 23:09.
Tiella vaulted purified focus crystal on Oct  6 23:09.
Rosuav vaulted purified focus crystal on Oct  6 23:12.
Rosuav vaulted purified focus crystal on Oct  6 23:19.
Rosuav vaulted purified focus crystal on Oct 10 23:48.
Rosuav vaulted purified focus crystal on Oct 15 03:32.
Rosuav vaulted purified focus crystal on Oct 15 04:31.
Rosuav vaulted purified focus crystal on Oct 15 05:33.
Gorn vaulted purified focus crystal on Oct 19 23:41.
Rosuav vaulted purified focus crystal on Oct 23 08:34.
Gorn vaulted purified focus crystal on Oct 23 21:08.
Gorn vaulted purified focus crystal on Oct 23 21:08.
Gorn vaulted purified focus crystal on Oct 23 21:08.
Gorn vaulted purified focus crystal on Oct 23 21:08.
Thaelos vaulted purified focus crystal on Oct 23 21:26.
Thaelos vaulted purified focus crystal on Oct 24 06:26.
Thaelos vaulted purified focus crystal on Oct 24 07:32.
Thaelos vaulted purified focus crystal on Oct 26 11:44.
Thaelos vaulted purified focus crystal on Oct 31 22:10.
Thaelos vaulted purified focus crystal on Oct 31 22:10.
Thaelos vaulted purified focus crystal on Nov  1 19:14.
Thaelos vaulted purified focus crystal on Nov  1 19:14.
Gorn vaulted purified focus crystal on Nov  2 00:31.
Thaelos vaulted purified focus crystal on Nov  2 16:32.
Thaelos vaulted purified focus crystal on Nov  2 20:38.
Thaelos vaulted purified focus crystal on Nov  2 21:06.
Thaelos vaulted purified focus crystal on Nov  2 21:36.
Tiella vaulted purified focus crystal on Nov  3 01:27.
Tiella vaulted purified focus crystal on Nov  3 01:27.
Tiella vaulted purified focus crystal on Nov  3 01:44.
Rosuav vaulted purified focus crystal on Nov  3 08:30.
Rosuav withdrew focus crystal on Oct  4 21:46.
Wylie withdrew focus crystal on Oct  5 03:33.
Jibrael withdrew focus crystal on Oct  5 20:10.
Jibrael withdrew focus crystal on Oct  6 20:13.
Jibrael withdrew focus crystal on Oct  6 20:13.
Tiella withdrew focus crystal on Oct  6 22:18.
Tiella withdrew focus crystal on Oct  6 22:18.
Tiella withdrew focus crystal on Oct  6 22:18.
Tiella withdrew focus crystal on Oct  6 22:22.
Tiella withdrew focus crystal on Oct  6 22:22.
Tiella withdrew focus crystal on Oct  6 22:22.
Tiella withdrew focus crystal on Oct  6 22:22.
Tiella withdrew focus crystal on Oct  6 22:22.
Tiella withdrew focus crystal on Oct  6 22:56.
Tiella withdrew focus crystal on Oct  6 22:56.
Tiella withdrew focus crystal on Oct  6 22:56.
Tiella withdrew focus crystal on Oct  6 22:56.
Jibrael withdrew focus crystal on Oct  7 08:56.
Jibrael withdrew focus crystal on Oct  7 08:56.
Wylie withdrew focus crystal on Oct  9 14:05.
Jibrael withdrew focus crystal on Oct 10 07:39.
Jibrael withdrew focus crystal on Oct 10 07:39.
Amariah withdrew focus crystal on Oct 10 22:54.
Amariah withdrew focus crystal on Oct 10 22:54.
Amariah withdrew focus crystal on Oct 10 22:54.
Amariah withdrew focus crystal on Oct 10 22:54.
Jibrael withdrew focus crystal on Oct 11 13:55.
Jibrael withdrew focus crystal on Oct 11 13:55.
Rosuav withdrew focus crystal on Oct 15 03:20.
Rosuav withdrew focus crystal on Oct 15 03:20.
Rosuav withdrew focus crystal on Oct 15 03:20.
Wylie withdrew focus crystal on Oct 15 20:40.
Wylie withdrew focus crystal on Oct 15 20:40.
Wylie withdrew focus crystal on Oct 15 20:40.
Wylie withdrew focus crystal on Oct 15 20:40.
Wylie withdrew focus crystal on Oct 16 13:03.
Wylie withdrew focus crystal on Oct 16 13:03.
Wylie withdrew focus crystal on Oct 16 13:03.
Wylie withdrew focus crystal on Oct 16 13:03.
Tiella withdrew focus crystal on Oct 19 19:33.
Tiella withdrew focus crystal on Oct 19 19:33.
Sekoth withdrew focus crystal on Oct 19 19:34.
Zossiz withdrew focus crystal on Oct 20 23:54.
Zossiz withdrew focus crystal on Oct 21 13:33.
Zossiz withdrew focus crystal on Oct 22 13:43.
Rosuav withdrew focus crystal on Oct 23 08:29.
Rosuav withdrew focus crystal on Oct 23 08:31.
Gorn withdrew focus crystal on Oct 23 19:20.
Gorn withdrew focus crystal on Oct 23 19:20.
Gorn withdrew focus crystal on Oct 23 19:20.
Gorn withdrew focus crystal on Oct 23 19:20.
Thaelos withdrew focus crystal on Oct 23 20:17.
Zossiz withdrew focus crystal on Oct 23 20:56.
Thaelos withdrew focus crystal on Oct 24 06:00.
Thaelos withdrew focus crystal on Oct 24 06:26.
Rosuav withdrew focus crystal on Oct 25 03:17.
Rosuav withdrew focus crystal on Oct 25 03:17.
Rosuav withdrew focus crystal on Oct 25 21:55.
Rosuav withdrew focus crystal on Oct 25 21:55.
Scipio withdrew focus crystal on Oct 25 23:33.
Thaelos withdrew focus crystal on Oct 26 11:28.
Wylie withdrew focus crystal on Oct 26 15:26.
Wylie withdrew focus crystal on Oct 26 15:26.
Wylie withdrew focus crystal on Oct 26 15:26.
Wylie withdrew focus crystal on Oct 26 15:26.
Thaelos withdrew focus crystal on Oct 31 21:26.
Thaelos withdrew focus crystal on Oct 31 21:26.
Thaelos withdrew focus crystal on Nov  1 18:51.
Thaelos withdrew focus crystal on Nov  1 18:51.
Rosuav withdrew focus crystal on Nov  2 06:05.
Rosuav withdrew focus crystal on Nov  2 06:05.
Thaelos withdrew focus crystal on Nov  2 15:57.
Thaelos withdrew focus crystal on Nov  2 20:15.
Thaelos withdrew focus crystal on Nov  2 20:15.
Thaelos withdrew focus crystal on Nov  2 20:38.
Tiella withdrew purified focus crystal on Oct  6 22:19.
Rosuav withdrew purified focus crystal on Oct 15 08:01.
Scipio withdrew purified focus crystal on Oct 18 17:04.
Rosuav withdrew purified focus crystal on Oct 19 10:49.
Tiella withdrew purified focus crystal on Oct 19 19:33.
Rosuav withdrew purified focus crystal on Oct 22 11:50.
Rosuav withdrew purified focus crystal on Oct 25 03:12.
Rosuav withdrew purified focus crystal on Oct 25 20:35.
Rosuav withdrew purified focus crystal on Oct 26 08:57.
Rosuav withdrew purified focus crystal on Oct 30 06:36.
Rosuav withdrew purified focus crystal on Nov  1 08:41.
Rosuav withdrew purified focus crystal on Nov  2 06:05.
"/"\n",string line) if (sscanf(line,"%s %s %s on %*s",string subj,string verb,string obj)==4)
	{
		if (verb=="withdrew" && obj=="purified focus crystal") verb="procured";
		mapping person=movements[subj]; if (!person) person=movements[subj]=([]);
		person[verb]++;
	}
	write("%20s %8s %8s\n","Person","Cloudy","Clear");
	foreach (sort_mapping(movements);string subj;mapping info)
	{
		string cloudy="",clear="";
		if (info->stored) cloudy+="+"+info->stored;
		if (info->withdrew) cloudy+="-"+info->withdrew;
		if (info->vaulted) clear+="+"+info->vaulted;
		if (info->procured) clear+="-"+info->procured;
		write("%20s %8s %8s\n",subj,cloudy,clear);
	}
}

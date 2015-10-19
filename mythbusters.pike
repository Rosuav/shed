/*
Scrape the Wikipedia articles about Mythbusters episodes and compile a more-or-less readable form of the list.

TODO: More wiki-to-text translations, as appropriate

TODO: Should this actually parse wiki markup, instead of depending on heaps of formatting details?
*/

Stdio.File out=Stdio.File("_mythbusters.txt","wct");

int fetch(int year,string url)
{
	write("Fetching %d... ",year);
	#ifdef USE_INTERNAL_CONNECTION
	string data=Protocols.HTTP.get_url_data(url);
	if (!data) return 0;
	#else
	string data=Process.run(({"wget",url,"-qO-"}))->stdout;
	if (data=="") return 0;
	#endif
	sscanf(data,"%*s<onlyinclude>%s</onlyinclude>",string body);
	if (!body) return 0; //All we care about is the stuff transcluded into the main page - not the episode details. If there is no such section, it's probably a redirect or something.
	int count=0;
	while (sscanf(body,"%*s{{Episode list\n|%s\n}}%s",string ep,body))
	{
		mapping info=([]);
		while (ep!="" && sscanf(ep,"%s=%s\n|%s",string kwd,string val,ep)==3) info[String.trim_all_whites(kwd)]=String.trim_all_whites(val);
		sscanf(info->Title||"","[[%*s|%s]]",string title);
		string myths=info->ShortSummary||""; sscanf(myths,"'''Myths tested''':%s",myths);
		while (sscanf(myths,"%s[[%s]]%s",string before,string link,string after)==3) myths=before+(link/"|")[-1]+after;
		while (sscanf(myths,"%s<ref%s</ref>%s",string before,string ref,string after)==3) myths=before+after; //Strip references completely
		myths-="'''Note''': This was a special episode."; //We really don't need that tag repeated everywhere...
		myths-="'''Note''': This is a special episode."; //Nor this form of it...
		out->write("/%d-%s %s.mkv\n%s\n\n",
			year,replace(info->EpisodeNumber2||"00","Special ","SP"),
			replace(title||"title unknown","/","-"),
			String.trim_all_whites(replace(myths,"<br />","\n"))
		);
		++count;
	}
	write("%d episodes.\n",count);
	return count;
}

int main()
{
	fetch(2003,"http://en.wikipedia.org/w/index.php?title=List_of_MythBusters_pilot_episodes&action=raw"); //Hack: Grab the pilot episodes and count them as 2003, same as the first actual year (they count as specials)
	for (int year=2003;fetch(year,"http://en.wikipedia.org/w/index.php?title=MythBusters_("+year+"_season)&action=raw");++year);
	write("No such page found - all done.\n");
	out->close();
	Process.create_process(({"git","commit","_mythbusters.txt","-mUpdate Mythbusters from Wikipedia"}))->wait();
	Process.create_process(({"scp","_mythbusters.txt","huix:/video/Mythbusters/00index.txt"}))->wait();
}

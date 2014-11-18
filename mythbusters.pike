/*
Scrape the Wikipedia articles about Mythbusters episodes and compile a more-or-less readable form of the list.

TODO: More wiki-to-text translations, as appropriate

TODO: Should this actually parse wiki markup, instead of depending on heaps of formatting details?
*/

int main()
{
	Stdio.File out=Stdio.File("mythbusters.txt","wct");
	for (int year=2003;;++year)
	{
		write("Fetching %d... ",year);
		string data=Protocols.HTTP.get_url_data("http://en.wikipedia.org/w/index.php?title=MythBusters_("+year+"_season)&action=raw");
		if (!data) break;
		sscanf(data,"%*s<onlyinclude>%s</onlyinclude>",string body);
		if (!body) break; //All we care about is the stuff transcluded into the main page - not the episode details. If there is no such section, it's probably a redirect or something.
		int count=0;
		while (sscanf(body,"%*s{{Episode list\n|%s\n}}%s",string ep,body))
		{
			mapping info=([]);
			while (ep!="" && sscanf(ep,"%s=%s\n|%s",string kwd,string val,ep)==3) info[String.trim_all_whites(kwd)]=String.trim_all_whites(val);
			sscanf(info->Title||"","[[%*s|%s]]",string title);
			string myths=info->ShortSummary||""; sscanf(myths,"'''Myths tested''':%s",myths);
			while (sscanf(myths,"%s[[%s]]%s",string before,string link,string after)==3) myths=before+(link/"|")[-1]+after;
			myths-="'''Note''': This was a special episode."; //We really don't need that tag repeated everywhere...
			out->write("%d-%s %s.mkv\n%s\n\n",
				year,replace(info->EpisodeNumber2||"00","Special ","SP"),
				replace(title||"title unknown","/","-"),
				String.trim_all_whites(replace(myths,"<br />","\n"))
			);
			++count;
		}
		write("%d episodes.\n",count);
	}
	write("No such page found - all done.\n");
}

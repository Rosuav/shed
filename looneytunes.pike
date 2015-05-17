int main(int argc,array(string) argv)
{
	if (argc>1 && argv[1]=="index")
	{
		string url="http://looney.goldenagecartoons.com/WBchecklist.html";
		string data=replace(Protocols.HTTP.get_url_data(url),"\r","");
		sscanf(data,"%{%*s\n19%2d:\n%{____ %s\n%}%}",array years);
		Stdio.File out=Stdio.File("LooneyTunes.txt","wct");
		out->write("Looney Tunes checklist from %s\n\n",url);
		foreach (years,[int year,array(array(string)) titles])
			out->write("%{/19"+year+" - %s.mkv\n%}",titles);
		return 0;
	}
}

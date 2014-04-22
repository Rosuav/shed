/*
PiTiVi (or Pitivi as it's now styled) saves XML project files. If the project
consists solely of clipping one piece from one file (as a number of mine did),
the same job can be done by ffmpeg or avconv. This script parses the .xptv
file(s) named and shells out to avconv to recreate the clips (and also logs
the commands used, in case that's of use).
*/
int main(int argc,array(string) argv)
{
	foreach (argv[1..],string xptv) parse(xptv);
}

//Convert a nanosecond timestamp into seconds and optional milliseconds
string xml2secms(string xmltime)
{
	int ns=(int)(xmltime-"(gint64)");
	string ret=(string)(ns/1000000000);
	if (int ms=ns/1000000%1000) return sprintf("%s.%03d",ret,ms);
	return ret;
}

void parse(string xptv)
{
	mixed req=Parser.XML.Simple()->parse(Stdio.read_file(xptv),
	    lambda(string type,
		string name,
		mapping(string:string) attr,
		mixed data,
		mixed loc,
		mixed ... extra) {
	    switch(type) {
		case "<?xml":
		    return 0;
		case "":
		case "<![CDATA[":
		    return data;
		case "<":
		    return 0;
		case "<>":
		case ">":
		    {
			array|mapping ret=({});
			if (data)
			    foreach (data, mixed x)
				if (arrayp(x)) {
				    ret=x;
				} else if (stringp(x) && sizeof(String.trim_all_whites(x))) {
				    ret+=({ x });
				} else if (mappingp(x)) {
				    if (!mappingp(ret)) {
					ret=attr;
				    }
				    foreach (x; mixed key; mixed val) {
					if (arrayp(val) && arrayp(ret[key])) {
					    ret[key]+=val;
					} else if (mappingp(ret[key])) {
					    if (has_index(ret,key)) {
						mixed m=ret[key];
						ret[key]=({ m,val });
					    } else {
						ret[key]=val;
					    }
					} else {
					    ret[key]=val;
					}
				    }
				}
				return ([ name: ret ]);
		    }
	    default:
		return 0;
	    }
	});

	string fn=req[0]->pitivi->factories->sources->source->filename;
	fn=Protocols.HTTP.uri_decode(Standards.URI(fn)->path);
	//Hack: I renamed "Disney Classic" to "Disney" since making those xptv files.
	fn=replace(fn,"Disney Classic/","Disney/");
	if (!file_stat(fn)) {werror("%s: Not found\n",fn); return;}
	mixed track=req[0]->pitivi->timeline->tracks->track[0]["track-objects"]["track-object"];
	if (arrayp(track)) track=track[0];
	string start=xml2secms(track->in_point);
	string length=xml2secms(track->media_duration);
	string outfn=explode_path(xptv)[-1]-".xptv"+".mkv";
	array(string) cmd=({"avconv","-i",fn,"-ss",start,"-t",length,outfn});
	string shellcmd=sprintf("%{%s %}\n",Process.sh_quote(cmd[*]));
	write(shellcmd);
	Stdio.append_file("xptv_to_avconv.log",shellcmd);
	Process.create_process(cmd)->wait();
}

int main(int argc,array(string) argv)
{
	string in,out;
	switch (argc)
	{
		case 1: exit(0,"USAGE: %s infile [outfile]\nConverts XML annotations from Youtube into .srt format\n");
		case 2: in=argv[1]; out=in-".xml"+".srt"; break;
		default: in=argv[1]; out=argv[2]; break;
	}
	mixed data=Parser.XML.Simple()->parse(utf8_to_string(Stdio.read_file(in)),
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
			//Hack. This is the only attribute we care about.
			if ((<"rectRegion","anchoredRegion">)[name] && attr && attr->t) return attr->t;
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
					} else if (arrayp(ret[key])) {
					    ret[key]+=({val});
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
	array(string) srt=({ });
	foreach (data[0]->document->annotations->annotation,mapping ann)
	{
		//Interesting subelements:
		//ann->TEXT[0]: text to be output (there seems to be always exactly one element)
		//ann->segment->movingRegion: array of two strings, ({start time, end time})
		[string starttime,string endtime]=ann->segment->movingRegion;
		string text=ann->TEXT[0];
		sscanf(starttime,"%d:%d.%d",int min,int sec,int ms); //Not sure what happens if it goes over an hour.
		starttime=sprintf("00:%02d:%02d.%03d",min,sec,ms);
		sscanf(endtime,"%d:%d.%d",min,sec,ms); //Likewise.
		endtime=sprintf("00:%02d:%02d.%03d",min,sec,ms);
		srt+=({sprintf("%s --> %s\n%s\n",starttime,endtime,replace(text,"\n\n","\n"))}); //Squish out any blank lines, for safety.
	}
	Stdio.write_file(out,string_to_utf8(sort(srt)*"\n"));
}

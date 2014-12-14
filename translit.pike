#charset utf-8
//Due to the use of GPL/LGPL transliteration data, this script, unlike
//pretty much everything else I write, is licensed GPL 2.0.

//From Gypsum
multiset(GTK2.Widget) _noexpand=(<>);
GTK2.Widget noex(GTK2.Widget wid) {_noexpand[wid]=1; return wid;}
GTK2.Table GTK2Table(array(array(string|GTK2.Widget)) contents,mapping|void label_opts)
{
	if (!label_opts) label_opts=([]);
	GTK2.Table tb=GTK2.Table(sizeof(contents[0]),sizeof(contents),0);
	foreach (contents;int y;array(string|GTK2.Widget) row) foreach (row;int x;string|GTK2.Widget obj) if (obj)
	{
		int opt;
		if (stringp(obj)) {obj=GTK2.Label(label_opts+(["label":obj])); opt=GTK2.Fill;}
		else if (_noexpand[obj]) _noexpand[obj]=0; //Remove it from the set so we don't hang onto references to stuff we don't need
		else opt=GTK2.Fill|GTK2.Expand;
		int xend=x+1; while (xend<sizeof(row) && !row[xend]) ++xend; //Span cols by putting 0 after the element
		tb->attach(obj,x,xend,y,y+1,opt,opt,1,1);
	}
	return tb;
}
GTK2.Table two_column(array(string|GTK2.Widget) contents) {return GTK2Table(contents/2,(["xalign":1.0]));}
//End from Gypsum

//Translation table taken from https://pypi.python.org/pypi/transliterate
//License: GPL 2.0/LGPL 2.1
//This translation should be a self-reversing ISO-9 transliteration.
//The preprocessing is a two-step stabilization: first, Roman letters with
//no diacriticals, easily typed; these translate into Cyrillic letters, but
//the reverse transformation produces single letters with diacriticals.
//The two-letter (or three-letter) codes come from the above link; the
//diacritical forms come from passing the Cyrillic letters through the
//"Unicode to ISO-9" mode of http://www.convertcyrillic.com/Convert.aspx
array preprocess=({
	//Cyrillic, then canonical Latin, then aliases for the Latin.
	//The aliases will be the easiest to type, but will be replaced
	//prior to output with the canonical character.
	"ж ž zh",
	"ц c ts",
	"ч č ch",
	"ш š sh",
	"щ ŝ sch",
	"ю û ju yu",
	"я â ja ya",
	"Ж Ž Zh",
	"Ц C Ts",
	"Ч Č Ch",
	"Ш Š Sh",
	"Щ Ŝ Sch",
	"Ю Û Ju Yu",
	"Я Â Ja Ya"
})[*]/" ";
mapping preprocess_r2c=(["'":"’","\"":"″"]); //The rest is done in create() - not main() as this may be imported by other scripts
mapping preprocess_c2r=mkmapping(@Array.columns(preprocess,({0,1})));
constant latin  ="abvgdezijklmnoprstufh″y’ABVGDEZIJKLMNOPRSTUFH″Y’";
constant russian="абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ";
//End from Python transliterate module
constant serbian="абвгдезијклмнопрстуфхъыьАБВГДЕЗИЈКЛМНОПРСТУФХЪЫЬ"; //TODO: Check if this is the right translation table
constant ukraine="абвґдезійклмнопрстуфгъиьАБВҐДЕЗІЙКЛМНОПРСТУФГЪИЬ"; //(fudging the variable name for alignment)
string Latin_to_Russian(string input)   {return replace(replace(input,preprocess_r2c),latin/1,russian/1);}
string Russian_to_Latin(string input)   {return replace(replace(input,preprocess_c2r),russian/1,latin/1);}
string Latin_to_Serbian(string input)   {return replace(replace(input,preprocess_r2c),latin/1,serbian/1);}
string Serbian_to_Latin(string input)   {return replace(replace(input,preprocess_c2r),serbian/1,latin/1);}
string Latin_to_Ukrainian(string input) {return replace(replace(input,preprocess_r2c),latin/1,ukraine/1);}
string Ukrainian_to_Latin(string input) {return replace(replace(input,preprocess_c2r),ukraine/1,latin/1);}

void create()
{
	foreach (preprocess,array(string) set)
		foreach (set[1..],string alias) preprocess_r2c[alias]=set[0];
}

//Translate "a\'" into "á" - specifically, translate "\'" into U+0301,
//and then attempt Unicode NFC normalization. Other escapes similarly.
//(Note that these are single backslashes, the above examples are not
//code snippets. In code, double the backslashes.)
string diacriticals(string input)
{
	//Note that using \: for U+030B is pushing it, UI-wise. (It's the double acute accent; for
	//instance, Hungarian uses an acute accent to indicate a long vowel, with double acute used
	//to indicate the long forms of vowels with umlauts.) I've no idea what would make sense.
	//Possibly it'd be worth taking \" for that, but then what would be better for U+0308?
	mapping map=(["\\!":"\u00A1","\\?":"\u00BF","\\`":"\u0300","\\'":"\u0301","\\^":"\u0302","\\~":"\u0303","\\\"":"\u0308","\\o":"\u030A","\\:":"\u030B","\\,":"\u0327","o\\e":"ø","a\\e":"æ","s\\s":"ß"]);
	input=replace(input,map);
	return Unicode.normalize(input,"NFC"); //Attempt to compose characters as much as possible - some applications have issues with combining characters
}

void update(object self,array args)
{
	[object other,function translit]=args;
	string txt=translit(self->get_text());
	if (other) {if (txt!=other->get_text()) other->set_text(txt);}
	else {if (txt!=self->get_text()) self->set_text(txt);} //Self-translation only
}

int main(int argc,array(string) argv)
{
	GTK2.setup_gtk();
	GTK2.Entry roman,other=GTK2.Entry();
	GTK2.Entry original,trans;
	GTK2.Button next,pause;
	string lang="Russian";
	if (argc>1 && (<"Latin","Russian","Serbian","Ukrainian">)[argv[1]]) argv-=({lang=argv[1]});
	int srtmode=(sizeof(argv)>1 && !!file_stat(argv[1])); //If you provide a .srt file on the command line, have extra features active.
	GTK2.Window(0)->set_title(lang+" transliteration")->add(two_column(({
		srtmode && "Original",srtmode && (original=GTK2.Entry()),
		lang!="Latin" && lang,lang!="Latin" && other,
		"Roman",roman=GTK2.Entry(),
		srtmode && "Trans",srtmode && (trans=GTK2.Entry()),
		srtmode && (GTK2.HbuttonBox()->add(pause=GTK2.Button("_Pause")->set_use_underline(1))->add(next=GTK2.Button("_Next")->set_use_underline(1))),0,
	})))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	if (lang!="Latin")
	{
		roman->signal_connect("changed",update,({other,this["Latin_to_"+lang]}));
		other->signal_connect("changed",update,({roman,this[lang+"_to_Latin"]}));
	}
	else roman->signal_connect("changed",update,({0,diacriticals}));
	if (next) next->signal_connect("clicked",lambda() {
		array(string) data=utf8_to_string(Stdio.read_file(argv[1]))/"\n\n";
		string orig=original->get_text();
		original->set_text(""); //In case we find nothing
		foreach (data;int i;string paragraph) if (sizeof(paragraph/"\n"-({""}))==2)
		{
			//Two-line paragraphs need translations entered. If the first one we see
			//has the same text as the 'Original' field, and we have data entered,
			//patch in the new content.
			string english=(paragraph/"\n")[1];
			if (orig!="" && orig==english)
			{
				data[i]=sprintf("%s%{\n%s%}",String.trim_all_whites(paragraph),({other->get_text(),roman->get_text(),trans->get_text()})-({""}));
				Stdio.write_file(argv[1],string_to_utf8(String.trim_all_whites(data*"\n\n")+"\n"));
				continue;
			}
			//The first two-line paragraph, ignoring any we're patching in, ought
			//to be the next one needing translation.
			original->set_text(english);
			break;
		}
		({other, roman, trans})->set_text("");
		roman->grab_focus();
	});
	Stdio.File vlc;
	if (pause) pause->signal_connect("clicked",lambda() {
		if (!vlc) catch
		{
			(vlc=Stdio.File())->connect("localhost",4212);
			vlc->write("admin\n");
		};
		if (catch {vlc->write("pause\n");}) vlc=0; //Note that the "pause" command toggles paused status, but if you want an explicit "unpause" command, that's there too ("play").
	});
	return -1;
}

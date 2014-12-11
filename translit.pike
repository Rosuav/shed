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
	"zh ж ž",
	"ts ц c",
	"ch ч č",
	"sh ш š",
	"sch щ ŝ",
	"ju ю û",
	"ja я â",
	"Zh Ж Ž",
	"Ts Ц C",
	"Ch Ч Č",
	"Sh Ш Š",
	"Sch Щ Ŝ",
	"Ju Ю Û",
	"Ja Я Â"
})[*]/" ";
//I'm doing it this way just because it's cool and I almost never have an excuse to use Array.columns :)
mapping preprocess_r2c=mkmapping(@Array.columns(preprocess,({0,1})))+mkmapping(@Array.columns(preprocess,({2,1})))+(["'":"’","\"":"″"]);
mapping preprocess_c2r=mkmapping(@Array.columns(preprocess,({1,2})));
string r2c(string input)
{
	return replace(replace(input,preprocess_r2c),
		"abvgdezijklmnoprstufh″y’ABVGDEZIJKLMNOPRSTUFH″Y’"/1,
		"абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ"/1,
	);
}
string c2r(string input)
{
	return replace(replace(input,preprocess_c2r),
		"абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ"/1,
		"abvgdezijklmnoprstufh″y’ABVGDEZIJKLMNOPRSTUFH″Y’"/1,
	);
}
//End from Python transliterate module

//Translate "a\'" into "á" - specifically, translate "\'" into U+0301.
//Likewise "\`" becomes U+0300 (grave), "\," becomes U+0327 (cedilla),
//"\^" becomes U+0302 (circumflex), and others can be added easily.
//(Note that these are single backslashes, the above examples are not
//code snippets. In code, double the backslashes.)
string diacriticals(string input)
{
	while (sscanf(input,"%s\\%1['`,^]%s",string before,string marker,string after) && after)
		input=sprintf("%s%c%s",before,(["'":0x0301,"`":0x0300,",":0x0327,"^":0x0302])[marker],after);
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
	GTK2.Button next;
	string lang="Cyrillic";
	if (argc>1 && (<"Latin","Cyrillic">)[argv[1]]) argv-=({lang=argv[1]});
	int srtmode=(sizeof(argv)>1 && !!file_stat(argv[1])); //If you provide a .srt file on the command line, have extra features active.
	GTK2.Window(0)->set_title(lang+" transliteration")->add(two_column(({
		srtmode && "Original",srtmode && (original=GTK2.Entry()),
		lang!="Latin" && lang,lang!="Latin" && other,
		"Roman",roman=GTK2.Entry(),
		srtmode && "Trans",srtmode && (trans=GTK2.Entry()),
		srtmode && (next=GTK2.Button("_Next")->set_use_underline(1)),0,
	})))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	if (lang!="Latin")
	{
		roman->signal_connect("changed",update,({other,r2c}));
		other->signal_connect("changed",update,({roman,c2r}));
	}
	else roman->signal_connect("changed",update,({0,diacriticals}));
	if (next) next->signal_connect("clicked",lambda() {
		string data=utf8_to_string(Stdio.read_file(argv[1]));
		string orig=original->get_text();
		if (orig!="" && sscanf(data,"%s"+orig+"\n\n%s",string before,string after)==2)
			Stdio.write_file(argv[1],string_to_utf8(data=sprintf("%s%{%s\n%}\n%s",before,({orig,other->get_text(),roman->get_text(),trans->get_text()})-({""}),after)));
		original->set_text(""); //In case we find nothing
		foreach (data/"\n\n",string paragraph) if (sizeof(paragraph/"\n")==2)
		{
			//The first two-line paragraph ought to be the next one needing doing.
			original->set_text((paragraph/"\n")[1]);
			break;
		}
		({other, roman, trans})->set_text("");
		roman->grab_focus();
	});
	return -1;
}

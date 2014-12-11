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
mapping preprocess_r2c=mkmapping(@Array.columns(preprocess,({0,1})))+mkmapping(@Array.columns(preprocess,({2,1})));
mapping preprocess_c2r=mkmapping(@Array.columns(preprocess,({1,2})));
string r2c(string input)
{
	return replace(replace(input,preprocess_r2c),
		"abvgdezijklmnoprstufh’y’ABVGDEZIJKLMNOPRSTUFH'Y'"/1,
		"абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ"/1,
	);
}
string c2r(string input)
{
	return replace(replace(input,preprocess_c2r),
		"абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ"/1,
		"abvgdezijklmnoprstufh’y’ABVGDEZIJKLMNOPRSTUFH’Y’"/1,
	);
}
//End from Python transliterate module

void update(object self,array args)
{
	[object other,function translit]=args;
	string txt=translit(self->get_text());
	if (txt!=other->get_text()) other->set_text(txt);
}

int main()
{
	GTK2.Entry roman,cyrillic;
	GTK2.setup_gtk();
	GTK2.Window(0)->set_title("Cyrillic transliteration")->add(two_column(({
		"Cyrillic",cyrillic=GTK2.Entry(),
		"Roman",roman=GTK2.Entry(),
	})))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	roman->signal_connect("changed",update,({cyrillic,r2c}));
	cyrillic->signal_connect("changed",update,({roman,c2r}));
	return -1;
}

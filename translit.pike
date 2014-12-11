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
string translit(string input)
{
	return replace(input,
		"abvgdezijklmnoprstufh'y'ABVGDEZIJKLMNOPRSTUFH'Y'"/1+"абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ"/1,
		"абвгдезийклмнопрстуфхъыьАБВГДЕЗИЙКЛМНОПРСТУФХЪЫЬ"/1+"abvgdezijklmnoprstufh'y'ABVGDEZIJKLMNOPRSTUFH'Y'"/1,
	);
}
//End from Python transliterate module

void update(object self,object other)
{
	string txt=translit(self->get_text());
	if (txt!=other->get_text()) other->set_text(txt);
}

int main()
{
	GTK2.Entry roman,cyrillic;
	GTK2.setup_gtk();
	GTK2.Window(0)->set_title("Cyrillic transliteration")->add(two_column(({
		"Roman",roman=GTK2.Entry(),
		"Cyrillic",cyrillic=GTK2.Entry(),
	})))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	roman->signal_connect("changed",update,cyrillic);
	cyrillic->signal_connect("changed",update,roman);
	return -1;
}

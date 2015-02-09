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
	"Я Â Ja Ya",
	"є ye je", //Possibly only for Ukrainian? I can't find a canonical one-character representation in ISO-9 (which is for Russian).
	"х kh", "Х Kh", //Ditto??
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

//Korean romanization is positionally-influenced.
//There are three blocks in Unicode which are useful here:
//U+1100 to U+1112: initial consonants
//U+1161 to U+1175: vowels
//U+11A8 to U+11C2: final consonants (but not all of them are used(??))
//Currently, the code assumes that a trailing consonant is followed by the
//end of a syllable. Any non-alphabetic character also ends a syllable, so
//hyphenation can help here.
array hangul_translation=({
	//Mode 0: Initial consonants
	mkmapping(
		"g	kk	n	d	tt	r	m	b	pp	s	ss		j	jj	ch	k	t	p	h"/"	",
		"\u1100	\u1101	\u1102	\u1103	\u1104	\u1105	\u1106	\u1107	\u1108	\u1109	\u110a	\u110b	\u110c	\u110d	\u110e	\u110f	\u1110	\u1111	\u1112"/"	"
	),
	//Mode 1: Vowels
	mkmapping(
		"a	ae	ya	yae	eo	e	yeo	ye	o	wa	wae	oe	yo	u	wo	we	wi	yu	eu	ui	i"/"	",
		"\u1161	\u1162	\u1163	\u1164	\u1165	\u1166	\u1167	\u1168	\u1169	\u116a	\u116b	\u116c	\u116d	\u116e	\u116f	\u1170	\u1171	\u1172	\u1173	\u1174	\u1175"/"	"
	),
	//Mode 2: Final consonants
	mkmapping(
		//There are duplicates in the table :( I have no idea how to enter these reliably.
		"k	k1	n	t	l	m	p	t1	t2	ng	t3	j	t4	k2	t5	p1	t6"/"	",
		"\u11a8	\u11a9	\u11ab	\u11ae	\u11af	\u11b7	\u11b8	\u11b9	\u11ba	\u11bb	\u11bc	\u11bd	\u11be	\u11bf	\u11c0	\u11c1	\u11c2"/"	"
	),
});
string Latin_to_Korean(string input)
{
	//Representational ambiguities can be resolved by dividing syllables.
	//In the keyed-in form, this is done with a slash; in both output forms,
	//a zero-width space is used instead.
	input=replace(input,"/","\u200b");
	string output="";
	int state=0;
	while (input!="")
	{
		sscanf(input,"%[aeiouyw]%s",string vowels,input);
		if (vowels!="")
		{
			//if (state==2) output+="-"; //Presumably there's no final consonant on this syllable.
			if (state!=1) output+=hangul_translation[0][""]; //Implicit initial consonant.
			//if (state==0) output+="[c0-]"; //Implicit initial consonant.
			while (vowels!="" && !hangul_translation[1][vowels]) //Take the longest prefix that has a translation entry
			{
				input=vowels[<0..]+input;
				vowels=vowels[..<1];
			}
			if (hangul_translation[1][vowels])
			{
				//output+="[*"+vowels+"]";
				output+=hangul_translation[1][vowels];
				state=2; //Now looking for a final consonant.
				continue;
			}
			//Else we may have an incomplete vowel definition (still being typed in), which can be carried through unchanged for now.
		}
		sscanf(input,"%[gkndtrmbpsjchl0-9]%s",string consonants,input); //Hack: Include digits to allow round-tripping
		if (consonants!="")
		{
			if (state==1) state=2; //Huh? No vowel? Dunno what to do there.
			while (consonants!="" && !hangul_translation[state][consonants])
			{
				input=consonants[<0..]+input;
				consonants=consonants[..<1];
			}
			//output+="["+state+consonants+"]";
			if (state || consonants!="")
			{
				//If we look for a final consonant that doesn't exist, put no character out ( ||"" ), and change state so we go looking for an initial instead.
				//But if we had been looking for an initial, and it doesn't exist, then just skip the character and move on.
				//This isn't perfect, but it should allow interactive typing to result in at least something, even with only the first half of a two-letter sequence.
				output+=hangul_translation[state][consonants]||"";
				state=!state; //If this was the initial consonant [0], look for a vowel [1]; if the final [2], look for the next initial [0]. :)
				continue;
			}
		}
		//The next character isn't a recognized syllable character, so carry it through unchanged.
		output+=input[..0]; input=input[1..];
		state=0; //After any punctuation, we're looking for the beginning of a new syllable.
	}
	return Unicode.normalize(output,"NFC"); //If all goes well, this should remove all the separate pieces and replace everything with precombined syllables.
}

mapping hangul_reverse=mkmapping(`+(@values(hangul_translation[*])),`+(@indices(hangul_translation[*]))); //This ought to be constant. Hrm.
string Korean_to_Latin(string input)
{
	input=Unicode.normalize(input,"NFD"); //Crack the syllables up into parts
	return replace(input,hangul_reverse); //The reverse translation is pretty straight-forward, yay!
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
	mapping map=(["\\!":"\u00A1","\\?":"\u00BF","o\\e":"ø","a\\e":"æ","s\\s":"ß",
		"\\`":"\u0300","\\'":"\u0301","\\^":"\u0302","\\~":"\u0303","\\-":"\u0304","\\@":"\u0306","\\\"":"\u0308",
		"\\o":"\u030A","\\:":"\u030B","\\v":"\u030C","\\,":"\u0327","d\\-":"đ","d\u0304":"đ","D\\-":"Đ","D\u0304":"Đ",
		"I\\.":"İ","i\\.":"ı", //Note that these are, in a way, reversed; I\. adds a dot, but i\. removes one.
	]);
	input=replace(input,map);
	return Unicode.normalize(input,"NFC"); //Attempt to compose characters as much as possible - some applications have issues with combining characters
}

string Latin_to_ElderFuthark(string input)
{
	return replace(input,([
		"f":"ᚠ","u":"ᚢ","þ":"ᚦ","a":"ᚨ","r":"ᚱ","k":"ᚲ","g":"ᚷ","w":"ᚹ","h":"ᚻ","n":"ᚾ","i":"ᛇ","th":"ᚦ",
		"j":"ᛃ","p":"ᛈ","z":"ᛉ","s":"ᛊ","t":"ᛏ","b":"ᛒ","e":"ᛖ","m":"ᛗ","l":"ᛚ","o":"ᛟ","d":"ᛞ","ng":"ᛝ","ŋ":"ᛝ",
	]));
}

string ElderFuthark_to_Latin(string input)
{
	return replace(input,([
		"ᛇ":"i","ᚲ":"k","ᛃ":"j","ᛞ":"d","ᚱ":"r","ᚦ":"th","ᛏ":"t","ᚷ":"g","ᚠ":"f","ᛈ":"p","ᚾ":"n","ᛟ":"o",
		"ᛒ":"b","ᚦ":"þ","ᚨ":"a","ᛚ":"l","ᛊ":"s","ᚻ":"h","ᛝ":"ŋ","ᚢ":"u","ᛖ":"e","ᛉ":"z","ᚹ":"w","ᛗ":"m",
		"ᚺ":"h","ᛜ":"ŋ","ᛁ":"i",
	]));
}

//ELOT transliteration from https://en.wikipedia.org/wiki/Romanization_of_Greek#Modern_Greek
//Keying Eta (Ηη) is done as "i\-", which requires a complex set of steps. First, the \- becomes
//U+0304 (Macron), and the i becomes U+03B9 (Iota); then NFC normalization combines those two
//into U+1FD1 (Iota with macron). The reverse transformation decomposes that to U+03B9 U+0304,
//then translates U+03B9 into i, then recomposes into U+012B "i with macron"; then a repeated
//forward transformation converts that into η (Eta), which reversibly translates back to U+012B.
//A similar multi-step transformation is required to key Omega (Ωω), done as "o\-", except that
//there's no combined form. It's a mess, and has gone through several iterations of editing, and
//I'm not 100% sure that all the code matches what I'm trying to do here; some of it may even be
//completely redundant (in some iterations, I wasn't decomposing on reverse transformation, for
//instance, and that may have required some translations that now aren't necessary). It seems to
//work now, so I'm sticking with it.
object medial_s=Regexp.PCRE.Widestring("s+[a-zψΨ]");
string medial_sigma(string x) {return "σ"*(sizeof(x)-1)+x[<0..];}
string Latin_to_Greek(string input)
{
	//Note that these are six separate steps, which must be done in strict order or stuff breaks - probably with the medial sigma.
	//1) Unicode decomposition - break out any diacriticals into separate combining characters.
	//2) Convert ps into ψ, so the s doesn't get translated in step 3.
	//3) Convert "s followed by letter" into medial sigma. For this, "letter" means a-z and ψ; note that this means diacriticals on an s will break it.
	//4) Convert the two-letter forms, as some of them could be parsed as individual letters too.
	//5) Convert the single letters.
	//6) Convert diacritical notation, and recombine characters.
	//All in very strict order or it won't work!
	return diacriticals(replace(replace(medial_s->replace(replace(Unicode.normalize(input,"NFD"),(["ps":"ψ","Ps":"Ψ","PS":"Ψ"])),medial_sigma),
			(["ch":"χ","Ch":"Χ","CH":"Χ","th":"θ","Th":"Θ","TH":"Θ","O\u0304":"Ω","o\u0304":"ω","I\u0304":"Η","i\u0304":"η"])
		),"AaVvGgDdEeZzIiKkLlMmNnXxOoPpRrSsTtYyFfhṓ"/1,"ΑαΒβΓγΔδΕεΖζΙιΚκΛλΜμΝνΞξΟοΠπΡρΣςΤτΥυΦφ῾ώ"/1));
}

string Greek_to_Latin(string input)
{
	return Unicode.normalize(replace(replace(Unicode.normalize(input,"NFD"),"ΑαΒβΓγΔδΕεΖζΗηΙιΚκΛλΜμΝνΞξΟοΠπΡρΣςΤτΥυΦφΩωσῙῑ῾ώ"/1,"AaVvGgDdEeZzĪīIiKkLlMmNnXxOoPpRrSsTtYyFfŌōsĪīhṓ"/1),
		(["χ":"ch","Χ":"Ch","θ":"th","Θ":"Th","ψ":"ps","Ψ":"Ps","ή":"ī\u0301"])),"NFC");
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
	if (argc>1 && (<"Latin","Russian","Serbian","Ukrainian","Korean","ElderFuthark","Greek">)[argv[1]]) argv-=({lang=argv[1]});
	int srtmode=(sizeof(argv)>1 && !!file_stat(argv[1])); //If you provide a .srt file on the command line, have extra features active.
	GTK2.Window(0)->set_title(lang+" transliteration")->add(two_column(({
		srtmode && "Original",srtmode && (original=GTK2.Entry()),
		lang!="Latin" && lang,lang!="Latin" && other,
		"Roman",roman=GTK2.Entry(),
		srtmode && "Trans",srtmode && (trans=GTK2.Entry()),
		srtmode && (GTK2.HbuttonBox()->add(pause=GTK2.Button("_Pause")->set_use_underline(1))->add(next=GTK2.Button("_Next")->set_use_underline(1))),0,
	})))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	(({original, other, roman, trans})-({0}))->modify_font(GTK2.PangoFontDescription("Sans 18"));
	function latin_to,to_latin;
	if (lang!="Latin")
	{
		roman->signal_connect("changed",update,({other,latin_to=this["Latin_to_"+lang]}));
		other->signal_connect("changed",update,({roman,to_latin=this[lang+"_to_Latin"]}));
	}
	else roman->signal_connect("changed",update,({0,diacriticals}));
	if (next) next->signal_connect("clicked",lambda() {
		array(string) data=utf8_to_string(Stdio.read_file(argv[1]))/"\n\n";
		string orig=original->get_text();
		original->set_text(""); //In case we find nothing
		foreach (data;int i;string paragraph)
		{
			array lines=paragraph/"\n"-({""});
			if (sizeof(lines)==2)
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
			else if (sizeof(lines)==5 && latin_to && to_latin)
			{
				//Five-line paragraph. Verify its two-way transliterations.
				//The lines will be Timing, English, Other, Roman, Translation.
				if (lines[2]!=latin_to(lines[3]) || lines[3]!=to_latin(lines[2]))
				{
					//Something's wrong. We're going to spam the screen a lot with these, unless the job's all done.
					write("Mismatched:\n%{%s\n%}",string_to_utf8(lines[*]));
				}
			}
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

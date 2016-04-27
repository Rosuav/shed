/*
Namegen:
* Start with a lead vowel, a trail vowel, or a one-letter consonant
* If random(10) < sizeof(name)-3, break
* Otherwise, add a continuation:
  - After a lead vowel: lead vowel, trail vowel, or one-letter consonant plus lead vowel
  - After a trail vowel: lead vowel, trail vowel, or consonant plus lead vowel
* Additional units may be constructed to take advantage of English phonograms:
  - "CHe" is a trail vowel
  - "SHe" is a trail vowel
  - "EsHf" is a lead vowel
  - "AcHs" is a lead vowel
  - "AgH" is a lead vowel
  - A one-letter consonant plus a trail vowel becomes a trail vowel.
  - A lead vowel plus a consonant becomes a lead vowel.
  - Neither of these can recurse. "AcHsH" is not valid.
  - Valid phonograms: CH, SH, GH, PH, NG, CK
*/
array(string) vowel = "Au I O U Eu"/" ";
array(string) lead = "Ac Al Am Ar As At In Ir Os Ag Er Es"/" ";
array(string) trail = "Ba Be Bi Ca Co Cu Ce Ga Ge He Ho Fe La Li Lu Mo Ne Ni No Pu Po Pa Ra Re Ru Se Si Na Ta Te Ti Xe"/" ";
array(string) consonant = "C F Cl Cr Cs Gd Dy Cm Cf Fr Fm Sb Bk Bh B Br Cd Hf Hs H Kr Lr Pb Mg Mn Mt Md Hg Nd Np Nb N Pd P Pt K Pr Pm Rn Rh Rg Rb Rf Sm Sc Sg Sr S Tc Tb Tl Th Tm Sn W V Yb Y Zn Zr"/" ";
array(string) singlecons = filter(consonant, lambda(string x) {return sizeof(x)==1;});
array(string) phonograms = "CH SH GH PH NG CK"/" ";

//Names will not be accepted if they're shorter than min_length characters.
//If they're at least top_length characters, they will always terminate.
//Note that they may exceed this (it's not a maximum); they simply won't
//have any new units added.
constant min_length = 3, top_length = 12;

void gather_compounds()
{
	//Start by constructing some compounds that are valid units in themselves.
	array(string) morelead = ({ }), moretrail = ({ });
	foreach (phonograms, string pair)
	{
		if (has_value(singlecons, pair[..0]))
		{
			//Single consonant plus any trail vowel that starts with the other half
			moretrail += pair[..0] + filter(trail, has_prefix, pair[1..])[*];
		}
		foreach (filter(lead, has_suffix, lower_case(pair[..0])), string l)
			morelead += l + filter(consonant, has_prefix, pair[1..])[*];
	}
	//All-vowel units get consonants added to one end or the other.
	foreach (vowel, string v)
	{
		morelead += v + consonant[*];
		moretrail += consonant[*] + v;
	}
	//Only append to the main arrays once we're done collecting.
	//The new constructs are not themselves participants in compounding.
	lead += morelead; trail += moretrail;
}

string generate_name()
{
	string name = "";
	int last_vowel = 0;
	while (1)
	{
		if (random(top_length-min_length) < sizeof(name)-min_length) return name;
		array options = ({
			({random(lead), 0}),
			({random(trail), 1}),
			//If our last unit had a trailing vowel, we can use a double consonant.
			//Otherwise, it has to be a single-letter consonant, and gets reduced probability.
			({random(last_vowel ? consonant : singlecons) + random(lead), 0}),
		});
		if (!last_vowel && !random(3)) options = options[..1];
		[string unit, last_vowel] = random(options);
		name += unit;
	}
}

int main()
{
	gather_compounds();
	for (int i=0;i<20;++i)
	{
		string n = generate_name();
		write("%c%-15s %-20s ", n[0], lower_case(n[1..]), "["+n+"]");
		n = generate_name();
		write("%c%-15s %s\n", n[0], lower_case(n[1..]), "["+n+"]");
	}
}

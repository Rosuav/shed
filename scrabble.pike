/* Scrabble word finder

Basically equivalent to grep across /usr/share/dict/words, with a few exceptions:

1) Your available letters (defaulting to a-z) can be specified once, and then
apply to every dot. Effectively, "." means "anything I have available" rather
than "any character in all of Unicode". (This means that proper nouns (with
capital letters), hyphenated words, and words with apostrophes, are always 
eliminated from the results.)
2) As a shorthand, any digit becomes that many dots - so for instance, l10n
would become l..........n and would match "localization", except that this is
done on individual digits rather than two-digit tokens. (So "l55n" would match
it.) This is similar to the brace notation of an extended regex (".{10}").
3) The regex implicitly begins with ^ and ends with $, so if you want to allow
characters outside of the specified range, put dots there. These dots will
then be translated as per rule 1, rather than allowing any random characters.
4) The regex will be parsed by Regexp.SimpleRegexp rather than by grep. This
shouldn't have any majorly significant differences, but it is a difference.

Usage: pike scrabble a.c.e.*

The alphabet may either precede or follow the pattern. It will be detected by
virtue of containing nothing but letters and/or hyphens.
*/

int main(int argc,array(string) argv)
{
	string pat,alphabet="[qwertyuiopasdfghjklzxcvbnm]";
	foreach (argv[1..],string arg)
		if (!sizeof((multiset)(array)arg-(multiset)(array)"qwertyuiopasdfghjklzxcvbnm-")) alphabet="["+arg+"]"; //What's the best way to say "does this contain only these characters"?
		else pat=arg;
	object regex;
	//Yeeee-haaaaaw! Do all the translations at once. :) Okay, this may not be the most-readable code, but some days, I just looooove doing one-liners.
	if (!pat || catch {regex=Regexp.SimpleRegexp(replace(replace("^"+pat+"$",(array(string))enumerate(10),"."*enumerate(10)[*]),".",alphabet));})
		exit(0,"USAGE: pike scrabble pattern [alphabet]\nSee source comments for details.\n");
	write("%{%s\n%}",regex->match(Stdio.read_file("/usr/share/dict/words")/"\n"-({""})));
}

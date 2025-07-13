//Mastermind, Dead-and-Wounded, Wordle, etc
constant WORD_LENGTH = 5;
array(string) all_words = filter((Stdio.read_file("/usr/share/dict/Wordle") || Stdio.read_file("/usr/share/dict/words")) / "\n")
	{return sizeof(__ARGS__[0]) == WORD_LENGTH;};

string compare(string word, string target) {
	//Compare a guess word to a target word and give the dead/wounded ratings
	//The word and target should have the same length. The returned string will
	//have that length too, and will have "d" for any exactly correct letter,
	//"w" for any that's in the wrong place, and "." for wrong letters.

	string ret ="." * sizeof(target);
	//First, find the exactly-correct letters, and remove them. If they were not
	//removed, compare("added", "adder") would return "ddddw".
	for (int i = 0; i < sizeof(target); ++i) if (word[i] == target[i]) {
		ret[i] = 'd';
		target[i] = '.';
	}
	//Now find any mispositioned ones. Again, remove them as they're found, else
	//compare("patty", "greet") would return "..ww." instead of "..w..".
	for (int i = 0; i < sizeof(word); ++i) if (ret[i] == '.') {
		int pos = search(target, word[i]);
		if (pos != -1) {
			ret[i] = 'w';
			target[pos] = '.';
		}
	}
	//Anything untouched is still a dot.
	return ret;
}

string recommend(array potential, int|void only_potential, int|void maximin) {
	//Given a set of potential words, choose a good guess.
	//If only_potential, the guess will be a potential word, otherwise it could
	//be any valid word.
	//If maximin, will pick the word with the best worst-case, otherwise will
	//aim for the best expected yield.

	//A guess will produce some kind of response based on an unknown target word.
	//At that point, we will be able to reduce the potential solutions to those
	//that match the response received. Thus the quality of a guess can be seen
	//as the extent to which it reduces the potential solutions; but the effect
	//will depend on the actual target. Thus there are multiple ways to judge a
	//guess; the expected yield is the reduction multiplied by the probability
	//that it happens (or, worded another way, is the average reduction across
	//all potential words), and the minima is the worst possible reduction in
	//the case where we're the most unlucky.

	float bestscore = 0.0; string best = "?????";
	foreach (only_potential ? potential : all_words, string guess) {
		mapping results = ([]);
		foreach (potential, string target) results[compare(guess, target)]++;
		//results["....."] is the number of words still potential after
		//we guess this guess and get back all-nothings.
		float score = 0.0;
		if (maximin) score = (float)sizeof(potential) - max(@values(results));
		else {
			foreach (results; string result; int count)
				score += count * (sizeof(potential) - count);
			score /= sizeof(potential);
		}
		if (score > bestscore) {bestscore = score; best = guess;}
		werror("%s %8.2f | %s %.2f\r", guess, score, best, bestscore);
	}
	werror("\n");
	return best;
}

int main() {
	//werror("Guess: %s\n", recommend(all_words)); //lares
	//werror("Guess: %s\n", recommend(all_words, 1, 1)); //seria
	array potential = all_words;
	while (1) {
		write("Enter your guess: ");
		string guess = Stdio.stdin->gets(); if (!guess) break;
		write("Enter the result (d/w/.): ");
		string result = Stdio.stdin->gets(); if (!result) break;
		potential = filter(potential) {return compare(guess, __ARGS__[0]) == result;};
		write("%d words remain.\n", sizeof(potential));
		if (sizeof(potential) <= 12) write("%{%s %}\n", potential);
		//write("Guess00: %s\n", recommend(potential));
		//write("Guess01: %s\n", recommend(potential, 0, 1));
		//write("Guess10: %s\n", recommend(potential, 1, 0));
		write("Guess: %s\n", recommend(potential, 1, 1));
	}
}

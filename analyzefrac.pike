/*
Theory: The expansion of 1/n for any prime number n will either terminate or
repeat. It will terminate after i digits if 10**i counts by n, and will repeat
on a period of i digits if 10**i-1 counts by n. Since only 2 and 5 can possibly
fulfil the termination requirement, every other prime number MUST repeat.

I want to prove this, somehow, but I don't know how.

20140703: Woohoo! Have a proof of this, courtesy to sci.math posters. It's a
form of Fermat's Little Theorem, and there are a number of proofs... including
one that's effectively based on the long division concept that I was working
with here.

So the question is, what determines the ones that repeat sooner than their
maximum period? They're factors of 10**((p-1)/n)-1, where n is a factor of p-1.

int findfac(int n) {write("%d:%{ %d%}\n",n,find_factors((pow(10,n-1)-1)/n));}
3: 3 11
7: 3 3 3 11 13 37
11: 3 3 41 271 9091
13: 3 3 3 7 11 37 101 9901
17: 3 3 11 73 101 137 5882353
19: 3 3 3 3 7 11 13 37 52579 333667
23: 3 3 11 11 4093 8779 21649 513239
29: 3 3 11 101 239 281 4649 909091 121499449
*/

//Test for primality, brute-force
//if (!find_factor(n)) n_is_prime;
int find_factor(int n)
{
	if (!(n%2)) return 2;
	for (int i=3;;i+=2)
	{
		if ((n%i)==0) return i;
		if (i*i>n) return 0;
	}
}

//Recursively enumerate all prime factors, brute-force
array(int) find_factors(int n)
{
	if (!(n%2)) return ({2})+find_factors(n/2);
	for (int i=3;;i+=2)
	{
		if ((n%i)==0) return ({i})+find_factors(n/i);
		if (i*i>n) return ({n});
	}
}

int main()
{
	System.Timer tm=System.Timer();
	array(int) primes=({ });
	//int cnt,maxi;
	for (int n=2;;++n)
	{
		int prime=1;
		foreach (primes,int p) if (n%p==0) {prime=0; break;}
		if (!prime) continue;
		primes+=({n});
		//Okay, we have a prime number.
		for (int i=1;i<=n;++i)
		{
			//if (pow(10,i)%n==0) {write("%d: Terminates after %d digits\n",n,i); break;} //Don't bother checking; only 2 and 5 can possibly hit this.
			if ((pow(10,i)-1)%n==0) {write("%d: Repeats on period %d [factor %d] - fac %d\n",n,i,(n-1)/i,find_factor((pow(10,n-1)-1)/n)); break;}
			//if ((pow(10,i)-1)%n==0) {write("%d: %d - %0*d\n",n,(n-1)/i,i,pow(10,i)/n); break;} //Recreate the REXX script's output
			//if ((pow(10,i)-1)%n==0) {if ((n-1)/i>maxi) write("%d: %d - %0*d\n",n,maxi=(n-1)/i,i,pow(10,i)/n); break;}
			//if ((pow(10,i)-1)%n==0) {if (i==n-1) ++cnt; write("[%.2fs %c%.5f] %d: %d    \r",tm->peek(),i==n-1?'+':'-',cnt/(float)sizeof(primes),n,(n-1)/i); break;}
		}
		//write("%d...   \r",n);
		
	}
}

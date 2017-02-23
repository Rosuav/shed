Random notes on the Kytheon build
=================================

Brand new server to become the new Gideon. He's still young, though, so he goes
by the name Kytheon.

Hosting options:
* In-house: expensive internet, easy administration, our ping LAN, other ping SOHO
* Australia: expensive internet, adequate admin, our ping domestic, other ping OK
* Europe: cheap internet, laggy admin, our ping int'l, other ping int'l
* America: cheap internet, laggy admin, our ping int'l, other ping int'l or low

Desired use-cases include access from us, from other Australians (eg G&S Soc), and
from general public (eg Minstrel Hall clients). Low ping for us is very good; low
ping for G&S Soc people is of minor importance (since the site itself is so slow);
low ping for Minstrel Hall people is of moderate importance (there aren't many,
and they're mostly happy with what they have, so any improvement is improvement).

Operating system: Debian Jessie. Stretch is getting close to stable, but until it
actually _is_ stable, I won't grab it. Don't want too many kernel updates.

Pike: I'm upgrading to 8.1 because there are some features that I want. I may
end up backing down to 8.0 though.

Setting up courier-imap involved a lot of configuration (git-managed), and one
odd package installation: 'apt install gamin'. Some sort of weird issue with the
default filesystem notification library, but gamin replaces it and works. Weird.

Setting up SASL authentication for SMTP (as an alternative to IMAP-before-SMTP)
required adding the 'postfix' user to the 'sasl' group. Didn't find that in any
docos anywhere.

Still TODO:
* Email delivery: spamassassin bayes filtering data (check it!)
* STARTTLS on all email-carrying sockets

Creating a mail user:
* Run `userdbpw` to encrypt the password (or use some other crypt() eg Pike's)
* insert into users values ('address@domain.example', 'shortname', 'password');
* mkdir /var/mail/virtual/shortname
* chown 111:118 /var/mail/virtual/shortname
* TODO: Switch to better encryption eg bcrypt

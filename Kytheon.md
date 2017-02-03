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

Pike: I'm upgrading to 8.1 because there are a lot of features that I want. I may
end up backing down to 8.0 though.

From now on, Minstrel Hall will NOT be running as root. This may have a few small
consequences, but for the most part, I've already removed the need. This means
adjusting it to accept a socket from systemd, which in turn necessitates a change
to Pike, so this is not considered stable yet.

Still TODO:
* DNS (auth only - migrate recursive to Sikorsky)
* Apache, preferably with Py3 (libapache2-mod-wsgi-py3) - check compatibility
* Email delivery: Postfix, spamassassin, SPF checking
* Viewing email: Courier IMAP, Squirrel, optional RoundCube
* Migrate outgoing email to Sikorsky???
* Mailing lists - mailman 3???
* PostgreSQL - dump/reload to upgrade to the latest version
* MySQL, but avoid it for anything crucial (eg email accounts)
* Pure-FTPD maybe (can I push everyone to SCP?)

Notes from exploration of Devuan
================================

As of 2026-03-21, current stable is "Excalibur", minor planet 9499.
The Devuan equivalent of Debian's "Sid" is "Ceres", a codename that tracks
the unstable branch. Codenames are drawn from a long list of minor planets.

As naming conventions go, not a bad choice. Like Ubuntu, they alphabetize;
so like Ubuntu, the Qs and Xs may feel forced. (I see some decent Q options,
including "Quasimodo", "Quincy", "Quartz", "Quenisset", and plenty of others.
Less so with X, but we have "Xerxes", "Xenophanes", and a few others, though
I would personally avoid all the Chinese place names there, as it'll be hard
to get people to pronounce them correctly.) But unlike Ubuntu, they're not
chewing through the alphabet at two letters per year. Devuan's release cycle
matches (at least roughly) Debian's, so it's more like 18 months per letter.
At that rate, they won't need a second X name until somewhere around 2100AD.

Init system
-----------

Devuan Excalibur offers three: sysvinit, openrc, runit. (Side note: Is it
"r-unit" or "run-it"?) What are the pros and cons of each? Plenty of people
saying that all three are fine for normal usage, but since I create my own
services, I need to know a bit more.

Currently trying runit.

My needs:
* Personal service files that I can conveniently git track
  - Should be easy, but also, I would like for these to be able to symlink
    from another location if that makes more sense.
* Automatic restarting of services
* Log messages from services. If it prints to stderr, where does it go?
* Report on failed services. If something keeps crashing, does it eventually
  stop getting restarted, and if so, how do I see that?
* One-shot services run periodically. Can do with cron if not supported by
  the init daemon.
* Service features/config:
  - Working directory
  - User (ie don't run everything as root)
  - Env vars (eg "DISPLAY=:0.0")
  - Dependencies (eg "Requires postgres")
  - Launch on boot (default), or explicit launch request

Desktop
-------

Xfce is the default. Awesome. Others are also available, great.

The preselected theme "Clearlooks-Phenix-Sapphire" is more readable than the
one called "Default" (which I think is the default I'm used to). Might mean
that I no longer need to do custom tweaks. TODO: Test Chrome, test Pike GTK2,
test gnome-system-monitor (if it's available).

Speaking of gnome-system-monitor, I do like its graphs. It could be replaced
if there's something equivalent.

(Tried playing a quick game of Dots and Boxes, and maybe there's a termtype
issue??? Look into this.)

Other random notes
------------------

Feels fairly comfortable in the 8GB RAM that I gave it. Should try it in a
memory-constrained state to see how Traal's likely to feel. Probably same as
Debian but worth a check.

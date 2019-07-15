"""
TODO Mon?: Autohost manager for AliCatFiberarts (and others).
* Have a list of high priority streams, in order (or with priorities)
* Listen for, or poll for, streams going live
* If (a) a high priority stream has just gone live, and (b) you are currently hosting, and (c) the hosted stream has lower priority
* Then send "/unhost" to the channel.
* Have a very very simple GUI (tkinter?)
* "Optional: Rename this to autohost_manager.pyw to hide the black box"
"""

# Components needed:
# 1) Hosting control via IRC
# 2) Going-live detection
# 2a) Poll at a set interval eg 15 mins
# 2b) Receive webhook notifications from Twitch
# 3) Authentication, mainly for IRC
# 3b) Optionally allow user to override channel name (in case you're an editor)
# 4) Configuration of channel priorities, since we can't query Twitch
# 5) JSON config storage

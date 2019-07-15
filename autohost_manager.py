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

# Goal: Make this a single-file download with no deps other than Python 3.7+.

import json
from pprint import pprint
import threading
import webbrowser
import tkinter as tk
import urllib.request

"""
PASS oauth:%s
NICK %s
CAP REQ :twitch.tv/commands
JOIN #%s
"""

def checkauth(oauth):
	print("Checking auth...")
	with urllib.request.urlopen(urllib.request.Request(
		"https://api.twitch.tv/kraken/user",
		headers={"Authorization": "OAuth " + oauth},
	)) as f:
		data = json.load(f)
	pprint(data)

class Application(tk.Frame):
	def __init__(self, master=None):
		super().__init__(master)
		self.pack()
		# TODO: Fix layout later and make things prettier
		self.login_frame = tk.LabelFrame(self, text="Authenticate with Twitch")
		self.login_frame.pack(side="top")
		self.login_lbl = tk.Label(self.login_frame, text="OAuth token:")
		self.login_lbl.pack(side="left")
		self.login_ef = tk.Entry(self.login_frame)
		self.login_ef.pack(side="left")
		self.login_go_browser = tk.Button(self.login_frame, text="Get a token", command=self.cmd_login_go_browser)
		self.login_go_browser.pack(side="left")
		self.login_check_auth = tk.Button(self.login_frame, text="Verify token", command=self.cmd_login_check_auth)
		self.login_check_auth.pack(side="left")

		# To prepopulate this, go to https://www.twitch.tv/rosuav/dashboard/settings/autohost
		# and enter this into the console:
		# document.querySelector(".autohost-list-edit").innerText
		# Sadly, the API call /kraken/autohost/list is not documented anywhere and does
		# not appear to be easily callable :(
		self.hostlist_frame = tk.LabelFrame(self, text="Autohost list in priority order")
		self.hostlist_frame.pack(side="top")
		self.hostlist = tk.Text(self.hostlist_frame, width=30, height=20)
		self.hostlist.pack()
		self.show = tk.Button(self, text="Show stuff", command=self.cmd_show)
		self.show.pack(side="top")

	def cmd_show(self):
		print(self.hostlist.get(1.0, tk.END))

	def cmd_login_go_browser(self):
		webbrowser.open("https://id.twitch.tv/oauth2/authorize?response_type=token&client_id=q6batx0epp608isickayubi39itsckt&redirect_uri=https://twitchapps.com/tmi/&scope=chat:read+chat:edit+channel_editor+user_read")

	def cmd_login_check_auth(self):
		oauth = self.login_ef.get()
		if oauth.startswith("oauth:"): oauth = oauth[6:]
		threading.Thread(target=checkauth, args=(oauth,)).start()

win = tk.Tk()
win.title("Autohost manager")
app = Application(master=win)
app.mainloop()
import pyinotify
import time
wm=pyinotify.WatchManager()
class Handler(pyinotify.ProcessEvent):
	lastevent='00000000'
	def process_default(self,event):
		if ".git" in event.pathname: return
		today=time.strftime("%Y%m%d")
		f=open("/video/00index.txt","a")
		if today!=self.lastevent:
			self.lastevent=today
			f.write("\n"+today+":\n")
			# print "\n"+today+":"
		f.write(event.pathname[6:]+"\n")
		# print event.pathname[6:]
notifier=pyinotify.Notifier(wm,Handler())
wm.add_watch('/video',pyinotify.IN_CREATE|pyinotify.IN_MOVED_TO,rec=True)
notifier.loop()

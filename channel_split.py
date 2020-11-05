# Split the audio channel from a file into its channels
# Keeps video and subtitles tracks untouched
import json
import subprocess
import sys

if len(sys.argv) < 3:
	sys.exit(1, "USAGE: python3 %s inputfile outputfile")
_, infile, outfile, *_ = sys.argv

# Determine the channel layout of the input file
p = subprocess.run(["ffprobe", "-print_format", "json", "-show_streams", "-v", "quiet", infile],
	check=True, capture_output=True)
info = json.loads(p.stdout)
if not isinstance(info, dict): raise Exception("shouldn't happen - non-dict output from ffprobe")
map_video = map_subs = []
audio = None
# Scan streams. If we have any video streams, make sure we grab them, ditto subs.
for strm in info["streams"]:
	if strm["codec_type"] == "video": map_video = ["-map", "0:v"] # If there are multiple, these still only need one map argument
	elif strm["codec_type"] == "subtitle": map_subs = ["-map", "0:s"]
	elif audio is None: audio = strm
if audio is None: sys.exit(1, "No audio stream found")

# Good. There's an audio stream. (We'll use the first if there are multiple.)
# Ask ffmpeg what channel layouts there are and how the channels should be described.
p = subprocess.run(["ffmpeg", "-layouts"], check=True, capture_output=True)
channel_desc, layouts = {}, {}
cur = None
for line in p.stdout.decode().split("\n"):
	if line == "": pass
	elif line == "Individual channels:": cur = channel_desc
	elif line == "Standard channel layouts:": cur = layouts
	else:
		k, v = line.split(maxsplit=1)
		cur[k] = v

# Give each channel a descriptive title eg "[FR] front right".
audio_titles = []
for i, channel in enumerate(layouts[audio["channel_layout"]].split("+")):
	audio_titles.extend(["-metadata:s:a:%d" % i, f"title=[{channel}] {channel_desc[channel]}"])

# Let's do this.
args = (["ffmpeg", "-y", "-i", infile, "-filter_complex", "channelsplit=channel_layout=" + audio["channel_layout"]]
	+ map_video + map_subs + audio_titles
	+ ["-c:v", "copy", "-c:s", "copy", "-loglevel", "error", "-stats", outfile])
# print(args)
sys.exit(subprocess.run(args).returncode)

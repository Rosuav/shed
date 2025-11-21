import base64
import socket
import subprocess
import threading
from netfilterqueue import NetfilterQueue # pip install netfilterqueue

# Everything here is in the address space 2403:5803:bf48:1::xxxx.
# This is magically routed to the netfilter queue and handled by this script.
# Currently, all relevant addresses are in 2403:5803:bf48:1::/112 but this may change in the future.
# ::0000 is the DNS server
# ::0001 is the target for the first trace (Jabberwocky)
# ::01xx is the steps of the first trace, where xx is the hop count.

def calc_checksum(src, dest, extra, pkt):
	"""Calculate an ICMPv6 or UDP checksum for a packet
	The algorithm is not the same as the one used for ICMPv4, and includes a pseudo-header.
	The source and dest IPs should be provided in packed format.
	"""
	pkt = src + dest + len(pkt).to_bytes(4, "big") + extra + pkt
	checksum = 0
	for i in range(0, len(pkt), 2):
		checksum += (pkt[i] << 8) + pkt[i + 1]
	if len(pkt) % 2:
		# Unsure if this is correct. Is a loose byte considered high or low?
		checksum += pkt[i] << 8
	while checksum > 0x10000:
		checksum = (checksum >> 16) + (checksum & 0xFFFF)
	return ~checksum & 0xFFFF

dnshandler = subprocess.Popen(["pike", "dnspipe.pike"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)
def dnsresp():
	buf = b""
	while True:
		while b"\n" not in buf:
			chunk = dnshandler.stdout.read(1024)
			print("GOT CHUNK", chunk)
			if not chunk: return
			buf += chunk
		msg, _, buf = buf.partition(b"\n")
		ip, port, data = msg.split(b" ")
		data = base64.b64decode(data)
		print("Send to", ip, port)
		# TODO: Build a UDP header, using the correct port numbers (source 53, dest as given)
		# Then send it from "2403:5803:bf48:1::" to the given IP
		#checksum = calc_checksum(
		...

threading.Thread(target=dnsresp).start()

def handle_packet(pkt):
	data = pkt.get_payload()
	src = socket.inet_ntop(socket.AF_INET6, data[8:8+16])
	dest = socket.inet_ntop(socket.AF_INET6, data[24:24+16])
	print(pkt, "from", src, "to", dest, "TTL", data[7])
	pkt.drop()
	# Is it a UDP packet on port 53? That's what we in the biz call "DNS"!
	if data[6] == 17 and dest == "2403:5803:bf48:1::" and data[42:44] == b"\0\x35":
		print("That looks like DNS to me!")
		port = data[40] * 256 + data[41]
		dnshandler.stdin.write(b"%s %d %s\n" % (src.encode(), port, base64.b64encode(data[48:])));
		return
	# If we've reached the end of the trace (here, arbitrarily set at 10 hops), send back "Port unreachable",
	# otherwise send back "Time exceeded".
	if data[7] >= 10:
		srcaddr = dest # Response comes back from the actual destination
		resp = b"\1\4\0\0\0\0\0\0" + data[:48]
	else:
		# Response comes back from a mythical hop between here and there
		srcaddr = "2403:5803:bf48:1::%x" % (0x100 + data[7])
		resp = b"\3\0\0\0\0\0\0\0" + data[:48]
	srcbin = socket.inet_pton(socket.AF_INET6, srcaddr)
	destbin = data[8:8+16]
	checksum = calc_checksum(srcbin, destbin, b"\0\0\0\x3a", resp)
	resp = resp[:2] + checksum.to_bytes(2, "big") + resp[4:]
	send_ipv6(srcbin, destbin, resp)

def send_ipv6(srcaddr, destaddr, pkt):
	# Prepend an IPv6 header to the ICMP packet.
	# TODO: Randomize the 20-bit flow label (here 0x12345) once I no longer need to be able to spot it in wireshark
	resp = b"\x60\x01\x23\x45" + len(pkt).to_bytes(2, "big") + b"\x3a\x40" + srcaddr + destaddr + pkt
	sock = socket.socket(socket.AF_INET6, socket.SOCK_RAW, socket.IPPROTO_ICMPV6)
	# So, we need to send this from a specific origin address. Option 1: Have every one of those
	# addresses as an actual bindable address on the network interface. Bit of a pain. I don't
	# know how 127.x.y.z works, as you can bind to any address within that range, but I haven't
	# been able to replicate that for an IPv6 netblock. So we use option 2: raw socket, no IP
	# header, and build our own. However, we need to stop the system from adding its own. On an
	# IPv4 socket, that's pretty straightforward; for some reason, the corresponding sockopt
	# for IPv6 doesn't seem to be listed in the Python socket module, at least not in 3.14.
	# Fortunately, the underlying kernel does support it, and it's socket option 36.
	sock.setsockopt(socket.IPPROTO_IPV6, 36, 1)
	sock.sendto(resp, (socket.inet_ntop(socket.AF_INET6, destaddr), 0))

nfqueue = NetfilterQueue()
nfqueue.bind(1, handle_packet)
try: nfqueue.run()
except KeyboardInterrupt: print()
finally:
	nfqueue.unbind()
	dnshandler.stdin.close()
	dnshandler.wait()

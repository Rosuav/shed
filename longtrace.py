from random import randrange
import socket
from netfilterqueue import NetfilterQueue

def icmpv6_checksum(src, dest, pkt):
	"""Calculate an ICMPv6 checksum for a packet
	The algorithm is not the same as the one used for ICMPv4, and includes a pseudo-header.
	The source and dest IPs should be provided in packed format.
	"""
	pkt = src + dest + len(pkt).to_bytes(4, "big") + b"\0\0\0\x3a" + pkt
	checksum = 0
	for i in range(0, len(pkt), 2):
		checksum += (pkt[i] << 8) + pkt[i + 1]
	if len(pkt) % 2:
		# Unsure if this is correct. Is a loose byte considered high or low?
		checksum += pkt[i] << 8
	while checksum > 0x10000:
		checksum = (checksum >> 16) + (checksum & 0xFFFF)
	return ~checksum & 0xFFFF

def print_and_accept(pkt):
	data = pkt.get_payload()
	src = socket.inet_ntop(socket.AF_INET6, data[8:8+16])
	dest = socket.inet_ntop(socket.AF_INET6, data[24:24+16])
	print(pkt, "from", src, "to", dest, "TTL", data[7])
	pkt.drop()
	# If we've reached the end of the trace (here, arbitrarily set at 10 hops), send back "Port unreachable",
	# otherwise send back "Time exceeded".
	if data[7] >= 10:
		srcaddr = data[24:24+16] # Response comes back from the actual destination
		resp = b"\1\4\0\0\0\0\0\0" + data[:48]
	else:
		# Response comes back from a mythical hop between here and there
		srcaddr = socket.inet_pton(socket.AF_INET6, "2403:5803:bf48:1::1")[:-2] + b"\1" + data[7:8]
		resp = b"\3\0\0\0\0\0\0\0" + data[:48]
	checksum = icmpv6_checksum(srcaddr, data[8:8+16], resp)
	resp = resp[:2] + checksum.to_bytes(2, "big") + resp[4:]
	# Prepend an IPv6 header to the ICMP packet.
	# TODO: Randomize the 20-bit flow label (here 0x12345) once I no longer need to be able to spot it in wireshark
	resp = b"\x60\x01\x23\x45" + len(resp).to_bytes(2, "big") + b"\x3a\x40" + srcaddr + data[8:8+16] + resp
	sock = socket.socket(socket.AF_INET6, socket.SOCK_RAW, socket.IPPROTO_ICMPV6)
	# So, we need to send this from a specific origin address. Option 1: Have every one of those
	# addresses as an actual bindable address on the network interface. Bit of a pain. I don't
	# know how 127.x.y.z works, as you can bind to any addrses within that range, but I haven't
	# been able to replicate that for an IPv6 netblock. So we use option 2: raw socket, no IP
	# header, and build our own. However, we need to stop the system from adding its own. On an
	# IPv4 socket, that's pretty straightforward; for some reason, the corresponding sockopt
	# for IPv6 doesn't seem to be listed in the Python socket module, at least not in 3.14.
	# Fortunately, the underlying kernel does support it, and it's socket option 36.
	sock.setsockopt(socket.IPPROTO_IPV6, 36, 1)
	sock.sendto(resp, (src, 0))

nfqueue = NetfilterQueue()
nfqueue.bind(1, print_and_accept)
try: nfqueue.run()
except KeyboardInterrupt: print()
finally: nfqueue.unbind()

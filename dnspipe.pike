//Generate responses to DNS packets sent on stdin
//Python's tools for DNS management aren't all that good, so we drop to Pike for this part.

//For decode_res and low_send_reply (the latter of which is protected, so we inherit rather than instantiating)
inherit Protocols.DNS.server_base;

//And here are the actual traces. They're a bit long, so you may need to extend your traceroute's max hop count.
array(array(string)) traces = ({({
	"twas.brillig.and.the.slithy.toves",
	"did.gyre.and.gimble.in.the.wabe",
	"all.mimsy.were.the.borogoves",
	"and.the.mome.raths.outgrabe",
	"beware.the.jabberwock.my.son",
	"the.jaws.that.bite.the.claws.that.catch",
	"beware.the.jujub.bird.and.shun",
	"the.frumious.bandersnatch",
	"he.took.his.vorpal.sword.in.hand",
	"long.time.the.manxome.foe.he.sought",
	"so.rested.he.by.the.tumtum.tree",
	"and.stood.awhile.in.thought",
	"and.as.in.uffish.thought.he.stood",
	"the.jabberwock.with.eyes.of.flame",
	"came.whiffling.through.the.tulgey.wood",
	"and.burbled.as.it.came",
	"one.two.one.two.and.through.and.through",
	"the.vorpal.blade.went.snicker.snack",
	"he.left.it.dead.and.with.its.head",
	"he.went.galumphing.back",
	"and.has.thou.slain.the.jabberwock",
	"come.to.my.arms.my.beamish.boy",
	"o.frabjous.day.calloh.callay",
	"he.chortled.in.his.joy",
	"twas.brillig.and.the.slithy.toves",
	"did.gyre.and.gimble.in.the.wabe",
	"all.mimsy.were.the.borogoves",
	"and.the.mome.raths.outgrabe",
}), ({
	"a.boat.beneath.a.sunny.sky",
	"lingering.onward.dreamily",
	"in.an.evening.of.july",
	"children.three.that.nestle.near",
	"eager.eye.and.willing.ear",
	"pleased.a.simple.tale.to.hear",
	"long.had.paled.that.sunny.sky",
	"echoes.fade.and.memories.die",
	"autumn.frosts.have.slain.july",
	"still.she.haunts.me.phantomwise",
	"alice.moving.under.skies",
	"never.seen.by.waking.eyes",
	"children.yet.the.tale.to.hear",
	"eager.eye.and.willing.ear",
	"lovingly.shall.nestle.near",
	"in.a.wonderland.they.lie",
	"dreaming.as.the.days.go.by",
	"dreaming.as.the.summers.die",
	"ever.drifting.down.the.stream",
	"lingering.in.the.golden.gleam",
	"life.what.is.it.but.a.dream",
})});

array(string) endpoints = ({
	"tomfoolery.rosuav.com.", //The DNS server itself
	"jabberwocky.rosuav.com.",
	"aboatbeneath.rosuav.com.",
});

mapping dns_response(mapping req) {
	mapping q = req->qd[0];
	if (q->type == Protocols.DNS.T_PTR) {
		sscanf(q->name, "%x.%x.%x.%x.%s", int d, int c, int b, int a, string tail);
		//This should be the only domain that's delegated to us
		if (tail != "0.0.0.0.0.0.0.0.0.0.0.0.1.0.0.0.e.0.9.f.3.0.8.5.3.0.4.2.ip6.arpa") return (["rcode": Protocols.DNS.NXDOMAIN]);
		if (a) return (["rcode": Protocols.DNS.NXDOMAIN]);
		string ptr;
		if (b) {
			//eg ::01xx, this is a step in the chain. The last two digits are the step number, and b is the document number.
			int step = (c << 4) | d;
			if (b <= sizeof(traces) && step <= sizeof(traces[b - 1])) ptr = traces[b - 1][step - 1];
		} else if (d) {
			//It's ::0000, the DNS server itself, or ::000x, the endpoint of a chain
			if (d < sizeof(endpoints)) ptr = endpoints[d];
		}
		if (!ptr) return (["rcode": Protocols.DNS.NXDOMAIN]);
		return (["an": (["cl": q->cl, "ttl": 600, "type": q->type, "name": q->name, "ptr": ptr])]);
	}
}

int main(int argc, array(string) argv) {
	if (has_value(argv, "--fmt")) {
		array lines = ({ });
		write("Enter lines, Ctrl-D to end\n");
		while (1) {
			string line = Stdio.stdin->gets();
			if (!line) break;
			lines += ({(Regexp.replace("[^a-z]", lower_case(line), " ") / " " - ({""})) * "."});
		}
		write("%O\n", lines - ({""}));
		return 0;
	}

	//Notify the parent of our available traces and their lengths.
	write("TRACES%{ %d%}\n", sizeof(traces[*]));

	while (1) catch {
		string line = Stdio.stdin->gets();
		if (!line || !sizeof(line)) break;
		sscanf(line, "%s %d %s", string ip, int port, string pkt);
		mapping req = decode_res(MIME.decode_base64(pkt));
		pkt = low_send_reply(dns_response(req), req, ([]));
		write("%s %d %s\n", ip, port, MIME.encode_base64(pkt, 1));
		Stdio.stdout->flush();
	};
}

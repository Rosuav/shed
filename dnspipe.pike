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
}), ({
	"sevot.yhtils.eht.dna.gillirb.sawt",
	"ebaw.eht.ni.elbmig.dna.eryg.did",
	"sevogorob.eht.erew.ysmim.lla",
	"ebargtuo.shtar.emom.eht.dna",
}), ({
	"the.sun.was.shining.on.the.sea",
	"shining.with.all.his.might",
	"he.did.his.very.best.to.make",
	"the.billows.smooth.and.bright",
	"and.this.was.odd.because.it.was",
	"the.middle.of.the.night",
	"the.moon.was.shining.sulkily",
	"because.she.thought.the.sun",
	"had.got.no.business.to.be.there",
	"after.the.day.was.done",
	"it.s.very.rude.of.him.she.said",
	"to.come.and.spoil.the.fun",
	"the.sea.was.wet.as.wet.could.be",
	"the.sands.were.dry.as.dry",
	"you.could.not.see.a.cloud.because",
	"no.cloud.was.in.the.sky",
	"no.birds.were.flying.over.head",
	"there.were.no.birds.to.fly",
	"the.walrus.and.the.carpenter",
	"were.walking.close.at.hand",
	"they.wept.like.anything.to.see",
	"such.quantities.of.sand",
	"if.this.were.only.cleared.away",
	"they.said.it.would.be.grand",
	"if.seven.maids.with.seven.mops",
	"swept.it.for.half.a.year",
	"do.you.suppose.the.walrus.said",
	"that.they.could.get.it.clear",
	"i.doubt.it.said.the.carpenter",
	"and.shed.a.bitter.tear",
	"o.oysters.come.and.walk.with.us",
	"the.walrus.did.beseech",
	"a.pleasant.walk.a.pleasant.talk",
	"along.the.briny.beach",
	"we.cannot.do.with.more.than.four",
	"to.give.a.hand.to.each",
	"the.eldest.oyster.looked.at.him",
	"but.never.a.word.he.said",
	"the.eldest.oyster.winked.his.eye",
	"and.shook.his.heavy.head",
	"meaning.to.say.he.did.not.choose",
	"to.leave.the.oyster.bed",
	"but.four.young.oysters.hurried.up",
	"all.eager.for.the.treat",
	"their.coats.were.brushed.their.faces.washed",
	"their.shoes.were.clean.and.neat",
	"and.this.was.odd.because.you.know",
	"they.hadn.t.any.feet",
	"four.other.oysters.followed.them",
	"and.yet.another.four",
	"and.thick.and.fast.they.came.at.last",
	"and.more.and.more.and.more",
	"all.hopping.through.the.frothy.waves",
	"and.scrambling.to.the.shore",
	"the.walrus.and.the.carpenter",
	"walked.on.a.mile.or.so",
	"and.then.they.rested.on.a.rock",
	"conveniently.low",
	"and.all.the.little.oysters.stood",
	"and.waited.in.a.row",
	"the.time.has.come.the.walrus.said",
	"to.talk.of.many.things",
	"of.shoes.and.ships.and.sealing.wax",
	"of.cabbages.and.kings",
	"and.why.the.sea.is.boiling.hot",
	"and.whether.pigs.have.wings",
	"but.wait.a.bit.the.oysters.cried",
	"before.we.have.our.chat",
	"for.some.of.us.are.out.of.breath",
	"and.all.of.us.are.fat",
	"no.hurry.said.the.carpenter",
	"they.thanked.him.much.for.that",
	"a.loaf.of.bread.the.walrus.said",
	"is.what.we.chiefly.need",
	"pepper.and.vinegar.besides",
	"are.very.good.indeed",
	"now.if.you.re.ready.oysters.dear",
	"we.can.begin.to.feed",
	"but.not.on.us.the.oysters.cried",
	"turning.a.little.blue",
	"after.such.kindness.that.would.be",
	"a.dismal.thing.to.do",
	"the.night.is.fine.the.walrus.said",
	"do.you.admire.the.view",
	"it.was.so.kind.of.you.to.come",
	"and.you.are.very.nice",
	"the.carpenter.said.nothing.but",
	"cut.us.another.slice",
	"i.wish.you.were.not.quite.so.deaf",
	"i.ve.had.to.ask.you.twice",
	"it.seems.a.shame.the.walrus.said",
	"to.play.them.such.a.trick",
	"after.we.ve.brought.them.out.so.far",
	"and.made.them.trot.so.quick",
	"the.carpenter.said.nothing.but",
	"the.butter.s.spread.too.thick",
	"i.weep.for.you.the.walrus.said",
	"i.deeply.sympathize",
	"with.sobs.and.tears.he.sorted.out",
	"those.of.the.largest.size",
	"holding.his.pocket.handkerchief",
	"before.his.streaming.eyes",
	"o.oysters.said.the.carpenter",
	"you.ve.had.a.pleasant.run",
	"shall.we.be.trotting.home.again",
	"but.answer.came.there.none",
	"and.that.was.scarcely.odd.because",
	"they.d.eaten.every.one",
})});

array(string) endpoints = ({
	"tomfoolery.rosuav.com.", //The DNS server itself
	"jabberwocky.rosuav.com.",
	"aboatbeneath.rosuav.com.",
	"ykcowrebbaj.rosuav.com.",
	"walruscarpenter.rosuav.com.",
});
//Convenience aliases - will need to be covered by the SSL cert too
array(string) aliases = ({
	"walrus.rosuav.com.",
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

	if (has_value(argv, "--cert")) {
		//Request an SSL certificate covering all the necessary names
		Process.exec("/usr/bin/env", "certbot", "certonly", "--standalone", "-d", (endpoints + aliases) * ",");
	}
	if (has_value(argv, "--html")) {
		//TODO: Build a series of files in /var/www/html
		//Make an index.html that lists non-redirect poetry destinations
		//For each destination (including redirects), create a file explaining what the traceroute
		//does, how to trigger it (on multiple platforms, and include a parameter to lengthen the
		//max trace), and showing what it looks like. Colour-code the trace; borrow the trace start
		//from Gideon but do only a single probe so that it pretends to be stable.
		string template = Stdio.read_file(replace(__FILE__, ".pike", ".html"));
		string targetdir = "/var/www/html/";
		foreach (endpoints[1..]; int i; string dest) {
			array(string) trace = ({ });
			foreach (traces[i]; int idx; string name) {
				trace += ({sprintf("<span class=poem><span class=index>%d  </span><span class=line>%s</span> <span class=ip>(2403:5803:f90e:1::%x%02x)</span>  <span class=time>%.3f ms  %.3f ms %.3f ms</span></span>",
					idx + 19, //Hop count where the interesting trace begins
					name,
					i + 1, idx + 1, //The last part of the IP address
					//Randomize some timings here. This means it's unstable but I don't really mind.
					250.0 + idx + random(5.0),
					250.0 + idx + random(5.0),
					250.0 + idx + random(5.0),
				)});
			}
			trace += ({sprintf("<span class=arrival><span class=index>%d  </span><span class=landing>%s</span> <span class=ip>(2403:5803:f90e:1::%x)</span>  <span class=time>%.3f ms  %.3f ms %.3f ms</span></span>",
				sizeof(traces[i]) + 19, //Should be the final hop count to the destination
				dest[..<1],
				i + 1,
				250.0 + sizeof(traces[i]) + random(5.0),
				250.0 + sizeof(traces[i]) + random(5.0),
				250.0 + sizeof(traces[i]) + random(5.0),
			)});
			Stdio.write_file(targetdir + dest + "html", replace(template, ([
				"$$destination$$": dest[..<1],
				"$$ip$$": sprintf("2403:5803:f90e:1::%x", i + 1),
				"$$trace$$": trace * "\n",
			])));
		}
		foreach (aliases, string alias) {
			//Create a redirect?
		}
		//Copy some static files
		foreach (({"dnspipe.css", "dnspipe.js"}), string fn)
			Stdio.cp(fn, targetdir + fn);
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

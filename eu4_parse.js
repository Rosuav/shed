//Not to be confused with eu4_parse.json which is a cache
import choc, {set_content, DOM} from "https://rosuav.github.io/shed/chocfactory.js";
const {A, ABBR, B, BR, DETAILS, DIV, FORM, H1, H3, IMG, INPUT, LABEL, LI, OPTGROUP, OPTION, P, SELECT, SPAN, STRONG, SUMMARY, TABLE, TD, TH, TR, UL} = choc; //autoimport
const {BLOCKQUOTE, H4} = choc; //Currently autoimport doesn't recognize the section() decorator

function table_head(headings) {
	if (typeof headings === "string") headings = headings.split(" ");
	return TR(headings.map(h => TH(h))); //TODO: Click to sort
}

let curgroup = [], provgroups = { }, provelem = { }, pinned_provinces = { }, discovered_provinces = { };
function proventer(kwd) {
	curgroup.push(kwd);
	const g = curgroup.join("/");
	provgroups[g] = [];
	return provelem[g] = SPAN({
		className: "provgroup size-" + curgroup.length,
		"data-group": g, title: "Select cycle group " + g,
	}, "📜"); //TODO: If this is the selected cycle group, show it differently?
}
function provleave() { //Can safely be put into a DOM array (will be ignored)
	const g = curgroup.join("/");
	if (!provgroups[g].length) {
		const el = provelem[g];
		set_content(el, "📃");
		el.title = "No provinces in group " + g;
		el.classList.add("empty");
	}
	curgroup.pop();
}
function PROV(id, name, namelast) {
	let g;
	for (let kwd of curgroup) {
		if (g) g += "/" + kwd; else g = kwd;
		if (provgroups[g].indexOf(id) < 0) provgroups[g].push(id);
	}
	const pin = pinned_provinces[id], disc = discovered_provinces[id];
	return SPAN({className: "province"}, [
		!namelast && name,
		SPAN({className: "goto-province provbtn", title: (disc ? "Go to #" : "Terra Incognita, cannot goto #") + id, "data-provid": id}, disc ? "🔭" : "🌐"),
		SPAN({className: "pin-province provbtn", title: (pin ? "Unpin #" : "Pin #") + id, "data-provid": id}, pin ? "⛳" : "📌"),
		namelast && name,
	]);
}

let countrytag = "", hovertag = ""; //The country we're focusing on (usually a player-owned one) and the one highlighted.
let country_info = { };
function COUNTRY(tag, nameoverride) {
	if (tag === "") return "";
	const c = country_info[tag] || {name: tag};
	return SPAN({className: "country", "data-tag": tag}, [
		IMG({className: "flag small", src: "/flags/" + c.flag + ".png", alt: "[flag of " + c.name + "]"}),
		" ", nameoverride || c.name,
	]);
}
function update_hover_country() {
	const tag = hovertag, c = country_info[tag];
	const me = country_info[countrytag] || {tech: [0,0,0]};
	if (!c) {
		set_content("#hovercountry", "").classList.add("hidden");
		return;
	}
	function attrs(n) {
		if (n > 0) return {className: "tech above", title: n + " ahead of you"};
		if (n < 0) return {className: "tech below", title: -n + " behind you"};
		return {className: "tech same", title: "Same as you"};
	}
	set_content("#hovercountry", [
		DIV({className: "close"}, "☒"),
		A({href: "/tag/" + hovertag, target: "_blank"}, [
			IMG({className: "flag large", src: "/flags/" + c.flag + ".png", alt: "[flag of " + c.name + "]"}),
			H3(c.name),
		]),
		UL([
			LI(["Tech: ", ["Adm", "Dip", "Mil"].map((cat, i) => [SPAN(
				attrs(c.tech[i] - me.tech[i]),
				cat + " " + c.tech[i],
			), " "])]),
			LI(["Capital: ", PROV(c.capital, c.capitalname, 1), c.hre && SPAN({title: "Member of the HRE"}, "👑")]),
			LI(["Provinces: " + c.province_count + " (",
				SPAN({title: "Total province development, modified by local autonomy"}, c.development + " dev"), ")"]),
			LI(["Institutions embraced: ", SPAN(attrs(c.institutions - me.institutions), ""+c.institutions)]),
			LI(["Opinion: ", B({title: "Their opinion of you"}, c.opinion_theirs),
				" / ", B({title: "Your opinion of them"}, c.opinion_yours)]),
			LI(["Mil units: ", SPAN(attrs(c.armies - me.armies), c.armies + " land"),
				" ", SPAN(attrs(c.navies - me.navies), c.navies + " sea")]),
			c.subjects && LI("Subject nations: " + c.subjects),
			c.alliances && LI("Allied with: " + c.alliances),
			c.overlord && LI([B(c.subject_type), " of ", COUNTRY(c.overlord)]),
		]),
	]).classList.remove("hidden");
}
//Note that there is no mouseout. Once you point to a country, it will remain highlighted (even through savefile updates).
on("mouseover", ".country:not(#hovercountry .country)", e => {hovertag = e.match.dataset.tag; update_hover_country();});
on("click", "#hovercountry .country", e => {hovertag = e.match.dataset.tag; update_hover_country();});
//The hovered country can only be removed with its little Close button.
on("click", "#hovercountry .close", e => {hovertag = ""; update_hover_country();});

on("click", ".goto-province", e => {
	ws_sync.send({cmd: "goto", tag: countrytag, province: e.match.dataset.provid});
});

on("click", ".pin-province", e => {
	ws_sync.send({cmd: "pin", province: e.match.dataset.provid});
});

on("click", ".provgroup", e => {
	ws_sync.send({cmd: "cyclegroup", cyclegroup: e.match.dataset.group});
});

on("click", "#interesting_details li", e => {
	const el = document.getElementById(e.match.dataset.id);
	el.open = true;
	el.scrollIntoView({block: "start", inline: "nearest"});
});

on("change", "#highlight_options", e => {
	ws_sync.send({cmd: "highlight", building: e.match.value});
});

let search_allow_change = 0;
on("input", "#searchterm", e => {
	search_allow_change = 1000 + +new Date;
	ws_sync.send({cmd: "search", term: e.match.value});
});

let max_interesting = { };

function upgrade(upg, tot) {
	if (!tot) return TD("");
	return TD({className: upg ? "interesting1" : ""}, upg + "/" + tot);
}

const sections = [];
function section(id, lbl, render) {sections.push({id, lbl, render});}

section("cot", "Centers of Trade", state => {
	max_interesting.cot = state.cot.maxinteresting;
	const content = [SUMMARY(`Centers of Trade (${state.cot.level3}/${state.cot.max} max level)`), proventer("cot")];
	for (let kwd of ["upgradeable", "developable"]) {
		const cots = state.cot[kwd];
		if (!cots.length) continue;
		content.push(TABLE({id: kwd, border: "1"}, [
			TR(TH({colSpan: 4}, [proventer(kwd), `${kwd[0].toUpperCase()}${kwd.slice(1)} CoTs:`])),
			cots.map(cot => TR({className: "interesting" + cot.interesting}, [
				TD(PROV(cot.id, cot.name)), TD("Lvl "+cot.level), TD("Dev "+cot.dev), TD(cot.noupgrade)
			])),
		]));
		provleave();
	}
	provleave();
	return content;
});

section("monuments", "Monuments", state => [
	SUMMARY(`Monuments [${state.monuments.length}]`),
	TABLE({border: "1"}, [
		TR([TH([proventer("monuments"), "Province"]), TH("Tier"), TH("Project"), TH("Upgrading")]),
		state.monuments.map(m => TR([TD(PROV(m[1], m[3])), TD(m[2]), TD(m[4]), TD(m[5])])),
	]),
	provleave(),
]);

section("favors", "Favors", state => {
	let free = 0, owed = 0, owed_total = 0;
	function compare(val, base) {
		if (val <= base) return val.toFixed(3);
		return ABBR({title: val.toFixed(3) + " before cap"}, base.toFixed(3));
	}
	const cooldowns = state.favors.cooldowns.map(cd => {
		if (cd[1] === "---") ++free;
		return TR({className: cd[1] === "---" ? "interesting1" : ""}, cd.slice(1).map(TD));
	});
	const countries = Object.entries(state.favors.owed).sort((a,b) => b[1][0] - a[1][0]).map(([c, f]) => {
		++owed_total; if (f[0] >= 10) ++owed;
		return TR({className: f[0] >= 10 ? "interesting1" : ""}, [TD(COUNTRY(c)), f.map((n,i) => TD(compare(n, i ? +state.favors.cooldowns[i-1][4] : n)))]);
	});
	max_interesting.favors = free && owed ? 1 : 0;
	return [
		SUMMARY(`Favors [${free}/3 available, ${owed}/${owed_total} owe ten]`),
		P("NOTE: Yield estimates are often a bit wrong, but can serve as a guideline."),
		TABLE({border: "1"}, cooldowns),
		TABLE({border: "1"}, [
			table_head("Country Favors Ducats Manpower Sailors"),
			countries,
		]),
	];
});

section("wars", "Wars", state => [SUMMARY("Wars: " + (state.wars.length || "None")), state.wars.map(war => {
	//For each war, create or update its own individual DETAILS/SUMMARY. This allows
	//individual wars to be collapsed as uninteresting without disrupting others.
	let id = "warinfo-" + war.name.toLowerCase().replace(/[^a-z]/g, " ").replace(/ +/g, "-");
	//It's possible that a war involving "conquest of X" might collide with another war
	//involving "conquest of Y" if the ASCII alphabetics in the province names are identical.
	//While unlikely, this would be quite annoying, so we add in the province ID when a
	//conquest CB is used. TODO: Check this for other CBs eg occupy/retain capital.
	if (war.cb) id += "-" + war.cb.type + "-" + (war.cb.province||"no-province");
	//NOTE: The atk and def counts refer to all players. Even if you aren't interested in
	//wars involving other players but not yourself, they'll still have their "sword" or
	//"shield" indicator given based on any player involvement.
	const atkdef = (war.atk ? "\u{1f5e1}\ufe0f" : "") + (war.def ? "\u{1f6e1}\ufe0f" : "");
	return set_content(DOM("#" + id) || DETAILS({id, open: true}), [
		SUMMARY(atkdef + " " + war.name),
		TABLE({border: "1"}, [
			table_head(["Country", "Infantry", "Cavalry", "Artillery",
				ABBR({title: "Merc infantry"}, "Inf $$"),
				ABBR({title: "Merc cavalry"}, "Cav $$"),
				ABBR({title: "Merc artillery"}, "Art $$"),
				"Total", "Manpower", ABBR({title: "Army professionalism"}, "Prof"),
				ABBR({title: "Army tradition"}, "Trad"),
			]),
			war.armies.map(army => TR({className: army[0].replace(",", "-")}, [TD(COUNTRY(army[1])), army.slice(2).map(x => TD(x ? ""+x : ""))])),
		]),
		TABLE({border: "1"}, [
			table_head(["Country", "Heavy", "Light", "Galley", "Transport", "Total", "Sailors",
				ABBR({title: "Navy tradition"}, "Trad"),
			]),
			war.navies.map(navy => TR({className: navy[0].replace(",", "-")}, [TD(COUNTRY(navy[1])), navy.slice(2).map(x => TD(x ? ""+x : ""))])),
		]),
	]);
})]);

section("badboy_hatred", "Badboy Haters", state => [
	SUMMARY("Badboy Haters (" + state.badboy_hatred.length + ")"),
	!(max_interesting.badboy_hatred = state.badboy_hatred.length ? 1 : 0) && "Nobody hates you enough to join a coalition.",
	TABLE({border: "1"}, [
		table_head(["Opinion", ABBR({title: "Aggressive Expansion"}, "Badboy"), "Country", "Notes"]),
		state.badboy_hatred.map(hater => {
			const info = country_info[hater.tag];
			const attr = { };
			if (hater.in_coalition) {attr.className = "interesting2"; max_interesting.badboy = 2;}
			return TR([
				TD({className: info.opinion_theirs < 0 ? "interesting1" : ""}, info.opinion_theirs),
				TD({className: hater.badboy >= 50000 ? "interesting1" : ""}, Math.floor(hater.badboy / 1000) + ""),
				TD(attr, COUNTRY(hater.tag)),
				TD(attr, [
					info.overlord && SPAN({title: "Is a " + info.subject_type + " of " + country_info[info.overlord].name}, "🙏"),
					info.truce && SPAN({title: "Truce until " + info.truce}, "🏳"),
					hater.in_coalition && SPAN({title: "In coalition against you!"}, "😠"),
				]),
			]);
		}),
	]),
]);

section("colonization_targets", "Colonization targets", state => [
	SUMMARY("Colonization targets (" + state.colonization_targets.length + ")"), //TODO: Count interesting ones too?
	TABLE({border: "1"}, [
		table_head(["Province", "Dev", "Geography", "Settler penalty", "Features"]),
		state.colonization_targets.map(prov => TR([
			TD(PROV(prov.id, prov.name)),
			TD(""+prov.dev),
			TD(prov.climate + " " + prov.terrain + (prov.has_port ? " port" : "")),
			TD(""+prov.settler_penalty),
			TD(UL([
				prov.cot && LI("L" + prov.cot + " center of trade"),
				prov.modifiers.map(mod => LI(ABBR({title: mod.effects.join("\n")}, mod.name))),
			])),
		])),
	]),
]);

section("highlight", "Building expansions", state => state.highlight.id ? [
	SUMMARY("Building expansions: " + state.highlight.name),
	P([proventer("expansions"), "If developed, these places could support a new " + state.highlight.name + ". "
		+ "They do not currently contain one, there is no building that could be upgraded "
		+ "to one, and there are no building slots free. This list allows you to focus "
		+ "province development in a way that enables a specific building; once the slot "
		+ "is opened up, the province will disappear from here and appear in the in-game "
		+ "macro-builder list for that building."]),
	TABLE({border: true}, [
		table_head("Province Buildings Devel MP-cost"),
		state.highlight.provinces.map(prov => TR([
			TD(PROV(prov.id, prov.name)),
			TD(`${prov.buildings}/${prov.maxbuildings}`),
			TD(""+prov.dev),
			TD(""+prov.cost[3]),
		])),
	]),
	provleave(),
] : [
	SUMMARY("Building expansions"),
	P("To search for provinces that could be developed to build something, choose a building in" +
	" the top right options."),
]);

section("upgradeables", "Upgrades available", state => [ //Assumes that we get navy_upgrades with upgradeables
	SUMMARY("Upgrades available: " + state.upgradeables.length + " building type(s), " + state.navy_upgrades.length + " fleet(s)"),
	P([proventer("upgradeables"), state.upgradeables.length + " building type(s) available for upgrade."]),
	UL(state.upgradeables.map(upg => LI([
		proventer(upg[0]), upg[0] + ": ",
		upg[1].map(prov => PROV(prov.id, prov.name)),
		provleave(),
	]))),
	provleave(),
	P(state.navy_upgrades.length + " fleets(s) have outdated ships."),
	TABLE({border: true}, [
		table_head(["Fleet", "Heavy ships", "Light ships", "Galleys", "Transports"]),
		state.navy_upgrades.map(f => TR([
			TD(f.name),
			upgrade(...f.heavy_ship),
			upgrade(...f.light_ship),
			upgrade(...f.galley),
			upgrade(...f.transport),
		])),
	]),
]);

section("flagships", "Flagships of the World", state => [
	SUMMARY("Flagships of the World (" + state.flagships.length + ")"),
	TABLE({border: true}, [
		table_head(["Country", "Fleet", "Vessel", "Modifications", "Built by"]),
		state.flagships.map(f => TR([TD(COUNTRY(f[0])), TD(f[1]), TD(f[2] + ' "' + f[3] + '"'), TD(f[4].join(", ")), TD(f[5])])),
	]),
]);

section("truces", "Truces", state => [
	SUMMARY("Truces: " + state.truces.map(t => t.length - 1).reduce((a,b) => a+b, 0) + " countries, " + state.truces.length + " blocks"),
	state.truces.map(t => [
		H3(t[0]),
		UL(t.slice(1).map(c => LI([COUNTRY(c[0]), " ", c[1]]))),
	]),
]);

section("cbs", "Casus belli", state => [
	SUMMARY(`Casus belli: ${state.cbs.from.tags.length} potential victims, ${state.cbs.against.tags.length} potential aggressors`),
	//NOTE: The order here (from, against) has to match the order in the badboy/prestige/peace_cost arrays (attacker, defender)
	[["from", "CBs you have on others"], ["against", "CBs others have against you"]].map(([grp, lbl], scoreidx) => [
		H3(lbl),
		BLOCKQUOTE(Object.entries(state.cbs[grp]).map(([type, cbs]) => type !== "tags" && [
			(t => H4([
				ABBR({title: t.desc}, t.name),
				" ",
				t.restricted && SPAN({className: "caution", title: t.restricted}, "⚠️"),
				" (", ABBR({title: "Aggressive Expansion"}, Math.floor(t.badboy[scoreidx] * 100) + "%"),
				", ", ABBR({title: "Prestige"}, Math.floor(t.prestige[scoreidx] * 100) + "%"),
				", ", ABBR({title: "Peace cost"}, Math.floor(t.peace_cost[scoreidx] * 100) + "%"),
				")",
			]))(state.cbs.types[type]),
			UL(cbs.map(cb => LI([
				COUNTRY(cb.tag),
				cb.end_date && " (until " + cb.end_date + ")",
			]))),
		])),
	]),
]);

export function render(state) {
	curgroup = []; provgroups = { };
	//Set up one-time structure. Every subsequent render will update within that.
	if (!DOM("#error")) set_content("main", [
		DIV({id: "error", className: "hidden"}),
		DIV({id: "menu", className: "hidden"}),
		IMG({className: "flag large", id: "playerflag", alt: "[flag of player's nation]"}),
		H1({id: "player"}),
		DETAILS({id: "selectprov"}, [
			SUMMARY("Find a province/country"),
			DIV({id: "search"}, H3("Search for a province or country")),
			DIV({id: "pin"}, H3("Pinned provinces")),
		]),
		sections.map(s => DETAILS({id: s.id}, SUMMARY(s.lbl))),
		DIV({id: "options"}, [ //Positioned fixed in the top corner
			LABEL(["Building highlight: ", SELECT({id: "highlight_options"}, OPTGROUP({label: "Building highlight"}))]),
			DIV({id: "cyclegroup"}),
			UL({id: "interesting_details"}),
			UL({id: "notifications"}),
			DIV({id: "agenda"}),
			DIV({id: "now_parsing", className: "hidden"}),
			DIV({id: "hovercountry", className: "hidden"}),
		]),
		//Always have DETAILS/SUMMARY nodes for every expandable, such that,
		//whenever content is updated, they remain in their open/closed state.
	]);

	if (state.error) {
		set_content("#error", [state.error, state.parsing ? state.parsing + "%" : ""]).classList.remove("hidden");
		return;
	}
	set_content("#error", "").classList.add("hidden");
	if (state.discovered_provinces) discovered_provinces = state.discovered_provinces;
	if (state.countries) country_info = state.countries;
	if (state.tag) {
		const c = country_info[countrytag = state.tag];
		DOM("#playerflag").src = "/flags/" + c.flag + ".png";
	}
	if (state.pinned_provinces) {
		pinned_provinces = { };
		set_content("#pin", [H3([proventer("pin"), "Pinned provinces: " + state.pinned_provinces.length]),
			UL(state.pinned_provinces.map(([id, name]) => LI(PROV(pinned_provinces[id] = id, name, 1)))),
		]);
		provleave();
	}
	if (state.search) {
		const input = DOM("#searchterm") || INPUT({id: "searchterm", size: 30});
		const focus = input === document.activeElement;
		set_content("#search", [H3([proventer("search"), "Search results: " + state.search.results.length]),
			P({className: "indent"}, LABEL(["Search for:", input])),
			UL(state.search.results.map(info => LI(
				(typeof info[0] === "number" ? PROV : COUNTRY)(info[0], [info[1], STRONG(info[2]), info[3]])
			))),
		]);
		if (state.search.term !== input.value) {
			//Update the input, but avoid fighting with the user
			let change_allowed = search_allow_change - +new Date;
			if (change_allowed <= 0) input.value = state.search.term;
			//else ... hold the change for the remaining milliseconds, and then do some sort of resynchronization
		}
		if (focus) input.focus();
	}
	if (state.parsing) set_content("#now_parsing", "Parsing savefile... " + state.parsing + "%").classList.remove("hidden");
	else set_content("#now_parsing", "").classList.add("hidden");
	if (state.menu) {
		function lnk(dest) {return A({href: "/tag/" + encodeURIComponent(dest)}, dest);}
		set_content("#menu", [
			"Save file parsed. Pick a player nation to monitor, or search for a country:",
			UL(state.menu.map(c => LI([lnk(c[0]), " - ", lnk(c[1])]))),
			FORM([
				LABEL(["Enter tag or name:", INPUT({name: "q", placeholder: "SPA"})]),
				INPUT({type: "submit", value: "Search"}),
			]),
		]).classList.remove("hidden");
		return;
	}
	if (state.name) set_content("#player", state.name);
	sections.forEach(s => state[s.id] && set_content("#" + s.id, s.render(state)));
	if (state.buildings_available) set_content("#highlight_options", [
		OPTION({value: "none"}, "None"),
		OPTGROUP({label: "Need more of a building? Choose one to highlight places that could be expanded to build it."}), //hack
		Object.values(state.buildings_available).map(b => OPTION(
			{value: b.id},
			b.name, //TODO: Keep this brief, but give extra info, maybe in hover text??
		)),
	]).value = (state.highlight && state.highlight.id) || "none";
	update_hover_country();
	const is_interesting = [];
	Object.entries(max_interesting).forEach(([id, lvl]) => {
		const el = DOM("#" + id + " > summary");
		if (lvl) is_interesting.push(LI({className: "interesting" + lvl, "data-id": id}, el.innerText));
		el.className = "interesting" + lvl;
	});
	set_content("#interesting_details", is_interesting);
	if (state.cyclegroup) {
		if (!state.cycleprovinces) ws_sync.send({cmd: "cycleprovinces", provinces: provgroups[state.cyclegroup] || []});
		set_content("#cyclegroup", ["Selected group: " + state.cyclegroup + " ", SPAN({className: "provgroup clear"}, "❎")]);
	}
	else set_content("#cyclegroup", "");
	if (state.notifications) set_content("#notifications", state.notifications.map(n => LI({className: "interesting2"}, "🔔 " + n))); //Might end up having a "go-to" button on these
	if (state.agenda) {
		//Regardless of the agenda, you'll have a description and an expiry date.
		//The description might contain placeholders "[agenda_province.GetName]"
		//and/or "[agenda_country.GetUsableName]", which should be replaced with
		//PROV() and COUNTRY() markers respectively. It may also contain other
		//markers. Currently we have no way to handle these here on the client,
		//so hopefully the server can cope with them on our behalf.
		let prov = state.agenda.province && PROV(state.agenda.province, state.agenda.province_name);
		let country = state.agenda.country && COUNTRY(state.agenda.country);
		let rival_country = state.agenda.rival_country && COUNTRY(state.agenda.rival_country);
		let info = ["Agenda expires ", state.agenda.expiry, ": ", BR()];
		let desc = state.agenda.desc;
		let spl;
		while (spl = /^(.*)\[([^\]]*)\](.*)$/.exec(desc)) {
			info.push(spl[1]);
			switch (spl[2]) {
				case "agenda_province.GetName": info.push(prov || "(province)"); prov = null; break;
				case "agenda_country.GetUsableName": info.push(country || "(country)"); country = null; break;
				case "rival_country.GetUsableName": info.push(rival_country || "(rival)"); rival_country = null; break;
				default: info.push(B(spl[2])); //Unknown marker type, which the server didn't translate for us. A bit ugly.
			}
			desc = spl[3];
		}
		info.push(desc);
		if (prov) info.push(BR(), "See: ", prov); //If there's no placeholder, but there is a focus-on province/country, show it underneath.
		if (country) info.push(BR(), "See: ", country);
		set_content("#agenda", info);
	}
}

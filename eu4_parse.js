//Not to be confused with eu4_parse.json which is a cache
import choc, {set_content, DOM} from "https://rosuav.github.io/shed/chocfactory.js";
const {A, ABBR, BLOCKQUOTE, DETAILS, DIV, FORM, H1, H3, H4, IMG, INPUT, LABEL, LI, OPTGROUP, OPTION, P, SELECT, SPAN, STRONG, SUMMARY, TABLE, TD, TH, TR, UL} = choc; //autoimport

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
	return DIV({className: "province"}, [
		!namelast && name,
		SPAN({className: "goto-province provbtn", title: (disc ? "Go to #" : "Terra Incognita, cannot goto #") + id, "data-provid": id}, disc ? "🔭" : "🌐"),
		SPAN({className: "pin-province provbtn", title: (pin ? "Unpin #" : "Pin #") + id, "data-provid": id}, pin ? "⛳" : "📌"),
		namelast && name,
	]);
}

let countrytag = "", hovertag = ""; //The country we're focusing on (usually a player-owned one) and the one highlighted.
let country_info = { };
function COUNTRY(tag) {
	const c = country_info[tag] || {name: tag};
	return SPAN({className: "country", "data-tag": tag}, [
		IMG({className: "flag small", src: "/flags/" + tag + ".png", alt: "[flag of " + c.name + "]"}),
		" " + c.name,
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
		IMG({className: "flag large", src: "/flags/" + tag + ".png", alt: "[flag of " + c.name + "]"}),
		H3(c.name),
		UL([
			LI(["Tech: ", ["Adm", "Dip", "Mil"].map((cat, i) => [SPAN(
				attrs(c.tech[i] - me.tech[i]),
				cat + " " + c.tech[i],
			), " "])]),
			LI(["Capital: ", PROV(c.capital, c.capitalname)]),
			LI("Provinces: " + c.province_count + " (total " + c.development + " dev)"),
			LI(["Instutions: ", SPAN(attrs(c.institutions - me.institutions), ""+c.institutions)]),
		]),
	]).classList.remove("hidden");
}
//Note that there is no mouseout. Once you point to a country, it will remain highlighted (even through savefile updates).
on("mouseover", ".country", e => {hovertag = e.match.dataset.tag; update_hover_country();});
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

on("change", "#highlight", e => {
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

export function render(state) {
	curgroup = []; provgroups = { };
	//Set up one-time structure. Every subsequent render will update within that.
	if (!DOM("#error")) set_content("main", [
		DIV({id: "error", className: "hidden"}),
		DIV({id: "menu", className: "hidden"}),
		H1({id: "player"}),
		DETAILS({id: "selectprov"}, [
			SUMMARY("Find a province"),
			DIV({id: "search"}, H3("Search for a province")),
			DIV({id: "pin"}, H3("Pinned provinces")),
		]),
		DETAILS({id: "cot"}, SUMMARY("Centers of Trade")),
		DETAILS({id: "monuments"}, SUMMARY("Monuments")),
		DETAILS({id: "favors"}, SUMMARY("Favors")),
		DETAILS({id: "wars"}, SUMMARY("Wars")),
		DETAILS({id: "expansions"}, SUMMARY("Building expansions")),
		DETAILS({id: "upgradeables"}, SUMMARY("Upgrades available")),
		DETAILS({id: "flagships"}, SUMMARY("Flagships of the World")),
		DETAILS({id: "truces"}, SUMMARY("Truces")),
		DETAILS({id: "cbs"}, SUMMARY("Casus Belli")),
		DIV({id: "options"}, [ //Positioned fixed in the top corner
			LABEL(["Building highlight: ", SELECT({id: "highlight"}, OPTGROUP({label: "Building highlight"}))]),
			DIV({id: "cyclegroup"}),
			UL({id: "interesting_details"}),
			DIV({id: "now_parsing", className: "hidden"}),
			DIV({id: "hovercountry", className: "hidden"}),
		]),
		//TODO: Have DETAILS/SUMMARY nodes for every expandable, such that,
		//whenever content is updated, they remain in their open/closed state
	]);

	if (state.error) {
		set_content("#error", [state.error, state.parsing ? state.parsing + "%" : ""]).classList.remove("hidden");
		return;
	}
	set_content("#error", "").classList.add("hidden");
	if (state.discovered_provinces) discovered_provinces = state.discovered_provinces;
	if (state.countries) country_info = state.countries;
	if (state.tag) countrytag = state.tag;
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
			UL(state.search.results.map(info => LI(PROV(info[0], [info[1], STRONG(info[2]), info[3]])))),
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
	if (state.cot) {
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
		set_content("#cot", content);
		provleave();
	}
	if (state.monuments) set_content("#monuments", [
		SUMMARY(`Monuments [${state.monuments.length}]`),
		TABLE({border: "1"}, [
			TR([TH([proventer("monuments"), "Province"]), TH("Tier"), TH("Project"), TH("Upgrading")]),
			state.monuments.map(m => TR([TD(PROV(m[1], m[3])), TD(m[2]), TD(m[4]), TD(m[5])])),
		]),
		provleave(),
	]);
	if (state.favors) {
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
			return TR({className: f[0] >= 10 ? "interesting1" : ""}, [TD(c), f.map((n,i) => TD(compare(n, i ? +state.favors.cooldowns[i-1][4] : n)))]);
		});
		max_interesting.favors = free && owed ? 1 : 0;
		set_content("#favors", [
			SUMMARY(`Favors [${free}/3 available, ${owed}/${owed_total} owe ten]`),
			P("NOTE: Yield estimates are often a bit wrong, but can serve as a guideline."),
			TABLE({border: "1"}, cooldowns),
			TABLE({border: "1"}, [
				table_head("Country Favors Ducats Manpower Sailors"),
				countries
			]),
		]);
	}
	if (state.wars) {
		//For each war, create or update its own individual DETAILS/SUMMARY. This allows
		//individual wars to be collapsed as uninteresting without disrupting others.
		set_content("#wars", [SUMMARY("Wars: " + (state.wars.length || "None")), state.wars.map(war => {
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
					war.armies.map(army => TR({className: army[0].replace(",", "-")}, army.slice(1).map(x => TD(x ? ""+x : "")))),
				]),
				TABLE({border: "1"}, [
					table_head(["Country", "Heavy", "Light", "Galley", "Transport", "Total", "Sailors",
						ABBR({title: "Navy tradition"}, "Trad"),
					]),
					war.navies.map(navy => TR({className: navy[0].replace(",", "-")}, navy.slice(1).map(x => TD(x ? ""+x : "")))),
				]),
			]);
		})]);
	}
	if (state.highlight) {
		if (state.highlight.id) set_content("#expansions", [
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
		]);
		else set_content("#expansions", [
			SUMMARY("Building expansions"),
			P("To search for provinces that could be developed to build something, choose a building in" +
			" the top right options."),
		]);
	}
	if (state.buildings_available) set_content("#highlight", [
		OPTION({value: "none"}, "None"),
		OPTGROUP({label: "Need more of a building? Choose one to highlight places that could be expanded to build it."}), //hack
		Object.values(state.buildings_available).map(b => OPTION(
			{value: b.id},
			b.name, //TODO: Keep this brief, but give extra info, maybe in hover text??
		)),
	]).value = (state.highlight && state.highlight.id) || "none";
	if (state.upgradeables && state.navy_upgrades) set_content("#upgradeables", [ //Yeah, gotta get both or neither for proper rendering.
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
	if (state.flagships) set_content("#flagships", [
		SUMMARY("Flagships of the World (" + state.flagships.length + ")"),
		TABLE({border: true}, [
			table_head(["Country", "Fleet", "Vessel", "Modifications", "Built by"]),
			state.flagships.map(f => TR([TD(f[0]), TD(f[1]), TD(f[2] + ' "' + f[3] + '"'), TD(f[4].join(", ")), TD(f[5])])),
		]),
	]);
	if (state.truces) set_content("#truces", [
		SUMMARY("Truces: " + state.truces.map(t => t.length - 1).reduce((a,b) => a+b) + " countries, " + state.truces.length + " blocks"),
		state.truces.map(t => [
			H3(t[0]),
			UL(t.slice(1).map(c => LI(c))),
		]),
	]);
	if (state.cbs) set_content("#cbs", [
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
}

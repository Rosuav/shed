//Not to be confused with eu4_parse.json which is a cache
import choc, {set_content, DOM} from "https://rosuav.github.io/shed/chocfactory.js";
const {A, ABBR, DETAILS, DIV, FORM, H1, INPUT, LABEL, LI, SUMMARY, TABLE, TD, TH, TR, UL} = choc; //autoimport

export function render(state) {
	//Set up one-time structure. Every subsequent render will update within that.
	if (!DOM("#error")) set_content("main", [
		DIV({id: "error", className: "hidden"}), DIV({id: "now_parsing", className: "hidden"}),
		DIV({id: "menu", className: "hidden"}),
		H1({id: "player"}),
		DETAILS({id: "cot"}, SUMMARY("Centers of Trade")),
		DETAILS({id: "monuments"}, SUMMARY("Monuments")),
		DETAILS({id: "favors"}, SUMMARY("Favors")),
		//TODO: Have DETAILS/SUMMARY nodes for every expandable, such that,
		//whenever content is updated, they remain in their open/closed state
	]);

	if (state.error) {
		set_content("#error", state.error).classList.remove("hidden");
		return;
	}
	set_content("#error", "").classList.add("hidden");
	if (state.parsing) set_content("#now_parsing", "Parsing savefile...").classList.remove("hidden");
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
		const content = [SUMMARY(`Max level CoTs [${state.cot.level3}/${state.cot.max}]`)];
		for (let kwd of ["upgradeable", "developable"]) {
			const cots = state.cot[kwd];
			if (!cots.length) continue;
			content.push(TABLE({id: kwd, border: "1"}, [
				TR(TH({colSpan: 5}, `${kwd[0].toUpperCase()}${kwd.slice(1)} CoTs:`)),
				cots.map(cot => TR({className: cot.noupgrade === "" ? "highlight" : ""}, [
					TD(cot.id), TD("Lvl "+cot.level), TD("Dev "+cot.dev), TD(cot.name), TD(cot.noupgrade)
				])),
			]));
		}
		set_content("#cot", content);
	}
	if (state.monuments) set_content("#monuments", [
		SUMMARY(`Monuments [${state.monuments.length}]`),
		TABLE({border: "1"}, [
			TR([TH("ID"), TH("Tier"), TH("Province"), TH("Project"), TH("Upgrading")]),
			state.monuments.map(m => TR(m.slice(1).map(TD))),
		]),
	]);
	if (state.favors) {
		let free = 0, owed = 0, owed_total = 0;
		function compare(val, base) {
			if (val <= base) return val.toFixed(3);
			return ABBR({title: val.toFixed(3) + " before cap"}, base.toFixed(3));
		}
		const cooldowns = state.favors.cooldowns.map(cd => {
			if (cd[1] === "---") ++free;
			return TR({className: cd[1] === "---" ? "highlight" : ""}, cd.slice(1).map(TD));
		});
		const countries = Object.entries(state.favors.owed).sort((a,b) => b[1][0] - a[1][0]).map(([c, f]) => {
			++owed_total; if (f[0] >= 10) ++owed;
			return TR({className: f[0] >= 10 ? "highlight" : ""}, [TD(c), f.map((n,i) => TD(compare(n, i ? +state.favors.cooldowns[i-1][4] : n)))]);
		});
		set_content("#favors", [
			SUMMARY(`Favors [${free}/3 available, ${owed}/${owed_total} owe ten]`),
			TABLE({border: "1"}, cooldowns),
			TABLE({border: "1"}, [
				TR([TH("Country"), TH("Favors"), TH("Ducats"), TH("Manpower"), TH("Sailors")]), //TODO: Click to sort
				countries
			]),
		]);
	}
}
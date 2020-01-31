function pad(n) {return (n < 10 ? "0" : "") + n;}
function describe(ms) {
	if (ms < 0) return "in the future";
	if (ms < 1000) return "just now";
	if (ms < 60000) return Math.ceil(ms / 1000) + " seconds ago";
	if (ms < 3600000) return pad(Math.floor(ms / 60000)) + ":" + pad(Math.floor((ms % 60000) / 1000)) + " ago";
	const days = ms / 86400000;
	if (days < 1) return "earlier today";
	if (days < 2) return "yesterday";
	return Math.floor(days) + " days ago";
}

let locations = null;
function check_response(req) {
	if (req.responseURL.slice(34, 42) === "view/loc") {
		//console.log("Got one!");
		//This is *not* an API. It returns what appears to be deliberately malformed JSON.
		//assert req.responseText.slice(0,5) === ")]}'\n"
		const data = JSON.parse(req.responseText.slice(5));
		//console.log(window.data = data);
		if (!locations) locations = JSON.parse(localStorage.getItem("dancingmen_locations"));
		data[0].forEach(info => {
			const who = info[0];
			const name = who[3];
			const whenwhere = info[1];
			const [_, longitude, latitude] = whenwhere[1];
			const age = +new Date() - whenwhere[2];
			const desc = whenwhere[4];
			console.log(name, "was at", desc, describe(age));
			//TODO: Pre-code a lat/long for origin and destination, and interpolate.
			//Assume a one-hour trip. Predict arrival time.
			locations.forEach(([loc, lat, lon]) => {
				const dist = ((lat - latitude) ** 2 + (lon - longitude) ** 2) ** 0.5;
				console.log(loc, dist);
			});
		});
	}
	if (req.responseURL.slice(36, 45) === "story/pre") {
		//console.log("Got dest:", req);
		const data = JSON.parse(req.responseText.slice(5));
		//console.log(window.destdata = data);
		const locs = [data[19][0], data[19][1], ...data[19][2]].filter(x => x && x.length >= 31);
		locations = locs.map(l => [l[2], l[0][2], l[0][3]]);
		localStorage.setItem("dancingmen_locations", JSON.stringify(locations));
	}
}

const trampoline = XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open = function() {
	this.addEventListener("readystatechange", function() {
		if(this.readyState === 4) try {check_response(this);} catch (e) {console.error(e);}
	}, false);
	trampoline.apply(this, arguments);
};

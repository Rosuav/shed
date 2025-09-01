import {choc, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {P} = choc; //autoimport

//1. Embed Google Maps, highlight South America
//2. Add markers for every place name containing a saint honorific
//   - Match marker size to city size? Probably not.
//   - Search city names for any complete word matching a saint.
//   - Match on the city name ASCII

const saint_colors = {
	san: "#de6",
	sao: "#3a3",
	saint: "#811", st: "#811",
	sainte: "#218",
	santo: "#639", santa: "#639",
};

const {Map3DElement} = await google.maps.importLibrary("maps3d");
set_content("#map", [
	new Map3DElement({
		center: {lat: -14.7928311, lng: -59.6839768, altitude: 7500000},
		mode: "HYBRID",
	}),
	P("Legend:"), //TODO
]);

import {choc, replace_content, DOM} from "https://rosuav.github.io/choc/factory.js";
const {} = choc; //autoimport

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

//Not to be confused with eu4_parse.json which is a cache
import choc, {set_content, DOM} from "https://rosuav.github.io/shed/chocfactory.js";
const {DIV} = choc; //autoimport

export function render(state) {
	//Set up one-time structure. Every subsequent render will update within that.
	if (!DOM("#error")) set_content("main", 
		DIV({id: "error"}),
		//TODO: Have DETAILS/SUMMARY nodes for every expandable, such that,
		//whenever content is updated, they remain in their open/closed state
	);

	if (state.error) {
		set_content("#error", state.error).classList.remove("empty");
		return;
	}
	set_content("#error", "").classList.add("empty");
}

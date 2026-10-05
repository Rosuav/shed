//Analysis of Rogue Voltage run.xml and prefs files
constant PATH = "../.config/unity3d/HorizontComputergrafik/RogueVoltage";

int main() {
	string run = Stdio.read_file(PATH + "/Main/run.xml");
	if (run) { //The file won't exist if there's no current run
		//We're not doing a proper XML parse here; it's easier to just read line-by-line.
		array lines = run / "\n";
		array path = ({ });
		mapping cur = ([]);
		foreach (lines; int i; string line) {
			//Supported line formats:
			//<openingtag>
			//<opening attr="value">
			//<selfclosing />
			//<selfclosing attr="value" />
			//<oneline>value</oneline>
			//</closingtag>
			sscanf(line, "%*[ ]<%[/]%[^ >]%s>%s</%*s>", string slash, string tag, string attrs, string value);
			if (!tag) continue;
			if (slash == "/") {
				//assert path[-1] == tag
				path = path[..<1];
				continue;
			}
			int selfclosing = has_suffix(attrs, "/");
			attrs = String.trim(attrs[..<selfclosing]);
			//Super simplistic attribute parsing
			mapping attr = ([]);
			while (sscanf(attrs, "%*[ ]%s=\"%[^\"]\"%*[ ]%s", string a, string v, attrs) && a && v) attr[a] = v;
			switch (tag) {
				case "PlayerCharacter":
					cur->player = attr->Code - "playercharacter-";
					break;
				case "CurrentHP":
					if (has_value(path, "PlayerCharacter")) write("Player character %s [%s HP]:\n", cur->player, value);
					break;
				case "Socket":
					cur->socket = attr->ID;
					break;
				case "Module":
					if (has_value(path, "PlayerCharacter")) {
						//Player modules. There are also modules for the camp and for loot, less interesting.
						cur->module = attr->FileName - "module-";
					}
					break;
				case "StatusEffect":
					if (has_value(path, "PlayerCharacter")) {
						write("MODULE %O %O %O %O\n", cur->player, cur->socket, cur->module, attr->Code);
					}
					break;
			}
			if (!selfclosing && !value) path += ({tag});
		}
	}
}

int main(int argc, array(string) argv) {
	if (argc < 2) argv += ({Stdio.stdin->gets()});
	string xml = MIME.decode_base64(argv[1]);
	//Attempt to pretty-print the XML.
	//Slightly unideal; a self-closing tag followed by a closing tag leaves a blank line.
	int indent = 0, lastclose = 0;
	while (sscanf(xml, "%s<%s>%s", string before, string tag, xml)) {
		if (tag[..0] != "/") {
			//Opening or self-closing tag
			if (lastclose) {lastclose = 0; before += "\n" + "    " * indent;}
			if (tag[-1] != '/') {
				//Special case: If this is an opening tag, and the next tag is its
				//closing tag, print it all out and don't indent.
				if (sscanf(xml, "%s<%s>%s", string data, string nexttag, string after) && nexttag == "/" + (tag/" ")[0]) {
					write("%s<%s>%s<%s>\n%s", before, tag, data, nexttag, "    " * indent);
					xml = after;
					continue;
				}
				++indent;
			}
			write("%s<%s>\n%s", before, tag, "    " * indent);
		}
		else {
			write("%s\n%s<%s>", before, "    " * --indent, tag);
			lastclose = 1;
		}
	}
	write("%s\n", xml);
}

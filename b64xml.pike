int main(int argc, array(string) argv) {
	if (argc < 2) argv += ({Stdio.stdin->gets()});
	string xml = MIME.decode_base64(argv[1]);
	//Attempt to pretty-print the XML. Not perfect but reasonable for many cases.
	int indent = 0;
	while (sscanf(xml, "%s<%s>%s", string before, string tag, xml)) {
		if (tag[..0] != "/") {
			//Opening or self-closing tag
			int addindent = tag[-1] != '/';
			if (addindent) {
				//Special case: If this is an opening tag, and the next tag is its
				//closing tag, print it all out and don't indent.
				if (sscanf(xml, "%s<%s>%s", string data, string nexttag, string after) && nexttag == "/" + (tag/" ")[0]) {
					write("%s\n%s<%s>%s<%s>", before, "    " * indent, tag, data, nexttag);
					xml = after;
					continue;
				}
			}
			write("%s\n%s<%s>", before, "    " * indent, tag);
			indent += addindent;
		}
		else write("%s\n%s<%s>", before, "    " * --indent, tag); //Closing tag
	}
	write("%s\n", xml);
}

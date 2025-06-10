int main() {
	Stdio.Readline readline = Stdio.Readline();
	readline->message("Enter a path/to/file/spec for source files.");
	readline->message("Supports globbing in the filename portion only.");
	readline->enable_history(512);
	readline->set_prompt("FROM> ");
	string dir; array files;
	while (1) {
		string path = readline->read();
		if (!path) return 0;
		if (path == "") break;
		if (!has_value(path, "/")) path = "./" + path;
		dir = dirname(path);
		files = sort(glob(basename(path), get_dir(dir)));
		readline->message(sprintf("Will rename these files:%{\n    %s%}\nBlank line to confirm, or adjust the source name.", files));
	}
	if (!dir || !files || !sizeof(files)) return 0;
	int maxlen = max(@sizeof(files[*]));
	write("Enter Pike code to transform \e[1mfn\e[0m into the new name.\n");
	write("For example: \e[1mfn - \".txt\" + \".md\"\e[0m\n");
	readline->message("If a path is included, it is relative to the current directory.");
	readline->set_prompt("TO> ");
	string|zero dest; array targets;
	while (1) {
		string path = readline->read();
		if (!path) return 0;
		if (path == "" && targets) break;
		if (has_value(path, "/")) {dest = dirname(path); path = basename(path);}
		else dest = 0;
		function xlat = compile_string("string xlat(string fn) {return " + path + ";}")()->xlat;
		targets = xlat(files[*]);
		readline->message(sprintf("Will rename:%{\n    %" + maxlen + "s --> %s%}\nBlank line to confirm, or adjust the transform.", Array.transpose(({files, targets}))));
	}
	files = dir + "/" + files[*]; targets = (dest || dir) + "/" + targets[*];
	write("%d files renamed.\n", `+(@mv(files[*], targets[*])));
}

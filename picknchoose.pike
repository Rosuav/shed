//Pick and choose stuff to commit or revert
//You can do some of this with 'git gui', but it doesn't have an option to checkout a path,
//and you can't restrict it to a specific directory.

mapping win = ([]);

@({"mainwindow", "delete_event"}):
void closewindow() {
	if (win->mainwindow->destroy) win->mainwindow->destroy();
	destruct(win->mainwindow);
	exit(0);
}

GTK2.Table table(array(array|string|GTK2.Widget) contents) {
	GTK2.Table tb = GTK2.Table(sizeof(contents[0]), sizeof(contents), 0);
	foreach (contents; int y; array(string|GTK2.Widget) row) foreach (row; int x; string|GTK2.Widget obj) if (obj) {
		int opt=0;
		if (stringp(obj)) {obj=GTK2.Label((["xalign": 1.0, "label":obj])); opt=GTK2.Fill;}
		int xend=x+1; while (xend<sizeof(row) && !row[xend]) ++xend; //Span cols by putting 0 after the element
		tb->attach(obj,x,xend,y,y+1,opt,opt,1,1);
	}
	return tb;
}

void btn_clicked(object btn, array(string) cmd) {
	Process.run(cmd);
}

GTK2.Button button(string lbl, string ... cmd) {
	GTK2.Button btn = GTK2.Button(lbl);
	btn->signal_connect("clicked", (function)btn_clicked, cmd);
	return btn;
}

int main(int argc, array(string) argv) {
	array lines = Process.run(({"git", "status", "--porcelain"}) + argv[1..])->stdout / "\n";
	GTK2.setup_gtk();
	win->mainwindow = GTK2.Window((["title": "Pick and choose"]))->add(table(map(lines) {
		if (__ARGS__[0] == "") return 0;
		sscanf(__ARGS__[0], "%c%c %s", int c1, int c2, string fn);
		if (c1 == '?') return ({fn, "New file", button("Accept", "git", "add", ":/" + fn), button("Del")});
		if (c1 != ' ' && c2 == ' ') return 0; //({fn, "Staged", "", ""});
		if (c2 == 'D') return ({fn, "Deleted", button("Accept", "git", "add", ":/" + fn), button("Restore", "git", "checkout", ":/" + fn)});
		if (c2 == 'M') return ({fn, "Changed", button("Accept", "git", "add", ":/" + fn), button("Restore", "git", "checkout", ":/" + fn)});
		werror("UNKNOWN: %O\n", __ARGS__[0]);
		return ({fn, "Unknown", "", ""});
	} - ({0})));
	win->mainwindow->show_all();
	array val = values(this);
	foreach (annotations(this); int i; mixed ann)
		if (ann) foreach (indices(ann), mixed anno)
			if (arrayp(anno) && sizeof(anno) == 2)
				win[anno[0]]->signal_connect(anno[1], val[i]);
	return -1;
}

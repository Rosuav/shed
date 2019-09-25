//Copy a blueprint string to the clipboard and then use this to see it expanded

//Lower the tech requirements - slower belts, plain inserters
constant lower_tech = ([
	"express-transport-belt": "transport-belt",
	"express-splitter": "splitter",
	"express-underground-belt": "underground-belt",
	"stack-inserter": "inserter",
]);

void replace_entities(mapping info, mapping(string:string) changes)
{
	foreach (info->blueprint->entities, mapping ent)
		ent->name = changes[ent->name] || ent->name;
}

int main()
{
	string data = Process.run(({"xclip", "-o", "-selection", "clipboard"}))->stdout;
	if (data[0] != '0') exit(1, "Unexpected version byte %c\n", data[0]);
	data = MIME.decode_base64(data[1..]);
	data = Gz.uncompress(data);
	mapping info = Standards.JSON.decode_utf8(data);
	write("Got data: %O\n", info);
	//Optionally construct a new blueprint by switching out some entities for others
	replace_entities(info, lower_tech);
	//And now we reverse the process.
	data = Standards.JSON.encode(info);
	data = Gz.compress(data, 0, 9);
	data = "0" + MIME.encode_base64(data, 1);
	//xclip will fork itself into the background, but only if we aren't controlling
	//its stdout. So don't use Process.run() here.
	Stdio.File pipe = Stdio.File();
	object proc = Process.create_process(({"xclip", "-i", "-selection", "clipboard"}),
		(["stdin": pipe->pipe()]));
	pipe->write(data);
	pipe->close();
	proc->wait();
}

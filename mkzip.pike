//Build a zip file out of a series of file names and content
//Requires no external tools.

//TODO: What happens if a file name isn't ASCII? How should it be represented?

//files is an array of ({name, content}) pairs
string(8bit) make_zip(array(array(string(8bit))) files) {
	Stdio.Buffer data = Stdio.Buffer();
	Stdio.Buffer central = Stdio.Buffer();
	//Put the same modification date/time on all files
	mapping tm = localtime(time());
	string ts = sprintf("%-2c%-2c",
		tm->hour << 11 | tm->min << 5 | tm->sec >> 1, //Time
		(tm->year - 80) << 9 | (tm->mon + 1) << 5 | tm->mday, //Date
	);
	foreach (files, [string name, string content]) {
		//Slap in the local file header, followed by the file itself.
		int crc = Gz.crc32(content);
		string|zero compressed = Gz.compress(content, 1, 9, 0, 15);
		if (sizeof(compressed) >= sizeof(content)) compressed = 0; //Stored (0%)
		int pos = sizeof(data);
		data->sprintf("PK\3\4\x14\0\0\0%c\0%s%-4c%-4c%-4c%-2c\0\0%s",
			compressed ? 8 : 0, ts, crc,
			sizeof(compressed || content), sizeof(content), //Compressed and uncompressed size
			sizeof(name), name,
		);
		data->add(compressed || content);
		//Add the entry to the central directory, to be appended.
		central->sprintf("PK\1\2\x1e\3\x14\0\0\0%c\0%s%-4c%-4c%-4c%-2c\0\0\0\0\0\0\0\0\0\0\0\0%-4c%s",
			compressed ? 8 : 0, ts, crc,
			sizeof(compressed || content), sizeof(content), //Compressed and uncompressed size
			sizeof(name), pos, name,
		);
	}
	int sz = sizeof(central), pos = sizeof(data);
	data->add(central);
	//Finally, add the EOCD. It gives the position and size of the central directory,
	//and the rest of the information we aren't using.
	data->sprintf("PK\5\6\0\0\0\0%-2c%<-2c%-4c%-4c\0\0", sizeof(files), sz, pos);
	return (string)data;
}

int main() {
	Stdio.write_file("mkzip.zip", make_zip(({
		({"hello.txt", "Hello, world!\n" * 32}),
		({"goodbye.txt", "Goodbye, world.\n"}), //Small enough that compression isn't worth it, so this should store uncompressed
	})));
	Process.exec("/usr/bin/env", "unzip", "-l", "mkzip.zip");
}

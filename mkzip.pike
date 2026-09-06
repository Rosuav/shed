//Build a zip file out of a series of file names and content
//Requires no external tools.

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
	string xtra = sprintf("%{%s%-2H%}", ({
		({"UT", sprintf("\3%-4c", time())}), //Timestamp
		({"ux", sprintf("\1\4%-4c\4%-4c", getuid(), getgid())}), //Unix ownership
	}));
	foreach (files, [string name, string content]) {
		//Slap in the local file header, followed by the file itself.
		int crc = Gz.crc32(content);
		string|zero compressed = Gz.compress(content, 1, 9, 0, 15);
		if (sizeof(compressed) >= sizeof(content)) compressed = 0; //Stored (0%)
		int pos = sizeof(data);
		//NOTE: This assumes that the files are not going to contain text, and will not set the
		//internal flag "file appears to be text". We also assume a file mode of 0o100644 for
		//all files, which is a safe default but may at some points need to be overridden.
		//TODO: Make sure that this works correctly for non-ASCII names. There's supposed
		//to be support for setting bitflag 11 but I haven't confirmed that this works.
		name = string_to_utf8(name);
		data->sprintf("PK\3\4\x14\0\0\0%c\0%s%-4c%-4c%-4c%-2c%-2c%s%s",
			compressed ? 8 : 0, ts, crc,
			sizeof(compressed || content), sizeof(content), //Compressed and uncompressed size
			sizeof(name), sizeof(xtra), name, xtra,
		);
		data->add(compressed || content);
		//Add the entry to the central directory, to be appended.
		//(A481 is hex for file mode 100644)
		central->sprintf("PK\1\2\x1e\3\x14\0\0\0%c\0%s%-4c%-4c%-4c%-2c%-2c\0\0\0\0\0\0\0\0\xa4\x81%-4c%s%s",
			compressed ? 8 : 0, ts, crc,
			sizeof(compressed || content), sizeof(content), //Compressed and uncompressed size
			sizeof(name), sizeof(xtra), pos, name, xtra,
		);
	}
	int sz = sizeof(central), pos = sizeof(data);
	data->add(central);
	//Finally, add the EOCD. It gives the position and size of the central directory,
	//and the rest of the information we aren't using.
	data->sprintf("PK\5\6\0\0\0\0%-2c%<-2c%-4c%-4c\0\0", sizeof(files), sz, pos);
	return (string)data;
}

void read_zip(string zipfn, string|void data) {
	if (!data) data = Stdio.read_file(zipfn);
	//Note that the EOCD includes the zip file comment and so is of variable length.
	//For now, we assume that the last instance of "PK\5\6" is the EOCD; is it possible
	//to have a comment that happens to include that signature?
	if (!has_value(data, "PK\5\6")) return; //Not a zip file.
	string eocd = (data / "PK\5\6")[-1];
	sscanf(eocd, "%-2c%-2c%-2c%-2c%-4c%-4c%-2H%s", int disk, int cddisk, int diskent, int entries, int cdsize, int cdoffset, string comment, string residue);
	if (residue != "") {werror("Unexpected trailing data on ZIP file %O\n", residue); return;}
	write("%s: %O\n", zipfn, comment);
	if (disk || cddisk || diskent != entries) {werror("Multi-volume archives not supported"); return;}
	Stdio.Buffer cd = Stdio.Buffer(data[cdoffset..cdoffset+cdsize-1]);
	//Note that the central directory can be empty (if the archive contains no files).
	while (array parse = cd->sscanf("PK\1\2%-2c%-2c%-2c%-2c%-2c%-2c%-4c%-4c%-4c%-2c%-2c%-2c%-2c%-2c%-4c%-4c")) {
		[int ver, int minver, int flags, int compr,
		int time, int date, int crc, int compsz, int decompsz,
		int fnlen, int xtralen, int commlen, int disk,
		int intattr, int extattr, int offset] = parse;
		string fn = cd->read(fnlen);
		string xtra = cd->read(xtralen);
		string comm = cd->read(commlen);
		write("\t%s flg %x/%x\n", fn, intattr, extattr);
		while (sscanf(xtra, "%2c%-2H%s", int ident, string body, xtra)) switch (ident) {
			//case 'UT': break; //Extended timestamp - one byte for which time(s) are included, then four bytes per time_t
			case 'ux': //Unix info
				//Assuming for now that the uid/gid are stored as four byte integers
				//(they're length preceded).
				sscanf(body, "%c\4%-4c\4%-4c", int ver, int uid, int gid);
				write("\t\tXTRA uid %d gid %d\n", uid, gid);
				break;
			default:
				write("\t\tXTRA '%2c' %O\n", ident, body);
		}
	}
	//(string)cd should now be empty (unless the zip64 info is included in the EOCD's size of CD)
}

int main() {
	read_zip("/tmp/mkzip/empty.zip");
	read_zip("/tmp/mkzip/madezip.zip");
	string zip = make_zip(({
		({"hello.txt", "Hello, world!\n" * 32}),
		({"goodbye.txt", "Goodbye, world.\n"}), //Small enough that compression isn't worth it, so this should store uncompressed
	}));
	read_zip("synthesized", zip);
	Stdio.write_file("mkzip.zip", zip); Process.exec("/usr/bin/env", "unzip", "-l", "mkzip.zip");
}

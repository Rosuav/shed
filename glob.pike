//Expand globs and execute a command
//Is there a standard command to do this???
//Not smart enough to handle escaped special characters.
//Also not smart enough to cope with file names that themselves contain special
//chars, so they'll be re-globbed. This can only cause false positives with *
//and ?, but with [], it might result in misrecognition.

array(string) globexpand(string path,array(string) parts)
{
	array(string) dir=glob(parts[0],get_dir(path));
	if (!sizeof(dir)) dir=({parts[0]}); //If nothing, expand to self. (Handles a leading slash, too.)
	dir=combine_path(path||"",dir[*]);
	if (sizeof(parts)==1) return dir; //Last part! Return what we have.
	return globexpand(dir[*],parts[1..])*({ });
}

int main(int argc,array(string) argv)
{
	array(string|array(string)) args=argv[1..];
	foreach (args;int i;string arg) if (has_value(arg,'?') || has_value(arg,'*') || has_value(arg,'['))
		args[i]=globexpand(0,explode_path(arg));
	Process.exec(@Array.flatten(args));
}

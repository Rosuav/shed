//Rename a number of files in order of their dates

int main(int argc,array(string) argv)
{
	if (argc<2) exit(1,"USAGE: %s list_of_files\n");
	array(string) files=argv[1..];
	sscanf(files[0],"--%s",string key);
	if (key) files=files[1..]; else key="ctime";
	int len=sizeof((string)sizeof(files));
	sort(file_stat(files[*])[*][key],files);
	for (int i=0;i<sizeof(files);++i) mv(files[i],sprintf("%0"+len+"d - %s",i,files[i]));
}


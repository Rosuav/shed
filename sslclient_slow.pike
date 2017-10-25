object ssl;
void readcb(mixed id, string data) {exit(0, "Readable\n%s\n", data);}
int x=1; void writecb() {if (x) ssl->write("asdf\n"); x=0; write("Writable\n");}

int main()
{
	Stdio.File sock = Stdio.File();
	sock->connect("127.0.0.1", 2211);
	ssl = SSL.File(sock, SSL.Context());
	ssl->set_nonblocking(readcb, writecb, lambda() {exit(0, "Closed\n");});
	ssl->connect("localhost");
	write("Connected\n");
	return -1;
}

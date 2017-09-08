//Experimental SSL/non-SSL negotiating server
//In theory, this should be equally able to accept cleartext or encrypted
//connections on the same port; in practice, there's a small delay on the
//cleartext ones (to see if they're starting SSL negotiation), and a larger
//delay on encrypted (to actually do the negotiation).

//The server design has been heavily cribbed from Minstrel Hall, as this
//was originally a POC for supporting this exact model there. However, that
//plan is not currently on the books, and this code is specific to Pike 8,
//due to a significant reworking of the SSL and X509 subsystems since 7.8
//(which Minstrel Hall still runs on, as at 20160518).

//Modified version of sslserver.pike to use nonblocking I/O.
Stdio.Port mainsock;
array(object) clients = ({ });
object ctx = SSL.Context();

class client(object sock)
{
	void create()
	{
		write("Got connection %O\n", sock);
		clients += ({this});
		sock->set_buffer_mode(Stdio.Buffer(), Stdio.Buffer());
		sock->set_nonblocking(read_callback, write_callback, close_callback);
	}

	void write_callback(mixed ... args) {write("write: %O\n", args);}
	void close_callback(mixed ... args) {write("close: %O\n", args);}
	void accept_callback(mixed ... args) {write("accept: %O\n", args);}
	void read_ssl_callback(mixed ... args) {write("read_ssl: %O\n", args);}

	void read_callback(mixed id, Stdio.Buffer buf)
	{
		write("read_callback\n");
		if (buf->sscanf("\x16\x03")) //Is this the best way to peek for a couple of bytes?
		{
			//Probable SSL handshake
			sock = SSL.File(sock, ctx);
			sock->set_buffer_mode(Stdio.Buffer(), Stdio.Buffer());
			sock->set_accept_callback(accept_callback);
			sock->set_read_callback(read_ssl_callback);
			write("accept: %O\n", sock->accept("\x16\x03" + buf->read()));
			write("SSL connection established [errno %O]\n", sock->errno());
			write("sock: %O\n", sock);
			write("buf: %O\n", (string)buf);
			call_out(debug, 2, buf);
			return;
		}
		string line = buf->match("%s%*[\r]\n");
		write("Line: %O\n", line);
		sock->write(sprintf("Command: %O\n", line));
	}
	void debug(object buf)
	{
		write("Debug state: %O %O %O\n", sock, (array(string))sock->query_buffer_mode(), (string)buf);
	}
}

void accept()
{
	while (Stdio.File sock = mainsock->accept())
	{
		write("Connection established: %O\n", sock);
		client(sock);
	}
}

int main()
{
	mainsock = Stdio.Port(2211, accept, "::");
	object key = Crypto.RSA()->generate_key(4096);
	ctx->add_cert(key, ({Standards.X509.make_selfsigned_certificate(key,
		3600*24*365, ([
			"organizationName" : "Demo SSL server",
			"commonName" : "*",
		])
	)}));
	werror("Ready and listening: "+ctime(time())); //May be slightly different from the mudbooted record
	return -1;
}

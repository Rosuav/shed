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
array(object) clients = ({ });

class SSLFile
{
	inherit SSL.File;
	int is_nonblocking() {return nonblocking_mode;}
}

object ctx = SSL.Context();

class client
{
	object sock;
	void handle_client(Stdio.File sock1)
	{
		sock = sock1;
		write("Got connection %O\n", sock);
		if (sock->peek(0.05) == 1)
		{
			string handshake = sock->read(9, 1);
			if (sizeof(handshake) >= 2 && handshake[0] == 0x16 && handshake[1] == 0x03)
			{
				//Probable SSL handshake
				Pike.SmallBackend backend = Pike.SmallBackend();
				sock->set_backend(backend);
				sock = SSLFile(sock, ctx);
				sock->accept(handshake);
				backend->call_out(sock->set_blocking, 0.0001);
				while (sock->is_nonblocking())
					backend(1.0);
				write("SSL connection established.\n");
			}
		}
		object readbuf = Stdio.Buffer();
		sock->set_buffer_mode(readbuf);
		sock->write("Hello!\n");
		out: while (1)
		{
			while (string cmd = readbuf->match("%s%*[\r]\n"))
			{
				if (cmd == "quit") break out;
				write("cmd: %O\n", cmd);
				sock->write("Sure, whatever.\n");
			}
			readbuf->add(sock->read(1024, 1));
		}
		sock->write("Bye!\n");
		write("Dropping connection %O\n", sock);
		sock->close();
	}
}

void handler(Stdio.File sock)
{
	object obj=client();
	clients+=({obj});
	mixed ex=catch {obj->handle_client(sock);};
	if (ex)
	{
		werror("Exception unhandled! %O\n",ex);
		if (get_backtrace(ex)) werror(describe_backtrace(get_backtrace(ex))+"\n");
	}
	clients-=({obj});
}

int main()
{
	Stdio.Port mainsock=Stdio.Port();
	if (!mainsock->bind(2211)) werror("Error binding: "+mainsock->errno()+"\n");
	object key = Crypto.RSA()->generate_key(4096);
	ctx->add_cert(key, ({Standards.X509.make_selfsigned_certificate(key,
		3600*24*365, ([
			"organizationName" : "Demo SSL server",
			"commonName" : "*",
		])
	)}));
	werror("Ready and listening: "+ctime(time())); //May be slightly different from the mudbooted record
	while (1)
	{
		Stdio.File sock=mainsock->accept();
		if (!sock) break;
		thread_create(handler,sock);
		//client()->handle_client(sock);
	}
}

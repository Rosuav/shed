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

class SSLFile
{
	inherit SSL.File;
	int(1bit) accept(string pending_data)
	{
	    conn = SSL.ServerConnection(context);
	    ssl_read_callback(0, pending_data);
	    stream->set_read_callback(ssl_read_callback);
	    stream->set_close_callback(ssl_close_callback);
	    return 1;
	}
}

class client(object sock)
{
	void create()
	{
		write("Got connection %O\n", sock);
		clients += ({this});
		sock->set_buffer_mode(Stdio.Buffer(), Stdio.Buffer());
		sock->set_nonblocking(read_callback, write_callback, close_callback);
	}

	void write_callback(mixed ... args) {/*write("writecb: %O\n", args);*/}
	void close_callback(mixed ... args) {write("closecb: %O\n", args);}
	void accept_callback(mixed ... args) {write("acceptcb: %O\n", args);}
	void read_ssl_callback(mixed ... args) {write("read_sslcb: %O\n", args);}

	void read_callback(mixed id, Stdio.Buffer buf)
	{
		write("read_callback %d\n", sizeof((string)buf));
		if (buf->sscanf("\x16\x03")) //Is this the best way to peek for a couple of bytes?
		{
			//Probable SSL handshake
			sock->set_buffer_mode(0, 0);
			sock = SSLFile(sock, ctx);
			sock->set_buffer_mode(Stdio.Buffer(), Stdio.Buffer());
			sock->set_accept_callback(accept_callback);
			sock->set_read_callback(read_callback);
			write("accept: %O\n", sock->accept("\x16\x03" + buf->read()));
			write("SSL connection established [errno %O]\n", sock->errno());
			write("sock: %O\n", sock);
			write("buf: %O\n", (string)buf);
			call_out(debug, 2, buf);
			return;
		}
		string line = buf->match("%[^\r\n]%*[\r]\n");
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
	object key = Crypto.RSA()->generate_key(4096);
	ctx->add_cert(key, ({Standards.X509.make_selfsigned_certificate(key,
		3600*24*365, ([
			"organizationName" : "Demo SSL server",
			"commonName" : "*",
		])
	)}));
	mainsock = Stdio.Port(2211, accept, "::");
	//mainsock = PORT(ctx, 2211, accept);
	werror("Ready and listening: "+ctime(time())); //May be slightly different from the mudbooted record
	return -1;
}


class PORT
{
	Stdio.Port socket;
	SSL.Context ctx;
	protected ADT.Queue accept_queue = ADT.Queue();
	function(object, mixed|void:void) accept_callback;

	void finished_callback(object f, mixed|void id)
	{
	  write("finished_callback\n");
	  accept_queue->put(f);
	  while (accept_callback && sizeof(accept_queue))
	  {
	    accept_callback(f, id);
	  }
	}

	string readbuf = "";
	object sendto;
	void low_read(mixed id, string|object data)
	{
		if (objectp(data)) data = data->read();
		write("low_read: %O\n", data);
		if (sendto) sendto->ssl_read_callback(id, data);
		else readbuf += data;
	}
	void low_write(mixed id)
	{
		write("low_write\n");
	}

	void ssl_callback(mixed id)
	{
		object f = socket->accept();
		f->set_buffer_mode(Stdio.Buffer(), Stdio.Buffer());
		f->set_nonblocking(low_read, low_write);
		write("Got socket: %O\n", f);
		if (f) call_out(lambda()
		{
			write("NOW we'll accept that\n");
			object ssl_fd = SSLFile(f, ctx);
			ssl_fd->set_nonblocking(low_read, low_write);
			f->set_buffer_mode(0, 0);
			write("accept: %O\n", ssl_fd->accept(readbuf));
			//sendto = ssl_fd;
			//f->set_read_callback(low_read);
			ssl_fd->set_accept_callback(finished_callback);
		}, 1.0);
	}

	object accept()
	{
	  return accept_queue->get();
	}

	protected void create(SSL.Context ctx, int port, function cb)
	{
	  if (ctx)
	    this::ctx = ctx;
	  accept_callback = cb;
	  socket = Stdio.Port(port, ssl_callback);
	}

}

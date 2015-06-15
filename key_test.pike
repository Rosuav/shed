//Test generating keys, and signing and verifying messages

int main()
{
	//Generate a new keypair for the test, so we're not ever revealing anything dangerous
	Process.create_process(({"ssh-keygen","-q","-N","","-f","temp_key"}))->wait();
	sscanf(Stdio.read_file("temp_key"),"%*s-----BEGIN RSA PRIVATE KEY-----%s-----END RSA PRIVATE KEY-----",string key);
	object priv=Standards.PKCS.RSA.parse_private_key(MIME.decode_base64(key));
	//The public key is somewhat adorned. We need it... differently adorned. This is the
	//bit that I understand the least.
	string text_pub=MIME.decode_base64((Stdio.read_file("temp_key.pub")/" ")[1]);
	string generated_pub=Standards.PKCS.RSA.public_key(priv);
	//write("Text key: %O\n\nGenerated key: %O\n\n",text_pub,generated_pub);
	rm("temp_key"); rm("temp_key.pub");
	object pub=Standards.PKCS.RSA.parse_public_key("0\202\1\n\2\202"+text_pub[20..]+"\2\3\1\0\1");
	//Okay. Whatever. We should now have a private key, capable of creating signatures, and a
	//public key, capable of verifying them. And the decoder object required nothing but the
	//test_key.pub one-liner, albeit with some strange rewrapping done.
	string msg="Hello, world! - "*16;
	string sig=priv->pkcs_sign(msg,Crypto.SHA256);
	if (!priv->pkcs_verify(msg,Crypto.SHA256,sig)) exit(1,"FAIL: Can't decode even with the original key!\n");
	//This saturates one CPU core for a while - on my system, about two seconds (roughly 5K decodes per second).
	constant tries=10000;
	float tm=gauge {for (int i=0;i<tries;++i) if (!pub->pkcs_verify(msg,Crypto.SHA256,sig)) exit(1,"FAIL: Unable to decode with public key\n");};
	write("Test successful: %f verifications/second.\n",tries/tm);
}

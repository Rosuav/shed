#!/usr/bin/env pike
//Run a program, teeing stdout to ./stdout and stderr to ./stderr
//May also be worth colorizing stderr for visibility?

int main(int argc,array(string) argv)
{
	Stdio.File out = Stdio.File("./stdout","wct"), err = Stdio.File("./stderr","wct");
	//Begin code cribbed from Process.run() - this could actually *use* Process.run() if stdout/stderr functions were supported
	Stdio.File mystdout = Stdio.File(), mystderr = Stdio.File();
	object p=Process.create_process(argv[1..],(["stdout":mystdout->pipe(),"stderr":mystderr->pipe()]));
	Pike.SmallBackend backend = Pike.SmallBackend();
	mystdout->set_backend(backend);
	mystdout->set_read_callback(lambda( mixed i, string data) {write(data); out->write(data);});
	mystdout->set_close_callback(lambda () {mystdout = 0;});
	mystderr->set_backend(backend);
	mystderr->set_read_callback(lambda( mixed i, string data) {werror(data); err->write(data);});
	mystderr->set_close_callback(lambda () {mystderr = 0;});
	while (mystdout || mystderr) backend(1.0);
	int ret=p->wait();
	//End code from Process.run()
	if (ret>=0) return ret;
}

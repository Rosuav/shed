mapping(string:object) w=([]);
object orig=Image.PNG.decode(Stdio.read_file("postcard.png"));
object scaled=orig->scale(0.5);

int x,y;
void sig_win_destroy()
{
	Stdio.write_file("postcard_cropped.png",Image.PNG.encode(orig->copy(0,0,x,y)));
	exit(0);
}

void sig_evbox_motion_notify_event(object self,object ev)
{
	x=2*(int)ev->x,y=2*(int)ev->y;
	write("%d,%d   \r",x,y);
	object lines=scaled->copy();
	lines->line(x/2,0,x/2,lines->ysize());
	lines->line(0,y/2,lines->xsize(),y/2);
	w->img->set_from_image(GTK2.GdkImage(0,lines));
}

int main()
{
	GTK2.setup_gtk();
	w->win=GTK2.Window(0)->set_title("Image crop")
		->add(w->evbox=GTK2.EventBox()->add(w->img=GTK2.Image()))
		->show_all();
	w->img->set_from_image(GTK2.GdkImage(0,scaled));
	foreach (indices(this),string key)
		if (sscanf(key,"sig_%s_%s",string obj,string sig) && sig && callablep(this[key]) && w[obj])
			w[obj]->signal_connect(sig,this[key]);
	w->evbox->add_events(GTK2.GDK_POINTER_MOTION_MASK);
	return -1;
}

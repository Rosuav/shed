//Mark out an area on your screen
//Link with OBS to crop a desktop capture

object mainwindow;

void resize(object win, object ev) {
	mapping pos = win->get_position(), sz = win->get_size();
	write("Resize %d,%d :: %d,%d\n", pos->x, pos->y, sz->width, sz->height);
}

int main() {
	GTK2.setup_gtk();
	mainwindow = GTK2.Window((["title": "Cropper"]))->add(GTK2.Label("Cropper"));
	mainwindow->set_default_size(400, 300); //TODO: Remember from last run
	mainwindow->set_keep_above(1);
	mainwindow->signal_connect("destroy", lambda() {exit(0);});
	mainwindow->signal_connect("configure-event", resize, 0, "", 1);
	mainwindow->show_all();
	call_out(lambda() {
		//For some reason, doing this immediately also hides the frame
		mainwindow->shape_combine_mask(GTK2.GdkBitmap(Image.Image(1, 1, 0, 0, 0)), 0, 0);
	}, 0.125);
	return -1;
}

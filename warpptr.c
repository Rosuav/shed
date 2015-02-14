/* Compile with: gcc warpptr.c -lX11 -o warpptr */
/* Moves the mouse pointer - eg: ./warpptr 200 300 */
#include <stdlib.h>
#include <X11/Xlib.h>

void warp_pointer(int x,int y)
{
	Display *dpy = XOpenDisplay(0);
	XWarpPointer(dpy, None, XRootWindow(dpy, 0), 0, 0, 0, 0, x, y);
	XFlush(dpy);
}

int main(int argc,char **argv)
{
	if (argc<3) return 1;
	warp_pointer(atoi(argv[1]),atoi(argv[2]));
	return 0;
}

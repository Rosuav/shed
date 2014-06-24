array colors=values(Image.Color); //Snapshot the arbitrary order so it's consistent within a given run
int r=0,g=255,b=255;

int calcpixel(float x,float y,int iter)
{
	float cx=x,cy=y; //For a Mandelbrot set, the mutation point is the point itself. For a Julia set, it's a fixed vector.
	for (int i=0;i<iter;++i)
	{
		[x,y]=({x*x-y*y + cx,2*x*y + cy});
		if (x*x+y*y > 4) return i;
	}
	return -1; //Inside the set
}

constant quickiter=30,longiter=30;
Image.Image genfractal(float x1,float x2,float y1,float y2,int xres,int yres)
{
	Image.Image img=Image.Image(xres,yres);
	array(array(int)) rows=allocate(yres);
	int total,long,xextra,yextra;
	for (int ypos=0;ypos<yres;++ypos)
	{
		array(int) currow=allocate(xres,-1);
		rows[ypos]=currow;
		array(int) lastrow=ypos && rows[ypos-1];
		for (int xpos=0;xpos<xres;++xpos)
		{
			float x=(x2-x1)*xpos/xres+x1, y=(y2-y1)*ypos/yres+y1;
			int iter=quickiter; ++total;
			if (!lastrow || lastrow[xpos]<0 || !xpos || currow[xpos-1]<0) {++long; iter=longiter;}
			int i=calcpixel(x,y,iter);
			if (i>=0)
			{
				//img->setpixel(xpos,ypos,colors[i]);
				img->setpixel(xpos,ypos,r*i/longiter,g*i/longiter,b*i/longiter);
				for (int xp=xpos-1;xp>=0 && currow[xp]==quickiter;--xp)
				{
					//If this pixel is outside the set and the last one was deemed inside by
					//a quick check, do a long check.
					++total; ++long; ++xextra;
					i=calcpixel((x2-x1)*xp/xres+x1,y,longiter);
					if (i!=-1)
					{
						img->setpixel(xp,ypos,r*i/longiter,g*i/longiter,b*i/longiter);
						currow[xpos-1]=longiter;
					}
					else break;
				}
				for (int yp=ypos-1;yp>=0 && rows[yp][xpos]==quickiter;--yp)
				{
					//As above, vertically.
					++total; ++long; ++yextra;
					i=calcpixel(x,(y2-y1)*yp/yres+y1,longiter);
					if (i!=-1)
					{
						img->setpixel(xpos,yp,r*i/longiter,g*i/longiter,b*i/longiter);
					}
				}
			}
			else currow[xpos]=iter;
		}
	}
	write("Long calcs: %d/%d (%d horiz, %d vert) -> %f\n",long,total,xextra,yextra,(float)long/total);
	return img;
}

object gimg;
void zoom(float x1,float x2,float y1,float y2,int xres,int yres)
{
	float xc=(x2+x1)/2,yc=(y2+y1)/2; //Center is the average
	float xs=(x2-x1)/2,ys=(y2-y1)/2; //Size is half the diff
	while (1)
	{
		Image.Image img;
		write("Generated at size %f,%f in %fs\n",xs,ys,gauge {img=genfractal(xc-xs,xc+xs,yc-ys,yc+ys,xres,yres);});
		gimg->set_from_image(GTK2.GdkImage(0,img));
		xs*=0.95; ys*=0.95;
	}
}

int main()
{
	float x1=-2.25,x2=0.75,y1=-1.0,y2=1.0;
	int xres=1920,yres=990;
	//Image.Image img;
	//write("Time to generate: %O\n",gauge {img=genfractal(x1,x2,y1,y2,xres,yres);});
	//Stdio.write_file("mandelbrot.png",Image.PNG.encode(img));
	GTK2.setup_gtk();
	GTK2.Window(0)->set_title("Mandelbrot")->add(gimg=GTK2.Image(GTK2.GdkImage(0,Image.Image(xres,yres))))->show_all()->signal_connect("destroy",lambda() {exit(0);});
	Thread.Thread(zoom,x1,x2,y1,y2,xres,yres);
	return -1;
}

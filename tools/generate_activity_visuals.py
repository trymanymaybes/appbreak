"""Generate original decorative activity GIFs and reduced-motion stills (Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
out=Path(__file__).resolve().parents[1]/'assets/activity_visuals'
out.mkdir(exist_ok=True)
for name in ['calm','movement','water','ideas']:
    frames=[]
    for frame in range(32):
        t=frame/32*2*math.pi
        im=Image.new('RGB',(360,180),'#101714');d=ImageDraw.Draw(im)
        green='#91d5b6'; pale='#d7eee3'; blue='#83c7eb'
        if name=='calm':
            for row in range(3):
                pts=[(x,95+row*18+12*math.sin(x/55+t+row)) for x in range(20,341,3)]
                d.line(pts,fill=[green,blue,pale][row],width=3)
            d.ellipse((157,25,203,71),fill=pale)
        elif name=='movement':
            y=83+5*math.sin(t)
            d.ellipse((162,22,198,58),outline=pale,width=4)
            d.line([(180,62),(180,122),(149,155)],fill=green,width=5)
            d.line([(180,122),(211,155)],fill=green,width=5)
            d.line([(128,y+13),(155,y),(180,76),(205,y),(232,y+13)],fill=pale,width=5)
        elif name=='water':
            d.polygon([(139,42),(221,42),(211,151),(149,151)],outline=pale,width=4)
            y=91+4*math.sin(t)
            d.polygon([(145,y),(215,y),(209,145),(151,145)],fill=blue)
            for x in [166,191]:
                cy=125-((frame*2+x)%32);d.ellipse((x-3,cy-3,x+3,cy+3),outline=pale,width=1)
        else:
            d.rounded_rectangle((132,50,228,132),radius=18,outline=green,width=4)
            for i in range(5):
                a=t/8+i*math.tau/5;x=180+72*math.cos(a);y=90+60*math.sin(a)
                r=3+2*(1+math.sin(t+i))/2
                d.ellipse((x-r,y-r,x+r,y+r),fill=pale)
            d.line([(157,77),(203,77)],fill=pale,width=3)
            d.line([(157,94),(192,94)],fill=blue,width=3)
            d.line([(157,111),(198,111)],fill=pale,width=3)
        frames.append(im)
    frames[0].save(out/f'{name}.png')
    frames[0].save(out/f'{name}.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,optimize=True)

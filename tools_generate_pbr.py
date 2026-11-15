"""Generate the game's original deterministic PBR-ish floor/wall textures.
No external downloads. These textures are authored procedurally specifically for this project.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT=Path(__file__).parent/'assets'/'textures'
ROOT.mkdir(exist_ok=True,parents=True)
N=768
rng=np.random.default_rng(1428)
y,x=np.mgrid[:N,:N]

def save(name, rgb):
    a=np.asarray(np.clip(rgb,0,255),np.uint8)
    Image.fromarray(a,'RGB').save(ROOT/f'{name}.png',optimize=True)
    print(name,a.shape)

# Wood grain: narrow boards and many small natural grain lines; tileable at left/right.
noise=rng.normal(0,1,(N,N))
board=np.floor(x/(N/5)).astype(int)
cols=np.array([[121,88,62],[107,76,55],[132,98,69],[118,82,59],[130,94,63]],float)
wood=cols[np.minimum(board,4)].copy()
wood += (np.sin(y*0.24 + np.sin(y*0.013)*3 + board*4.5)*4 + np.sin(y*0.063+board*8)*6)[...,None]
wood += noise[...,None]*3
seams=(x%(N/5)<3)
wood[seams]*=.38
# fine wood varnish and tiny scratch marks
save('floor_library',wood)

# Worn gray-warm limestone / ceramic lobby tiles.
cols=np.array([163,153,139],float)
stone=np.zeros((N,N,3),float)+cols
stone += rng.normal(0,7,(N,N,1))
for period in (192,384):
    d=((x%period)<3)|((y%period)<3)
    stone[d]*=.66 if period==192 else .85
stone += 2*np.sin(x/24 + y/40)[...,None]
save('floor_stone',stone)

# Scientific linoleum: fine almost-square panels, wear around seams.
lab=np.zeros((N,N,3),float)+[127,133,129]
lab+=rng.normal(0,4,(N,N,1))
for c in (x,y):
    edges=(c%128<3)
    lab[edges]*=.64
lab+=((np.sin(x*.08)+np.sin(y*.07))*2)[...,None]
save('floor_lab',lab)

# Archive heavy rubber / worn concrete with dust and worn seams.
archive=np.zeros((N,N,3),float)+[117,109,100]
archive+=rng.normal(0,9,(N,N,1))
for c in (x,y):
    d=(c%256<3)
    archive[d]*=.60
archive+=np.sin(x*.035+y*.047)[...,None]*2
save('floor_archive',archive)

# plaster; texturing needed on large wall planes and patchy floors.
wall=np.zeros((N,N,3),float)+[143,139,129]
wall+=rng.normal(0,4.5,(N,N,1))
wall+=((np.sin(x*.012+y*.005)+np.sin(y*.022-x*.009))*2.2)[...,None]
save('plaster_neutral',wall)

# walnut grain usable on shelves and table surfaces
w=np.zeros((N,N,3),float)+[84,65,49]
w+=(np.sin(y*.10+np.sin(x*.025)*4)*5 + np.sin(y*.34)*1.8 +rng.normal(0,2,(N,N)))[...,None]
save('walnut_furniture',w)

# normal maps inferred from grayscale tiny structure; reduces plastic effect.
for key in ('floor_library','floor_stone','floor_lab','floor_archive','plaster_neutral','walnut_furniture'):
    a=np.asarray(Image.open(ROOT/f'{key}.png').convert('L'),dtype=np.float32)/255
    dy,dx=np.gradient(a)
    scale=2.0 if key in ('floor_library','plaster_neutral') else 1.3
    nx=-dx*scale; ny=-dy*scale; nz=np.ones_like(nx)
    norm=np.sqrt(nx*nx+ny*ny+nz*nz)
    rgb=np.stack([(nx/norm+.5)*127.5,(ny/norm+.5)*127.5,(nz/norm+.5)*127.5],axis=2)
    save(key+'_normal',rgb)

"""Build P02's native 1 px/wu canal cutaway, using the room's twelve structural solids."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ROOM = ROOT / "production/rooms/world/P02.json"
OUT = ROOT / "production/assets/scenery/p02"
sheet = Image.open(HERE / "bank-walls.webp").convert("RGB")
size = (1648,768)
doc = json.loads(ROOM.read_text())
solids = {k:tuple(e["properties"]["rect"]) for k,e in doc["entities"].items() if e["definition_id"]=="platform.solid"}

def cut(bounds,width,height):
    return sheet.crop(bounds).resize((width,height),Image.Resampling.LANCZOS).convert("RGBA")

def masked(canvas, piece, area):
    area = area.crop((0,0,*size))
    piece.putalpha(ImageChops.multiply(piece.getchannel("A"),area))
    canvas.alpha_composite(piece)

def contour(points):
    img = Image.new("L",size)
    ImageDraw.Draw(img).polygon(points,fill=255)
    return img

def stamp(canvas,part,x,y):
    canvas.alpha_composite(part,(x,y))

def beam(canvas,a,b,width):
    ax,ay=a;bx,by=b
    dx,dy=bx-ax,by-ay
    span=(dx*dx+dy*dy)**.5
    timber=cut((168,81,647,120),round(span)+2,width)
    angle=-np.degrees(np.arctan2(dy,dx))
    timber=timber.rotate(angle,Image.Resampling.BICUBIC,expand=True)
    stamp(canvas,timber,round((ax+bx-timber.width)/2),round((ay+by-timber.height)/2))

def save_piece(key,img):
    box=img.getchannel("A").getbbox()
    piece=img.crop(box)
    rgb=piece.convert("RGB").quantize(colors=112,dither=Image.Dither.NONE).convert("RGBA")
    rgb.putalpha(piece.getchannel("A"))
    rgb.save(OUT/(key+".png"),optimize=True)
    return {"asset":key,"at":[(box[0]+box[2])/2,box[3]],"layer":"attached"}

def underbanks():
    west=Image.new("RGBA",size)
    westwall=Image.new("RGBA",size)
    root_plate=cut((0,3,2172,358),682,131)
    # The western bearing projects in front of the lamp. Set its painted wick just
    # inside the open arch; the seam in the buried left margin stays inside soil.
    stamp(westwall,root_plate,70,442)
    stamp(westwall,root_plate,88,442)
    tint=np.array(westwall).astype(float)
    gy,gx=np.indices((size[1],size[0]))
    lamp=np.exp(-((gx-180)/19.)**2-((gy-520)/16.)**2)[...,None]
    tint[:,:,:3]=tint[:,:,:3]*.82+lamp*np.array([15,7,2])
    westwall=Image.fromarray(np.clip(tint,0,255).astype(np.uint8))
    # Daylight opens into the retry basin at the tip of the return stairs.
    cap=contour([(65,431),(362,436),(409,452),(439,461),(449,474),(465,482),
                 (472,487),(479,502),(492,507),(508,523),(523,538),(538,550),
                 (549,552),(558,565),(566,573),(65,573)])
    masked(west,westwall,cap)
    # The lintel passes into the earthen shoulder. Its joints sit directly under
    # the lower stair and transfer load into a stone shoe on the real basin floor.
    beam(west,(459,567),(486,517),11)
    beam(west,(418,518),(509,518),9)
    beam(west,(431,517),(431,567),11)
    for x,w in [(424,16),(453,17)]:
        stamp(west,cut((125,580,229,619),w,7),x,566)
    east=Image.new("RGBA",size)
    eastwall=Image.new("RGBA",size)
    stamp(eastwall,cut((0,372,2172,714),777,183),742,459)
    # The west end of this gallery keys into the entire underside of the
    # cantilever. A real corbel inclines from its projecting nose into the quay.
    cap=contour([(771,459),(999,459),(1000,470),(987,474),(979,480),
                 (968,482),(962,488),(953,495),(950,503),(954,525),(979,544),
                 (997,553),(1015,564),(1044,573),(1061,563),(1085,541),(1115,506),
                 (1130,486),(1155,475),(1460,469),(1460,643),(771,643)])
    cool=np.array(eastwall).astype(float)
    cool[:,:,:3]*=np.array([.76,.82,.88])
    # Water from the open channel throws a narrow cool reflection into the left
    # jamb and across the last stone courses. Preserve the darker mortar joints.
    distance_x=(gx-1312)/109.
    floor_light=np.exp(-distance_x**4-((gy-637)/8.)**2)
    jamb_light=np.exp(-((gx-1211)/13.)**2-((gy-589)/37.)**2)
    stone_response=np.clip(cool[:,:,:3].mean(axis=2)/60.,.18,1)
    cool[:,:,:3]+=((floor_light+.65*jamb_light)*(.47+.53*stone_response))[...,None]*np.array([12,27,37])
    masked(east,Image.fromarray(cool.astype(np.uint8)),cap)
    # Worn corbel stones connect the playable overhang to the retaining wall.
    # All their feet sit in masonry; no plank marks an extra landing in the gap.
    brace=Image.new("RGBA",size)
    block=cut((295,422,1015,648),163,63)
    stamp(brace,block,850,461)
    bracket=contour([(850,461),(1001,461),(1001,468),(989,474),(976,475),
                     (976,481),(962,486),(954,494),(942,494),(939,501),
                     (928,505),(918,505),(912,513),(900,519),(867,524),(850,524)])
    masked(east,brace,bracket)
    # A staggered pair of masonry piers carries the cold gallery stair.
    for x,w,h in [(1069,27,69),(1166,31,70)]:
        stamp(east,cut((1947,411,2071,706),w,h),x,640-h)
        stamp(east,cut((115,589,282,625),w+8,8),x-4,632)
    beam(east,(1059,579),(1197,579),8)
    return save_piece("p02_root_gallery",west),save_piece("p02_sluice_gallery",east)

def soil_face():
    coords=np.indices((size[1],size[0]))
    yy,xx=coords
    field=np.zeros((size[1],size[0],4),dtype=np.uint8)
    soil=cut((693,0,1683,348),516,174).convert("RGB")
    stone=cut((267,389,1176,703),456,152).convert("RGB")
    dry=np.array(soil); masonry=np.array(stone)
    # Place individual terrace materials in one room-coordinate field. There is no
    # world-grid atlas repetition across the middle pier or either exposed return.
    alpha=np.zeros(yy.shape,dtype=bool)
    for key,(x,y,w,h) in solids.items():
        alpha[y:y+h,x:x+w]=True
    for side,ids,soil_y in [
        (0,["west_pier","west_field","west_upper_return","west_lower_return","retry_basin_floor"],384),
        (1,["bell_terrace_pier","bell_terrace_cap","drain_bed"],408),
        (2,["east_road_pier","east_road_cap","drain_upper_return","drain_lower_return"],430),
    ]:
        for key in ids:
            x,y,w,h=solids[key]
            X=xx[y:y+h,x:x+w];Y=yy[y:y+h,x:x+w]
            sx=(X+side*137+(Y-soil_y)//12)%dry.shape[1]
            sy=((Y-soil_y)*.80).astype(int)
            if key in ["retry_basin_floor","drain_bed"]:
                sy=((Y-y)*1.22+32).astype(int)
                sx=(X+152+(Y-y)//8)%dry.shape[1]
            # Fold the native stratification at depth; never stretch one texel over
            # dozens of world pixels at the lower edge of a texture.
            band=sy//dry.shape[0]
            sy=np.where(band%2==0,sy%dry.shape[0],dry.shape[0]-1-sy%dry.shape[0])
            base=dry[sy,sx].astype(float)
            # Exposed earth is warm and root-bound; jointed stone carries the centre
            # terrace. Each visible stair has a full-width worn stone nosing.
            seam=(X+Y//9+side*97)%masonry.shape[1]
            courses=(Y-418+side*33)%masonry.shape[0]
            block=masonry[courses,seam].astype(float)
            m=np.clip((Y-soil_y-30)/44,0,1)[...,None]
            if key=="retry_basin_floor": m=np.clip((Y-y-35)/145,0,.78)[...,None]
            if key=="drain_bed" or "return" in key: m=np.ones_like(m)
            rgb=(base*(1-m)+block*m)*np.clip(1.22-(Y-y)/475,.67,1.20)[...,None]
            field[y:y+h,x:x+w,:3]=np.clip(rgb,0,255).astype(np.uint8)
            if "return" in key:
                edge=cut((127,571,480,595),w,5)
                field[y:y+5,x:x+w,:3]=np.array(edge)[:,:,:3]
    # Preserve the authored walkable grass edge above the field surfaces, the
    # original side silhouette, and bare downward faces. Only cover true solids.
    mask=Image.fromarray(np.uint8(alpha)*255)
    inset=np.array(mask.filter(ImageFilter.MinFilter(3)))
    tops=alpha & ~np.roll(alpha,1,axis=0)
    for offset in range(9):
        edge=np.roll(tops,offset,axis=0)
        inset[edge]=np.minimum(inset[edge],max(0,(offset-3)*49))
    # Worn stair noses and drain bed use their native masonry albedo through
    # the top pixel. The meadow surfaces alone retain the grassy strip.
    for key in ["west_upper_return","west_lower_return","drain_upper_return","drain_lower_return","drain_bed"]:
        x,y,w,h=solids[key]
        inset[y+1:y+9,x+1:x+w-1]=255
        field[y:y+1,x:x+w,:3]=np.clip(field[y:y+1,x:x+w,:3]*1.19,0,255)
    # The middle pier turns into its own side face in the light from the gap.
    for x,t,w in [(736,425,8),(864,475,4),(1434,487,6),(162,453,4)]:
        for i in range(w):
            col=x+i if x in [736,1434] else x-i-1
            factor=1.10-(i/w)*.10
            field[t:,col,:3]=np.clip(field[t:,col,:3]*factor,0,255).astype(np.uint8)
    # A damp bevel on the standing surface separates the boot from the gate.
    bed_light=np.exp(-((xx-1314)/110.)**4-((yy-641)/3.7)**2)
    mottling=.36+.64*np.clip((masonry[yy%masonry.shape[0],xx%masonry.shape[1],1].astype(float)-5)/60,0,1)
    reflected=field[:,:,:3].astype(float)+(bed_light*mottling)[...,None]*np.array([16,32,41])
    field[:,:,:3]=np.clip(reflected,0,255).astype(np.uint8)
    field[:,:,3]=inset
    return save_piece("p02_terrace_facing",Image.fromarray(field))

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out",type=Path,default=OUT,help="Runtime sprite directory")
    parser.add_argument("--fields",type=Path,help="Optionally export placement and material data")
    args=parser.parse_args()
    OUT=args.out
    OUT.mkdir(parents=True,exist_ok=True)
    west,east=underbanks()
    face=soil_face()
    scenery={"backdrop":doc["scenery"]["backdrop"],"pieces":[west,east,face,
             {"asset":"windchime_plains_v2_chime_span","at":[831,409],"layer":"attached"},
             {"asset":"p02_reed_screen","at":[310,572],"layer":"front","discover":"discover_p02_low_slope"}]}
    paint={"version":1,"regions":[{"id":"return_step_stone","material_id":"mill_masonry","bounds":[380,448,135,68]},
                                  {"id":"sluice_step_stone","material_id":"mill_masonry","bounds":[1058,484,149,92]},
                                  {"id":"sluice_bed","material_id":"mill_masonry","bounds":[864,640,570,27]}]}
    paint["surfaces"]=[{"id":key+"_dry_lip","facing":"up","surface_id":"bare",
                       "bounds":[solids[key][0],solids[key][1]-1,solids[key][2],2]}
                      for key in ["west_upper_return","west_lower_return","drain_upper_return","drain_lower_return","drain_bed"]]
    fields={"scenery":scenery,"terrain_paint":paint}
    if args.fields:
        args.fields.write_text(json.dumps(fields,ensure_ascii=False,indent=2)+"\n")

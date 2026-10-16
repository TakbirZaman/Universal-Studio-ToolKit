"""Original geometric four-studio mark, generated without external assets/fonts."""
import pathlib
import struct

root = pathlib.Path(__file__).resolve().parents[1]
sizes = [16, 32, 48, 64, 128, 256]
images = []
for size in sizes:
    pixels = bytearray()
    for y in reversed(range(size)):
        for x in range(size):
            u, v = (x + .5) / size, (y + .5) / size
            r, g, b, a = 32, 35, 51, 255
            # Four document cards: PDF, scan, photo, application pack.
            for left, top, color in [(.12,.12,(222,77,80)),(.54,.12,(0,135,123)),(.12,.54,(101,83,211)),(.54,.54,(168,109,0))]:
                if left <= u < left+.34 and top <= v < top+.34:
                    r,g,b = color
                    if left+.08 <= u < left+.26 and (top+.10 <= v < top+.13 or top+.20 <= v < top+.23):
                        r,g,b = 255,255,255
            pixels.extend((b,g,r,a))
    mask = bytes(((size+31)//32)*4*size)
    header = struct.pack('<IIIHHIIIIII',40,size,size*2,1,32,0,len(pixels),0,0,0,0)
    images.append(header+pixels+mask)
offset=6+16*len(images)
out=bytearray(struct.pack('<HHH',0,1,len(images)))
for size,data in zip(sizes,images):
    out.extend(struct.pack('<BBBBHHII',size%256,size%256,0,0,1,32,len(data),offset))
    offset+=len(data)
for data in images: out.extend(data)
p=root/'windows/runner/resources/app_icon.ico'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_bytes(out)
print('Generated original four-studio Windows icon.')

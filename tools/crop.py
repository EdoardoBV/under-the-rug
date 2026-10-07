# Обрезает фон и бахрому по краям сгенерированного ковра.
import sys
from PIL import Image
import numpy as np
src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
a = np.asarray(im).astype(np.float32)
bright = a.mean(axis=2)
sat = a.max(axis=2) - a.min(axis=2)
bg = (bright > 215) & (sat < 40)
def edge(fr, rev):
    idx = range(len(fr) - 1, -1, -1) if rev else range(len(fr))
    for i in idx:
        if fr[i] < 0.02:
            return i
    return 0
rows = bg.mean(axis=1); cols = bg.mean(axis=0)
H, W = bg.shape
top = edge(rows, False); bottom = edge(rows, True)
left = edge(cols, False); right = edge(cols, True)
pad = int(min(W, H) * 0.006)
box = (left + pad, top + pad, right - pad, bottom - pad)
im.crop(box).save(dst, quality=92)
print(src, box, (W, H))

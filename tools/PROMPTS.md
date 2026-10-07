# Texture prompts

Textures were generated with Nano Banana 2 (`google/gemini-3.1-flash-image` on OpenRouter) at 4K.

```bash
export OPENROUTER_API_KEY=...
python3 tools/gen.py "<prompt>" out.png 3:2 4K
python3 tools/crop.py out.png "Resources/rugs/5 my-rug.jpg"
```

`crop.py` trims leftover background and fringe at the edges. Rugs use 3:2, floors 16:9.

## Rugs

Every rug prompt starts with this base.

> Perfectly flat orthographic top-down scan of an entire hand-knotted wool rug. The rug fills the whole image exactly edge to edge, its outer border touches all four image edges, no floor or background visible, no fringe, no tassels, no folds, no perspective, no shadows, even soft diffuse museum-scan lighting, visible wool pile texture.

**Persian.** Deep madder red field with intricate floral arabesques, central navy and ivory diamond medallion, ivory spandrels in the corners, wide navy main border with red rosettes and thin guard stripes. Visible hand-knotted wool pile texture, slightly worn and faded naturally. Symmetric composition.

**Neural.** A classic Persian medallion carpet layout, but every ornament is secretly made of technology. The arabesques are printed circuit board traces, the rosettes are microchips and neural network node graphs, the central medallion is a stylized glowing neural network diagram, the border has a repeating band of tiny chips and connector pins. Palette deep madder red, indigo navy, antique gold and ivory.

**Soviet.** A classic Soviet 1970s wall carpet like in every Russian grandmother's apartment, burgundy and deep red field, large geometric central medallion with stepped diamonds and stylized flowers, black and beige accents, multiple geometric borders, synthetic wool look, slightly faded.

**Pixel.** A Persian carpet rendered as chunky 8-bit pixel art, every motif built from visible square pixels like a retro video game, central medallion, corner spandrels and floral border all pixelated, palette crimson, navy, cream, teal and gold.

## Floors

Base for floors.

> Perfectly flat orthographic top-down photo of a floor, camera pointing straight down, no perspective, no furniture, no objects, no people, no shadows, no vignette, soft even daylight, the floor fills the entire image edge to edge.

**Soviet herringbone.** Classic Soviet 1970s apartment herringbone oak parquet. Short narrow oak strips laid in herringbone, the columns run vertically, about ten herringbone columns across the image width. Honey amber glossy lacquer slightly yellowed with age, worn in a few places, tiny dark gaps between strips.

**Soviet mosaic.** Mosaic parquet made of square panels, each square made of five short oak strips, neighbouring squares alternate direction like a basket weave checkerboard, about fourteen squares across the image width. Warm amber varnish slightly yellowed with age, a few worn spots.

**Oak planks.** Light natural oak plank floor, planks run horizontally, staggered joints, subtle realistic wood grain and knots, matte finish.

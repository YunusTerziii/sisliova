# K11 · Derya portresi (eksik görsel)

Derya'nın portresi henüz yok. Oyun bu sürede Derya sahnelerinde kaplıca çizimini gösteriyor; harfli daire kullanılmıyor.
Görsel gelince `App/Karacam/Assets.xcassets/portrait-derya.imageset/` olarak eklenir, `story.json` içindeki
`derya` konuşmacısına `"portrait": "portrait-derya"` yazılır ve `asset_manifest.json` durumu `final` olur.

Üretim: diğer portreleri ürettiğin ChatGPT sohbetinde devam et (stil tutarlı kalsın). Komutu tek parça kopyala.

```
Match exactly the pencil style, line weight, hatching and paper color of the reference images.

PORTRAIT of DERYA, a 28-year-old restoration specialist who has come to a small Turkish mountain village to survey an old stone bridge and a closed hot-spring building. Very simple round-head cartoon style like Deniz in the reference: dot eyes, 2-3 line expression, no detailed anatomy. Distinctive silhouette: shoulder-length straight dark hair tied loosely at the nape with a few strands loose, a canvas field jacket with many pockets over a plain sweater, a folding measuring tape clipped to one pocket. She holds a small sketchbook open against her forearm with a pencil resting on it. Expression: attentive and calm, looking slightly past the viewer as if checking a wall, the corner of her mouth relaxed. She is an adult professional; friendly but focused on her work, not flirtatious, not glamorous.

PORTRAIT FORMAT: head and shoulders only, facing the viewer at a slight 3/4 angle, centered. The head fills the upper half of the square; the top of the hair is about 8% below the top edge. Transparent background, square 1024x1024. The face must stay readable when shrunk to a 64-pixel circle.

STYLE: flat 2D sketchbook drawing on aged off-white cream paper (#F3EAD9). Graphite pencil and dry ink lines in charcoal black (#292621), light hand hatching in faded pencil gray (#77736A). Lines are slightly uneven, asymmetric and natural, with varying pencil pressure; a few faint construction lines are welcome. Very limited colors: charcoal, pencil gray and cream only. No gradients, no neon, no glow, no realistic lighting, no lens effects, no blur, no 3D, no photorealism, no clean vector geometry. Absolutely no text, letters, numbers, currency symbols, signatures or logos anywhere in the image.
```

Sık düzeltmeler:

- Fazla "güzel/romantik" çıktıysa: `Make her look like an ordinary working professional; neutral, practical clothes, no makeup emphasis.`
- Öbür portrelerden büyük/küçük çıktıysa: `Same drawing style and head size as the previous portraits in this chat.`

## Aynı sırada yenilenmesi iyi olanlar

- **Nermin**: mevcut görsel web demosundan 159×300 px; 1024 px kare portre olarak yeniden üretilmeli.
- **Araba / kamyon**: web demosundan 300 px civarı; 1024 px kare çizim olarak yeniden üretilmeli.

#  Copyright (c) 2017 emekoi
#
#  This library is free software; you can redistribute it and/or modify it
#  under the terms of the MIT license. See LICENSE for details.
#

{.deadCodeElim: on, optimization: speed.}
{.compile: "suffer/ttf_impl.c".}
{.compile: "suffer/stb_impl.c".}

when defined(Posix) and not defined(haiku):
  {.passl: "-lm".}

import
  strutils,
  sequtils,
  math,
  tables,
  hashes

when defined(MODE_RGBA):
  const RGB_MASK = 0x00FFFFFF'u32
elif defined(MODE_ARGB):
  const RGB_MASK = 0xFFFFFF00'u32
elif defined(MODE_ABGR):
  const RGB_MASK = 0xFFFFFF00'u32
else:
  const RGB_MASK = 0x00FFFFFF'u32

type
  BufferError* = object of Exception
  FontError* = object of Exception
  
  PixelFormat* = enum
    ## the different pixel formats supported
    FMT_BGRA
    FMT_RGBA
    FMT_ARGB
    FMT_ABGR

  BlendMode* = enum
    ## the different blend modes supported
    BLEND_ALPHA
    BLEND_COLOR
    BLEND_ADD
    BLEND_SUBTRACT
    BLEND_MULTIPLY
    BLEND_LIGHTEN
    BLEND_DARKEN
    BLEND_SCREEN
    BLEND_DIFFERENCE

  Pixel* = object {.union.}
    ## how color is represented
    ## dependeding on which mode is defined at compile time, a different color format is used
    word*: uint32
    when defined(MODE_RGBA):
      rgba*: tuple[r, g, b, a: uint8]
    elif defined(MODE_ARGB):
      rgba*: tuple[a, r, g, b: uint8]
    elif defined(MODE_ABGR):
      rgba*: tuple[a, b, g, r: uint8]
    else:
      rgba*: tuple[b, g, r, a: uint8]

  Rect* = tuple
    ## a rectangle used for clipping and drawing specific regions of buffer
    x, y, w, h: int

  DrawMode* = object
    ## affects how things are drawn onto the buffer
    color*: Pixel
    alpha*: uint8
    blend*: BlendMode

  Transform* = tuple
    ## describes a tranformation applied to a buffer when it is drawn onto another buffer
    ox, oy, r, sx, sy: float

  Buffer* = ref object
    ## a collection of pixels that represents an image
    mode*: DrawMode
    clip*: Rect
    pixels*: seq[Pixel]
    w*, h*: int

  stbtt_fontinfo = object

  ttf_Font = ref object
    font*: stbtt_fontinfo
    fontData*: pointer
    ptsize*: cfloat
    scale*: cfloat
    baseline*: cint
  
  Font* = ref ptr ttf_Font
    ## a reference to the actual font object

{.push inline.}

proc pixel*[T](r, g, b, a: T): Pixel
  ## creates a pixel with the color `rgba(r, g, b, a)`
proc color*(c: string): Pixel
  ## creates a pixel from the given hex color code
proc color*[T](r, g, b: T): Pixel
  ## an alias for `pixel(r, g, b, 255)`
proc newBuffer*(w, h: int): Buffer
  ## creates a blank pixel buffer
proc newBufferFile*(filename: string): Buffer
  ## creates a new pixel buffer from a file
proc newBufferString*(str: string): Buffer
  ## creates a new pixel buffer from a string
  ## (it doesn't actually work for some reason and i have no idea why)
proc cloneBuffer*(src: Buffer): Buffer
  ## creates a copy of the buffer
proc loadPixels*(buf: Buffer, src: openarray[uint32], fmt: PixelFormat)
  ## loads the data from `src` into the buffer using the given pixel format
proc loadPixels8*(buf: Buffer, src: openarray[uint8], pal: openarray[Pixel])
  ## loads the data from `src` into the buffer using the given palette
proc loadPixels8*(buf: Buffer, src: openarray[uint8])
  ## loads the data from `src` into the buffer, using it set the alpha of all its pixels
proc setBlend*(buf: Buffer, blend: BlendMode)
  ## sets the buffer's blend mode
proc setAlpha*[T](buf: Buffer, alpha: T)
  ## sets the buffer's alpha
proc setColor*(buf: Buffer, c: Pixel)
  ## sets the buffer's color
proc setClip*(buf: Buffer, r: Rect)
  ## sets the buffer's clipping rectanlge
proc reset*(buf: Buffer)
  ## resets the buffer to a default state
proc clear*(buf: Buffer, c: Pixel)
  ## sets the buffer's blend mode
proc getPixel*(buf: Buffer, x: int, y: int): Pixel
  ## gets the color of the pixel at (x, y) on the buffer
proc setPixel*(buf: Buffer, c: Pixel, x: int, y: int)
  ## sets the color of the pixel at (x, y) on the buffer
proc copyPixels*(buf, src: Buffer, x, y: int, sub: Rect, sx, sy: float)
  ## copies the pixels from one buffer to another
proc copyPixels*(buf, src: Buffer, x, y: int, sx, sy: float)
  ## copies the pixels from one buffer to another
proc noise*(buf: Buffer, seed: uint, low, high: int, grey: bool)
  ## fills the buffer with psuedo-random noise in the form of pixels
proc floodFill*(buf: Buffer, c: Pixel, x, y: int)
  ## fills the pixel (x, y) and all surrounding pixels of the same color with the color `c`
proc drawPixel*(buf: Buffer, c: Pixel, x, y: int)
  ## draws a pixel of color `c` at `(x, y)`
proc drawLine*(buf: Buffer, c: Pixel, x0, y0, x1, y1: int)
  ## draws a line of color `c` through `(x0, y0)`, (x`1, y1)`
proc drawRect*(buf: Buffer, c: Pixel, x, y, w, h: int)
  ## draws a rect with the dimensions w X h, of color `c` at `(x, y)`
proc drawBox*(buf: Buffer, c: Pixel, x, y, w, h: int)
  ## draws a box with the dimensions w X h, of color `c` at `(x, y)`
proc drawCircle*(buf: Buffer, c: Pixel, x, y, r: int)
  ## draws a circle with radius of `r` and color of `c` at `(x, y)`
proc drawRing*(buf: Buffer, c: Pixel, x, y, r: int)
  ## draws a ring with a radius of `r` and color of `c` at `(x, y)`
proc drawText*(buf: Buffer, font: Font, c: Pixel, txt: string, x, y: int, width: int=0)
  ## draws the string `txt` with the color `c` and a maximum width of `width` at `(x, y)`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, sub: Rect, t: Transform)
  ## draw the Buffer `src` at (x, y) with a clipping rect of `sub` and a transform of `t`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, sub: Rect)
  ## draw the Buffer `src` at (x, y) with a clipping rect of `sub`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, t: Transform)
  ## draw the Buffer `src` at (x, y) with a transform of `t`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int)
  ## draw the Buffer `src` at (x, y)
proc desaturate*(buf: Buffer, amount: int)
  ## desaturates the buffer by the given amount
proc mask*(buf, mask: Buffer, channel: char)
  ## uses the buffer `mask` to mask the given channel on the buffer
proc palette*(buf: Buffer, palette: openarray[Pixel])
  ## converts the buffer to the given palette
proc dissolve*(buf: Buffer, amount: int, seed: uint)
  ## randomly dissolves the palette by the given amount
proc wave*(buf, src: Buffer, amountX, amountY, scaleX, scaleY, offsetX, offsetY: int)
  ## distorts `src` in a wave-like pattern as it is drawn onto `buf`
proc displace*(buf, src, map: Buffer, channelX, channelY: char, scaleX, scaleY: int)
  ## uses `map` to displace `src`, then draws `src` onto `buf`
proc blur*(buf, src: Buffer, radiusx, radiusy: int)
  ## blurs then draws `src` onto `buf`
proc newFont*(data: seq[byte], ptsize: float): Font
  ## attemtpts to create a font from a sequence of bytes
proc newFontFile*(filename: string, ptsize: float): Font
  ## loads a font from a file
proc newFontString*(data: string, ptsize: float): Font
  ## creates a font from a string
proc setSize*(font: Font, ptsize: float)
  ## sets the font point size
proc getHeight*(font: Font): int
  ## gets the height of the font
proc getWidth*(font: Font, txt: string): int
  ## gets the width of `str` rendered in the font
proc render*(font: Font, txt: string): Buffer
  ## creates a new Buffer with `txt` rendered on it using `font`

{.pop.}

proc `$`*(p: Pixel): string =
  ## a readable representation of the pixel
  return "($#, ($#, $#, $#, $#))" % [$p.word, $p.rgba.r, $p.rgba.g, $p.rgba.b, $p.rgba.a]

proc lerp[T](bits, a, b, p: T): T =
  return (a + (b - a) * p) shr bits

const
  PI2 = 6.28318530718'f32
  FX_BITS_12 = 12
  FX_UNIT_12 = 1 shl FX_BITS_12
  # FX_MASK = FX_UNIT_12 - 1
  FX_BITS_10 = 10
  FX_UNIT_10 = 1 shl FX_BITS_10
  FX_MASK_10 = FX_UNIT_10 - 1

proc genDivTable(): array[256, array[256, uint8]] =
  for b in 1'u8..255'u8:
    for a in 0'u8..255'u8:
      result[a][b] = uint8((a shl 8) div b)

proc genSinTable(): array[FX_UNIT_10, int] =
  # make a sin table
  for i in 0..<FX_UNIT_10:
    result[i] = (sin((i.float / FX_UNIT_10.float) * 6.28318530718) * FX_UNIT_10).int

const
  div8Table: array[256, array[256, uint8]] = genDivTable()  
  tableSin = genSinTable()
  
type
  Point = tuple
    x, y: int

  RandState = tuple
    x, y, z, w: uint

proc xdiv[T](n, x: T): T =
  if x == 0: return n
  return n div x

template check(cond, msg: untyped) =
  if not cond: GC_FullCollect(); raise newException(BufferError, msg)

proc fxsin(n: int): int =
  return tableSin[n and FX_MASK_10]

proc checkBufferSizesMatch(a, b: Buffer) =
  check(a.w == b.w or a.h == b.h, "expected buffer sizes to match") 
    
proc rand128init(seed: uint): RandState =
  result.x = (seed and 0xff000000'u) or 1'u
  result.y = seed and 0xff0000'u
  result.z = seed and 0xff00'u
  result.w = seed and 0xff'u

proc rand128(s: var RandState): uint =
  result = s.x xor (s.x shl 11'u)
  s.x = s.y; s.y = s.z; s.z = s.w
  s.w = s.w xor (s.w shr 19) xor result xor (result shr 8)
  return s.w

proc pixel*[T](r, g, b, a: T): Pixel =
  result.rgba.r = clamp(r, 0, 0xff).uint8
  result.rgba.g = clamp(g, 0, 0xff).uint8
  result.rgba.b = clamp(b, 0, 0xff).uint8
  result.rgba.a = clamp(a, 0, 0xff).uint8

proc color*(c: string): Pixel =
  let hex = parseHexInt(c)
  if hex >= 0xffffff:
    result.rgba.r = (hex shr 24) and 0xff
    result.rgba.g = (hex shr 16) and 0xff
    result.rgba.b = (hex shr  8) and 0xff
    result.rgba.a = (hex shr  0) and 0xff
  else:
    result.rgba.r = (hex shr 16) and 0xff
    result.rgba.g = (hex shr  8) and 0xff
    result.rgba.b = (hex shr  0) and 0xff
    result.rgba.a = 0xff
  
proc color*[T](r, g, b: T): Pixel =
  return pixel(r, g, b, 0xff)

converter toBytes(str: string): seq[byte] =
  return cast[seq[byte]](str)

proc clipRect(r: ptr Rect, to: Rect) =
  let
    x1 = max(r.x, to.x)
    y1 = max(r.y, to.y)
    x2 = min(r.x + r.w, to.x + to.w)
    y2 = min(r.y + r.h, to.y + to.h)
  r.x = x1
  r.y = y1
  r.w = max(x2 - x1, 0)
  r.h = max(y2 - y1, 0)


proc clipRectAndOffset(r: ptr Rect, x, y: ptr int, to: Rect) =
  var d: int
  if (d = to.x - x[]; d) > 0:
    x[] += d; r.w -= d; r.x += d
  if (d = to.y - y[]; d) > 0:
    y[] += d; r.h -= d; r.y += d
  if (d = (x[] + r.w) - (to.x + to.w); d) > 0: r.w -= d
  if (d = (y[] + r.h) - (to.y + to.h); d) > 0: r.h -= d

proc newBuffer*(w, h: int): Buffer =
  new result
  check(w > 0, "expected width of 1 or greater")
  check(h > 0, "expected height of 1 or greater")
  result.pixels = repeat(color(0, 0, 0), w * h)
  # initialize the buffer
  result.w = w; result.h = h
  result.reset()

proc stbi_failure_reason_c(): cstring
  {.cdecl, importc: "stbi_failure_reason".}

proc stbi_failure_reason(): string =
  return $stbi_failure_reason_c()

{.push cdecl, importc.}
proc stbi_image_free(retval_from_stbi_load: pointer)
proc stbi_load_from_memory(
  buffer: ptr cuchar,
  len: cint,
  x, y, channels_in_file: var cint,
  desired_channels: cint
): ptr cuchar
proc stbi_load(
  filename: cstring,
  x, y, channels_in_file: var cint,
  desired_channels: cint
): ptr cuchar
{.pop.}

proc newBufferFile*(filename: string): Buffer =
  var width, height, bpp: cint
  let data = stbi_load(filename.cstring, width, height, bpp, 4.cint)
  check(data != nil, stbi_failure_reason())
  var pixels = newSeq[uint32](width * height)
  copyMem(pixels[0].addr, data, pixels.len * sizeof(uint32))
  result = newBuffer(width, height)
  result.loadPixels(pixels, FMT_RGBA)
  stbi_image_free(data)


proc newBufferString*(str: string): Buffer =
  var width, height, bpp: cint
  var data = cast[ptr cuchar](str[0].unsafeAddr)
  let pixelData = stbi_load_from_memory(data, data.len.cint,
    width, height, bpp, 4)
  check(pixelData != nil, stbi_failure_reason())
  var pixels = newSeq[uint32](width * height)
  copyMem(pixels[0].addr, pixelData, pixels.len)
  result = newBuffer(width, height)
  result.loadPixels(pixels, FMT_RGBA)
  stbi_image_free(pixelData)

proc cloneBuffer*(src: Buffer): Buffer =
  deepCopy(result, src)

proc loadPixels*(buf: Buffer, src: openarray[uint32], fmt: PixelFormat) =
  var sr, sg, sb, sa: int
  let sz = (buf.w * buf.h) - 1
  case fmt:
    of FMT_BGRA: (sr = 16; sg =  8; sb =  0; sa = 24;)
    of FMT_RGBA: (sr =  0; sg =  8; sb = 16; sa = 24;)
    of FMT_ARGB: (sr =  8; sg = 16; sb = 24; sa =  0;)
    of FMT_ABGR: (sr = 24; sg = 16; sb =  8; sa =  0;)

  for i in countdown(sz, 0):
    buf.pixels[i].rgba.r = (src[i] shr sr) and 0xff
    buf.pixels[i].rgba.g = (src[i] shr sg) and 0xff
    buf.pixels[i].rgba.b = (src[i] shr sb) and 0xff
    buf.pixels[i].rgba.a = (src[i] shr sa) and 0xff

proc loadPixels8*(buf: Buffer, src: openarray[uint8], pal: openarray[Pixel]) =
  let sz = (buf.w * buf.h) - 1
  for i in countdown(sz, 0):
    buf.pixels[i] = pal[src[i].int]

proc loadPixels8*(buf: Buffer, src: openarray[uint8]) =
  let sz = (buf.w * buf.h) - 1
  for i in countdown(sz, 0):
    buf.pixels[i] = pixel(0xff'u8, 0xff'u8, 0xff'u8, src[i])

proc setBlend*(buf: Buffer, blend: BlendMode) =
  buf.mode.blend = blend

proc setAlpha*[T](buf: Buffer, alpha: T) =
  buf.mode.alpha = clamp(alpha, 0, 0xff).uint8

proc setColor*(buf: Buffer, c: Pixel) =
  buf.mode.color.word = c.word and RGB_MASK

proc setClip*(buf: Buffer, r: Rect) =
  buf.clip = r
  clipRect(addr buf.clip, (0, 0, buf.w, buf.h))

proc reset*(buf: Buffer) =
  buf.setBlend(BLEND_ALPHA)
  buf.setAlpha(0xff)
  buf.setColor color(0xff, 0xff, 0xff)
  buf.setClip((0, 0, buf.w, buf.h))

proc clear*(buf: Buffer, c: Pixel) =
  for pixel in mitems(buf.pixels): pixel = c

proc getPixel*(buf: Buffer, x: int, y: int): Pixel =
  if (x >= 0 and y >= 0 and x < buf.w and y < buf.h):
    return buf.pixels[x + y * buf.w]
  result.word = 0

proc setPixel*(buf: Buffer, c: Pixel, x: int, y: int) =
  if (x >= 0 and y >= 0 and x < buf.w and y < buf.h):
    buf.pixels[x + y * buf.w] = c

{.push checks: off.}

proc copyPixelsBasic(buf, src: Buffer, x, y: int, sub: Rect) =
  # Clip to destination buffer
  var (x, y, sub) = (x, y, sub)
  clipRectAndOffset(addr sub, addr x, addr y, buf.clip)
  # Clipped off screen?
  if sub.w <= 0 or sub.h <= 0: return
  # Copy pixels
  for i in 0..<sub.h:
    copyMem(addr buf.pixels[x + (y + i) * buf.w],
      addr src.pixels[sub.x + (sub.y + i) * src.w], sub.w * sizeof(Pixel))

proc copyPixelsScaled(buf, src: Buffer, x, y: int, sub: Rect, scalex, scaley: float) =
  var
    d: int
    (x, y, sub) = (x, y, sub)
    (w, h) = ((sub.w.float * scalex).int, (sub.h.float * scaley).int)
    (inx, iny) = ((FX_UNIT_12 / scalex).int, (FX_UNIT_12 / scaley).int)
  # Clip to destination buffer
  if (d = buf.clip.x - x; d) > 0:
    x += d; sub.x += (d.float / scalex).int; w -= d;
  if (d = buf.clip.y - y; d) > 0:
    y += d; sub.y += (d.float / scaley).int; h -= d;
  if (d = (x + w) - (buf.clip.x + buf.clip.w); d) > 0: w -= d
  if (d = (y + h) - (buf.clip.y + buf.clip.h); d) > 0: h -= d
  # Clipped offscreen
  if w == 0 or h == 0: return
  # Draw
  var sy = sub.y shl FX_BITS_12

  for dy in y..<(y + h):
    var
      sx = 0
      dx = x + buf.w * dy
    let
      offset = (sub.x shr FX_BITS_12) + src.w * (sy shr FX_BITS_12)
      edx = dx + w
    while dx < edx:
      buf.pixels[dx] = src.pixels[offset + (sx shr FX_BITS_12)]
      sx += inx; dx += 1
    sy += iny

proc copyPixels*(buf, src: Buffer, x, y: int, sub: Rect, sx, sy: float) =
  let (sx, sy) = (abs(sx), abs(sy))
  if sx == 0 or sy == 0: return
  if sub.w <= 0 or sub.h <= 0: return
  check sub.x >= 0 and sub.y >= 0 and sub.x + sub.w <= src.w and sub.y + sub.h <= src.h, "sub rectangle out of bounds"
  # Dispatch
  if (sx == 1 and sy == 1):
  # Basic un-scaled copy
    copyPixelsBasic(buf, src, x, y, sub)
  else:
  # Scaled copy
    copyPixelsScaled(buf, src, x, y, sub, sx, sy)

proc copyPixels*(buf, src: Buffer, x, y: int, sx, sy: float) =
  copyPixels(buf, src, x, y, (0, 0, src.w, src.h), sx, sy)

proc noise*(buf: Buffer, seed: uint, low, high: int, grey: bool) =
  var
    s = rand128init(seed)
    high = clamp(high, low + 1, 0xff).uint
    low = clamp(low, 0, 0xfe).uint
  if grey:
    for i in countdown((buf.w * buf.h) - 1, 0):
      buf.pixels[i].rgba.r = (low + rand128(s) mod (high - low)).uint8
      buf.pixels[i].rgba.g = buf.pixels[i].rgba.r
      buf.pixels[i].rgba.b = buf.pixels[i].rgba.r
      buf.pixels[i].rgba.a = 0xff
  else:
    for i in countdown((buf.w * buf.h) - 1, 0):
      buf.pixels[i].word = (rand128(s) or (not RGB_MASK).uint).uint32
      buf.pixels[i].rgba.r = low.uint8 + buf.pixels[i].rgba.r mod (high - low).uint8
      buf.pixels[i].rgba.g = low.uint8 + buf.pixels[i].rgba.g mod (high - low).uint8
      buf.pixels[i].rgba.b = low.uint8 + buf.pixels[i].rgba.b mod (high - low).uint8

proc floodFill(buf: Buffer, c, o: Pixel, x, y: int) {.locks: 0.} =
  if
    y < 0 or y >= buf.h or x < 0 or x >= buf.w or
    buf.pixels[x + y * buf.w].word != o.word: return
  # Fill left
  var il = x
  while il >= 0 and buf.pixels[il + y * buf.w].word == o.word:
    buf.pixels[il + y * buf.w] = c;
    il -= 1
  # Fill right
  var ir = if x < buf.w - 1: x + 1 else: x
  while ir < buf.w and buf.pixels[ir + y * buf.w].word == o.word:
    buf.pixels[ir + y * buf.w] = c;
    ir += 1
  # Fill up and down
  while il <= ir:
    buf.floodFill(c, o, il, y - 1)
    buf.floodFill(c, o, il, y + 1)
    il += 1

proc floodFill*(buf: Buffer, c: Pixel, x: int, y: int) =
  floodFill(buf, c, buf.getPixel(x, y), x, y)

proc blendPixel(m: DrawMode, d: ptr Pixel, s: Pixel) =
  let alpha = (s.rgba.a.int * m.alpha.int) shr 8
  var s = s
  if alpha <= 1: return
  # Color
  if m.color.word != RGB_MASK:
    s.rgba.r = (s.rgba.r * m.color.rgba.r) shr 8
    s.rgba.g = (s.rgba.g * m.color.rgba.g) shr 8
    s.rgba.b = (s.rgba.b * m.color.rgba.b) shr 8
  # Blend
  case m.blend
  of BLEND_ALPHA:
    discard
  of BLEND_COLOR:
    s = m.color
  of BLEND_ADD:
    s.rgba.r = min(d.rgba.r.int + s.rgba.r.int, 0xff).uint8
    s.rgba.g = min(d.rgba.g.int + s.rgba.g.int, 0xff).uint8
    s.rgba.b = min(d.rgba.b.int + s.rgba.b.int, 0xff).uint8
  of BLEND_SUBTRACT:
    s.rgba.r = min(d.rgba.r.int - s.rgba.r.int, 0).uint8
    s.rgba.g = min(d.rgba.g.int - s.rgba.g.int, 0).uint8
    s.rgba.b = min(d.rgba.b.int - s.rgba.b.int, 0).uint8
  of BLEND_MULTIPLY:
    s.rgba.r = ((s.rgba.r.int * d.rgba.r.int) shr 8).uint8
    s.rgba.g = ((s.rgba.g.int * d.rgba.g.int) shr 8).uint8
    s.rgba.b = ((s.rgba.b.int * d.rgba.b.int) shr 8).uint8
  of BLEND_LIGHTEN:
    s = if s.rgba.r.int + s.rgba.g.int + s.rgba.b.int >
          d.rgba.r.int + d.rgba.g.int + d.rgba.b.int: s else: d[]
  of BLEND_DARKEN:
    s = if s.rgba.r.int + s.rgba.g.int + s.rgba.b.int <
          d.rgba.r.int + d.rgba.g.int + d.rgba.b.int: s else: d[]
  of BLEND_SCREEN:
    s.rgba.r = (0xff - (((0xff - d.rgba.r.int) * (0xff - s.rgba.r.int)) shr 8)).uint8
    s.rgba.g = (0xff - (((0xff - d.rgba.g.int) * (0xff - s.rgba.g.int)) shr 8)).uint8
    s.rgba.b = (0xff - (((0xff - d.rgba.b.int) * (0xff - s.rgba.b.int)) shr 8)).uint8
  of BLEND_DIFFERENCE:
    s.rgba.r = abs(s.rgba.r.int - d.rgba.r.int).uint8
    s.rgba.g = abs(s.rgba.g.int - d.rgba.g.int).uint8
    s.rgba.b = abs(s.rgba.b.int - d.rgba.b.int).uint8
  # Write
  if alpha >= 254:
    d[] = s
  elif d.rgba.a >= 254'u8:
    d.rgba.r = lerp(8, d.rgba.r.int, s.rgba.r.int, alpha).uint8
    d.rgba.g = lerp(8, d.rgba.g.int, s.rgba.g.int, alpha).uint8
    d.rgba.b = lerp(8, d.rgba.b.int, s.rgba.b.int, alpha).uint8
  else:
    let
      a = 0xff - (((0xff - d.rgba.a.int) * (0xff - alpha)) shr 8)
      z = (d.rgba.a.int * (0xff - alpha)) shr 8
    d.rgba.r = div8Table[((d.rgba.r.int * z) shr 8) + ((s.rgba.r.int * alpha) shr 8)][a]
    d.rgba.g = div8Table[((d.rgba.g.int * z) shr 8) + ((s.rgba.g.int * alpha) shr 8)][a]
    d.rgba.b = div8Table[((d.rgba.b.int * z) shr 8) + ((s.rgba.b.int * alpha) shr 8)][a]
    d.rgba.a = a.uint8
    

proc drawPixel*(buf: Buffer, c: Pixel, x, y: int) =
  if
    x >= buf.clip.x and x < buf.clip.x + buf.clip.w and
    y >= buf.clip.y and y < buf.clip.y + buf.clip.h:
      blendPixel(buf.mode, buf.pixels[x + y * buf.w].addr, c);

proc drawLine*(buf: Buffer, c: Pixel, x0, y0, x1, y1: int) =
  let steep = abs(y1 - y0) > abs(x1 - x0)
  var (x0, y0, x1, y1) = (x0, y0, x1, y1)
  if steep:
    swap x0, y0
    swap x1, y1
  if x0 > x1:
    swap x0, x1
    swap y0, y1
  var
    deltax = x1 - x0
    deltay = abs(y1 - y0)
    error = deltax / 2
    ystep = if y0 < y1: 1 else: -1
    y = y0
  for x in x0..x1:
    if steep:
      buf.drawPixel(c, y, x)
    else:
      buf.drawPixel(c, x, y)
    error -= deltay.float
    if error < 0:
      y += ystep
      error += deltax.float

proc drawRect*(buf: Buffer, c: Pixel, x, y, w, h: int) =
  var
    r = (x: x, y: y, w: w, h: h)
  clipRect(r.addr, buf.clip)
  for y1 in countdown(r.h - 1, 0):
    for x1 in countdown(r.w - 1, 0):
      blendPixel(buf.mode, buf.pixels[(r.x + (r.y + y1) * buf.w) + x1].addr, c)

proc drawBox*(buf: Buffer, c: Pixel, x, y, w, h: int) =
  buf.drawRect(c, x + 1, y, w - 1, 1)
  buf.drawRect(c, x, y + h - 1, w - 1, 1)
  buf.drawRect(c, x, y, 1, h - 1)
  buf.drawRect(c, x + w - 1, y + 1, 1, h - 1)

template DRAW_ROW(x, y, len: untyped) =
  if y >= 0 and (not rows[y shr 5] and (1 shl (y and 31)).uint) != 0:
    buf.drawRect(c, x, y, len, 1)
    rows[y shr 5] = rows[y shr 5] or (1 shl (y and 31)).uint

proc drawCircle*(buf: Buffer, c: Pixel, x, y, r: int) =
  var
    dx = abs(r)
    dy = 0
    radiusError = 1 - dx
    rows: array[511, uint]
  # Clipped completely off-screen?
  if x + dx < buf.clip.x or x - dx > buf.clip.x + buf.clip.w or
    y + dx < buf.clip.y or y - dx > buf.clip.y + buf.clip.h: return
  # zeroset bit array of drawn rows -- we keep track of which rows have been
  # drawn so that we can avoid overdraw
  # memset(rows, 0, sizeof(rows));
  reset(rows)
  while dx >= dy:
    DRAW_ROW(x - dx, y + dy, dx shl 1)
    DRAW_ROW(x - dx, y - dy, dx shl 1)
    DRAW_ROW(x - dy, y + dx, dy shl 1)
    DRAW_ROW(x - dy, y - dx, dy shl 1)
    dy += 1
    if radiusError < 0:
      radiusError += 2 * dy + 1
    else:
      dx -= 1
      radiusError += 2 * (dy - dx + 1)

proc drawRing*(buf: Buffer, c: Pixel, x, y, r: int) =
  # TODO : Prevent against overdraw?
  var
    dx = abs(r)
    dy = 0
    radiusError = 1 - dx
  # Clipped completely off-screen?
  if x + dx < buf.clip.x or x - dx > buf.clip.x + buf.clip.w or
      y + dx < buf.clip.y or y - dx > buf.clip.y + buf.clip.h: return
  # Draw
  while dx >= dy:
    buf.drawPixel(c,  dx + x,  dy + y)
    buf.drawPixel(c,  dy + x,  dx + y)
    buf.drawPixel(c, -dx + x,  dy + y)
    buf.drawPixel(c, -dy + x,  dx + y)
    buf.drawPixel(c, -dx + x, -dy + y)
    buf.drawPixel(c, -dy + x, -dx + y)
    buf.drawPixel(c,  dx + x, -dy + y)
    buf.drawPixel(c,  dy + x, -dx + y)
    dy += 1
    if radiusError < 0:
      radiusError += 2 * dy + 1
    else:
      dx -= 1
      radiusError += 2 * (dy - dx + 1)

var fontTexCache = initTable[Font, Table[string, Buffer]]()

proc hash(f: Font): Hash =
  result = cast[int](f[]).hash
  result = !$result

proc drawText*(buf: Buffer, font: Font, c: Pixel, txt: string, x, y, width: int) =
  let color = buf.mode.color
  buf.setColor(c)
  if not fontTexCache.hasKey(font):
    fontTexCache[font] = initTable[string, Buffer](16)
    fontTexCache[font][txt] = font.render(txt)
  elif not fontTexCache[font].hasKey(txt):
    fontTexCache[font][txt] = font.render(txt)

  buf.drawBuffer(fontTexCache[font][txt], x, y)
  buf.setColor(color)

proc drawBufferBasic(buf: Buffer, src: Buffer, x, y: int, sub: Rect) =
  # Clip to destination buffer
  var (sub, x, y) = (sub, x, y)
  clipRectAndOffset(sub.addr, x.addr, y.addr, buf.clip)
  # Clipped off screen?
  if sub.w <= 0 or sub.h <= 0: return
  # Draw
  for iy in 0..<sub.h:
    for i in 0..<sub.w:
      blendPixel(buf.mode, buf.pixels[(x + (y + iy) * buf.w) + i].addr,
        src.pixels[(sub.x + (sub.y + iy) * src.w) + i])

proc drawBufferScaled(buf: Buffer, src: Buffer, x, y: int, sub: Rect, t: Transform) =
  let
    absSx = if t.sx < 0: -t.sx else: t.sx
    absSy = if t.sy < 0: -t.sy else: t.sy
    osx = if t.sx < 0: (sub.w shl FX_BITS_12) - 1 else: 0
    osy = if t.sy < 0: (sub.h shl FX_BITS_12) - 1 else: 0
    ix = ((sub.w shl FX_BITS_12).float / t.sx / sub.w.float).int
    iy = ((sub.h shl FX_BITS_12).float / t.sy / sub.h.float).int
  var
    sub = sub
    w = (sub.w.float * absSx + 0.5).floor.int
    h = (sub.h.float * absSy + 0.5).floor.int
    # Adjust x/y depending on origin
    x = (x.float - (((if t.sx < 0: w else: 0) - (if t.sx < 0: -1 else: 1)).float * t.ox * absSx)).int
    y = (y.float - (((if t.sy < 0: h else: 0) - (if t.sy < 0: -1 else: 1)).float * t.oy * absSy)).int
  # Clipped completely offscreen horizontally?
  if x + w < buf.clip.x or x > buf.clip.x + buf.clip.w: return
  # Adjust for clipping
  var
    d = 0
    dy = 0
    odx = 0
  if (d = (buf.clip.y - y); d) > 0: dy = d;  sub.y += (d.float / t.sy).int
  if (d = (buf.clip.x - x); d) > 0: odx = d; sub.x += (d.float / t.sx).int
  if (d = (y + h) - (buf.clip.y + buf.clip.h); d) > 0: h -= d
  if (d = (x + w) - (buf.clip.x + buf.clip.w); d) > 0: w -= d
  # Draw
  var sy = osy
  while dy < h:
    var dx = odx
    var sx = osx;
    while dx < w:
      blendPixel(buf.mode, buf.pixels[(x + dx) + (y + dy) * buf.w].addr,
                 src.pixels[(sub.x + (sx shr FX_BITS_12)) +
                             (sub.y + (sy shr FX_BITS_12)) * src.w])
      sx += ix
      dx += 1
    sy += iy
    dy += 1

proc drawScanLine(buf, src: Buffer, sub: Rect, left, right, dy, sx, sy, sxIncr, syIncr: int) =
  var 
    x, y, d = 0
    (left, right, dy, sx, sy) = (left, right, dy, sx, sy)
  # Adjust for clipping
  if dy < buf.clip.y or dy >= buf.clip.y + buf.clip.h: return
  if (d = buf.clip.x - left; d) > 0:
    left += d
    sx += d * sxIncr
    sy += d * syIncr
  if (d = right - (buf.clip.x + buf.clip.w); d) > 0:
    right -= d
  # Does the scaline length go out of bounds of our `s` rect? If so we
  # should adjust the scan line and the source coordinates accordingly
  block checkSourceLeft:
    while true:
      x = sx shr FX_BITS_12
      y = sy shr FX_BITS_12
      if x < sub.x or y < sub.y or x >= sub.x + sub.w or y >= sub.y + sub.h:
        left += 1
        sx += sxIncr
        sy += syIncr
        if left >= right:
          return
      else:
        break checkSourceLeft
  block checkSourceRight:
    while true:
      x = (sx + sxIncr * (right - left)) shr FX_BITS_12
      y = (sy + syIncr * (right - left)) shr FX_BITS_12
      if x < sub.x or y < sub.y or x >= sub.x + sub.w or y >= sub.y + sub.h:
        right -= 1
        if left >= right: return
      else:
        break checkSourceRight
  # Draw
  var dx = left;
  while dx < right:
    blendPixel(
      buf.mode, 
      buf.pixels[dx + dy * buf.w].addr, 
      src.pixels[(sx shr FX_BITS_12) +
      (sy shr FX_BITS_12) * src.w])
    sx += sxIncr
    sy += syIncr
    dx += 1

proc drawBufferRotatedScaled(buf: Buffer, src: Buffer, x, y: int, sub: Rect, t: Transform) =
  var points: array[4, Point] = [(x:0, y:0), (x:0, y:0), (x:0, y:0), (x:0, y:0)]
  let 
    cosr = t.r.cos()
    sinr = t.r.sin()
    absSx = if t.sx < 0.0: -t.sx else: t.sx
    absSy = if t.sy < 0.0: -t.sy else: t.sy
    invX = t.sx < 0
    invY = t.sy < 0
    w = (sub.w.float * absSx).int
    h = (sub.h.float * absSy).int
    q = (t.r * 4.0 / PI2).int
    cosq = (q.float * PI2 / 4.0).cos()
    sinq = (q.float * PI2 / 4.0).sin()
    ox = (if invX: sub.w.float - t.ox else: t.ox) * absSx
    oy = (if invY: sub.h.float - t.oy else: t.oy) * absSy
  # Store rotated corners as points
  points[0].x = x + (cosr * (-ox          ) - sinr * (-oy          )).int
  points[0].y = y + (sinr * (-ox          ) + cosr * (-oy          )).int
  points[1].x = x + (cosr * (-ox + w.float) - sinr * (-oy          )).int
  points[1].y = y + (sinr * (-ox + w.float) + cosr * (-oy          )).int
  points[2].x = x + (cosr * (-ox + w.float) - sinr * (-oy + h.float)).int
  points[2].y = y + (sinr * (-ox + w.float) + cosr * (-oy + h.float)).int
  points[3].x = x + (cosr * (-ox          ) - sinr * (-oy + h.float)).int
  points[3].y = y + (sinr * (-ox          ) + cosr * (-oy + h.float)).int
  # Set named points based on rotation
  let top    = points[(-q + 0) and 3]
  let right  = points[(-q + 1) and 3]
  let bottom = points[(-q + 2) and 3]
  let left   = points[(-q + 3) and 3]
  # Clipped completely off screen?
  if bottom.y < buf.clip.y or top.y  >= buf.clip.y + buf.clip.h: return
  if right.x  < buf.clip.x or left.x >= buf.clip.x + buf.clip.w: return
  # Destination
  var 
    xl, xr = cast[int](top.x shl FX_BITS_12.int)
    il = xdiv((left.x - top.x) shl FX_BITS_12, left.y - top.y).int
    ir = xdiv((right.x - top.x) shl FX_BITS_12, right.y - top.y).int
  # Source
  let
    sxi  = (xdiv(sub.w shl FX_BITS_12, w).float * cos(-t.r)).int
    syi  = (xdiv(sub.h shl FX_BITS_12, h).float * sin(-t.r)).int
  var
    sxoi = (xdiv(sub.w shl FX_BITS_12, left.y - top.y).float * sinq).int
    syoi = (xdiv(sub.h shl FX_BITS_12, left.y - top.y).float * cosq).int
    (sx, sy) = case q
    of 1: (sub.x shl FX_BITS_12,                 ((sub.y + sub.h) shl FX_BITS_12) - 1)
    of 2: (((sub.x + sub.w) shl FX_BITS_12) - 1, ((sub.y + sub.h) shl FX_BITS_12) - 1)
    of 3: (((sub.x + sub.w) shl FX_BITS_12) - 1, sub.y shl FX_BITS_12)
    else: (sub.x shl FX_BITS_12,                 sub.y shl FX_BITS_12)
    # Draw
    dy = if left.y == top.y or right.y == top.y:
        # Adjust for right-angled rotation
        top.y - 1
      else:
        top.y    
  while dy <= bottom.y:
    # Invert source iterators & increments if we are scaled negatively
    let (tsx, tsxi) = if invX:
        (((sub.x * 2 + sub.w) shl FX_BITS_12) - sx - 1, -sxi)
      else:
        (sx, sxi)

    let (tsy, tsyi) = if invY:
        (((sub.y * 2 + sub.h) shl FX_BITS_12) - sy - 1, -syi)
      else:
        (sy, syi)
    # Draw row
    # debugEcho xl shr FX_BITS_12, " ", xr shr FX_BITS_12, " ", dy, " ",
      # tsx, " ", tsy, " ", tsxi, " ", tsyi
    drawScanline(buf, src, sub, cast[int16](xl shr FX_BITS_12), cast[int16](xr shr FX_BITS_12), dy,
      tsx, tsy, tsxi, tsyi);
    sx += sxoi
    sy += syoi
    xl += cast[int](il)
    xr += cast[int](ir)
    dy += 1
    # Modify increments if we've reached the left or right corner */
    if dy == left.y:
      il = xdiv((bottom.x - left.x) shl FX_BITS_12, bottom.y - left.y)
      sxoi = (xdiv(sub.w shl FX_BITS_12, bottom.y - left.y).float *  cosq).int
      syoi = (xdiv(sub.h shl FX_BITS_12, bottom.y - left.y).float * -sinq).int
    if dy == right.y:
      ir = xdiv((bottom.x - right.x) shl FX_BITS_12, bottom.y - right.y)

proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, sub: Rect, t: Transform) =
  var (x, y, t) = (x, y, t)
  # Move rotation value into 0..PI2 range
  t.r = fmod(fmod(t.r, PI2) + PI2, PI2)
  # Not rotated or scaled? apply offset and draw basic
  if t.r == 0 and t.sx == 1 and t.sy == 1:
    x = (x.float - t.ox).int; y = (y.float - t.oy).int
    drawBufferBasic(buf, src, x, y, sub)
  elif t.r == 0:
    drawBufferScaled(buf, src, x, y, sub, t)
  else:
    drawBufferRotatedScaled(buf, src, x, y, sub, t)

proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, sub: Rect) =
  var sub = sub
  if sub.w <= 0 or sub.h <= 0: return
  check(sub.x >= 0 and sub.y >= 0 and sub.x + sub.w <= src.w and sub.y + sub.h <= src.h, "sub rectangle out of bounds")
  drawBufferBasic(buf, src, x, y, sub)

proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, t: Transform) =
  drawBuffer(buf, src, x, y, (0, 0, src.w, src.h), t)

proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int) =
  drawBufferBasic(buf, src, x, y, (0, 0, src.w, src.h))

proc desaturate*(buf: Buffer, amount: int) =
  let amount = clamp(amount, 0, 0xff)
  if amount >= 0xfe:
    # full amount? don't bother with pixel lerping, just write pixel avg
    for p in buf.pixels.mitems:
      let avg = ((p.rgba.r.int + p.rgba.g.int + p.rgba.b.int) * 341) shr 10
      p.rgba.r = avg.uint8
      p.rgba.g = avg.uint8
      p.rgba.b = avg.uint8
  else:
    for p in buf.pixels.mitems:
      let avg = ((p.rgba.r.int + p.rgba.g.int + p.rgba.b.int) * 341) shr 10
      p.rgba.r = lerp(8, p.rgba.r.int, avg, amount).uint8
      p.rgba.g = lerp(8, p.rgba.g.int, avg, amount).uint8
      p.rgba.b = lerp(8, p.rgba.b.int, avg, amount).uint8


proc mask*(buf, mask: Buffer, channel: char) =
  checkBufferSizesMatch(buf, mask)
  let channel = ($channel.toLowerAscii)[0]
  for i in 0..<(buf.w * buf.h):
    case channel
    of 'r':
      buf.pixels[i].rgba.r = ((buf.pixels[i].rgba.r.int * mask.pixels[i].rgba.r.int) shr 8).uint8
    of 'g':
      buf.pixels[i].rgba.g = ((buf.pixels[i].rgba.g.int * mask.pixels[i].rgba.g.int) shr 8).uint8
    of 'b':
      buf.pixels[i].rgba.b = ((buf.pixels[i].rgba.b.int * mask.pixels[i].rgba.b.int) shr 8).uint8
    of 'a':
      buf.pixels[i].rgba.a = ((buf.pixels[i].rgba.a.int * mask.pixels[i].rgba.a.int) shr 8).uint8
    else:
      check(false, "expected channel to be 'r', 'g', 'b' or 'a'")

proc palette*(buf: Buffer, palette: openarray[Pixel]) =
  var pal: array[256, Pixel]
  let ncolors = palette.len()
  check(ncolors != 0, "expected non-empty table")
  # load palette from table
  for i in 0..<256:
    pal[i] = palette[((i * ncolors) shr 8)]
  # convert each pixel to palette color based on its brightest channel
  for p in buf.pixels.mitems:
    let idx = max(max(p.rgba.r, p.rgba.b), p.rgba.g)
    p.rgba.r = pal[idx].rgba.r
    p.rgba.g = pal[idx].rgba.g
    p.rgba.b = pal[idx].rgba.b

proc xorshift64star(x: ptr uint64): uint64 =
  x[] = x[] xor (x[] shr 12)
  x[] = x[] xor (x[] shl 25)
  x[] = x[] xor (x[] shr 27)
  return x[] * 2685821657736338717'u64

proc dissolve*(buf: Buffer, amount: int, seed: uint) =
  let amount = amount.clamp(0, 0xff).uint8
  var seed: uint64 = (1'u64 shl 32) or seed
  for p in buf.pixels.mitems:
    if (xorshift64star(seed.addr) and 0xff) < amount:
      p.rgba.a = 0

proc wave*(buf, src: Buffer, amountX, amountY, scaleX, scaleY, offsetX, offsetY: int) =
  checkBufferSizesMatch(buf, src)
  let
    scaleX = scaleX * FX_UNIT_10
    scaleY = scaleY * FX_UNIT_10
    offsetX = offsetX * FX_UNIT_10
    offsetY = offsetY * FX_UNIT_10
  for y in 0..<buf.h:
    let ox = (fxsin(offsetX + ((y * scaleX) shr FX_BITS_10)) * amountX) shr FX_BITS_10
    for x in 0..<buf.w:
      let oy = (fxsin(offsetY + ((x * scaleY) shr FX_BITS_10)) * amountY) shr FX_BITS_10
      buf.pixels[y * buf.w + x] = src.getPixel(x + ox, y + oy)

proc getChannel(px: Pixel, channel: char): uint8 =
  case channel
  of 'r': return px.rgba.r
  of 'g': return px.rgba.g
  of 'b': return px.rgba.b
  of 'a': return px.rgba.a
  else: check(false, "bad channel")

proc displace*(buf, src, map: Buffer, channelX, channelY: char, scaleX, scaleY: int) =
  let (scaleX, scaleY) = (scaleX * (1 shl 7), scaleY * (1 shl 7))
  checkBufferSizesMatch(buf, src)
  checkBufferSizesMatch(buf, map)
  for y in 0..<buf.h:
    for x in 0..<buf.w:
      let
        cx = ((getChannel(map.pixels[y * buf.w + x], channelX) - (1 shl 7)).int * scaleX) shr 14
        cy = ((getChannel(map.pixels[y * buf.w + x], channelY) - (1 shl 7)).int * scaleY) shr 14
      buf.pixels[y * buf.w + x] = src.getPixel(x + cx, y + cy)


template GET_PIXEL_FAST(buf, x, y: untyped): untyped = buf.pixels[x + y * w]
template BLUR_PIXEL(r, g, b, GET_PIXEL: untyped) =
  # r, g, b = 0
  for ky in -radiusy..radiusy:
    var r2, g2, b2 = 0'u8
    for kx in -radiusx..radiusx:
      p2 = GET_PIXEL(src, x + kx, y + ky)
      r2 += p2.rgba.r
      g2 += p2.rgba.g
      b2 += p2.rgba.b
    r += ((r2.float * dx).int shr 8).uint8
    g += ((g2.float * dx).int shr 8).uint8
    b += ((b2.float * dx).int shr 8).uint8

proc blur*(buf, src: Buffer, radiusx, radiusy: int) =
  let
    w = src.w
    h = src.h
    dx = 256 / (radiusx * 2 + 1)
    dy = 256 / (radiusy * 2 + 1)
    bounds: Rect = (radiusx, radiusy, w - radiusx, h - radiusy)
  checkBufferSizesMatch(buf, src)
  var
    p2: Pixel
    r, g, b = 0'u8
  # do blur
  for y in 0..<h:
    let inBoundsY = y >= bounds.y and y < bounds.h
    for x in 0..<w:
      # are the pixels that will be used in bounds?
      let inBounds = inBoundsY and x >= bounds.x and x < bounds.w
      # blur pixel
      if inBounds:
        BLUR_PIXEL(r, g, b, GET_PIXEL_FAST)
      else:
        BLUR_PIXEL(r, g, b, getPixel)
      # set pixel
      buf.pixels[x + y * buf.h].rgba.r = ((r.float * dy).int shr 8).uint8
      buf.pixels[x + y * buf.h].rgba.g = ((g.float * dy).int shr 8).uint8
      buf.pixels[x + y * buf.h].rgba.b = ((b.float * dy).int shr 8).uint8
      buf.pixels[x + y * buf.h].rgba.a = 0xff

{.pop.}

{.push cdecl, importc.}
proc ttf_new(data: pointer, len: cint): ptr ttf_Font
proc ttf_destroy(self: ptr ttf_Font)
proc ttf_ptsize(self: ptr ttf_Font, ptsize: cfloat)
proc ttf_height(self: ptr ttf_Font): cint
proc ttf_width(self: ptr ttf_Font, str: cstring): cint
proc ttf_render(self: ptr ttf_Font,
  str: cstring, w, h: var cint): pointer
{.pop.}

converter toCFont(font: Font): ptr ttf_Font = font[]

proc finalizer(font: Font) =
  if font != nil: ttf_destroy(font)
  
proc newFont*(data: seq[byte], ptsize: float): Font =
  new result, finalizer
  result[] = ttf_new(data[0].unsafeAddr, data.len.cint)
  if result == nil: raise newException(FontError, "unable to load font")
  result.setSize(ptsize)
    
proc newFontString*(data: string, ptsize: float): Font =
  return newFont(data, ptsize)

proc newFontFile*(filename: string, ptsize: float): Font =
  let data = readFile(filename)
  result = newFontString(data, ptsize)

proc setSize*(font: Font, ptsize: float) =
  ttf_ptsize(font, ptsize.cfloat)

proc getHeight*(font: Font): int =
  return ttf_height(font).int

proc getWidth*(font: Font, txt: string): int =
  return ttf_width(font, txt.cstring).int

{.push checks: off.}
  
proc render*(font: Font, txt: string): Buffer =
  var
    w, h: cint = 0
    txt = txt
  if txt == nil or txt.len == 0: txt = " "
  let bitmap = ttf_render(font, txt.cstring, w, h);
  if bitmap == nil:
    raise newException(FontError, "could not render text")
  # Load bitmap and free intermediate 8bit bitmap
  var pixels = newSeq[byte](w * h)
  copyMem(pixels[0].addr, bitmap, w * h * sizeof(byte))
  result = newBuffer(w, h)
  result.loadPixels8(pixels)

{.pop.}
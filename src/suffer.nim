{.deadCodeElim: on, optimization: speed.}

#  Copyright (c) 2017 emekoi
#
#  This library is free software; you can redistribute it and/or modify it
#  under the terms of the MIT license. See LICENSE for details.
#

import
  strutils,
  sequtils,
  math

when defined(MODE_RGBA):
  const RGB_MASK = 0x00FFFFFF'u32
elif defined(MODE_ARGB):
  const RGB_MASK = 0xFFFFFF00'u32
elif defined(MODE_ABGR):
  const RGB_MASK = 0xFFFFFF00'u32
else:
  const RGB_MASK = 0x00FFFFFF'u32

type
  PixelFormat* = enum
    FMT_BGRA
    FMT_RGBA
    FMT_ARGB
    FMT_ABGR

  BlendMode* = enum
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
    x, y, w, h: int

  DrawMode* = object
    color*: Pixel
    alpha*: uint8
    blend*: BlendMode

  Transform* = tuple
    ox, oy, r, sx, sy: float

  Buffer* = ref object
    mode*: DrawMode
    clip*: Rect
    pixels*: seq[Pixel]
    w*, h*: int

proc pixel*[T](r, g, b, a: T): Pixel
  ## creates a pixel with the color rgba(r, g, b, a)
proc color*[T](r, g, b: T): Pixel
  ## creates a pixel with the color rgba(r, g, b, 255)
proc newBuffer*(w, h: int): Buffer
  ## creates a pixel buffer
proc cloneBuffer*(src: Buffer): Buffer
  ## creates a copy of the buffer
proc loadPixels*(buf: Buffer, src: openarray[SomeUnsignedInt], fmt: PixelFormat)
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
  ## draws a pixel of color `c` at (x, y)
proc drawLine*(buf: Buffer, c: Pixel, x0, y0, x1, y1: int)
  ## draws a line of color `c` through (x0, y0), (x1, y1)
proc drawRect*(buf: Buffer, c: Pixel, x, y, w, h: int)
  ## draws a rect with the dimensions w X h, of color `c` at (x, y)
proc drawBox*(buf: Buffer, c: Pixel, x, y, w, h: int)
  ## draws a box with the dimensions w X h, of color `c` at (x, y)
proc drawCircle*(buf: Buffer, c: Pixel, x, y, r: int)
  ## draws a circle with radius of `r` and color of `c` at (x, y)
proc drawRing*(buf: Buffer, c: Pixel, x, y, r: int)
  ## draws a ring with a radius of `r` and color of `c` at (x, y)
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, sub: Rect, t: Transform)
  ## draw the Buffer `src` at (x, y) with a clipping rect of `sub` and a transform of `t`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, sub: Rect)
  ## draw the Buffer `src` at (x, y) with a clipping rect of `sub`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, t: Transform)
  ## draw the Buffer `src` at (x, y) with a transform of `t`
proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int)
  ## draw the Buffer `src` at (x, y)

# proc box[T](x: T): ref T =
#   new(result); result[] = x

proc `$`*(p: Pixel): string =
  return "($#, ($#, $#, $#, $#))" % [$p.word, $p.rgba.r, $p.rgba.g, $p.rgba.b, $p.rgba.a]

proc lerp[T](bits, a, b, p: T): T =
  return (a + (b - a) * p) shr bits

proc genDivTable(): array[256, array[256, uint8]] =
  for b in 1'u8..255'u8:
    for a in 0'u8..255'u8:
      result[a][b] = uint8((a shl 8) div b)

const PI  = 3.14159265359'f32
const PI2 = 6.28318530718'f32

const FX_BITS = 12
const FX_UNIT = 1 shl FX_BITS
# const FX_MASK = FX_UNIT - 1

const div8Table: array[256, array[256, uint8]] = genDivTable()

type
  Point = tuple
    x, y: int

  RandState = tuple
    x, y, z, w: uint

proc xdiv[T](n, x: T): T =
  if x == 0: return n
  return n div x

proc check(cond: bool, fname: string, msg: string) =
  if not cond:
    write(stderr, "(error)" & fname & " " & msg & "\n")
    quit(QuitFailure)

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

proc color*[T](r, g, b: T): Pixel =
  return pixel(r, g, b, 0xff)

converter fromU32(word: uint32): Pixel =
  result.word = word

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
  check(w > 0, "newBuffer", "expected width of 1 or greater")
  check(h > 0, "newBuffer", "expected height of 1 or greater")
  result.pixels = repeat(color(0, 0, 0), w * h)
  # initialize the buffer
  result.w = w; result.h = h
  result.reset()

proc cloneBuffer*(src: Buffer): Buffer =
  deepCopy(result, src)

proc loadPixels*(buf: Buffer, src: openarray[SomeUnsignedInt], fmt: PixelFormat) =
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
    (inx, iny) = ((FX_UNIT / scalex).int, (FX_UNIT / scaley).int)
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
  var sy = sub.y shl FX_BITS

  for dy in y..<(y + h):
    var
      sx = 0
      dx = x + buf.w * dy
    let
      pixels = src.pixels[((sub.x shr FX_BITS) + src.w * (sy shr FX_BITS))..<src.pixels.len]
      edx = dx + w
    while dx < edx:
      buf.pixels[dx] = pixels[sx shr FX_BITS]
      sx += inx; dx += 1
    sy += iny

proc copyPixels*(buf, src: Buffer, x, y: int, sub: Rect, sx, sy: float) =
  let (sx, sy) = (abs(sx), abs(sy))
  if sx == 0 or sy == 0: return
  if sub.w <= 0 or sub.h <= 0: return
  check sub.x >= 0 and sub.y >= 0 and sub.x + sub.w <= src.w and sub.y + sub.h <= src.h,
    "copyPixels", "sub rectangle out of bounds"
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

proc floodFill(buf: Buffer, c, o: Pixel, x, y: int) =
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
  let alpha = ((s.rgba.a.uint * m.alpha.uint) shr 8).uint8
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
    s.rgba.r = min(d.rgba.r + s.rgba.r, 0xff)
    s.rgba.g = min(d.rgba.g + s.rgba.g, 0xff)
    s.rgba.b = min(d.rgba.b + s.rgba.b, 0xff)
  of BLEND_SUBTRACT:
    s.rgba.r = min(d.rgba.r - s.rgba.r, 0)
    s.rgba.g = min(d.rgba.g - s.rgba.g, 0)
    s.rgba.b = min(d.rgba.b - s.rgba.b, 0)
  of BLEND_MULTIPLY:
    s.rgba.r = (s.rgba.r * d.rgba.r) shr 8
    s.rgba.g = (s.rgba.g * d.rgba.g) shr 8
    s.rgba.b = (s.rgba.b * d.rgba.b) shr 8
  of BLEND_LIGHTEN:
    s = if s.rgba.r + s.rgba.g + s.rgba.b >
          d.rgba.r + d.rgba.g + d.rgba.b: s else: d[]
  of BLEND_DARKEN:
    s = if s.rgba.r + s.rgba.g + s.rgba.b <
          d.rgba.r + d.rgba.g + d.rgba.b: s else: d[]
  of BLEND_SCREEN:
    s.rgba.r = 0xff'u8 - (((0xff'u8 - d.rgba.r) * (0xff'u8 - s.rgba.r)) shr 8'u8)
    s.rgba.g = 0xff'u8 - (((0xff'u8 - d.rgba.g) * (0xff'u8 - s.rgba.g)) shr 8'u8)
    s.rgba.b = 0xff'u8 - (((0xff'u8 - d.rgba.b) * (0xff'u8 - s.rgba.b)) shr 8'u8)
  of BLEND_DIFFERENCE:
    s.rgba.r = abs(s.rgba.r.int8 - d.rgba.r.int8).uint8
    s.rgba.g = abs(s.rgba.g.int8 - d.rgba.g.int8).uint8
    s.rgba.b = abs(s.rgba.b.int8 - d.rgba.b.int8).uint8
  # Write
  if alpha >= 254'u8:
    d[] = s
  elif d.rgba.a >= 254'u8:
    d.rgba.r = lerp(8'u8, d.rgba.r, s.rgba.r, alpha)
    d.rgba.g = lerp(8'u8, d.rgba.g, s.rgba.g, alpha)
    d.rgba.b = lerp(8'u8, d.rgba.b, s.rgba.b, alpha)
  else:
    let
      a = 0xff'u8 - (((0xff'u8 - d.rgba.a) * (0xff'u8 - alpha)) shr 8)
      z = (d.rgba.a * (0xff'u8 - alpha)) shr 8
    d.rgba.r = div8Table[((d.rgba.r * z) shr 8) + ((s.rgba.r * alpha) shr 8)][a]
    d.rgba.g = div8Table[((d.rgba.g * z) shr 8) + ((s.rgba.g * alpha) shr 8)][a]
    d.rgba.b = div8Table[((d.rgba.b * z) shr 8) + ((s.rgba.b * alpha) shr 8)][a]
    d.rgba.a = a

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
    (x, y, w, h) = (x, y, w, h)
    r = (x: x, y: y, w: w, h: h)
  clipRect(r.addr, buf.clip)
  y = r.h
  for y in countdown(r.h - 1, 0):
    for x in countdown(r.w - 1, 0):
      blendPixel(buf.mode, buf.pixels[(r.x + (r.y + y) * buf.w) + x].addr, c)

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
    osx = if t.sx < 0: (sub.w shl FX_BITS) - 1 else: 0
    osy = if t.sy < 0: (sub.h shl FX_BITS) - 1 else: 0
    ix = ((sub.w shl FX_BITS).float / t.sx / sub.w.float).int
    iy = ((sub.h shl FX_BITS).float / t.sy / sub.h.float).int
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
                 src.pixels[(sub.x + (sx shr FX_BITS)) +
                             (sub.y + (sy shr FX_BITS)) * src.w])
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
      x = sx shr FX_BITS
      y = sy shr FX_BITS
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
      x = (sx + sxIncr * (right - left)) shr FX_BITS
      y = (sy + syIncr * (right - left)) shr FX_BITS
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
      src.pixels[(sx shr FX_BITS) +
      (sy shr FX_BITS) * src.w])
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
    xl, xr = top.x shl FX_BITS
    il = xdiv((left.x - top.x) shl FX_BITS, left.y - top.y)
    ir = xdiv((right.x - top.x) shl FX_BITS, right.y - top.y)
  # Source
  let
    sxi  = (xdiv(sub.w shl FX_BITS, w).float * cos(-t.r)).int
    syi  = (xdiv(sub.h shl FX_BITS, h).float * sin(-t.r)).int
  var
    sxoi = (xdiv(sub.w shl FX_BITS, left.y - top.y).float * sinq).int
    syoi = (xdiv(sub.h shl FX_BITS, left.y - top.y).float * cosq).int
    (sx, sy) = case q
    of 1: (sub.x shl FX_BITS,                 ((sub.y + sub.h) shl FX_BITS) - 1)
    of 2: (((sub.x + sub.w) shl FX_BITS) - 1, ((sub.y + sub.h) shl FX_BITS) - 1)
    of 3: (((sub.x + sub.w) shl FX_BITS) - 1, sub.y shl FX_BITS)
    else: (sub.x shl FX_BITS,                 sub.y shl FX_BITS)
    # Draw
    dy = if left.y == top.y or right.y == top.y:
        # Adjust for right-angled rotation
        top.y - 1
      else:
        top.y
  while dy <= bottom.y:
    # Invert source iterators & increments if we are scaled negatively
    let (tsx, tsxi) = if invX:
        (((sub.x * 2 + sub.w) shl FX_BITS) - sx - 1, -sxi)
      else:
        (sx, sxi)

    let (tsy, tsyi) = if invY:
        (((sub.y * 2 + sub.h) shl FX_BITS) - sy - 1, -syi)
      else:
        (sy, syi)
    # Draw row
    drawScanline(buf, src, sub, xl shr FX_BITS, xr shr FX_BITS, dy,
      tsx, tsy, tsxi, tsyi);
    sx += sxoi
    sy += syoi
    xl += il
    xr += ir
    dy += 1
    # Modify increments if we've reached the left or right corner */
    if dy == left.y:
      il = xdiv((bottom.x - left.x) shl FX_BITS, bottom.y - left.y)
      sxoi = (xdiv(sub.w shl FX_BITS, bottom.y - left.y).float *  cosq).int
      syoi = (xdiv(sub.h shl FX_BITS, bottom.y - left.y).float * -sinq).int
    if dy == right.y:
      ir = xdiv((bottom.x - right.x) shl FX_BITS, bottom.y - right.y)

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
  check(sub.x >= 0 and sub.y >= 0 and sub.x + sub.w <= src.w and sub.y + sub.h <= src.h,
        "drawBuffer", "sub rectangle out of bounds")
  drawBufferBasic(buf, src, x, y, sub)

proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int, t: Transform) =
  drawBuffer(buf, src, x, y, (0, 0, src.w, src.h), t)

proc drawBuffer*(buf: Buffer, src: Buffer, x, y: int) =
  drawBufferBasic(buf, src, x, y, (0, 0, src.w, src.h))

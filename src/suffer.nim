{.deadCodeElim: on.}

#
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
  const RGB_MASK = 0x00FFFFFF
elif defined(MODE_ARGB):
  const RGB_MASK = 0xFFFFFF00
elif defined(MODE_ABGR):
  const RGB_MASK = 0xFFFFFF00
else:
  const RGB_MASK = 0x00FFFFFF

type
  PixelFormat* = enum
    BGRA
    RGBA
    ARGB
    ABGR

  BlendMode* = enum
    ALPHA
    COLOR
    ADD
    SUBTRACT
    MULTIPLY
    LIGHTEN
    DARKEN
    SCREEN
    DIFFERENCE

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

  BufferOwned = ref object
    mode*: DrawMode
    clip*: Rect
    pixels*: seq[Pixel]
    w*, h*: int

  BufferShared = ref object
    mode*: DrawMode
    clip*: Rect
    pixels*: pointer
    w*, h*: int

  Buffer* = BufferOwned | BufferShared

proc pixel*[T](r, g, b, a: T): Pixel
  ## creates a pixel with the color rgba(r, g, b, a)
proc color*[T](r, g, b: T): Pixel
  ## creates a pixel with the color rgba(r, g, b, 255)
proc color*(): Pixel
  ## creates a black pixel
proc newBuffer*(w, h: int): Buffer
  ## creates a pixel buffer
proc newBufferShared*(pixels: pointer, w, h: int): Buffer
  ## creates a pixel buffer that shares its pixels with another object
proc cloneBuffer*(src: Buffer): Buffer
  ## creates a copy of the buffer
proc loadPixels*(buf: Buffer, src: openarray[uint8], fmt: PixelFormat)
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
proc copyPixels*(buf, src: Buffer, x, y: int, sub: Rect, sx, sy: var float)
  ## copies the pixels from one buffer to another
proc copyPixels*(buf, src: Buffer, x, y: int, sx, sy: var float)
  ## copies the pixels from one buffer to another
proc noise*(buf: Buffer, seed: uint, low: int, high: int, grey: int)
  ## fills the buffer with psuedo-random noise in the form of pixels
proc floodFill*(buf: Buffer, c: Pixel, x: int, y: int)
  ## fills the pixel (x, y) and all surrounding pixels of the same color with the color `c`
proc drawPixel*(buf: Buffer, c: Pixel, x: int, y: int)
  ## draws a pixel of color `c` at (x, y)
proc drawLine*(buf: Buffer, c: Pixel, x0: int, y0: int, x1: int, y1: int)
  ## draws a line of color `c` through (x0, y0), (x1, y1) 
proc drawRect*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int)
  ## draws a rect with the dimensions w X h, of color `c` at (x, y)
proc drawBox*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int)
  ## draws a box with the dimensions w X h, of color `c` at (x, y) 
proc drawCircle*(buf: Buffer, c: Pixel, x: int, y: int, r: int)
  ## draws a circle with radius of `r` and color of `c` at (x, y)
proc drawRing*(buf: Buffer, c: Pixel, x: int, y: int, r: int)
  ## draws a ring with a radius of `r` and color of `c` at (x, y)
proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, sub: Rect, t: Transform)
  ## draw the Buffer `src` at (x, y) with a clipping rect of `sub` and a transform of `t`
proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, sub: Rect)
  ## draw the Buffer `src` at (x, y) with a clipping rect of `sub`
proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, t: Transform)
  ## draw the Buffer `src` at (x, y) with a transform of `t`
proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int)
  ## draw the Buffer `src` at (x, y)

# proc box[T](x: T): ref T =
#   new(result); result[] = x

proc `[]`(p: pointer, offset: int): pointer =
  return cast[pointer](uint(cast[int](p) + offset))

proc lerp[T](bits, a, b, p: T): T =
  return (a + (b - a) * p) shr bits

proc genDivTable(): array[256, array[256, uint8]] =
  for b in 1'u8..255'u8:
    for a in 0'u8..255'u8:
      result[a][b] = uint8((a shl 8) div b)

const PI  = 3.14159265359
const PI2 = 6.28318530718

const FX_BITS = 12
const FX_UNIT = 1 shl FX_BITS
const FX_MASK = FX_UNIT - 1

const div8Table: array[256, array[256, uint8]] = genDivTable()

type
  Point = tuple
    x, y: int

  RandState = ref tuple
    x, y, z, w: uint

proc xdiv[T](n, x: T): T =
  if x == 0: return n
  return n div x

proc check(cond: bool, fname: string, msg: string) =
  if not cond: 
    write(stderr, "(error)" & fname & " " & msg & "\n")
    quit(QuitFailure)

proc rand128init(seed: uint): RandState =
  result = new RandState
  result.x = (seed and 0xff000000'u) or 1'u
  result.y = seed and 0xff0000'u
  result.z = seed and 0xff00'u
  result.w = seed and 0xff'u

proc rand128(s: RandState): uint =
  result = s.x xor (s.x shl 11'u)
  s.x = s.y; s.y = s.z; s.z = s.w
  s.w = s.w xor (s.w shr 19) xor result xor (result shr 8)
  return s.w

proc pixel*[T](r, g, b, a: T): Pixel =
  result.rgba.r = uint8(clamp(r, 0, 0xff))
  result.rgba.g = uint8(clamp(g, 0, 0xff))
  result.rgba.b = uint8(clamp(b, 0, 0xff))
  result.rgba.a = uint8(clamp(a, 0, 0xff))

proc color*[T](r, g, b: T): Pixel =
  return pixel(r, g, b, 0xff)

proc color*(): Pixel =
  return color(0, 0, 0)

converter fromU32(word: uint32): Pixel =
  result.word = word

proc clipRect(r: var Rect, to: Rect) =
  let
    x1 = max(r.x, to.x)
    y1 = max(r.y, to.y)
    x2 = min(r.x + r.w, to.x + to.w)
    y2 = min(r.y + r.h, to.y + to.h)
  r.x = x1
  r.y = y1
  r.w = max(x2 - x1, 0)
  r.h = max(y2 - y1, 0)


proc clipRectAndOffset(r: var Rect, x, y: var int, to: Rect) =
  var d: int
  if (d = to.x - x; d) > 0:
    x += d; r.w -= d; r.x += d
  if (d = to.y - y; d) > 0:
    y += d; r.h -= d; r.y += d
  if (d = (x + r.w) - (to.x + to.w); d) > 0: r.w -= d
  if (d = (y + r.h) - (to.y + to.h); d) > 0: r.h -= d

proc initBuffer(buf: Buffer, w, h: int) =
  buf.w = w; buf.h = h
  buf.reset()

proc newBuffer*(w, h: int): Buffer =
  result = new BufferOwned
  check(w > 0, "newBuffer", "expected width of 1 or greater")
  check(h > 0, "newBuffer", "expected height of 1 or greater")
  result.pixels = repeat(color(0, 0, 0), w * h)
  # initialize the buffer
  initBuffer(result, w, h)

proc newBufferShared*(pixels: pointer, w, h: int): Buffer =
  result = new BufferShared
  result.pixels = pixels
  # initialize the buffer
  initBuffer(result, w, h)

proc cloneBuffer*(src: Buffer): Buffer =
  deepCopy(result, src)

proc loadPixels*(buf: Buffer, src: openarray[uint8], fmt: PixelFormat) =
  var sr, sg, sb, sa: int
  let sz = (buf.w * buf.h) - 1
  case fmt:
    of BGRA: (sr = 16; sg =  8; sb =  0; sa = 24;)
    of RGBA: (sr =  0; sg =  8; sb = 16; sa = 24;)
    of ARGB: (sr =  8; sg = 16; sb = 24; sa =  0;)
    of ABGR: (sr = 24; sg = 16; sb =  8; sa =  0;)
  
  for i in countdown(sz, 0):
    buf.pixels[i].rgba.r = (src[i] shr sr) and 0xff
    buf.pixels[i].rgba.g = (src[i] shr sg) and 0xff
    buf.pixels[i].rgba.b = (src[i] shr sb) and 0xff
    buf.pixels[i].rgba.a = (src[i] shr sa) and 0xff

proc loadPixels8*(buf: Buffer, src: openarray[uint8], pal: openarray[Pixel]) =
  let sz = (buf.w * buf.h) - 1
  for i in countdown(sz, 0):
    buf.pixels[i] = pal[src[i]]

proc loadPixels8*(buf: Buffer, src: openarray[uint8]) =
  let sz = (buf.w * buf.h) - 1
  for i in countdown(sz, 0):
    buf.pixels[i] = pixel(0xff'u8, 0xff'u8, 0xff'u8, src[i])

proc setBlend*(buf: Buffer, blend: BlendMode) =
  buf.mode.blend = blend

proc setAlpha*[T](buf: Buffer, alpha: T) =
  buf.mode.alpha = clamp(alpha, 0, 0xff)  

proc setColor*(buf: Buffer, c: Pixel) =
  buf.mode.color.word = c.word & RGB_MASK 

proc setClip*(buf: Buffer, r: Rect) =
  buf.clip = r
  var r = Rect(0, 0, buf.w, buf.h)
  clipRect(buf.clip, r)

proc reset*(buf: Buffer) =
  buf.setBlend(ALPHA)
  buf.setAlpha(0xff)
  buf.setColor color(0xff, 0xff, 0xff)
  buf.setClip Rect(0, 0, buf.w, buf.h)

proc clear*(buf: Buffer, c: Pixel) =
  for pixel in mitems(buf.pixels):
    pixel = c

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
  clipRectAndOffset(sub, x, y, buf.clip)
  # Clipped off screen?
  if sub.w <= 0 or sub.h <= 0: return
  # Copy pixels
  for i in 0..<sub.h:
    copyMem(
      (case buf:
        of BufferOwned:
          addr buf.pixels[0]
        of BufferShared:
          buf.pixels)[x + (y + i) * buf.w],
      (case src:
        of BufferOwned:
          addr src.pixels[0]
        of BufferShared:
          src.pixels)[sub.x + (sub.y + i) * src.w],
      sub.w * sizeof(buf.pixel[]))

proc copyPixelsScaled(buf, src: Buffer, x, y: int, sub: Rect, scalex, scaley: float) =
  var
    d: int
    (w, h) = (sub.w * scalex, sub.h * scaley)
    (inx, iny) = (FX_UNIT / scalex, FX_UNIT / scaley)
  # Clip to destination buffer  
  if (d = buf.clip.x - x; d) > 0:
    x += d; sub.x += d / scalex; w -= d;
  if (d = buf.clip.y - y; d) > 0:
    y += d; sub.y += d / scaley; h -= d;
  if (d = (x + w) - (buf.clip.x + buf.clip.w); d) > 0: w -= d
  if (d = (y + h) - (buf.clip.y + buf.clip.h); d) > 0: h -= d
  # Clipped offscreen
  if w == 0 or h == 0: return
  # Draw
  var sy = sub.y shl FX_BITS
  for dy in dy..<(y + h):
    var
      sx = 0
      dx = x + buf.w * dy
    let
      pixels = (case src:
        of BufferOwned:
          addr src.pixels[0]
        of BufferShared:
          src.pixels)[(sub.x shr FX_BITS) + src.w * (sy shr FX_BITS)]
      edx = dx + w
    while dx < edx:
      buf.pixels[(dx += 1; dx)] = pixels[sx shr FX_BITS]
      sx += inx
    sy += iny

proc copyPixels*(buf, src: Buffer, x, y: int, sub: Rect, sx, sy: var float) =
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

proc copyPixels*(buf, src: Buffer, x, y: int, sx, sy: var float) =
  copyPixels(buf, src, x, y, Rect(0, 0, src.w, src.h), sx, sy)

proc noise*(buf: Buffer, seed: uint, low: int, high: int, grey: int) =
  var 
    s = rand128init(seed)
    low = clamp(low, 0, 0xfe)
    high = clamp(high, low + 1, 0xff)
  if grey:
    for i in countdown(buf.w * buf.h, 0):
      buf.pixels[i].rgba.r = low + rand128(&s) % (high - low)
      buf.pixels[i].rgba.g = buf.pixels[i].rgba.r
      buf.pixels[i].rgba.b = buf.pixels[i].rgba.r
      buf.pixels[i].rgba.a = 0xff
  else:
    for i in countdown(buf.w * buf.h, 0):
      buf.pixels[i].word = rand128(&s) or (not RGB_MASK)
      buf.pixels[i].rgba.r = low + buf.pixels[i].rgba.r % (high - low)
      buf.pixels[i].rgba.g = low + buf.pixels[i].rgba.g % (high - low)
      buf.pixels[i].rgba.b = low + buf.pixels[i].rgba.b % (high - low)

proc floodFill(buf: Buffer, c, o: Pixel, x, y: int) =
  if
    y < 0 or y >= buf.h or x < 0 or x >= buf.wor||
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
    floodFill(buf, c, o, il, y - 1)
    floodFill(buf, c, o, il, y + 1)
    il += 1

proc floodFill*(buf: Buffer, c: Pixel, x: int, y: int) =
  floodFill(buf, c, buf.getPixel(x, y), x, y)

proc drawPixel*(buf: Buffer, c: Pixel, x: int, y: int) =
  discard

proc drawLine*(buf: Buffer, c: Pixel, x0: int, y0: int, x1: int, y1: int) =
  discard

proc drawRect*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int) =
  discard

proc drawBox*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int) =
  discard

proc drawCircle*(buf: Buffer, c: Pixel, x: int, y: int, r: int) =
  discard

proc drawRing*(buf: Buffer, c: Pixel, x: int, y: int, r: int) =
  discard

proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, sub: Rect, t: Transform) =
  discard

proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, sub: Rect) =
  discard

proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, t: Transform) =
  discard

proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int) =
  discard
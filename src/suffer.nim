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

proc box[T](x: T): ref T =
  new(result); result[] = x

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

# proc copyPixels*(buf: Buffer, src: Buffer, x: int, y: int, sub:  Rect, sx: float, sy: float)
# proc noise*(buf: Buffer, seed: cuint, low: int, high: int, grey: int)
# proc floodFill*(buf: Buffer, c: Pixel, x: int, y: int)
# proc drawPixel*(buf: Buffer, c: Pixel, x: int, y: int)
# proc drawLine*(buf: Buffer, c: Pixel, x0: int, y0: int, x1: int, y1: int)
# proc drawRect*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int)
# proc drawBox*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int)
# proc drawCircle*(buf: Buffer, c: Pixel, x: int, y: int, r: int)
# proc drawRing*(buf: Buffer, c: Pixel, x: int, y: int, r: int)
# proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, sub:  Rect, t:  Transform)

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
  if to.x - x > 0:
    let d = to.x - x
    x += d; r.w -= d; r.x += d;
  if to.y - y > 0:
    let d = to.y - y
    y += d; r.h -= d; r.y += d;
  if (x + r.w) - (to.x + to.w) > 0:
    r.w -= (x + r.w) - (to.x + to.w)
  if (y + r.h) - (to.y + to.h) > 0:
    r.h -= (y + r.h) - (to.y + to.h)

proc initBuffer(buf: Buffer, w, h: int) =
  buf.w = w; buf.h = h
  buf.reset()

proc newBuffer*(w, h: int): Buffer =
  result = new BufferOwned
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
          buf.pixels) + (x + (y + i) * buf.w),
      (case src:
        of BufferOwned:
          addr src.pixels[0]
        of BufferShared:
          src.pixels) + (sub.x + (sub.y + i) * src.w),
      sub.w * sizeof(buf.pixel[]))

# proc copyPixels*(buf: Buffer, src: Buffer, x: int, y: int, sub:  Rect, sx: float, sy: float)
# proc noise*(buf: Buffer, seed: cuint, low: int, high: int, grey: int)
# proc floodFill*(buf: Buffer, c: Pixel, x: int, y: int)
# proc drawPixel*(buf: Buffer, c: Pixel, x: int, y: int)
# proc drawLine*(buf: Buffer, c: Pixel, x0: int, y0: int, x1: int, y1: int)
# proc drawRect*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int)
# proc drawBox*(buf: Buffer, c: Pixel, x: int, y: int, w: int, h: int)
# proc drawCircle*(buf: Buffer, c: Pixel, x: int, y: int, r: int)
# proc drawRing*(buf: Buffer, c: Pixel, x: int, y: int, r: int)
# proc drawBuffer*(buf: Buffer, src: Buffer, x: int, y: int, sub:  Rect, t:  Transform)

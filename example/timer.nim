#  Copyright (c) 2017 emekoi
#
#  This library is free software; you can redistribute it and/or modify it
#  under the terms of the MIT license. See LICENSE for details.
#

import
  sdl2/sdl,
  math

var
  last = 0.0
  delta = 0.0
  average = 0.0
  avgTimer = 0.0
  avgAcc = 1.0
  avgCount = 1.0


proc step*() =
  let now = (sdl.getTicks() div 1000).float
  if last == 0: last = now
  delta = now - last
  last = now
  avgTimer = avgTimer - delta
  avgAcc = avgAcc + delta
  avgCount = avgCount + 1
  if avgTimer <= 0:
    average = avgAcc / avgCount
    avgTimer = avgTimer + 1
    avgCount = 0
    avgAcc = 0

proc getDelta*(): float =
  return delta


proc getAverage*(): float =
  return average

proc getFps*(): int32 =
  return int32((1 / average + 0.5).floor())
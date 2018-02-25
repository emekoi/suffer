#  Copyright (c) 2017 emekoi
#
#  This library is free software; you can redistribute it and/or modify it
#  under the terms of the MIT license. See LICENSE for details.
#

{.compile: "stb_impl.c".}

when defined(Posix) and not defined(haiku):
  {.passl: "-lm".}

const
  STBI_default*    = 0
  STBI_grey*       = 1
  STBI_grey_alpha* = 2
  STBI_rgb*        = 3
  STBI_rgb_alpha*  = 4

proc stbi_failure_reason_c(): cstring
  {.cdecl, importc: "stbi_failure_reason".}

proc stbi_failure_reason*(): string =
  return $stbi_failure_reason_c()

proc stbi_image_free*(retval_from_stbi_load: pointer)
  {.cdecl, importc: "stbi_image_free".}

proc stbi_load_from_memory*(
  buffer: ptr cuchar,
  len: cint,
  x, y, channels_in_file: var cint,
  desired_channels: cint
): ptr cuchar {.cdecl, importc: "stbi_load_from_memory".}


#  Copyright (c) 2017 emekoi
#
#  This library is free software; you can redistribute it and/or modify it
#  under the terms of the MIT license. See LICENSE for details.
#

import tables, ../src/suffer

const 
  Palettes* = {
    "oldschool":  [ color("#183442"), color("#529273"), color("#ADD794"), color("#EFFFDE") ],
    "tweet":      [ color("#292F33"), color("#0084B4"), color("#E5F2F7"), color("#FFFFFF") ],
    "7soul":      [ color("#1A111F"), color("#9C4CB0"), color("#95C7E9"), color("#FCFFFF") ],
    "retrostark": [ color("#34342C"), color("#70695A"), color("#AD9B5C"), color("#ECD893") ],
    "love":       [ color("#232323"), color("#91505A"), color("#CEB1AF"), color("#E0D7C3") ],
    "tokyo":      [ color("#191919"), color("#1E5D7C"), color("#F32860"), color("#FFFFFF") ],
    "hacker":     [ color("#A1FFC0"), color("#2CAF50"), color("#052312"), color("#1F4E34") ],
    "electro":    [ color("#FFFFFF"), color("#FF4D9B"), color("#151E2F"), color("#7000FF") ],
  }.toTable()

  PaletteNames* = [
    "oldschool",
    "tweet",
    "7soul",
    "retrostark",
    "love",
    "tokyo",
    "hacker",
    "electro",
  ]

  PaletteCount* = PaletteNames.len
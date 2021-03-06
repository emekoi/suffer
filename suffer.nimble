# Package

version       = "0.2.0"
author        = "emekoi"
description   = "a nim library for drawing 2d shapes, text, and images to 32bit software pixel buffers"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["docs", "example"]

# Dependencies

requires "nim >= 1.2.2"

# Build Tasks

task docs, "generate documentation and place it in the docs folder":
  mkDir "docs"
  for file in listFiles(srcDir):
    if file[^4..<file.len] == ".nim":
      exec "nimble doc2 -o:docs/" & file[4..^5] & ".html " & file

task example, "runs the (bad) included example":
  withDir "example":
    exec "mkdir -p bin"
    exec "nim c -r example.nim"

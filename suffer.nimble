# Package

version       = "0.1.0"
author        = "emekoi"
description   = "a nim library for drawing 2d shapes and images to 32bit software pixel buffers"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["docs, private"]

# Dependencies

requires "nim >= 0.17.2"


# Build Tasks

task docs, "generate documentation and place it in the docs folder":
  mkDir "docs"
  for file in listFiles(srcDir):
    if file[^4..<file.len] == ".nim":
      exec "nimble doc2 -o:docs/" & file[4..^5] & ".html " & file 
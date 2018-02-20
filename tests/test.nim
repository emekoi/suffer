import 
  sdl2/sdl,
  ../src/suffer,
  random, math
  
from timer import nil

#########
# TESTS #
#########

var 
  testBuffer = newBuffer(128, 128)
  ticks = 0.0
  rot = 0.0

proc random_pixel(): Pixel =
  result.rgba.r = random(255).uint8 + 1'u8
  result.rgba.g = random(255).uint8 + 1'u8
  result.rgba.b = random(255).uint8 + 1'u8
  result.rgba.a = random(255).uint8 + 1'u8

proc random_color(): Pixel =
  result = random_pixel()
  result.rgba.a = 255

proc draw_noise(buf: Buffer) =
  discard testBuffer
  let b = newBuffer(128, 128)
  b.noise(random(int32.high).uint32, 0, 255, false)
  buf.copyPixels(b, 0, 0, 4.0, 4.0)

proc draw_flood_fill(buf: Buffer) =
  discard testBuffer
  buf.floodFill(random_pixel(), 0, 0)

proc draw_pixel(buf: Buffer) =
  testBuffer.drawPixel(random_color(), random(128), random(128))
  buf.drawBuffer(testBuffer, 0, 0, (0.0, 0.0, 0.0, 4.0, 4.0, ))

proc draw_line(buf: Buffer) =
  discard testBuffer
  buf.drawLine(random_color(), 512, 512, 0, 0)

proc draw_rect(buf: Buffer) =
  discard testBuffer
  buf.drawRect(random_color(), 0, 0, 255, 255)

proc draw_box(buf: Buffer) =
  discard testBuffer
  buf.drawBox(random_color(), 0, 0, 255, 255)

proc draw_circle(buf: Buffer) =
  discard testBuffer
  let d = (512 div 2) - (255 div 2)
  buf.drawCircle(random_color(), d, d, 255)

proc draw_ring(buf: Buffer) =
  discard testBuffer
  let d = (512 div 2) - (255 div 2)
  buf.draw_ring(random_color(), d, d, 255)

proc draw_buffer_basic(buf: Buffer) =
  let d = (512 div 2) - (255 div 2)
  testBuffer.noise(random(int32.high).uint32, 0, 255, true)
  testBuffer.drawLine(random_color(), 128, 128, 0, 0)
  testBuffer.drawRect(random_color(), 0, 0, 64, 64)
  testBuffer.drawBox(random_color(), 0, 0, 128, 128)
  testBuffer.drawCircle(random_color(), d, d, 16)
  testBuffer.drawRing(random_color(), d, d, 96)
  testBuffer.drawPixel(random_color(), 128, 128)
  buf.drawBuffer(testBuffer, 10, 15)


proc draw_buffer_scaled(buf: Buffer) =
  let d = (512 div 2) - (255 div 2)
  testBuffer.noise(random(int32.high).uint32, 0, 255, true)
  testBuffer.drawLine(random_color(), 128, 128, 0, 0)
  testBuffer.drawRect(random_color(), 0, 0, 64, 64)
  testBuffer.drawBox(random_color(), 0, 0, 128, 128)
  testBuffer.drawCircle(random_color(), d, d, 16)
  testBuffer.drawRing(random_color(), d, d, 96)
  testBuffer.drawPixel(random_color(), 128, 128)
  buf.drawBuffer(testBuffer, -40, -23, (0.0, 0.0, 0.0, 3.0, 2.0))


# proc draw_buffer_rotate_scaled(buf: Buffer) =
#   let d = (512 div 2) - (255 div 2)
#   testBuffer.noise(random(int32.high).uint32, 0, 255, true)
#   testBuffer.drawLine(random_color(), 128, 128, 0, 0)
#   testBuffer.drawRect(random_color(), 0, 0, 64, 64)
#   testBuffer.drawBox(random_color(), 0, 0, 128, 128)
#   testBuffer.drawCircle(random_color(), d, d, 16)
#   testBuffer.drawRing(random_color(), d, d, 96)
#   testBuffer.drawPixel(random_color(), 128, 128)
#   ticks = fmod((ticks + 0.2),  3.0); rot += 1.0;
#   buf.drawBuffer(testBuffer, 256, 256,
#     (63.0, 63.0, rot.degToRad(),
#     2.0 * ticks.sin() + 1.0,
#     2.0 * ticks.sin() + 1.0))

const
  Title = "drawing-test | "
  ScreenW = 512
  ScreenH = 512
  Tests = [
    draw_noise,
    draw_flood_fill,
    draw_pixel,
    draw_line,
    draw_rect,
    draw_box,
    draw_circle,
    draw_ring,
    draw_buffer_basic,
    draw_buffer_scaled,
  ]
  max_fps = 60.0
  total_tests = Tests.len()

type
  App = ref object
    window*: sdl.Window
    canvas*: Buffer
    
proc init(app: App): bool =
  randomize()
  if sdl.init(sdl.InitVideo) != 0:
    quit "ERROR: can't initialize SDL: " & $sdl.getError()
    return false
  app.canvas = newBuffer(ScreenW, ScreenH)
  # Create window
  app.window = sdl.createWindow(
    Title,
    sdl.WindowPosUndefined,
    sdl.WindowPosUndefined,
    ScreenW, ScreenH, 0)
  if app.window == nil:
    quit "ERROR: can't create window: " & $sdl.getError()
    return false
  sdl.logInfo sdl.LogCategoryApplication, "SDL initialized successfully"
  return true

proc exit(app: App) =
  app.window.destroyWindow()
  sdl.quit()
  sdl.logInfo sdl.LogCategoryApplication, "SDL shutdown completed"

proc draw(app: App, cb: proc(canvas: Buffer)) =
  let screen = app.window.getWindowSurface
  if screen != nil and screen.mustLock():
    if screen.lockSurface() != 0:
      quit "ERROR: couldn't lock screen: " & $sdl.getError()
  cb(app.canvas)
  copyMem(screen.pixels, app.canvas.pixels[0].addr, (ScreenW * ScreenH) * sizeof(Pixel))
  if screen != nil and screen.mustLock(): screen.unlockSurface()
  if app.window.updateWindowSurface() != 0:
    quit "ERROR: couldn't update screen: " & $sdl.getError()

proc update(app: App) =
  var
    current_test = 0
    last = 0.0
    e: sdl.Event
    
  while true:
    app.window.setWindowTitle(Title & $timer.getFps() & " fps")
    while sdl.pollEvent(addr(e)) != 0:
      case e.kind
      of sdl.Quit:
        return
      of KeyDown:
        sdl.logInfo(sdl.LogCategoryApplication, "Pressed %s", $e.key.keysym.sym)
        case e.key.keysym.sym
        of sdl.K_Escape: return
        of sdl.K_LEFT:
          current_test = 
            if current_test == 0:
              total_tests - 1
            else:
              current_test - 1
        of sdl.K_RIGHT:
          current_test = (current_test + 1) mod total_tests
        else: discard
      else: discard
    
    timer.step()
    app.canvas.clear(color(0, 0, 0))
    app.draw(Tests[current_test])
    let step = 1.0 / max_fps
    let now = sdl.getTicks().float / 1000.0
    let wait = step - (now - last);
    last += step
    if wait > 0:
      sdl.delay((wait * 1000.0).uint32)
    else:
      last = now

########
# MAIN #
########

var
  app = App(window: nil, canvas: nil)

if init(app):
  app.update()
  
# Shutdown
app.exit()
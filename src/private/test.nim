

import sdl2/sdl


const
  Title = "SDL2 App"
  ScreenW = 640 # Window width
  ScreenH = 480 # Window height
  WindowFlags = 0


type
  App= ref object
    window*: sdl.Window # Window pointer


# Initialization sequence
proc init(app: App): bool =
  # Init SDL
  if sdl.init(sdl.InitVideo) != 0:
    echo "ERROR: Can't initialize SDL: ", sdl.getError()
    return false

  # Create window
  app.window = sdl.createWindow(
    Title,
    sdl.WindowPosUndefined,
    sdl.WindowPosUndefined,
    ScreenW,
    ScreenH,
    WindowFlags)
  if app.window == nil:
    echo "ERROR: Can't create window: ", sdl.getError()
    return false

  echo "SDL initialized successfully"
  return true

# Shutdown sequence
proc exit(app: App) =
  app.window.destroyWindow()
  sdl.quit()
  echo "SDL shutdown completed"


########
# MAIN #
########

var
  app = App(window: nil)

if init(app):
  let prt =  app.window.getWindowSurface().pixels

  # Pause for two seconds
  sdl.delay(2000)

# Shutdown
exit(app)

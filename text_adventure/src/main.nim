# the following code is taken from https://gist.github.com/ftsf/464aa66e1782bbd803ada33615bdc212 and is placeholder

import nico
import nico/utils

var textInputString: string
var textInputEventListener: EventListener
var step = 0
var frame: uint
var scale = 4

proc gameInit() =
  loadFont(0, "compass-pro-v1.1.png")
  setFont(0)
  textInputString = ""
  textInputEventListener = addEventListener(proc(ev: Event): bool =
    if ev.kind == ekTextInput:
      textInputString &= ev.text
  )
  startTextInput()

proc gameUpdate(dt: float32) =
  frame.inc()
  if frame mod 5 == 0:
    step += 1

  if keyp(K_F1):
    if scale > 1:
      # shrink text size
      scale -= 1
      let windowWidth = (screenWidth.float32 * getScreenScale()).int
      let windowHeight = (screenHeight.float32 * getScreenScale()).int
      setTargetSize(windowWidth div scale, windowHeight div scale)
  if keyp(K_F2):
    # increase text size
    scale += 1
    let windowWidth = (screenWidth.float32 * getScreenScale()).int
    let windowHeight = (screenHeight.float32 * getScreenScale()).int
    setTargetSize(windowWidth div scale, windowHeight div scale)

proc gameDraw() =
  cls()
  setColor(7)
  boxfill(4,4, screenWidth - 8, fontHeight() * 3 + 2)
  setColor(1)
  richPrintWrap("You are standing in front of a <8>house</>.", 6, 6, screenWidth - 12, step = step)
  setColor(7)
  richPrintWrap(textInputString, 1, screenHeight - fontHeight() - 2, screenWidth - 2)

# initialization
nico.init("nico", "test")

# we want a dynamic sized screen with perfect square pixels
fixedSize(false)
integerScale(true)

# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
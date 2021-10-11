# the following code is taken from https://gist.github.com/ftsf/464aa66e1782bbd803ada33615bdc212 and is placeholder
import std/[tables]
import nico
import nico/utils

type
  EntityId = uint64
  Color = enum
    black = 0
    anthracite
    plum
    darkGreen
    brown
    darkGrey
    lightGrey
    white
    red
    orange
    yellow
    brightGreen
    blue
    taupe
    pink
    peach

var textInputString: string
var textInputEventListener: EventListener
var step = 0
var frame: uint
var scale = 4

let descriptions = newTable[EntityId, string]()

descriptions[0] = "<0>0</> <1>1</> <2>2</> <3>3</> <4>4</> <5>5</> <6>6</> <7>7</> <8>8</> <9>9</> <10>10</> <11>11</> <12>12</> <13>13</> <14>14</> <15>15</>"

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
  var w = screenWidth - 2
  cls()
  setColor(7)
  boxfill(4,4, screenWidth - 16, fontHeight() * richWrapLines(descriptions[0], w).len + 4)
  setColor(6)
  boxfill(screenWidth - 10, 4, 6, fontHeight() * richWrapLines(descriptions[0], w).len + 4)
  setColor(7)
  boxfill(screenWidth - 10, 4, 6, 4)
  setColor(1)
  richPrintWrap(descriptions[0], 6, 6, screenWidth - 12, step = step)
  setColor(7)
  richPrintWrap(">" & textInputString, 1, screenHeight - fontHeight() - 2, w)

# initialization
nico.init("nico", "test")

# we want a dynamic sized screen with perfect square pixels
fixedSize(false)
integerScale(true)

# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)

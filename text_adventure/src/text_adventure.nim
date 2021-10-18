# the following code is taken from https://gist.github.com/ftsf/464aa66e1782bbd803ada33615bdc212 and is placeholder
import std/[tables, strutils, os]
import nico
import nico/utils
import text_adventure/helper

var textInputString: string
var textInputEventListener: EventListener
var step = 0
var frame: uint = 0
var scale = 4
var maxLines = 3
var currentLine = 0
var totalLines = 0

let gameData = getAllGameData()

func getSelfDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.selfDescriptions[key]]
func getRoomDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.roomDescriptions[key]]

proc getRoomLines(gameData: GameData, room: string, width: int): seq[string] =
  var desc = gameData.getSelfDesc(room)
  if room in gameData.inventory:
    for item in gameData.inventory[room]:
      desc &= "\n" & gameData.getRoomDesc(item)
  if room in gameData.exits:
    for item in gameData.exits[room]:
      desc &= "\n" & gameData.getRoomDesc(item)
  result = richWrapLines(desc, width)

proc gameInit() =
  loadFont(0, "fonts/compass-pro-v1.1.png")
  setFont(0)
  echo "font loaded"
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

  if keyp(K_UP) and currentLine > 0: currentLine -= 1
  if keyp(K_DOWN) and currentLine < totalLines - maxLines: currentLine += 1

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
  totalLines = gameData.getRoomLines(gameData.startRoom, screenWidth - 12).len
  var w = screenWidth - 2
  cls()
  #textbox
  setColor(7)
  boxfill(4,4, screenWidth - 16, fontHeight() * maxLines + 4)
  #grey part of scroll
  setColor(6)
  boxfill(screenWidth - 10, 4, 6, fontHeight() * maxLines + 4)
  #white part of scroll
  setColor(7)
  let ratioVisible:float = (maxLines + 1) / totalLines
  let visibleHeight:float = float fontHeight() * maxLines
  let scrollbarHeight:float = ratioVisible * visibleHeight
  boxfill(screenWidth - 10, float(scrollbarHeight) * float(currentLine) + 4, 6, float scrollbarHeight + 4)
  setColor(1)
  #6, 6, screenWidth - 12
  #do this only once later
  for idx, line in gameData.getRoomLines(gameData.startRoom, screenWidth - 12)[currentLine .. currentLine + maxLines - 1]:
    richPrint(line, 6, 6 + fontHeight() * idx)
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
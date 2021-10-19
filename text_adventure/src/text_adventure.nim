# the following code is taken from https://gist.github.com/ftsf/464aa66e1782bbd803ada33615bdc212 and is placeholder
import std/[tables, strutils, os, parseutils]
import nico
import nico/utils
import text_adventure/helper

var textInputString: string
var textInputEventListener: EventListener
var step = 0
var frame: uint = 0
var scale = 4
var minLines = 3
var maxLines = 3
var currentLine = 0
var totalLines = 0
var isTyping = false
var displayText = ""
var showPointer = false

var gameData = getAllGameData()

func getSelfDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.selfDescriptions[key]]
func getRoomDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.roomDescriptions[key]]
func getInv(gameData: GameData, key: string): seq[string] =
  if key in gameData.inventory:
    result = gameData.inventory[key]

proc getFullRoomDesc(gameData: GameData, room: string): string =
  var desc = gameData.getSelfDesc(room)
  for item in gameData.getInv(room):
    desc &= "\n" & gameData.getRoomDesc(item)
  if room in gameData.exits:
    for item in gameData.exits[room]:
      desc &= "\n" & gameData.getRoomDesc(item)
  result = desc

proc parseInput(input: string, gameData: var GameData) =
  var verb: string
  if parseIdent(input, verb, 0) != 0:
    case verb:
      of "debug":
        echo "room inventory"
        for item in gameData.getInv(gameData.currentRoom):
          echo item
        echo "--------"
        for pair in gameData.canPickup.pairs:
          echo pair
        echo gameData.canPickup["bedstead"]
      of "enter":
        var temp = input.substr(verb.len).strip().toLower()
        if temp in gameData.objectWordToThing:
          temp = gameData.objectWordToThing[temp]
          if temp in gameData.exits[gameData.currentRoom]:
            gameData.currentRoom = gameData.leadsTo[temp]
            displayText = gameData.getFullRoomDesc(gameData.currentRoom)
            currentLine = 0
      of "examine":
        var temp = input.substr(verb.len).strip().toLower()
        if temp in gameData.objectWordToThing:
          temp = gameData.objectWordToThing[temp]
          if temp in gameData.inventory[gameData.currentRoom] or temp in gameData.inventory[playerCharacter]:
            displayText = gameData.getSelfDesc(temp)
            currentLine = 0
      of "look", "back":
        displayText = gameData.getFullRoomDesc(gameData.currentRoom)
        currentLine = 0
      of "take":
        var temp = input.substr(verb.len).strip().toLower()
        if temp in gameData.objectWordToThing:
          temp = gameData.objectWordToThing[temp]
          if temp in gameData.getInv(gameData.currentRoom):
            currentLine = 0
            if gameData.canPickup[temp]:
              displayText = "You put it in your <orange>inventory</>.".multiReplace(colorReplaceTuples)
              gameData.inventory.addToSeqInTable(playerCharacter, temp)
              gameData.inventory.removeFromSeqInTable(gameData.currentRoom, temp)
            else:
              displayText = "You can't pick that up."
      of "invetory":
        displayText = "In your <orange>inventory</> you find:"
        for thing in gameData.inventory[playerCharacter]:
          displayText &= "\n" & gameData.titles[thing]


proc gameInit() =
  loadFont(0, "fonts/compass-pro-v1.1.png")
  setFont(0)
  textInputString = ""
  textInputEventListener = addEventListener(proc(ev: Event): bool =
    if ev.kind == ekTextInput:
      textInputString &= ev.text
  )
  displayText = getFullRoomDesc(gameData, gameData.currentRoom)

proc gameUpdate(dt: float32) =
  frame.inc()
  if frame mod 5 == 0:
    step += 1
  if frame mod 50 == 0:
    if isTyping:
      showPointer = not showPointer

  if keyp(K_RETURN):
    if isTyping:
      stopTextInput()
      isTyping = false
      parseInput(textInputString, gameData)
    else:
      isTyping = true
      #clear when sending, but for debug clear when new
      textInputString = ""
      startTextInput()

  if keyp(K_BACKSPACE) and isTyping and textInputString.len > 0:
    textInputString.setLen(textInputString.len - 1)

  if keyp(K_UP) and currentLine > 0: currentLine -= 1
  if keyp(K_DOWN) and currentLine < totalLines - maxLines: currentLine += 1

  if keyp(K_F1):
    if scale > 1:
      # shrink text size
      currentLine = 0
      scale -= 1
      let windowWidth = (screenWidth.float32 * getScreenScale()).int
      let windowHeight = (screenHeight.float32 * getScreenScale()).int
      setTargetSize(windowWidth div scale, windowHeight div scale)
  if keyp(K_F2):
    # increase text size
    currentLine = 0
    scale += 1
    let windowWidth = (screenWidth.float32 * getScreenScale()).int
    let windowHeight = (screenHeight.float32 * getScreenScale()).int
    setTargetSize(windowWidth div scale, windowHeight div scale)
  if keyp(K_F3):
    maxLines += 1
    currentLine = 0
  if keyp(K_F4):
    currentLine = 0
    if maxLines > minLines: maxLines -= 1

proc gameDraw() =
  #do this only once later
  let wrappedLines = richWrapLines(displayText, screenWidth - 12)
  totalLines = wrappedLines.len
  let ratioVisible:float = float(maxLines) / float(totalLines)
  let visibleHeight:float = float(fontHeight()) * float(maxLines) + 4
  let scrollbarHeight:float = ratioVisible * visibleHeight
  cls()
  #textbox
  setColor(7)
  boxfill(4,4, screenWidth - 16, visibleHeight)
  #grey part of scroll
  setColor(6)
  boxfill(screenWidth - 10, 4, 6, visibleHeight)
  #white part of scroll
  setColor(7)
  if totalLines > maxLines:
    boxfill(screenWidth - 10, float(currentLine) / float(totalLines) * float(visibleHeight) + 4, 6, float scrollbarHeight)
  else:
    boxfill(screenWidth - 10, 4, 6, visibleHeight)
  setColor(1)
  let maxIdx =
    if currentLine + maxLines > totalLines:
      totalLines - 1
    else:
      currentLine + maxLines - 1
  for idx, line in wrappedLines[currentLine .. maxIdx]:
    richPrint(line, 6, 6 + fontHeight() * idx)
  setColor(7)
  let offsetInput =
    if screenWidth < (">" & textInputString).richPrintWidthOneLine + 4:
      (">" & textInputString).richPrintWidthOneLine - (screenWidth - 4)
    else:
      0
  let txtPointer = if showPointer: "|" else: ""
  richPrint(">" & textInputString & txtPointer, 1 - offsetInput, screenHeight - fontHeight() - 2)

# initialization
nico.init("nico", "test")

# we want a dynamic sized screen with perfect square pixels
fixedSize(false)
integerScale(true)

# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
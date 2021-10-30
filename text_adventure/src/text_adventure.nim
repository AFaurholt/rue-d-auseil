import std/[tables, strutils, os, parseutils, streams, marshal]
import nico
import nico/utils
import text_adventure/helper

var
  textInputString: string
  textInputDisplayString: string
  textInputEventListener: EventListener
  frame: uint = 0
  scale = 2
  maxScale = 4
  scroll = 0
  isTyping = false
  textBoxMaxLines = 0
  textBoxText = ""
  textBoxLines: seq[string] = @["test"]
  textBoxLinesRender: seq[string]
  textBoxLinesRenderStep = 0
  subTextBoxLinesRender: array[3, string]
  subTextBoxLinesRenderStep = 0
  displayTitle = ""
  displayTitleStep = 0
  lastScreenDimensions: array[2, int]
  showPointer = false
  em = 8'f
  gameData: GameData

proc getScreenPadding: float =
  result = (em) / getScreenScale()

proc getScrollBarWidth: float =
  result = getScreenPadding() * 4

proc getTitleHeight(): float =
  let innerPadding = getScreenPadding() * 2
  result = float(fontHeight()) + innerPadding

proc getTitleHeightTotal(): float =
  let outerPadding = getScreenPadding() * 2
  result = getTitleHeight() + outerPadding

proc getSubTextBoxHeightTotal(): float =
  let padding = getScreenPadding() * 4
  result = float(fontHeight()) * 3 + padding

proc getAvailableRenderHeight(): float =
  let titleBoxAndPadding = getTitleHeightTotal()
  let inputAreaAndPadding = getTitleHeightTotal()
  let subtextHeightAndPadding = getSubTextBoxHeightTotal()
  result = float(screenHeight) - titleBoxAndPadding - inputAreaAndPadding - subtextHeightAndPadding + getScreenPadding()

proc getAvailableRenderWidth(): float =
  let outerPadding = getScreenPadding() * 2
  result = (float(screenWidth) - outerPadding)

proc getTextBoxHeight(): float =
  let outerPadding = getScreenPadding() * 2
  result = getAvailableRenderHeight() - outerPadding

proc getTextBoxHeightAdjusted(): float =
  let innerPadding = getScreenPadding() * 2
  result = getTextBoxHeight() + innerPadding

proc getTextBoxWidth(): float =
  result = getAvailableRenderWidth() - getScrollBarWidth() - getScreenPadding()

proc getTextBoxWidthAdjusted(): float =
  result = getTextBoxWidth() - getScreenPadding()

proc getTextBoxHeightOffset(): float =
  result = getTitleHeightTotal()

proc getSubTextBoxHeightOffset(): float =
  result = float(screenHeight) - getSubTextBoxHeightTotal() - getTitleHeightTotal() + getScreenPadding() * 2

proc getTextBoxMaxLines(): int =
  let textBoxHeight = getTextBoxHeight()
  result = int textBoxHeight / float(fontHeight())

func getLockDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.lockDescriptions[key]]
func getSelfDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.selfDescriptions[key]]
func getRoomDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.roomDescriptions[key]]
func getInv(gameData: GameData, key: string): seq[string] =
  if key in gameData.inventory:
    result = gameData.inventory[key]
func getTitle(gameData: GameData, key: string): string =
  result = gameData.titles[key]
func syncToChannel(gameData: GameData, name: string): int =
  result = gameData.audioChannel[gameData.audioSync[name]]
func normalize(num, min, max: float): float =
  #(x – x minimum) / (x maximum – x minimum)
  result = (num - min) / (max - min)

proc getFullRoomDesc(gameData: GameData, room: string): string =
  var desc = gameData.getSelfDesc(room)
  for item in gameData.getInv(room):
    desc &= "\n" & gameData.getRoomDesc(item)
  if room in gameData.exits:
    for item in gameData.exits[room]:
      desc &= "\n" & gameData.getRoomDesc(item)
  result = desc

proc clearTextInput() =
  textInputString = ""
  textInputDisplayString = ""

proc startTyping() =
  startTextInput()
  clearTextInput()
  isTyping = true

proc scrollUp() =
  if scroll > 0:
    scroll -= 1

proc scrollDown() =
  if scroll < textBoxLines.len - textBoxMaxLines:
    scroll += 1

proc clampScroll() =
  let upperBound =
    if textBoxLines.len < textBoxMaxLines: 0
    else: textBoxLines.len - textBoxMaxLines
  scroll = clamp(scroll, 0, upperBound)

proc setTextBoxLines() =
  textBoxLines = richWrapLines(textBoxText, int getTextBoxWidthAdjusted())

proc setTextBoxLinesRender() =
  let upperBound = clamp(scroll + textBoxMaxLines, 0, textBoxLines.len) - 1
  textBoxLinesRender = textBoxLines[scroll .. upperBound]

proc fixEverything() =
  setTextBoxLines()
  textBoxMaxLines = getTextBoxMaxLines()
  clampScroll()
  setTextBoxLinesRender()

proc setDisplayTitle(input: string) =
  displayTitleStep = 0
  displayTitle = input.multiReplace(colorReplaceTuples)

proc setTextBoxText(input: string) =
  textBoxText = input.multiReplace(colorReplaceTuples)
  scroll = 0
  textBoxLinesRenderStep = 0
  fixEverything()

proc setSubTextBoxLines(line1 = "", line2 = "", line3 = "") =
  subTextBoxLinesRenderStep = 0
  subTextBoxLinesRender = [
    line1.multiReplace(colorReplaceTuples)
    ,line2.multiReplace(colorReplaceTuples)
    ,line3.multiReplace(colorReplaceTuples)
  ]

proc setSubTextBoxLine(text: string, idx: int) =
  subTextBoxLinesRender[idx] = text.multiReplace(colorReplaceTuples)

proc setSubTextBoxLine(text: seq[string], idx: int) =
  var allText = ""
  for line in text:
    allText &= line

  setSubTextBoxLine(allText, idx)

proc addTextBoxText(input: string) =
  textBoxText &= input.multiReplace(colorReplaceTuples)
  fixEverything()

proc checkInteraction(verb, objectWord: string, gameData: var GameData) =
  if verb in gameData.interactionVerbs:
      var toRemove: seq[InteractionReq] = @[]
      for req in gameData.interactionVerbs[verb]:
        var
          isCorrectRoom = req.room.isEmptyOrWhitespace() or gameData.currentRoom == req.room
          isCorrectObject = req.objectWord.isEmptyOrWhitespace() or objectWord in gameData.objectWordToThing and gameData.objectWordToThing[objectWord] == req.objectWord
          hasCorrectItems = true
          hasCorrectExits = true
          hasCorrectFlags = true

        if req.flags.len > 0:
          for flag in req.flags:
            if not (flag in gameData.flags and gameData.flags[flag]):
              hasCorrectFlags = false
              break

        if req.inventoryHas.len > 0:
          for pair in req.inventoryHas:
            if pair.inv notin gameData.inventory or pair.item notin gameData.inventory[pair.inv]:
              hasCorrectItems = false
              break

        if req.hasExit.len > 0:
          for pair in req.hasExit:
            if pair.inv notin gameData.exits or pair.item notin gameData.exits[pair.inv]:
              hasCorrectExits = false
              break

        if isCorrectRoom and isCorrectObject and hasCorrectItems and hasCorrectExits and hasCorrectFlags:
          for gameCommand in gameData.interactionEvents[req.eventKey]:
            case gameCommand.tokens[0]:
            of "audio":
              case gameCommand.tokens[1]:
              of "clear":
                let
                  name = gameCommand.tokens[2]
                  channel = gameData.audioChannel[name]
                  isMusic = gameData.isMusic[name]

                #make the channel available
                gameData.availableChannels.add(channel)
                gameData.audioChannel.del(name)
                gameData.audioSync.del(name)
                if isMusic:
                  music(channel, -1)
              of "volume":
                let
                  name = gameCommand.tokens[2]
                  amount = gameCommand.tokens[3].parseInt()
                gameData.audioLevels[name] = float amount
                if name in gameData.audioChannel:
                  let channelIdx = gameData.audioChannel[name]
                  volume(channelIdx, amount)
              of "mute":
                let
                  name = gameCommand.tokens[2]
                  channel = gameData.audioChannel[name]
                volume(channel, 0)
              of "unmute":
                let
                  name = gameCommand.tokens[2]
                  channelIdx = gameData.audioChannel[name]
                volume(channelIdx, int gameData.audioLevels[name])
              of "fadeOut":
                gameData.fadeOutQueue.add((float32 gameCommand.tokens[3].parseFloat(), float32 0, gameCommand.tokens[2]))
              of "fadeIn":
                gameData.fadeInQueue.add((float32 gameCommand.tokens[3].parseFloat(), float32 0, gameCommand.tokens[2]))
              of "sync":
                let
                  syncParent = gameCommand.tokens[4]
                  syncChild = gameCommand.tokens[2]
                gameData.audioSync[syncChild] = syncParent
              of "desync":
                let
                  syncChild = gameCommand.tokens[2]
                gameData.audioSync.del(syncChild)
              of "play":
                #TODO error and stuff
                let name = gameCommand.tokens[2]
                if name in gameData.audioChannel:
                  let
                    isLoop = gameCommand.tokens.len == 4 and gameCommand.tokens[3] == "loop"
                    isSync = name in gameData.audioSync
                    channel = gameData.audioChannel[name]
                    audioIdx = gameData.audioIndex.find(name)
                  music(channel, audioIdx, if isLoop: -1 else: 0)
                  if isSync:
                    let syncPos = musicGetPos(syncToChannel(gameData, name))
                    musicSeek(channel, syncPos)
                elif gameData.availableChannels.len > 0:
                  let
                    idxChannel = gameData.availableChannels.pop()
                    idxAudio = gameData.audioIndex.find(name)
                    isMusic = gameData.isMusic[name]
                    isSync = name in gameData.audioSync
                    isLoop = gameCommand.tokens.len == 4 and gameCommand.tokens[3] == "loop"

                  gameData.audioChannel[name] = idxChannel

                  if isSync and isMusic:
                    music(idxChannel, idxAudio, if isLoop: -1 else: 0)
                    let syncPos = musicGetPos(syncToChannel(gameData, name))
                    musicSeek(idxChannel, syncPos)
                  if not isSync and isMusic:
                    music(idxChannel, idxAudio, if isLoop: -1 else: 0)
            of "display":
              setTextBoxText(gameData.descriptions[gameCommand.tokens[1]])
            of "subDisplay":
              case gameCommand.tokens[1]:
              of "1":
                setSubTextBoxLine(gameCommand.tokens[2 .. ^1], 0)
              of "2":
                setSubTextBoxLine(gameCommand.tokens[2 .. ^1], 1)
              of "3":
                setSubTextBoxLine(gameCommand.tokens[2 .. ^1], 2)
            of "unlock":
              gameData.isLocked[gameCommand.tokens[1]] = false
            of "lock":
              gameData.isLocked[gameCommand.tokens[1]] = true
            of "pickup":
              case gameCommand.tokens[1]:
              of "add":
                gameData.canPickup[gameCommand.tokens[2]] = true
              of "rem", "remove", "del", "delete":
                gameData.canPickup[gameCommand.tokens[2]] = false
            of "item":
              case gameCommand.tokens[1]:
              of "add":
                gameData.inventory.addToSeqInTable(gameCommand.tokens[3], gameCommand.tokens[2])
              of "rem", "remove", "del", "delete":
                gameData.inventory.removeFromSeqInTable(gameCommand.tokens[3],gameCommand.tokens[2])
            of "exit":
              case gameCommand.tokens[1]:
              of "add":
                gameData.exits.addToSeqInTable(gameCommand.tokens[3], gameCommand.tokens[2])
              of "rem", "remove", "del", "delete":
                gameData.exits.removeFromSeqInTable(gameCommand.tokens[3], gameCommand.tokens[2])
            of "desc", "description", "txt", "text":
              case gameCommand.tokens[1]:
              of "self":
                gameData.selfDescriptions[gameCommand.tokens[2]] = gameCommand.tokens[3]
              of "room":
                gameData.roomDescriptions[gameCommand.tokens[2]] = gameCommand.tokens[3]
              of "lock":
                gameData.lockDescriptions[gameCommand.tokens[2]] = gameCommand.tokens[3]
            of "refresh":
              setTextBoxText(gameData.getFullRoomDesc(gameData.currentRoom))
            of "flag":
              case gameCommand.tokens[1]:
              of "set":
                gameData.flags[gameCommand.tokens[2]] = true
              of "unset":
                gameData.flags[gameCommand.tokens[2]] = false
            of "gameOver":
              gameData.isGameOver = true

          if req.once:
            toRemove.add(req)
      #after for
      for req in toRemove:
        gameData.interactionVerbs.removeFromSeqInTable(verb, req)

proc newGame(gameData: var GameData) =
  for channel in countup(0, 15):
        music(channel, -1)
  gameData = getAllGameData()
  setTextBoxText(getFullRoomDesc(gameData, gameData.currentRoom))
  displayTitle = gameData.getTitle(gameData.currentRoom)
  checkInteraction("!init", "", gameData)

proc checkForNewGameSaveLoad(verb, objectWord: string, gameData: var GameData) =
  case verb:
  of "!newgame":
    gameData.newGame()
  of "!save":
    if objectWord.len > 0:
      setSubTextBoxLine("Trying to save...", 1)
      try:
        var strm = newFileStream(objectWord & ".save", fmWrite)
        store(strm, gameData)
        strm.close()
        setSubTextBoxLine("Saved...", 2)  
      except:
        setSubTextBoxLine("Error, check inputs and permissions", 2) 
    else:
      setSubTextBoxLine("You need to name the save file", 1)
  of "!load":
    if objectWord.len > 0:
      setSubTextBoxLine("Trying to load...", 1)
      try:
        load(newFileStream(objectWord & ".save", fmRead), gameData)
        setSubTextBoxLine("Loaded...", 2)  
        setTextBoxText(gameData.getFullRoomDesc(gameData.currentRoom))
        setDisplayTitle(gameData.getTitle(gameData.currentRoom))
      except:
        setSubTextBoxLine("Error, check inputs and permissions", 2) 
    else:
      setSubTextBoxLine("You need to name the save file", 1)

proc parseVerb(input: string, output: var string, start: int = 0): int =
  for c in input[start .. ^1]:
    if c.isAlphaNumeric or c == '!':
      output &= c
      result += 1
    if c == ' ':
      return

proc parseInput(input: string, gameData: var GameData) =
  ## Parses player input and does too much
  echo "input: ", input
  var verb: string
  setSubTextBoxLines(">"&input)
  if parseVerb(input.strip().toLower(), verb, 0) != 0:
    if not gameData.isGameOver:
      checkForNewGameSaveLoad(verb, input.substr(verb.len).strip(), gameData)
      case verb:
      of "debug":
        echo "game state:"
        echo gameData
      of "unlock":
        var temp = input.substr(verb.len).strip().toLower()
        if temp.isEmptyOrWhitespace():
          setSubTextBoxLine("<orange>Unlock</> what?", 1)
        elif temp in gameData.objectWordToThing:
            temp = gameData.objectWordToThing[temp]
            if temp in gameData.exits[gameData.currentRoom]:
              if not gameData.isLocked[temp]:
                setSubTextBoxLine("It's already <orange>unlocked</>.", 1)
              elif gameData.needsKey[temp] in gameData.inventory[playerCharacter]:
                setSubTextBoxLine("You <orange>unlock</> it.", 1)
                gameData.isLocked[temp] = false
              else:
                setSubTextBoxLine("You are missing the key.", 1)
            else:
              setSubTextBoxLine("Nowhere to be seen.", 1)
        else:
          setSubTextBoxLine("Nowhere to be seen.", 1)
      of "enter":
        var temp = input.substr(verb.len).strip().toLower()
        if temp.isEmptyOrWhitespace():
          setSubTextBoxLine("<orange>Enter</> what?", 1)
        elif temp in gameData.objectWordToThing:
            temp = gameData.objectWordToThing[temp]
            if temp in gameData.exits[gameData.currentRoom]:
              if not gameData.isLocked[temp]:
                gameData.currentRoom = gameData.leadsTo[temp]
                setDisplayTitle(gameData.getTitle(gameData.currentRoom))
                setTextBoxText(gameData.getFullRoomDesc(gameData.currentRoom))
                setSubTextBoxLine("You <orange>enter</>...", 1)
              else:
                setDisplayTitle(gameData.getTitle(temp))
                setTextBoxText(gameData.getLockDesc(temp))
                setSubTextBoxLine("Locked.", 1)
        else:
          setSubTextBoxLine("Nope.", 1)
      of "examine":
        var temp = input.substr(verb.len).strip().toLower()
        if temp.isEmptyOrWhitespace():
          setSubTextBoxLine("<orange>Examine</> what?", 1)
        elif temp in gameData.objectWordToThing:
            temp = gameData.objectWordToThing[temp]
            if temp in gameData.inventory[gameData.currentRoom] or temp in gameData.inventory[playerCharacter] or temp in gameData.exits[gameData.currentRoom]:
              setTextBoxText(gameData.getSelfDesc(temp))
              setDisplayTitle(gameData.getTitle(temp))
              setSubTextBoxLine("You take a closer look...", 1)
            else:
              setSubTextBoxLine("Nowhere to be seen.", 1)
        else:
          setSubTextBoxLine("Nowhere to be seen.", 1)
      of "look", "back":
        setTextBoxText(gameData.getFullRoomDesc(gameData.currentRoom))
        setDisplayTitle(gameData.getTitle(gameData.currentRoom))
        setSubTextBoxLine("You <orange>look</> around...", 1)
      of "drop":
        var temp = input.substr(verb.len).strip().toLower()
        if temp.isEmptyOrWhitespace():
          setSubTextBoxLine("<orange>Drop</> what?", 1)
        elif temp in gameData.objectWordToThing:
          temp = gameData.objectWordToThing[temp]
          if temp in gameData.inventory[playerCharacter]:
            gameData.inventory.addToSeqInTable(gameData.currentRoom, temp)
            gameData.inventory.removeFromSeqInTable(playerCharacter, temp)
            setSubTextBoxLine("You <orange>drop</> the item.", 1)
            setTextBoxText(gameData.getFullRoomDesc(gameData.currentRoom))
          else:
            setSubTextBoxLine("Not in your <orange>inventory</>...", 1)
        else:
          setSubTextBoxLine("Not in your <orange>inventory</>...", 1)
      of "take":
        var temp = input.substr(verb.len).strip().toLower()
        if temp.isEmptyOrWhitespace():
          setSubTextBoxLine("<orange>Take</> what?", 1)
        elif temp in gameData.objectWordToThing:
            temp = gameData.objectWordToThing[temp]
            if temp in gameData.getInv(gameData.currentRoom):
              if gameData.canPickup[temp]:
                setSubTextBoxLine("You put it in your <orange>inventory</>.", 1)
                gameData.inventory.addToSeqInTable(playerCharacter, temp)
                gameData.inventory.removeFromSeqInTable(gameData.currentRoom, temp)
                setTextBoxText(gameData.getFullRoomDesc(gameData.currentRoom))
              else:
                setSubTextBoxLine("You can't pick that up.", 1)
            else:
              setSubTextBoxLine("Nowhere to be seen.", 1)
        else:
          setSubTextBoxLine("Nowhere to be seen.", 1)
      of "inventory":
        setDisplayTitle("In your <orange>inventory</> you find:")
        setTextBoxText("")
        for thing in gameData.inventory[playerCharacter]:
          addTextBoxText(gameData.titles[thing] & "\n")

      #end of normal parse
      checkInteraction(verb, input.substr(verb.len).strip().toLower(), gameData)
    else:
      checkForNewGameSaveLoad(verb, input.substr(verb.len).strip(), gameData)

proc getScreenDimensions(): array[2, int] =
  result[0] = screenWidth
  result[1] = screenHeight

proc setInputDisplay =
  var offset = 0
  var tmp = ">" & textInputString & "|"
  var width: int = int getAvailableRenderWidth() - getScreenPadding() * 2
  while richPrintWidthOneLine(tmp, offset) > width:
    offset += 1

  textInputDisplayString = (">" & textInputString)[offset+1 .. ^1]

proc gameInit() =
  loadFont(0, "assets/fonts/compass-pro-v1.1.png")
  setFont(0)
  startTyping()
  textInputEventListener = addEventListener(proc(ev: Event): bool =
    if ev.kind == ekTextInput:
      if ev.text != "<" and ev.text != ">":
        textInputString &= ev.text
        setInputDisplay()
  )
  let windowWidth = (screenWidth.float32 * getScreenScale()).int
  let windowHeight = (screenHeight.float32 * getScreenScale()).int
  setTargetSize(windowWidth div scale, windowHeight div scale)

proc gameUpdate(dt: float32) =
  var
    newFadeOutQueue: seq[AudioFadeInfo]
    newFadeInQueue: seq[AudioFadeInfo]
  for fadeOut in gameData.fadeOutQueue:
    let
      newRunTime = fadeOut.runTime + dt
      volume = gameData.audioLevels[fadeOut.name]
      channel = gameData.audioChannel[fadeOut.name]
      newVolume: float32 =
        if newRunTime >= fadeOut.targetTime:
          float32 0
        else:
          newFadeOutQueue.add((fadeOut.targetTime, newRunTime, fadeOut.name))
          lerp(float volume, 0'f, newRunTime.normalize(0, fadeOut.targetTime))

    volume(channel, int newVolume)
  for fadeIn in gameData.fadeInQueue:
    let
      newRunTime = fadeIn.runTime + dt
      volume = gameData.audioLevels[fadeIn.name]
      channel = gameData.audioChannel[fadeIn.name]
      newVolume: float32 =
        if newRunTime >= fadeIn.targetTime:
          volume
        else:
          newFadeInQueue.add((fadeIn.targetTime, newRunTime, fadeIn.name))
          lerp(0'f, float volume, newRunTime.normalize(0, fadeIn.targetTime))
    volume(channel,int  newVolume)
  
  gameData.fadeOutQueue = newFadeOutQueue
  gameData.fadeInQueue = newFadeInQueue

  frame.inc()
  if frame mod 2 == 0:
    textBoxLinesRenderStep += 1
    subTextBoxLinesRenderStep += 1
    displayTitleStep += 1
  if frame mod 40 == 0:
    if isTyping:
      showPointer = not showPointer

  if keyp(K_RETURN):
    if isTyping:
      parseInput(textInputString, gameData)
      clearTextInput()

  if keyp(K_BACKSPACE) and isTyping and textInputString.len > 0:
    textInputString.setLen(textInputString.len - 1)
    setInputDisplay()

  if keyp(K_UP): 
    scrollUp()
    setTextBoxLinesRender()
  if keyp(K_DOWN): 
    scrollDown()
    setTextBoxLinesRender()

  if keyp(K_F1):
    if scale > 1:
      # shrink text size
      scale -= 1
      let windowWidth = (screenWidth.float32 * getScreenScale()).int
      let windowHeight = (screenHeight.float32 * getScreenScale()).int
      setTargetSize(windowWidth div scale, windowHeight div scale)
  if keyp(K_F2):
    if scale < maxScale:
      # increase text size
      scale += 1
      let windowWidth = (screenWidth.float32 * getScreenScale()).int
      let windowHeight = (screenHeight.float32 * getScreenScale()).int
      setTargetSize(windowWidth div scale, windowHeight div scale)

proc drawTitle =
  setColor(7)
  boxfill(getScreenPadding(), getScreenPadding(), getAvailableRenderWidth(), getTitleHeight())
  setColor(1)
  richPrint(displayTitle, int getScreenPadding() * 2, int getScreenPadding() * 2, step = displayTitleStep)

proc drawTextBox =
  let offset = getTextBoxHeightOffset()
  setColor(7)
  boxfill(getScreenPadding(), offset, getTextBoxWidth(), getTextBoxHeightAdjusted())
  setColor(1)
  for idx, line in textBoxLinesRender:
    richPrint(line, int getScreenPadding() * 2, int offset + getScreenPadding() + float(fontHeight() * idx), step = textBoxLinesRenderStep)

proc drawScrollBar =
  let
    offsetY: int = int getTextBoxHeightOffset()
    offsetX: int = int float(screenWidth) - getScrollBarWidth() - getScreenPadding()
    visibleRatio: float = clamp(textBoxMaxLines / textBoxLines.len, 0, 1)
    scrollRatio: float = clamp(scroll / textBoxLines.len, 0, 1)
    scrollCursorHeight: float = visibleRatio * getTextBoxHeightAdjusted()
    cursorOffsetY: int = offsetY + int(scrollRatio * getTextBoxHeightAdjusted())
  setColor(6)
  boxfill(offsetX, offsetY, getScrollBarWidth(), getTextBoxHeightAdjusted())
  #cursor
  setColor(7)
  boxfill(offsetX, cursorOffsetY, getScrollBarWidth(), scrollCursorHeight)

proc drawSubTextBox =
  setColor(5)
  boxfill(getScreenPadding(), getSubTextBoxHeightOffset(), getAvailableRenderWidth(), getSubTextBoxHeightTotal() - getScreenPadding() * 2)
  setColor(6)
  for idx, line in subTextBoxLinesRender:
    richPrint(line, int getScreenPadding() * 2, int getSubTextBoxHeightOffset() + getScreenPadding() + fontHeight() * idx, step = subTextBoxLinesRenderStep)

proc drawInputArea =
  let
    textPointer = if showPointer: "|" else: ""
    offsetY = float(screenHeight) - getTitleHeight() - getScreenPadding()
  setColor(5)
  boxfill(getScreenPadding(), offsetY, getAvailableRenderWidth(), getTitleHeight())
  setColor(7)
  richPrint(">" & textInputDisplayString & textPointer, int getScreenPadding() * 2, int offsetY + getScreenPadding())

proc gameDraw() =
  let currentScreenDim = getScreenDimensions()
  #if screen dim changed, fix all the stuff
  if lastScreenDimensions != currentScreenDim:
    lastScreenDimensions = currentScreenDim
    fixEverything()
  drawTitle()
  drawTextBox()
  drawScrollBar()
  drawSubTextBox()
  drawInputArea()

# initialization
nico.init("AFaurholt", "Text Adventure Engine 0.2.0")

gameData.newGame()

# we want a dynamic sized screen with perfect square pixels
fixedSize(false)
integerScale(true)

# create the window
nico.createWindow("Text Adventure Engine 0.2.0",250,250,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
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
var sampleCount1 = 0
var sampleCount2 = 0

var gameData: GameData

func getLockDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.lockDescriptions[key]]
func getSelfDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.selfDescriptions[key]]
func getRoomDesc(gameData: GameData, key: string): string =
  result = gameData.descriptions[gameData.roomDescriptions[key]]
func getInv(gameData: GameData, key: string): seq[string] =
  if key in gameData.inventory:
    result = gameData.inventory[key]
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

proc parseInput(input: string, gameData: var GameData) =
  ## Parses player input and does too much
  echo "input: ", input
  var verb: string
  if parseIdent(input.strip(), verb, 0) != 0:
    case verb:
    of "debug":
      echo "game state:"
      echo gameData
    of "unlock":
      var temp = input.substr(verb.len).strip().toLower()
      if temp in gameData.objectWordToThing:
        temp = gameData.objectWordToThing[temp]
        if temp in gameData.exits[gameData.currentRoom]:
          currentLine = 0
          if not gameData.isLocked[temp]:
            displayText = "It's already <orange>unlocked</>.".multiReplace(colorReplaceTuples)
          elif gameData.needsKey[temp] in gameData.inventory[playerCharacter]:
            displayText = "You <orange>unlock</> it.".multiReplace(colorReplaceTuples)
            gameData.isLocked[temp] = false
          else:
            displayText = "You don't have the correct key."
    of "enter":
      var temp = input.substr(verb.len).strip().toLower()
      if temp in gameData.objectWordToThing:
        temp = gameData.objectWordToThing[temp]
        if temp in gameData.exits[gameData.currentRoom]:
          currentLine = 0
          if not gameData.isLocked[temp]:
            gameData.currentRoom = gameData.leadsTo[temp]
            displayText = gameData.getFullRoomDesc(gameData.currentRoom)
          else:
            displayText = gameData.getLockDesc(temp)
    of "examine":
      var temp = input.substr(verb.len).strip().toLower()
      if temp in gameData.objectWordToThing:
        temp = gameData.objectWordToThing[temp]
        if temp in gameData.inventory[gameData.currentRoom] or temp in gameData.inventory[playerCharacter] or temp in gameData.exits[gameData.currentRoom]:
          displayText = gameData.getSelfDesc(temp)
          currentLine = 0
    of "look", "back":
      displayText = gameData.getFullRoomDesc(gameData.currentRoom)
      currentLine = 0
    of "drop":
      var temp = input.substr(verb.len).strip().toLower()
      if temp in gameData.objectWordToThing:
        temp = gameData.objectWordToThing[temp]
        if temp in gameData.inventory[playerCharacter]:
          currentLine = 0
          gameData.inventory.addToSeqInTable(gameData.currentRoom, temp)
          gameData.inventory.removeFromSeqInTable(playerCharacter, temp)
          displayText = "You <orange>drop</> the item.".multiReplace(colorReplaceTuples)
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
    of "inventory":
      currentLine = 0
      displayText = "In your <orange>inventory</> you find:"
      for thing in gameData.inventory[playerCharacter]:
        displayText &= "\n" & gameData.titles[thing]

    #end of normal parse
    if verb in gameData.interactionVerbs:
      var toRemove: seq[InteractionReq] = @[]
      for req in gameData.interactionVerbs[verb]:
        var
          objectWord = input.substr(verb.len).strip().toLower()
          isCorrectRoom = req.room.isEmptyOrWhitespace() or gameData.currentRoom == req.room
          isCorrectObject = req.objectWord.isEmptyOrWhitespace() or objectWord in gameData.objectWordToThing and gameData.objectWordToThing[objectWord] == req.objectWord
          hasCorrectItems = true
          hasCorrectExits = true

        if req.inventoryHas.len > 0:
          for pair in req.inventoryHas:
            if pair.inv notin gameData.inventory or pair.item notin gameData.inventory[pair.inv]:
              hasCorrectItems = false
        
        if req.hasExit.len > 0:
          for pair in req.hasExit:
            if pair.inv notin gameData.exits or pair.item notin gameData.exits[pair.inv]:
              hasCorrectExits = false

        if isCorrectRoom and isCorrectObject and hasCorrectItems and hasCorrectExits:
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
              currentLine = 0
              displayText = gameData.descriptions[gameCommand.tokens[1]]
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

          if req.once:
            toRemove.add(req)
      #after for
      for req in toRemove:
        gameData.interactionVerbs.removeFromSeqInTable(verb, req)

proc gameInit() =
  loadFont(0, "assets/fonts/compass-pro-v1.1.png")
  setFont(0)
  textInputString = ""
  textInputEventListener = addEventListener(proc(ev: Event): bool =
    if ev.kind == ekTextInput:
      textInputString &= ev.text
  )
  displayText = getFullRoomDesc(gameData, gameData.currentRoom)

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
      showPointer = false
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
    echo "F3 pressed"
    maxLines += 1
    currentLine = 0
  if keyp(K_F4):
    echo "F3 pressed"
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
    if screenWidth < (">" & textInputString).richPrintWidthOneLine + screenWidth * 0.1f:
      (">" & textInputString).richPrintWidthOneLine - (screenWidth * 0.9f)
    else:
      0
  let txtPointer = if showPointer: "|" else: ""
  richPrint(">" & textInputString & txtPointer, int(1 - offsetInput), screenHeight - fontHeight() - 2)

# initialization
nico.init("nico", "test")

gameData = getAllGameData()

# we want a dynamic sized screen with perfect square pixels
fixedSize(false)
integerScale(true)

# create the window
nico.createWindow("nico",128,128,4)

# start, say which functions to use for init, update and draw
nico.run(gameInit, gameUpdate, gameDraw)
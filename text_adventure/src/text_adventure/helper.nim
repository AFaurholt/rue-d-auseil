import std/[os, tables, strutils]
import nico

type
  GameCommand* = object
    tokens*: seq[string]
  InventoryItemPair* = tuple[inv: string, item: string]
  AudioFadeInfo* = tuple[targetTime, runTime: float32, name: string]
  InteractionReq* = object
    room*: string
    inventoryHas*: seq[InventoryItemPair]
    objectWord*: string
    eventKey*: string
    once*: bool
    hasExit*: seq[InventoryItemPair]
    flags*: seq[string]
  GameData* = object
    startRoom*: string
    descriptions*: TableRef[string, string]
    titles*: TableRef[string, string]
    leadsTo*: TableRef[string, string]
    selfDescriptions*: TableRef[string, string]
    roomDescriptions*: TableRef[string, string]
    lockDescriptions*: TableRef[string, string]
    canPickup*: TableRef[string, bool]
    inventory*: TableRef[string, seq[string]]
    exits*: TableRef[string, seq[string]]
    currentRoom*: string
    objectWordToThing*: TableRef[string, string]
    interactionVerbs*: TableRef[string, seq[InteractionReq]]
    interactionEvents*: TableRef[string, seq[GameCommand]]
    isLocked*: TableRef[string, bool]
    needsKey*: TableRef[string, string]
    audioIndex*: seq[string]
    audioSync*: TableRef[string, string]
    audioChannel*: TableRef[string, int]
    availableChannels*: seq[int]
    isMusic*: TableRef[string, bool]
    audioLevels*: TableRef[string, float32]
    fadeOutQueue*: seq[AudioFadeInfo]
    fadeInQueue*: seq[AudioFadeInfo]
    flags*: TableRef[string, bool]
    isGameOver*: bool

const
  colorReplaceTuples* = [
    ("<black>", "<0>")
    ,("<navy>", "<1>")
    ,("<maroon>", "<2>")
    ,("<darkGreen>", "<3>")
    ,("<brown>", "<4>")
    ,("<darkGrey>", "<5>")
    ,("<lightGrey>", "<6>")
    ,("<white>", "<7>")
    ,("<red>", "<8>")
    ,("<orange>", "<9>")
    ,("<yellow>", "<10>")
    ,("<lightGreen>", "<11>")
    ,("<blue>", "<12>")
    ,("<purple>", "<13>")
    ,("<pink>", "<14>")
    ,("<peach>", "<15>")
  ]
  playerCharacter* = "playerCharacter"

func newGameData*(): GameData =
  result = GameData(
    descriptions: newTable[string, string]()
    ,titles: newTable[string, string]()
    ,leadsTo: newTable[string, string]()
    ,selfDescriptions: newTable[string, string]()
    ,roomDescriptions: newTable[string, string]()
    ,canPickup: newTable[string, bool]()
    ,inventory: newTable[string, seq[string]]()
    ,exits: newTable[string, seq[string]]()
    ,objectWordToThing: newTable[string, string]()
  )
  result.inventory[playerCharacter] = @[]

proc addToSeqInTable*[TKey, TItem](table: var TableRef[TKey, seq[TItem]], key: TKey, val: TItem) =
  if key in table:
    table[key].add(val)
  else:
    table[key] = @[val]

proc removeFromSeqInTable*[TKey, TItem](table: var TableRef[TKey, seq[TItem]], key: TKey, val: TItem) =
  if key in table:
    let idx = table[key].find(val)
    if idx != -1:
      table[key].del(idx)
      
proc readAllPath*(path: string): string =
  let file = open(path)
  result = file.readAll()
  close(file)

proc loadAllAudio*(gameData: var GameData, path: string, isMusic = true) =
  if dirExists(path):
    if isMusic:
      for item in walkFiles(path & "/*.ogg"):
        let name = splitFile(item).name
        loadMusic(gameData.audioIndex.len, item)
        gameData.audioIndex.add(name)
        gameData.isMusic[name] = isMusic
        gameData.audioLevels[name] = float32 255
    #not music
    else:
      #TODO
      for item in walkFiles(path & "/*.ogg"):
        loadSfx(gameData.audioIndex.len, item)
        gameData.audioIndex.add(splitFile(item).name)
        gameData.isMusic[splitFile(item).name] = isMusic

proc getDescriptionsFromFiles*(path: string): TableRef[string ,string] =
  result = newTable[string, string]()
  if dirExists(path):
    for item in walkFiles(path & "/*.txt"):
      result[splitFile(item).name] = readAllPath(item).multiReplace(colorReplaceTuples)

proc getGameDataFromDir*(path: string, data: var GameData) =
  for item in walkFiles(path & "/*.txt"):
    let name = item.splitFile().name
    for line in readAllPath(item).splitLines:
      let pair = line.strip().split(":")
      case pair[0]:
      of "needsKey":
        data.needsKey[name] = pair[1].strip()
      of "isLocked":
        data.isLocked[name] = pair[1].strip().parseBool()
      of "title":
        data.titles[name] = pair[1].strip()
      of "leadsTo":
        data.leadsTo[name] = pair[1].strip()
      of "selfDescription":
        data.selfDescriptions[name] = pair[1].strip()
      of "roomDescription":
        data.roomDescriptions[name] = pair[1].strip()
      of "lockDescription":
        data.lockDescriptions[name] = pair[1].strip()
      of "pickup":
        data.canPickup[name] = pair[1].strip().parseBool()
      of "inRoom":
        for room in pair[1].split(","):
          data.inventory.addToSeqInTable(room.strip(), name)
      of "exits":
          for exit in pair[1].split(","):
            data.exits.addToSeqInTable(name, exit.strip())
      of "startRoom":
        data.startRoom = name
        data.currentRoom = name
      of "object":
        for word in pair[1].split(","):
          data.objectWordToThing[word.strip()] = name

proc createGameCommand*(key: string, tokens: seq[string], gameData: var GameData) =
  gameData.interactionEvents.addToSeqInTable(key, GameCommand(tokens: tokens))

proc getAllInteractions*(path: string, gameData: var GameData) =
  for item in walkFiles(path & "/*.txt"):
    let name = item.splitFile().name
    var requirements = InteractionReq(eventKey: name)
    var verb: string
    for line in readAllPath(item).splitLines:
      let pair = line.strip().split(":")
      case pair[0]:
        of "object":
          requirements.objectWord = pair[1].strip()
        of "verb":
          verb = pair[1].strip()
        of "room":
          requirements.room = pair[1].strip()
        of "event":
          for subPair in pair[1].split(";"):
            createGameCommand(name, subPair.strip().split("/"), gameData)
        of "once":
          requirements.once = true
        of "hasExit":
          for subPair in pair[1].split(";"):
            let subSubPair = subPair.split("/")
            requirements.hasExit.add((inv: subSubPair[0].strip(), item: subSubPair[1].strip()))
        of "inventory":
          for subPair in pair[1].split(";"):
            let subSubPair = subPair.split("/")
            requirements.inventoryHas.add((inv: subSubPair[0].strip(), item: subSubPair[1].strip()))
        of "flag":
          for flag in pair[1].split(","):
            requirements.flags.add(flag.strip())
          
    #end of lines
    gameData.interactionVerbs.addToSeqInTable(verb, requirements)

proc getAllGameData*(): GameData =
  result = GameData(
    descriptions: getDescriptionsFromFiles("assets/descriptions")
    ,titles: newTable[string, string]()
    ,leadsTo: newTable[string, string]()
    ,selfDescriptions: newTable[string, string]()
    ,roomDescriptions: newTable[string, string]()
    ,lockDescriptions: newTable[string, string]()
    ,canPickup: newTable[string, bool]()
    ,inventory: newTable[string, seq[string]]()
    ,exits: newTable[string, seq[string]]()
    ,objectWordToThing: newTable[string, string]()
    ,interactionVerbs: newTable[string, seq[InteractionReq]]()
    ,interactionEvents: newTable[string, seq[GameCommand]]()
    ,isLocked: newTable[string, bool]()
    ,needsKey: newTable[string, string]()
    ,audioSync: newTable[string, string]()
    ,audioChannel: newTable[string, int]()
    ,availableChannels: @[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    ,isMusic: newTable[string, bool]()
    ,audioLevels: newTable[string, float32]()
    ,flags: newTable[string, bool]()
  )
  result.inventory[playerCharacter] = @[]

  assetPath = basePath
  
  getGameDataFromDir("assets/exits", result)
  getGameDataFromDir("assets/items", result)
  getGameDataFromDir("assets/rooms", result)
  getAllInteractions("assets/interactions", result)
  result.loadAllAudio("assets/music")

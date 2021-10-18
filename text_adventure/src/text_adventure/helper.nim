import std/[os, tables, strutils]

type
  GameData* = object
    startRoom*: string
    descriptions*: TableRef[string, string]
    titles*: TableRef[string, string]
    leadsTo*: TableRef[string, string]
    selfDescriptions*: TableRef[string, string]
    roomDescriptions*: TableRef[string, string]
    canPickup*: TableRef[string, bool]
    inRoom*: TableRef[string, seq[string]]
    exits*: TableRef[string, seq[string]]

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

func newGameData*(): GameData =
  result = GameData(
    descriptions: newTable[string, string]()
    ,titles: newTable[string, string]()
    ,leadsTo: newTable[string, string]()
    ,selfDescriptions: newTable[string, string]()
    ,roomDescriptions: newTable[string, string]()
    ,canPickup: newTable[string, bool]()
    ,inRoom: newTable[string, seq[string]]()
    ,exits: newTable[string, seq[string]]()
  )

proc readAllPath*(path: string): string =
  let file = open(path)
  result = file.readAll()
  close(file)

proc getDescriptionsFromFiles*(path: string): TableRef[string ,string] =
  result = newTable[string, string]()
  if dirExists(path):
    for item in walkFiles(path & "/*.txt"):
      result[splitFile(item).name] = readAllPath(item).multiReplace(colorReplaceTuples)

proc getGameDataFromDir*(path: string, data: var GameData) =
  for item in walkFiles(path & "/*.txt"):
    let name = item.splitFile().name
    for line in readAllPath(item).splitLines:
      let pair = line.split(":")
      case pair[0]:
        of "title":
          data.titles[name] = pair[1]
        of "leadsTo":
          data.leadsTo[name] = pair[1]
        of "selfDescription":
          data.selfDescriptions[name] = pair[1]
        of "roomDescription":
          data.roomDescriptions[name] = pair[1]
        of "pickup":
          data.canPickup[name] = pair[1].parseBool()
        of "inRoom":
          data.inRoom[name] = pair[1].split(",")
        of "exits":
          data.exits[name] = pair[1].split(",")
        of "startRoom":
          data.startRoom = name

proc getAllGameData*(): GameData =
  result = GameData(
    descriptions: getDescriptionsFromFiles("assets/descriptions")
    ,titles: newTable[string, string]()
    ,leadsTo: newTable[string, string]()
    ,selfDescriptions: newTable[string, string]()
    ,roomDescriptions: newTable[string, string]()
    ,canPickup: newTable[string, bool]()
    ,inRoom: newTable[string, seq[string]]()
    ,exits: newTable[string, seq[string]]()
  )
  
  getGameDataFromDir("assets/exits", result)
  getGameDataFromDir("assets/items", result)
  getGameDataFromDir("assets/rooms", result)

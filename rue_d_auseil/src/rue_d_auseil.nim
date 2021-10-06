# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.
import std/[terminal, os, strutils, rdstdin, tables, sets, parseutils]
import rue_d_auseilpkg/submodule

when isMainModule:
  type
    Vector3 = object
      x: int32
      y: int32
      z: int32

  var 
    lastInput: string = ""
    lastVerb: string = ""
    lastVerbObject: string = ""
    verbs = newTable[string, proc(input: string)]()
    roomDescriptions = newTable[Vector3, string]()
    northExits = initHashSet[Vector3]()
    currentPos = Vector3()

  proc move(direction: string) =
    case direction
    of "north":
      if currentPos in northExits:
        currentPos.y -= 1
        echo "You go North. You are at ", currentPos, "."
      else:
        echo "There is no exit to the North here."

  proc look(thing: string) =
    case thing
    of "around":
      if currentPos in roomDescriptions:
        echo roomDescriptions[currentPos]
    else:
      echo "You need to look at something."

  verbs["move"] = move
  verbs["look"] = look
  northExits.incl(Vector3(x: 0, y: 0, z: 0))
  northExits.incl(Vector3(x: 0, y: -1, z: 0))
  roomDescriptions[Vector3()] = "You spot a door in the distance."
  roomDescriptions[Vector3(x: 0, y: -1, z: 0)] = "Coming closer to the door, you can make out the details better."

  while lastInput != "q":
    lastInput = readLineFromStdin(">")
    if parseIdent(lastInput, lastVerb) != 0:
      if lastVerb in verbs and parseIdent(lastInput, lastVerbObject, lastVerb.len + 1) != 0:
        verbs[lastVerb](lastVerbObject)
    
  discard getch()
  stdout.resetAttributes()
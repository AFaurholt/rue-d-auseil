import std/[strutils, tables]
import text_adventure/helper

proc testConvertColor() =
  const
    expected = "<0>0</> <1>1</> <2>2</> <3>3</> <4>4</> <5>5</> <6>6</> <7>7</> <8>8</> <9>9</> <10>10</> <11>11</> <12>12</> <13>13</> <14>14</> <15>15</>"
    input = "<black>0</> <navy>1</> <maroon>2</> <darkGreen>3</> <brown>4</> <darkGrey>5</> <lightGrey>6</> <white>7</> <red>8</> <orange>9</> <yellow>10</> <lightGreen>11</> <blue>12</> <purple>13</> <pink>14</> <peach>15</>"
    
  var
    actual: string

  actual = input.multiReplace(colorReplaceTuples)

  assert actual == expected, "\ngot " & actual & " \nbut expected " & expected

testConvertColor()

proc testGetGameData() =
  var
    expected = newGameData()
    actual = getAllGameData()

  expected.descriptions["bedroom"] = 
    "Zann's bedroom is spare and dusty."
  expected.descriptions["bedstead room"] = 
    "There is a rusty <12>bedstead</>, formerly grandiose, covered by a somewhat threadbare <12>duvet</> which barely disguises the bed's sagging springs."
  expected.descriptions["bedstead self"] = 
    "When pushed aside, the bedstead reveals an indentation in the plaster which hides a very small <12>crucifix</> hewn from wood."
  expected.descriptions["duvet self"] = 
    "The duvet is thin and worn. When lifted, it shows discoloration in the form of a body as if it absorbed much sweat at night. The underside has ripped threads with slight bloodstains as if it had been drawn along skin abrasions or used to drag an inert body across rough terrain."
  expected.titles["door to the bedroom"] = "Bedroom door"
  expected.titles["door to the entrance"] = "Entrance door"
  expected.titles["bedstead"] = "Bedstead"
  expected.titles["crucifix"] = "Crucifix"
  expected.titles["duvet"] = "Duvet"
  expected.titles["bedroom"] = "Zann's bedroom"
  expected.titles["hall"] = "Hall"
  expected.leadsTo["door to the bedroom"] = "bedroom"
  expected.leadsTo["door to the entrance"] = "hall"
  expected.selfDescriptions["bedstead"] = "bedstead self"
  expected.selfDescriptions["duvet"] = "duvet self"
  expected.selfDescriptions["bedroom"] = "bedroom"
  expected.selfDescriptions["hall"] = ""
  expected.roomDescriptions["bedstead"] = "bedstead room"
  expected.canPickup["bedstead"] = false
  expected.canPickup["duvet"] = false
  expected.canPickup["crucifix"] = true
  expected.inventory["bedroom"] = @["bedstead"]
  expected.exits["hall"] = @["door to the bedroom"]
  expected.exits["bedroom"] = @["door to the entrance"]
  expected.startRoom = "hall"

  assert expected.descriptions == actual.descriptions, "\ngot: " & $actual.descriptions & "\nexpected: " & $expected.descriptions
  assert expected.titles == actual.titles, "\ngot: " & $actual.titles & "\nexpected: " & $expected.titles
  assert expected.leadsTo == actual.leadsTo, "\ngot: " & $actual.leadsTo & "\nexpected: " & $expected.leadsTo
  assert expected.selfDescriptions == actual.selfDescriptions, "\ngot: " & $actual.selfDescriptions & "\nexpected: " & $expected.selfDescriptions
  assert expected.roomDescriptions == actual.roomDescriptions, "\ngot: " & $actual.roomDescriptions & "\nexpected: " & $expected.roomDescriptions
  assert expected.canPickup == actual.canPickup, "\ngot: " & $actual.canPickup & "\nexpected: " & $expected.canPickup
  assert expected.inventory == actual.inventory, "\ngot: " & $actual.inventory & "\nexpected: " & $expected.inventory
  assert expected.exits == actual.exits, "\ngot: " & $actual.exits & "\nexpected: " & $expected.exits
  assert expected.startRoom == actual.startRoom, "\ngot: " & $actual.startRoom & "\nexpected: " & $expected.startRoom
testGetGameData()
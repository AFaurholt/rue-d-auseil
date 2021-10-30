# Rue D'Auseil Text Adventure Engine thingy

## Built-in inputs
F1 and F2 to change text size
Arrow up and down to scroll
Enter to input
Backspace to delete
The currently supported commands are:  
Things in ( ) is either the object word for the exit or item
- ```debug```: Dumps the world state in console
- ```enter (exit)```: Goes to where that exit leadsTo
- ```look```: Gives the room description
- ```back```: Same as above
- ```examine (thing)```: Can be used on items and exits to show the selfDescription, if it has one
- ```inventory```: Shows a list of what the player is carrying
- ```take (item)```: If the item has pickup:true, removes it from the room and adds it to the players inventory
- ```drop (item)```: Opposite of the above, just regardless of pickup state
- ```unlock (exit)```: If player has the correct item in their inventory, the exit unlocks
- ```!newgame```: Starts a new game (hot reload of all assets)
- ```!save (filename)```: Saves the game to filename
- ```!load (filename)```: Loads filename and displays the current room

## Syntax
The syntax for making assets is a simple new-line delimited list of key:value pairs, or sometimes just a key. Keys and values are CaSe-sEnSiTiVe so watch your spelling. Even if some missing syntax does not crash the game immediately, it could when the game tries to look for that info. Where filenames are needed you do not need the extension, so if you have myFile.txt, then myFile will do.
## Rooms
Minimum:
- ```title:(string)``` - The title will be displayed in the top bar depending on context
- ```selfDescription:(description file name)``` - The selfDescription is printed first in the room's description. Then comes items, then exits.

Optional:
- ```exits:(comma seperated list of exit file names)``` - Most rooms will need at least one exit so the player can navigate between them.
- ```startRoom``` - Starts the player in this room

## Items
Minimum:
- ```object:(comma seperated list of words)``` - This list contains the object words that "hit" this item.
Example:  
```object: lock, padlock```

  Here if the player typed ```take padlock``` or ```take lock``` they would both hit this item.

(If you intend for the item to be in a room, you'll likely need most of these)  
Optional:
- ```title:(string)``` - Displayed in the top bar when examining the item
- ```selfDescription:(description file name)``` - Displayed when examing the item
- ```roomDescription:(description file name)``` - Displayed in the room's description, if the item is in that room
- ```pickup:(bool)``` - true if the item can be taken, false otherwise
- ```inRoom:(room file name or playerCharacter)``` - The room inventories this item starts in. You can also start items in the players inventory with playerCharacter

## Exits
Minimum:
- ```title:(string)``` - Displayed at the top bar

The thingy also supports an event system with custom verbs

Also supports events that follow this syntax:
- ```display/(description)```: Displays the description
- ```subDisplay/(num)/(string)```: num can be 1, 2 or 3 for which line in the subTextBox you want to display to, and the string can be a color formatted string such as ```<red>Danger!</>```
- ```unlock/(exit)```: Unlocks exit
- ```lock/(exit)```: Locks exit
- ```pickup/add/(item)```: Makes the item pickupable
- ```pickup/del/(item)```: Reverse of above
- ```item/add/(item)/(inventory)```: Adds item to inventory
- ```item/del/(item)/(inventory)```: Reverse of above
- ```exit/add/(exit)/(room)```: Adds exit to room
- ```exit/del/(exit)/(room)```: Reverse of above
- ```desc/self/(thing)/(description)```: Changes the thing's selfDescription to description
- ```desc/room/(thing)/(description)```: Changes the thing's roomDescription to description
- ```desc/lock/(thing)/(description)```: Changes the thing's lockDescription to description (only makes sense for exits right now)
- ```gameOver```: Stops accepting input except for !newgame, !save and !load

I haven't finalized the format for all the files but it's generally lenient and you don't need all fields every time, and the order doesn't matter either. It is CaSe-sEnSiTiVe and not super consistent atm. Hopefully you can learn to use it from playing around with the stuff that's there for now.
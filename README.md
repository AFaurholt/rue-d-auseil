# rue-d-auseil
F1 and F2 to change text size
F3 and F4 to change text box size
Arrow up and down to scroll
Enter to start typing
Backspace to delete
The currently supported commands are:  
Things in ( ) is either the object word for the exit or item, or the file name in case of events
- debug: Dumps the world state in console
- enter (exit): Goes to where that exit leadsTo
- look: Gives the room description
- back: Same as above
- examine (thing): Can be used on items and exits to show the selfDescription, if it has one
- inventory: Shows a list of what the player is carrying
- take (item): If the item has pickup:true, removes it from the room and adds it to the players inventory
- drop (item): Opposite of the above, just regardless of pickup state
- unlock (exit): If player has the correct item in their inventory, the exit unlocks

Also supports events that follow this syntax:
- display.(description): Displays the description
- unlock.(exit): Unlocks exit
- lock.(exit): Locks exit
- pickup.add.(item): Makes the item pickupable
- pickup.del.(item): Reverse of above
- item.add.(item).(inventory): Adds item to inventory
- item.del.(item).(inventory): Reverse of above
- exit.add.(exit).(room): Adds exit to room
- exit.del.(exit).(room): Reverse of above
- desc.self.(thing).(description): Changes the thing's selfDescription to description
- desc.room.(thing).(description): Changes the thing's roomDescription to description
- desc.lock.(thing).(description): Changes the thing's lockDescription to description (only makes sense for exits right now)

I haven't finalized the format for all the files but it's generally lenient and you don't need all fields every time, and the order doesn't matter either. It is CaSe-sEnSiTiVe and not super consistent atm. Hopefully you can learn to use it from playing around with the stuff that's there for now.
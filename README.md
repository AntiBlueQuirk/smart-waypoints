# Smart Waypoints

Download at [the mod portal](https://mods.factorio.com/mod/smart-waypoints), or search for it in game! (>= 0.17 required)

Skip to the [example section](#example) for a quick overview.

Smart Waypoints is a mod that enables waypoints with special names to control trains that go by, skipping around their schedule.

This mod does not add any new items or technologies to the game, its functionality is available from the first train stop you build. Smart Waypoints are any train stops that start with the default delimiter of `/`. This means in most worlds, you can just add Smart Waypoints without trouble. The mod does minimal processing
except when a smart waypoint is hit, so FPS should be minimally impacted.

Note that this mod was written in an afternoon, and due to limitations within the game, is a little odd to use. It's intended mostly as a proof of concept, but if you get some use out of it, that's great. Honestly, it took me almost as long to write this readme. :)

## How To Use

To create a Smart Waypoint, create a train stop with a name that matches the special format. This is called an "Order".

 - `/ACTION/SCRIPT`

The second `/` and everything after may be omitted. Such an order is called a "Direct Order", and it is treated as a script that always returns `true`.

An order "runs" whenever a train *leaves* its stop. This means that if the stop has wait conditions, the order won't run until the train leaves the stop. If the stop has no wait conditions (a waypoint), the order will run as the train goes by. This means that the train must actually reach the stop to run the order. Unfortunately, this means that with the current design of the mod, you are likely to have a large amount of stops named "/1". The stop must also actually be in the train's schedule. If a train just passes a smart waypoint, but that smart waypoint isn't it's current destination, nothing happens.

## Actions

The `ACTION` indicates the action that the order should take on the train. The action is only taken if the order succeeds.

 - If an action references an "absolute" entry, it means an entry in the trains schedule, starting at 1, where 1 is the first schedule entry.
   - If the target entry is one that does not exist, such as 0, or one past the end of the schedule, nothing happens. (Or, if configured, a stop error occurs.)
 - If an action references a "relative" entry, it means the entry relative to entry that caused the order.
   - 0 is the same entry, negative numbers indicate entries before, positive numbers indicate entries after.
   - Relative references may wrap the schedule. For instance, if the last schedule entry is `/+2`, the train's second schedule entry will be jumped to.

These are the actions you can use:

 - `/=X/` or `/X/` - (Where `X` is an integer)
   - The script must return a boolean-like value. If the value is like true, the *absolute* entry X is skipped to.
   - `/1` references the train's first schedule entry, `/2` is the second, and so on.
 - `/+X/` or `/-X/` - (Where `X` is an integer)
   - The script must return a boolean-like value. If the value is like true, the *relative* entry X is skipped to.
   - `/+0` means the schedule entry that triggered the order, `/+1` means the entry after, `/-1` means the entry before, and so on.
 - `/'Name/`
   - The script must return a boolean-like value. If the value is like true, the order searches for the next schedule entry with the given name, after the current entry, wrapping back to the start if the end of the schedule is reached, and jumps to it. (This is treated as an absolute jump.)
 - `/=/`
   - The script must return a number. The number returned is the *absolute* entry to skip to.
 - `/+/`
   - The script must return a number. The number returned is the *relative* entry to skip to.
 - `//`
   - The script can return anything. The action does nothing.

In addition, you may prefix the action with `!`. This will cause the result of the order to always be printed, as if debug_orders was true in the config.

Note that actions that require numbers cannot be used with Direct Orders. (Orders that omit a script.) Leading and trailing whitespace is removed from actions before parsing, so you may put padding around them if you would like.

## Scripts

The `SCRIPT` indicates the actual logic that will happen as the train goes by. For actions that include a schedule entry, it is a conditional, determining whether the action is taken. For actions that do not include a schedule entry, it returns a number, indicating the order to jump to.

Scripts are Lua scripts, run using the same Lua system that the game uses, but under a limited sandbox. Only a simple explanation of Lua will be included here. For more inforation about Lua, see the [Lua 5.2 Manual](https://www.lua.org/manual/5.2/).

The simplest scripts just check a condition and return true or false. Here are some example scripts, followed by and English explanation:

 - `item_count('iron-plate') > 100`
   - "If there are more than 100 iron plates in cargo."
 - `fluid_count() == 0`
   - "If the train has no fluid on board."
 - `math.random() > 0.5`
   - "Randomly true, 50% of the time."

There are 6 relational operators, which return true or false: `==`, `~=`, `<`, `>`, `<=`, `>=`

There are also 3 logical operators, which combine other true/false values: `and`, `or`, `not`. You may also use parentheses to group expressions.

 - `item_count() == 0 and fuel_count() < 10`
   - "If cargo is empty, and fuel count is less than 10."
 - `fluid_count() > 0 and (not fluid_count('crude-oil') > 0)`
   - "If carrying fluid cargo, and none of it is crude oil."
   
As a technical aside, most scripts are evaluated as if they were written `return YOURSCRIPT`. If a script contains the string `return` anywhere in its text, instead it is evaluated as if it was written `return (function() \n YOURSCRIPT \n end)()`. Using this, you can pack a decent amount of logic in station names.

## Script Library

The mod provides only a few functions right now for getting information about the train, but hopefully in the future this will be expanded. The library right now is:

 - `item_count(itemspec)`
   - Counts up all the items in cargo on the train and returns their total number. If itemspec is given, only items with that id are counted.
   - You can see an item's ID by enabling Debug Mode (F5).
 - `fluid_count(itemspec)`
   - Counts up all the fluids in cargo on the train and returns their total number. If itemspec is given, only fluids with that id are counted.
   - You can see a fluid's ID by enabling Debug Mode (F5), looking at the id for an appropriate barrel, and removing '-barrel' from the id.
 - `fuel_count(itemspec)`
   - Counts up all the fuel items in locomotives on the train and returns their total number. If itemspec is given, only items with that id are counted.
 - `signal(itemspec)`
   - Returns the count of the signals from the train stop. If itemspec is given, only items/fluids with that id are counted.
   - There is no in game way to see virtual signal names, but they usually have names like `signal-1`, `signal-A`, `signal-red`, and `signal-check`.
   - Due to limitations, if you have two stops with the same name very close to each other, the script may get confused about which stop to read signals from.
 - `passengers(passspec)`
   - Counts up all the passengers in the train and returns their total number. If passspec is given, only passengers with that name are counted.
 - `alert(message, icon, show_on_map)`
   - Adds an alert to the map, as if created by a programmable speaker.
 - `id`
   - The numeric id of the train. This is the same number that "Read stopped train" at a train stop gives over the circuit network.
 - `speed`
   - The current speed of the train, in km/h.

In addition, most of the Lua standard library is available, including but not limited to: `pairs`, `tonumber`, `math`, `string`, `table`, etc.

## Example

A train has this schedule:

 1. `/+4/fuel_count() <= 5`
 2. `/'Iron Unload/item_count('iron-plate') > 0`
 3. `Iron Load`
 4. `/1`
 5. `Fuel Up`
 6. `/1`
 7. `Iron Unload`
 
The track layout looks something like this. Note that the train travels clockwise in this loop, and stops 4 and 6 have the same name:

    /-------\--\--\
    |  12   |  |  |
    |      3| 7| 5|
    |      4|  | 6|
    |       |  |  |
    \-------/--/--/

As the train passes stops 1 and 2, it will decide to which of stations 3, 5, and 7 to goto:

 - If it is low on fuel, it will go to stop 5, then goes back to stop 1.
 - If it has any iron on board, it will go to stop 7, unload, then goes back to stop 1.
 - Otherwise, it goes to stop 3, loads up on iron, then goes back to stop 1.

## More Examples

 - `/'Fuel Up/fuel_count() < 0`
   - Skip to the next schedule stop named 'Fuel Up'
 - `/+2/item_count() > 100`
   - "If carrying any cargo, skip the next schedule stop."
 - `//print("I'm going " .. speed " km/h")`
   - "The train prints its speed as it goes by."
 - `/=1/signal('signal-R') > 0`
   - "If there is any Signal R at the stop, go to stop 1."
 - `/!1/id == 22`
   - "If this is train 22, go to stop 1. Always print the result as if debug mode was on."
 - `/`
   - "Always succeeds at doing nothing."

## FAQ

 - Why is it all so clunky?
   - The game's API for controlling train schedules is pretty narrow, and there's no way to modify the vanilla train UI. So I came up with the waypoint system instead.
 - My order doesn't work, but I'm not seeing an error.
   - Depending on the kind of order, it may be silently failing. This can happen if you're using absolute stop actions, but the number you gave was out of range. Try prefixing your action with `!`, which will cause the result of the order to printed when it happens.
 - Future plans?
   - Well, I'd like the method for setting orders to be cleaner, but that would require some changes to the game. For one, you would need to be able to specify names for non-existent stations. Second, the game would have to not just skip over non-existent stations, even if it was only for a frame. At the very least some sort of "train-schedule-updated" event would be necessary. Beyond that, it would be nice to expand the capabilities of scripts, for instance, allowing them to send signals as well as receive them.
   - I've also had an idea for another way to go about this, and just attach full Lua scripts to trains. That would allow fully programmable trains, but it would be far more technical than even this mod is.
 - API/feature requests for the devs?
   - `train-schedule-updated` event, or something like it, that triggers whenever a train picks a new destination. This would optimize the mod quite a bit, since I wouldn't have to poll trains for schedule changes.
   - Allow setting schedule destinations manually, so the user can type whatever they want. Also, don't skip non-existent stations immediately, wait a frame at least so events can trigger and respond. This would mean that placing stops would be unnecessary, and train schedules and stop names wouldn't be coupled together the ugly way they are now. The entire script could be managed from the train screen.
   - Or just add conditional goto orders. :)

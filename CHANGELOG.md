# Changelog

## 0.4.0 - Your item level

- **Item level in the character window**: under the stats, a row with the item level of what you wear now, from level 10 as the game shows one.
- **Item level of each gear set**: the tooltip of a set in the Equipment Manager ends with the item level of the items in the set. A set that leaves slots as they are shows none, here and in the gear panel.
- **One item level everywhere**, with one decimal: the levels of 17 slots (all but shirt and tabard) over 17, an empty slot counting 0 and a two-handed weapon with nothing in the off hand counting twice. That is the game's way, but with the ranged slot, which the game's own average leaves out though it holds the main weapon of many hunters and the relics and totems of other classes. The same items give the same level in the character window, in a set's tooltip and in the gear panel, also for "Equipped" (0.3 showed the game's average there, and the plain average of the items for sets).
- The item level shared with what you wear is worked out this way too, so the guild's Discord bot gets this figure from members on 0.4. Members on 0.3 and 0.4 share everything with each other.

## 0.3.0 - Item levels and slots left as they are

- **Item level in the gear panel**: under the icon of the set shown, its item level, the average of its items (shirt and tabard left out, as the game does), and, for "Equipped", the game's own average item level.
- **Slots a set leaves as they are**: the slots ignored in the Equipment Manager show the game's mark, with a tooltip that says so, instead of an empty slot.
- Members on 0.2 keep sharing builds and sets with this version; their sets come without item levels or ignored slots, and they skip what 0.3 adds.

## 0.2.0 - The gear you wear

- **The gear you wear goes with your talents**: while the talents in use share their gear ("Share gear" at the bottom of the talent window), what you wear is shared too, with its item levels and your average item level. Untick the box of the talents in use and it is taken back from the guild's copies, as with the gear sets.
- **"Equipped" in the gear panel**: beside a member's talents in use, after their gear sets, what they wear, with their average item level. A build without gear sets shows it too, so its gear opens from the roster and from the talent window's gear button. Other addons, such as the guild's Discord bot exporter, can read it as well.
- **Points not spent yet** are shared with the talents.
- Members on 0.1 keep sharing builds with this version, and skip what 0.2 adds.

## 0.1.0 - First release

- **Specializations in the guild roster**: in the Class column, next to each member's class, one icon per spec group (two with dual spec), Primary then Secondary, the one not active dimmed. The icon is the talent tree with the most points. Point at it for the tree, the points in each tree, its gear sets and when it was last updated.
- **Builds in the game's talent window**: click an icon to see that build in the game's own talent window, the way it shows a talent build linked in the chat, also while the member is offline. Click it again to close the window. Your own icons open your own talents.
- **Gear beside the talents**: the build's gear set shows in a panel beside the talent window, its items by slot with their tooltips; a menu picks between the build's sets. When only the gear is shared, it opens beside the guild window. A button by each window's close button opens or closes the other: the gear from the talents and the talents from the gear, greyed when that part is not shared.
- **Gear sets for your talents**: give the Equipment Manager's sets to your Primary or Secondary talents, from the menu at the bottom of your talent window or from each set's settings button in the character window. The first set given is the default until you pick another, and switching talents equips it (you can turn that off).
- **You choose what to share**: at the bottom of your talent window, for each spec group on its own, "Share talents" (off until you tick it) and "Share gear" (on until you untick it). Talents you do not share still show their main tree and points in the roster, but never leave your computer, and taking something back removes it from the guild's copies too.
- **Room for the icons**: the Class column gets just wide enough for the class icon and two more, and the Note column narrower; the other columns keep their width.
- **Shared through hidden addon messages**: each member's builds reach the rest of the guild, and you get the builds of guild members you never meet online, as long as someone with the addon is online.
- Members without the addon show only their class, as before.

# Changelog

## 0.8.0
- **Guild stock:** the guild master and officers can set minimum amounts for the guild bank
  (potions, food, bandages, bars …). The new *Guild stock* view shows what's below target, who can craft it
  and which mats are needed for the missing amount – with a button to ask the guild for those mats.
- Stock targets are shared with the guild and only accepted from the guild master and officers.
- Add targets with the input above the list (shift-click an item) or with `/fsmith target [item] 40`.
- Recipes for consumables and trade goods (potions, bandages, bars, cloth …) from all professions are now recorded too.
  Open your profession windows once after updating.
- Buff food detection now requires the "Well Fed" buff, so elixirs are no longer mistaken for food.

## 0.7.1
- Fixed: mat requests from guild members didn't show up. WoW Forever reports realm names differently
  on each client, so requests were wrongly rejected – names are now compared without the realm.
- Fixed: whisper buttons added a realm name that WoW Forever doesn't recognize ("No player named … is online").
  Whispers now go to the character name only and also work with surnames.
- Friends sync also compares names without the realm now.
- Request times use the server time instead of each player's PC clock.
- New command `/fsmith debug` shows incoming Friendsmith messages in chat (helps with bug reports).

## 0.7.0
- **Mats:** the details of an upgrade now list the mats it needs – how many you have (bags and bank of all your
  characters), how many are in the guild bank and what's still missing.
- **Guild bank:** whenever someone with Friendsmith opens the guild bank, its contents (tabs they can see) are
  shared with the guild. The window shows how old that snapshot is.
- **Mat requests:** *Ask for mats* saves a request for the missing mats that everyone in your guild with Friendsmith
  sees under the new *Mat requests* view, and prepares a guild chat message (you press Enter to send it).
  Requests show whether you have some of the mats and offer a whisper button; they expire after 3 days
  or when you close them.
- Recipe mats are recorded when a crafter opens their profession window, so crafters need to open it once after updating.

## 0.6.1
- The panel next to the profession window now also works for Cooking: it lists your buff food by category,
  strongest first. Gold means nobody you know can cook anything better in that category.

## 0.6.0
- **Buff food:** new view that shows who can cook the best "Well Fed" food in each category
  (Stamina & Spirit, Agility, Strength, Intellect, Mana regeneration …) – across your alts, guild and friends.
  The best food of each category is highlighted; the detail pane shows the buff, all cooks and a whisper button.
- Cooking recipes are now recorded when you open the cooking window and shared like gear recipes.
  Older Friendsmith versions simply ignore them.
- Item tooltips now also show who can cook a food.

## 0.5.0
- **Friends:** Friendsmith now also syncs with people on your friend list who use it, even if they're not in your guild.
  Data is exchanged automatically when you or a friend logs in, and only accepted from people on your own friend list.
  Can be turned off in the sidebar (*Share with friends*). Friends are marked as "Friend" in the window.
- The panel next to the profession window now matches the look of the profession window
  (Blizzard dialog frame, gold category headers, standard fonts and buttons).
- The *Sync* button and `/fsmith sync` now include online friends.
- The third view is now called *Guild & friends*.

## 0.4.0
- The interface is now in English. German game clients still show everything in German.
- New command `/fsmith armor` (the old `/fsmith ruestung` still works).

## 0.3.0
- New name: **Friendsmith** (formerly Zunftschmiede). Commands are now `/fsmith` and `/friendsmith`.
- Spec-aware ratings: once talent points are spent, item stats are weighted for the character's spec
  and compared with the equipped item (including random suffixes like "… of the Monkey").
  Can be changed per character; without talents, item level is used.
- Caster gear is no longer suggested to melee classes, and melee gear is no longer suggested to casters.
- Addon button with its own logo: broker bars (Titan Panel, ChocolateBar, …), minimap and addon compartment.

## 0.2.0
- New window: sidebar with "For me", "I can craft" and "Whole guild",
  a collapsible list like the profession window, a detail pane with comparison and whisper buttons, and a search box.
- Panel next to the profession window: "Upgrades for you / <alt> / <guildmate>" from the open profession.
- Bind-on-pickup items are only suggested to the crafter themselves.

## 0.1.0
- First version: records gear and recipes, shares them with the guild, rates upgrades by item level.

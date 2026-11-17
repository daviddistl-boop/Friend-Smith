# Changelog

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

# Changelog

## 0.15.0
- **Classic look:** in *Settings → Window → Look* you can switch Friendsmith between the modern look and a classic
  Blizzard look (dialog frame, gold accents, red buttons). Takes effect after a reload.
- Fixed for WoW Forever: food, armor kits and other non-equippable crafts were never recorded (the client reports
  them with a special "no slot" value). Buff food and guild stock now see them – open your profession windows once.
- Fixed for WoW Forever: jumping to a recipe used a function Forever blocks for addons; Friendsmith now selects the
  recipe directly in the profession window's list.
- New command `/fsmith apicheck`: writes a report of what the game client provides (for development and bug reports).

## 0.14.7
- Fixed: worn items with random bonuses ("… of the Falcon") were rated without those stats on WoW Forever, so worse
  items showed up as big upgrades (e.g. +286 %). Friendsmith now rates worn items by their full item link, including
  all bonuses, and shares those links with the guild. Log in once on each character after updating.

## 0.14.6
- The spec is now also detected on WoW Forever without OneForAll: Friendsmith reads the new talent system itself and
  assigns the talents to the three trees by their sub-tree (or position, left to right). OneForAll is still used first
  when installed, since it knows the exact tree of every talent.

## 0.14.5
- Fixed: the spec wasn't detected on WoW Forever (new talent system), so items were rated by item level only and
  some worse items showed up as upgrades. With OneForAll installed, Friendsmith now reads the talent points per tree
  the same way OneForAll does.
- Without detected talents, items are no longer rated by item level alone but by the class's usual leveling tree
  (e.g. Retribution for paladins, Enhancement for shamans, Feral for druids, Shadow for priests).
- If you wear part of an item set, a new item has to be clearly better before it's suggested ("set bonus lost" is shown).

## 0.14.4
- *Enchanting* now shows only the best enchants for each free slot, rated for the character's class and spec
  (e.g. Agility and Stamina for a hunter, no Spirit or Strength). Of the armor kits, only the best one the character
  can already use is shown.
- Clicking an item you can craft in the Friendsmith window jumps straight to its recipe in the profession window.
  If the profession window isn't open, Friendsmith jumps there as soon as you open it.

## 0.14.3
- Buff food now uses the categories of the cooking window ("Stamina Food", "Agility Food" …), which WoW Forever already
  sorts by buff. This works no matter how the tooltips are worded. Where the buff value isn't known, food is ranked by
  required level. Cooks need to open their cooking window once after updating.
- `/fsmith foodcheck` also shows how many recipes were found in buff food categories.
- *I can craft* and the profession window panel now show only the best item you can craft per player and slot
  (one shoulder for a player instead of three).

## 0.14.2
- Fixed: the OneForAll leveling route in *Profession help* differed from OneForAll's own Skill-Up Helper.
  Friendsmith now uses the same settings (patterns from the auction house / from vendors), so it shows the same route.
  The route is also recalculated when those settings change and every 30 minutes (auction prices).

## 0.14.1
- Fixed: buff food wasn't recognized on some clients ("none of your cooking recipes gives Well Fed").
  The "Well Fed" name is now looked up when needed instead of at login, colored tooltip lines are handled,
  and the German "satt" is recognized directly.
- New command `/fsmith foodcheck`: shows how Friendsmith rates your cooking recipes – helpful for bug reports.

## 0.14.0
- **Enchanting view:** shows your gear without an enchant and which enchants your guild's enchanters know for it –
  plus armor kits your leatherworkers can make for chest, legs, hands and feet. One click whispers the right person.
  Enchanters: open your enchanting window once so your guild sees your formulas.
- **Spare gear to disenchant:** green, blue and purple gear in your bags that none of your characters needs.
  Friendsmith estimates what it would disenchant into, who in the guild needs those mats right now (mat requests,
  guild stock, profession help) and which enchanter has the skill – and offers to whisper them.
  If a guild member could wear the item, it suggests giving it to them instead.
- **Your help this week:** the overview card shows how many people you helped this week – items given in trades,
  thank-yous received, help offered and welcomes. Only you can see it.

## 0.13.0
- **Helper profile:** in *Settings → Helper profile* you can tick what you're happy to help with – crafting, sharing mats,
  dungeons, quests, gathering, questions & tips or leveling together. Fixed topics only, no free text.
- **Helpers view:** shows who in your guild and among your friends is happy to help with what – online players first.
  One click opens a friendly whisper that fits the topic, so asking feels less awkward.
- **Welcome for newcomers:** when someone joins the guild, Friendsmith notices it, shares it in the guild feed and lists
  them under *New in the guild* with a *Whisper welcome* button. The overview reminds you to say hello.
- If you're new in a guild yourself, the overview welcomes you for a week and shows who is happy to help.
- New commands: `/fsmith helpers` and `/fsmith profile`.

## 0.12.0
- **Settings:** all switches moved from the sidebar into a settings page (*Settings* button above *Sync*,
  `/fsmith settings`, or *Options → AddOns → Friendsmith*). The new switches for milestones, login hints and the
  thank-you prompt after trades are there too.
- **Cleanup:** shortly after login Friendsmith removes old data – characters who left the guild or haven't been seen for
  60 days, old feed entries, expired requests and mats lists nobody needs anymore. Also available as *Clean up now* and `/fsmith cleanup`.
- **Leaner sync:** on login, Friendsmith only sends a short checksum per character. Guild members ask for the full data
  only if theirs is out of date, instead of everyone resending everything. The *Sync* button still sends everything.
  Older Friendsmith versions in the guild keep working.

## 0.11.0
- **Guild feed:** a new view with the nice moments of your guild – profession steps (75/150/225/300), level milestones,
  finished mat requests and thank-yous. Everyone sees that people in the guild help each other.
- **Say thanks:** thank someone with one click – in the guild feed (name or your current target), next to the crafter of an
  upgrade, or after a trade: when a guild member or friend gives you something, Friendsmith asks whether you'd like to say thanks.
  They get a short note and it shows up in the feed. You see how many thank-yous you've received.
- Congratulate others on their milestones with a prepared whisper.
- Only fixed texts, no free text; entries are only accepted from the player they're about.
- New commands: `/fsmith thanks Name [item]`, `/fsmith feed`, `/fsmith milestones` (share your milestones on/off),
  `/fsmith tradethanks` (prompt after trades on/off).
- The *Rescan gear* button was removed from the sidebar to make room – `/fsmith scan` still does it.

## 0.10.0
- **Silent wishes:** not everyone likes to ask for help. Tick *Happy about help* in the sidebar and Friendsmith asks for you:
  guild members and friends see by themselves what they could craft for you and which mats you need for your profession.
  Nobody gets a message – it only shows up in Friendsmith.
- Players who are happy about help are marked in the window and in the profession panel, and are listed first.
- **Gentle hints for helpers:** shortly after login, Friendsmith tells you (only you, in your own chat) who you could help –
  an upgrade you can craft for someone, or mats in your bags that someone needs. At most 3 lines, the same hint at most once a day.
  Turn them off with `/fsmith nudges`.
- The overview shows how many guild members would be happy about help.
- New commands: `/fsmith wishes` (on/off) and `/fsmith nudges` (login hints on/off).

## 0.9.1
- **Profession help with OneForAll:** if you have OneForAll installed, Friendsmith asks its Skill-Up Helper for the
  route to your next big step and shows it in *Profession help* – the steps with their crafts, trainer visits,
  recipes you still have to learn and the mats for the whole route.
- The route is shared with your guild and friends, so they see it (and can help with mats) even without OneForAll.
- Friendsmith only calls OneForAll's planner while you play; no OneForAll data is included in Friendsmith.

## 0.9.0
- **Profession help:** new view that shows who in your guild, among your friends and alts is leveling a profession.
  For each profession it shows the skill (e.g. 132/150), the points to the next big step (75/150/225/300)
  and a suggestion like "~18x Dark Leather Boots (orange)" with the mats needed – including what you and the guild bank have.
- Helpers get a whisper button with the mats they can offer; for your own characters you can ask the guild for the missing mats.
- Shows when a player needs a trainer before they can level further.
- Skill and recipe colors are recorded when the profession window is opened, so everyone needs to open it once after updating.
  Yellow recipes are counted as roughly two crafts per point – it's an estimate.

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

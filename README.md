# Friendsmith

**Who in my guild can craft me something better – and who can I help?**

Friendsmith shows who in your guild, among your friends and your own alts can craft a gear upgrade for whom.
Made for craft-locked guilds on WoW Forever, but it works for any guild.

Languages: English and German (follows your game client).

## Features
- Remembers the equipped gear and all learned gear recipes of every one of your characters.
- Shares this data invisibly with everyone in your guild who also runs Friendsmith.
- **Friends:** also syncs with people on your friend list who use Friendsmith, even outside your guild.
  Data is only accepted from people on your own friend list. Turn it off with *Share with friends* in the sidebar.
- Works out which craftable items are better than what each character is currently wearing.
- Shows the results in a window (`/fsmith`) with three views:
  - **For me** – who can craft something better for you or your alts?
  - **I can craft** – who can you craft something better for with your professions (your alts, guild and friends)?
  - **Guild & friends** – everything at a glance.
  - **Guild stock** – minimum amounts for the guild bank set by officers: what's missing, who can craft it and which mats are needed.
  - **Mat requests** – which mats your guild is looking for right now, and whether you have some.
  - **Buff food** – who can cook the best "Well Fed" food in each category (Stamina & Spirit, Agility, Strength, Intellect, Mana regeneration …), best first.

  The list is grouped by character (or by crafter) and collapsible, just like the profession window.
  The detail pane compares the item with what the character is wearing and has buttons to whisper a request or an offer – the item link is already filled in.
- **Upgrades next to your profession window**, in the same style as the profession window: "Upgrades for you", "Upgrades for &lt;alt&gt;" and "Upgrades for &lt;guildmate&gt;" from the profession you have open.
  In the cooking window it lists your buff food by category instead – gold means nobody you know cooks anything better.
  Click to open the recipe, right-click to show it in the Friendsmith window.
  Drag the panel by its header, or turn it off in the window's sidebar.
- **Mats:** the details of an upgrade list the mats it needs – how many you have (bags and bank of all your characters),
  how many are in the guild bank and what's missing. *Ask for mats* creates a request your guild sees in Friendsmith
  and prepares a guild chat message – nothing is sent until you press Enter.
- **Guild bank:** when someone with Friendsmith opens the guild bank, the tabs they can see are shared with the guild.
  It's a snapshot, so the window shows how old it is.
- **Item tooltips** show "craftable by …" and "upgrade for …".
- **Addon button** with its own logo:
  - Broker launcher for bars like Titan Panel, ChocolateBar or Bazooka (shows "X for me · Y craftable")
  - Minimap button (uses LibDBIcon if available, otherwise its own button you can drag around the minimap)
  - Entry in the addon compartment menu

  Left-click opens the window, right-click opens "I can craft".

## Installation
**CurseForge app:** search for *Friendsmith* and install it.

**Manually:**
1. Copy the `Friendsmith` folder into `...\World of Warcraft\<your Forever folder>\Interface\AddOns\`.
   You can find the right game folder in the Battle.net launcher: WoW Forever → gear icon → *Show in Explorer*.
2. On the character select screen, open *AddOns* and make sure Friendsmith is enabled.
   If it's marked as *out of date*, tick *Load out of date AddOns*.
3. Restart the game completely (a `/reload` is not enough for a newly added addon).

## Getting started
1. Log in once on **every** character – their gear is saved automatically.
2. On each crafter, open **every profession window** once (including Cooking for the buff food list). Expand all categories and turn off
   filters like "Have Materials" so all recipes get recorded.
3. Ask your guild and friends to install Friendsmith. Everyone syncs automatically on login;
   you can also click *Sync* or type `/fsmith sync`.

## Commands
| Command | What it does |
|---|---|
| `/fsmith` | Open/close the window |
| `/fsmith sync` | Exchange data with your guild and friends |
| `/fsmith scan` | Rescan the open profession window |
| `/fsmith diff 3` | Only count +3 item levels (or +3 % with spec rating) as an upgrade (default: 1) |
| `/fsmith armor` | Also suggest lower armor types (on/off) |
| `/fsmith minimap` | Show/hide the minimap button |
| `/fsmith stock` | Open the guild stock |
| `/fsmith target [item] 40` | Set a stock target, officers only (0 removes it) |
| `/fsmith debug` | Show incoming Friendsmith messages in chat (on/off) |
| `/fsmith reset` | Delete stored data of other guild members |
| `/fsmith help` | List all commands |

`/friendsmith` works as well.

In the window: click for details, Shift-click to link in chat, Ctrl-click to try on, mouse wheel to scroll, search box at the top right.

## How upgrades are rated
- **By spec:** Once a character has spent talent points, the talent tree with the most points is used.
  Item stats (Strength, Agility, Spell Power, weapon DPS, Armor …) are weighted for that spec and compared
  with the equipped item – including random suffixes like "… of the Monkey".
  The window shows how many percent better the new item is.
- Caster gear for warriors and rogues, and melee gear for casters, is left out.
- Without talent points (or with *Rate by spec stats* turned off), only **item level** counts.
- You can override the rating per character in the detail pane via *change*
  (automatic → talent tree 1/2/3 → item level only). This only affects you.
- The stat weights are rough leveling values – feedback is very welcome.
- **Armor:** by default only the best armor type for the class (cloth/leather/mail/plate) following Classic rules.
  Warriors and paladins get plate from level 40, hunters and shamans get mail from level 40.
- **Weapons:** based on each class's Classic weapon skills (rogues can also use one-handed axes, as in Forever).
- Items you can wear within the next 2 levels are shown too.
- Per character and slot, at most the 3 best suggestions are shown – plus up to 3 that you can craft yourself.
- Bind-on-pickup items are only suggested to the crafter themselves, since they can't be traded.
- Only characters in your guild, from your friend list (plus your own characters) are included.
  Data older than 30 days is ignored.

## Notes
- This is an early version. WoW Forever restricts some addon features.
  If you run into a Lua error, turn on error messages with `/console scriptErrors 1` and include the error text in your report.
- Friendsmith doesn't send or calculate anything during combat.
- Want to add a language? Add a block to `Locales.lua`.

## Contributing & license
Ideas, bug reports and pull requests are welcome on GitHub. Every change is reviewed before it goes into a release,
and only the official CurseForge project publishes Friendsmith releases.

Friendsmith is released under the [MIT License](LICENSE).

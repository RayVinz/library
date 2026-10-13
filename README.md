<div align="center">

<!-- upload your logo as logo.png next to this README, then delete the arrows around the next line -->
<!-- <img src="logo.png" width="96" alt="RayVinz logo"> -->

# RayVinzUI

**A macOS-style, liquid-glass UI library for Roblox — one file, works on PC and mobile.**

<sub>Key System • Resizable window • Deep search • Configs • Themes • Notifications</sub>

</div>

---

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Window](#window)
- [Tabs & sections](#tabs--sections)
- [Elements](#elements)
- [Notifications & popups](#notifications--popups)
- [Themes](#themes)
- [Configs](#configs)
- [Key System](#key-system)
- [Window control](#window-control)
- [Extras](#extras)
- [Mobile](#mobile)
- [Changelog](#changelog)

---

## Features

| | |
|---|---|
| 🪟 **Window** | macOS traffic-light buttons, drag, iPad-style resize corner, full screen, hide hotkey |
| 🔑 **Key System** | Glass key screen with LuaProt, Luarmor, Panda, Junkie or your own check, saves the key |
| 🔍 **Deep search** | Sidebar search finds tabs **and** every setting inside them, then jumps to it |
| 💾 **Configs** | Auto-save, named configs, auto-load, one-line config manager |
| 🎨 **Themes** | Accent presets, Dark / Midnight / Light, rainbow accent, live switching |
| 🔔 **Popups** | Notifications with actions, dialogs, text prompts, loading screen, changelog |
| 📱 **Mobile** | Auto-scales to small screens, touch support, floating open/close button |

---

## Installation

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RayVinz/library/main/RayVinzUI.lua"))()
UI:LoadLucide() -- required for icon names like "house" or "bell"
```

> [!TIP]
> While testing, add `?cb=" .. tick()` to the URL to skip GitHub's cache and always get the newest version.
> Remove it in the version you give to players so it loads faster.

Icons use [Lucide](https://lucide.dev/icons) names (`"house"`, `"settings"`, `"bell"`…). You can also pass an image: `"rbxassetid://123456"`.

---

## Quick start

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RayVinz/library/main/RayVinzUI.lua"))()
UI:LoadLucide()

local Window = UI:CreateWindow({
	Title = "My Hub",
	Logo  = "rbxassetid://124905448303407",
	Folder = "MyHub",
	ConfigAutoSave = true,
	ToggleKey = Enum.KeyCode.RightShift,
})

local Main = Window:Tab({ Title = "Main", Icon = "house" })
local Farm = Main:Section({ Title = "Farming", Icon = "sprout" })

Farm:Toggle({ Title = "Auto Farm", Default = false, Callback = function(on)
	print("Auto Farm:", on)
end })

UI:Notify({ Title = "Loaded", Content = "My Hub is ready!", Type = "Success" })
```

---

## Window

```lua
local Window = UI:CreateWindow({ ... })
```

| Option | Type | Default | Description |
|---|---|---|---|
| `Title` | string | game name | Window title. Leave it out to use the current game's name. |
| `Author` | string | – | Small "By …" text next to the title. |
| `Version` | string | `"v1.0.0"` | Colored tag next to the title. |
| `Tags` | table | – | Extra tags: `{ { Text = "Beta", Color = Color3 } }` |
| `Logo` | string / number | `"sparkles"` | Image id or Lucide icon name. |
| `Width` / `Height` | number | `660` / `460` | Starting size. |
| `Resizable` | boolean | `true` | Drag the bottom-right corner to resize. |
| `MinSize` / `MaxSize` | `{ w, h }` | `{480,340}` / `{1200,860}` | Resize limits. |
| `Search` | boolean | `true` | Sidebar search box. |
| `ToggleKey` | KeyCode | – | Key that shows / hides the window. |
| `Folder` | string | `"RayVinz"` | Folder in `workspace` for configs and the saved key. |
| `ConfigAutoSave` | boolean | `false` | Save every change automatically and load it on start. |
| `ConfigName` | string | `"default"` | Config used by auto-save. |
| `AutoFlag` | boolean | `true` | Give every element a config name automatically. |
| `Protect` | boolean | `false` | If something removes the GUI, put it back. |
| `Loading` | table / boolean | – | Loading screen first: `{ Title, SubTitle, Duration }` |
| `Changelog` | table | – | Shown after loading: `{ Version, Changes = { … } }` |
| `OnReady` | function | – | Runs once the window is open. |
| `KeySystem` | table | – | Lock the window behind a key. See [Key System](#key-system). |

**Title-bar buttons:** 🔴 close & unload (asks first) · 🟡 hide · 🟢 full screen / restore

---

## Tabs & sections

```lua
Window:SidebarSection("Combat")                       -- small heading in the sidebar

local Aim = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
local Assist = Aim:Section({ Title = "Aim Assist", Icon = "target", Collapsible = true })

Aim:SetDot(true)   -- red "new" dot on the tab (clears when opened)
Aim:Select()       -- open this tab from code
```

| Section option | Description |
|---|---|
| `Title` | Section heading |
| `Icon` | Icon next to the heading |
| `Collapsible` | Click the heading to fold the section |

---

## Elements

Every element below goes on a **section**. Most return a control with `Set(value)` and `Get()`.
Add `Description = "..."` for small text under the title, and `Tooltip = "..."` for a hover tip.

<details>
<summary><b>Toggle</b></summary>

```lua
local t = Section:Toggle({
	Title = "Auto Farm",
	Description = "Farms while you're AFK",
	Default = false,
	Keybind = Enum.KeyCode.F, -- optional: press F to flip it
	Callback = function(on) end,
})
t.Set(true) ; print(t.Get())
```
</details>

<details>
<summary><b>Button</b></summary>

```lua
-- full-width button
Section:Button({ Title = "Start", Callback = function() end })

-- row-style button (has an Icon or Style = "Row")
Section:Button({ Title = "Teleport", Description = "Go to spawn", Icon = "map-pin", Callback = function() end })
```
</details>

<details>
<summary><b>Slider</b></summary>

```lua
local s = Section:Slider({
	Title = "WalkSpeed",
	Min = 16, Max = 200, Default = 16,
	Rounding = 0,        -- decimal places
	Suffix = " studs",   -- text after the value
	Callback = function(v) end,
})
```
</details>

<details>
<summary><b>Dropdown</b></summary>

```lua
-- single choice
local d = Section:Dropdown({ Title = "Egg", Options = { "Common", "Rare" }, Default = "Common", Callback = function(v) end })

-- multiple choices
Section:Dropdown({ Title = "Targets", Multi = true, Options = { "A", "B", "C" }, Default = { "A" }, Callback = function(list) end })

-- live options, re-read every time it opens, with a refresh icon
Section:Dropdown({
	Title = "Eggs in map",
	Options = {},
	RefreshButton = true,
	Refresh = function()
		local names = {}
		for _, v in ipairs(workspace:GetChildren()) do table.insert(names, v.Name) end
		return names
	end,
	Callback = function(v) end,
})

d.Refresh({ "New", "Options" }) -- replace the options from code
```
Lists with more than 6 options get a search box automatically (or set `Search = true`).
</details>

<details>
<summary><b>Textbox & Textarea</b></summary>

```lua
Section:Textbox({ Title = "Username", Placeholder = "type here...", Callback = function(text) end })
Section:Textarea({ Title = "Notes", Placeholder = "Enter text...", Height = 100, Callback = function(text) end })
```
</details>

<details>
<summary><b>NumberInput</b></summary>

```lua
Section:NumberInput({ Title = "Amount", Default = 10, Min = 0, Max = 99, Step = 5, Callback = function(v) end })
```
</details>

<details>
<summary><b>Keybind</b></summary>

```lua
Section:Keybind({ Title = "Toggle UI", Default = Enum.KeyCode.RightShift, Callback = function() Window:Toggle() end })
```
Click the button in-game and press a key to rebind it.
</details>

<details>
<summary><b>ColorPicker</b></summary>

```lua
Section:ColorPicker({ Title = "ESP Color", Default = Color3.fromRGB(255, 0, 0), Callback = function(color) end })
```
</details>

<details>
<summary><b>ButtonGroup</b></summary>

```lua
Section:ButtonGroup({ Buttons = {
	{ Title = "Fill",  Callback = function() end },
	{ Title = "Reset", Variant = "Primary", Callback = function() end },
} })
```
</details>

<details>
<summary><b>Display: Label, Paragraph, Tags, Divider, Image, Progress</b></summary>

```lua
Section:Label("Plain text")
Section:Paragraph({ Title = "About", Content = "Longer text that wraps." })
Section:Tags({ { Text = "v1.0", Color = Color3.fromRGB(255, 214, 10) }, { Text = "Premium" } })
Section:Divider("controls")
local img = Section:Image({ Image = "rbxassetid://124905448303407", Height = 90 })
local bar = Section:Progress({ Title = "Download", Default = 0.2 }) ; bar.Set(0.75)
```
</details>

<details>
<summary><b>Banner, UserInfo, SystemInfo, StatGrid</b></summary>

```lua
Section:Banner({ Title = "My Hub", SubTitle = "v1.0", Color = Color3.fromRGB(255,121,198), Color2 = Color3.fromRGB(189,147,249), Logo = "rbxassetid://..." })
Section:UserInfo({})   -- avatar + display name + @username, filled in automatically
Section:SystemInfo({}) -- live FPS, ping, executor, players, game, time
local stats = Section:StatGrid({ { Label = "Kills", Value = 0, Icon = "swords" }, { Label = "Coins", Value = 0, Icon = "coins" } })
stats.Set("Kills", 5)
```
</details>

<details>
<summary><b>ConfigManager & HWID</b></summary>

```lua
Section:ConfigManager()  -- create / select / load / delete / auto-load, all in one line
Section:HWID({ Callback = function(id) end }) -- shows the HWID with Copy + Reload buttons
```
</details>

---

## Notifications & popups

```lua
UI:Notify({
	Title = "Saved",
	Content = "Your config was saved.",
	Type = "Success",          -- "Info" | "Success" | "Warning" | "Error"
	Icon = "check",            -- optional, overrides the type icon
	Duration = 4,              -- seconds
	Actions = { { Title = "Undo", Primary = true, Callback = function() end } }, -- optional buttons
})

UI:Dialog({
	Title = "Confirm", Content = "Start auto farm?",
	Buttons = { { Title = "Cancel" }, { Title = "Start", Variant = "Primary", Callback = function() end } },
})

UI:Prompt({ Title = "Set target", Placeholder = "player name", Callback = function(text) end })

local ld = UI:Loading({ Title = "My Hub", SubTitle = "Loading..." }) ; ld.Set(0.5) ; ld.Close()

UI:Changelog({ Version = "v1.1", Changes = { "New key system", "Bug fixes" } })
```

---

## Themes

```lua
UI:SetAccent("Pink")                 -- Pink, Purple, Blue, Green, Red, Orange
UI:SetAccent(Color3.fromRGB(0, 200, 255))
UI:SetTheme("Midnight")              -- Dark, Midnight, Light
UI:RainbowAccent(true)               -- animated accent; UI:RainbowAccent(false) to stop
```

Themes switch live and can be changed as often as you like.

---

## Configs

Every element is saved automatically. To control the name used in the file, add `Flag = "name"`:

```lua
Section:Toggle({ Title = "Auto Farm", Flag = "autofarm", Callback = function() end })
```

| Function | Description |
|---|---|
| `UI:SaveConfig(name)` | Save all values |
| `UI:LoadConfig(name)` | Load values |
| `UI:ListConfigs()` | List saved configs |
| `UI:DeleteConfig(name)` | Delete a config |
| `UI:SetAutoLoadConfig(name)` | Config to load on start |
| `UI:SetFolder("MyHub")` | Change the save folder |

Files are saved in your executor's `workspace` folder:

```
workspace/
  MyHub/
    default.json     ← config
    _autoload.txt    ← config loaded on start
    key.txt          ← saved key (Key System)
```

> [!IMPORTANT]
> Give your hub its own `Folder`. Hubs that share a folder overwrite each other's configs.

---

## Key System

A glass key screen that waits until the player enters a valid key.

<details open>
<summary><b>With a key service (LuaProt example)</b></summary>

```lua
UI:KeySystem({
	Title = "My Hub",
	Logo  = "rbxassetid://124905448303407",
	Folder = "MyHub",
	SaveKey = true,
	API = {
		{
			Type = "luaprot",
			ScriptId = "YOUR_SCRIPT_ID",                  -- keep the quotes
			KeyLink = "https://luaprot.net/ad/YOUR_LINK",
			LoadScript = true,                            -- runs your protected script after a valid key
		},
	},
	Links = { { Title = "Discord", Content = "discord.gg/yourserver", Icon = "message-circle" } },
})
```
</details>

<details>
<summary><b>Supported services</b></summary>

| `Type` | Options |
|---|---|
| `"luaprot"` | `ScriptId`, `KeyLink`, `LoadScript` |
| `"luarmor"` | `ScriptId`, `KeyLink`, `LoadScript` |
| `"pandadevelopment"` | `ServiceId` |
| `"junkiedevelopment"` | `ServiceId`, `ApiKey`, `Provider` (load Junkie's SDK first) |
| `"custom"` | `Name`, `Verify = function(key) return valid, "reason" end`, `Link` |

Each service can also have `Title`, `Desc` and `Icon` for its card on the key screen.
</details>

<details>
<summary><b>Your own check</b></summary>

```lua
local ok = UI:KeySystem({
	Verify = function(key) return key == "MY-KEY", "Wrong key" end,
	KeyLink = "https://your-site.com/getkey",
})
if not ok then return end
```
</details>

<details>
<summary><b>All options</b></summary>

| Option | Description |
|---|---|
| `Title`, `SubTitle`, `Logo` | Header |
| `API` | List of key services (above) |
| `Verify` / `Keys` | Your own check, or a list of valid keys |
| `KeyLink` | Copied by "Get a key" (string or function) |
| `SaveKey` | Remember a working key and skip the screen next time (it's checked again first) |
| `Folder`, `FileName` | Where the key is saved: `<Folder>/<FileName>.txt` |
| `Links` | Extra cards on the right; clicking copies the text |
| `SupportedGames` | `{ [PlaceId] = true }` shows "Supported" / "Not in our list" |
| `OnSuccess` | Runs with the key after it's accepted |
</details>

> [!NOTE]
> Use **one key screen**: put `KeySystem` in your loader and `CreateWindow` in your protected hub,
> or use `CreateWindow({ KeySystem = { ... } })` in a single script.

> [!WARNING]
> The key screen is only the look. Real protection comes from your key service, so your hub must be
> the script the service protects.

---

## Window control

```lua
Window:Toggle()        -- show / hide (with animation + blur)
Window:Toggle(true)    -- show
UI:Unload()            -- close the UI and stop everything it was running
```

- **Resize:** drag the curved handle at the bottom-right corner.
- **Full screen:** green button. Press again to restore your previous size and position.
- **Search:** type in the sidebar search to find any setting, then click a result to jump to it.

---

## Extras

```lua
local wm = UI:Watermark({ Text = "My Hub" })   -- draggable FPS / ping / time bar
wm.SetVisible(false)

UI:CheckUpdate({ VersionUrl = "https://raw.githubusercontent.com/you/repo/main/version.txt", Current = "v1.0" })

UI:AntiSpy({ Kick = true, Interval = 1 })      -- detects common remote-spy tools
```

---

## Mobile

- The window scales down to fit small screens automatically.
- A floating logo button opens and closes the UI.
- Dragging, resizing, sliders, dropdowns, the color picker and the key screen all work with touch.
- Keybinds and hover tooltips need a keyboard and mouse, so give important actions a button or toggle too.

---

## Changelog

**0.0.1**

*New features*
- Key System (LuaProt / Luarmor / Panda / Junkie / custom check, saves your key)
- Resizable window (iPad-style corner handle)
- Deep search across every tab
- Custom folder for configs and the saved key
- Red button asks before closing

*Bug fixes*
- Full screen no longer goes off-screen and restores your previous size
- Red button now fully closes the UI instead of hiding it
- Switching themes quickly no longer breaks colors
- Logo no longer turns dark when changing theme
- Color picker and resizing work on mobile
- Less lag with rainbow accent
- Nothing keeps running after Unload
- Dropdown refresh button works

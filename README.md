# RayVinzUI

A single-file **macOS / iOS-26 "liquid glass"** UI library for Roblox — frosted blur, glass panels, smooth animations, and a huge component set. One `loadstring`, no dependencies (icons are optional).

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RayVinz/library/main/RayVinzUI.lua?cb=" .. tick()))()
```
> `?cb=`..tick() busts the CDN cache so you always get the latest while developing. Remove it when shipping.

---

## ✨ Features

- 🧊 **Liquid glass** — real frosted blur (BlurEffect) behind translucent glass panels, sheen highlights, soft shadows
- 🎞️ **Animations** — spring open/close/minimize, dropdown fade+slide, button ripple + hover scale
- 📱 **Mobile ready** — auto-scales to small screens, draggable floating toggle button, full touch support
- 🎨 **Theming** — live accent switch (`SetAccent`) + 6 presets, full theme swap (`SetTheme`: Dark/Midnight/Light), animated **rainbow accent**
- 💾 **Config system** — auto-save/-load every element (auto-flags), create/load/delete/overwrite named configs, auto-load selection
- 🛡️ **AntiSpy** — detect & kick remote spies (SimpleSpy/Hydroxide/Octo-Spy/Turtle Spy/Cobalt…) without false-positiving Infinite Yield
- 🔔 **Notify / Dialog / Prompt / Loading / Changelog** — glass toasts (with action buttons + dismiss), modals, text-input modals, loading splash, what's-new popup
- 🪧 **Watermark** — floating FPS/ping/time pill (draggable)
- 🧩 **20+ elements** — Toggle, Slider, Dropdown (single/multi/search/refresh), Textbox, Textarea, Keybind, ColorPicker, NumberInput, Button, ButtonGroup, Label, Paragraph, Tags, Divider, Image, Progress, StatGrid, SystemInfo, UserInfo, Banner, ConfigManager, HWID
- 🔍 **Quality of life** — sidebar search, collapsible sections, tooltips, tab notification dots, keybind-to-toggle, lucide icons
- 🧹 **Clean lifecycle** — `Unload()` disconnects everything (no leaks on re-run), auto re-inject if the GUI is removed

---

## 🚀 Quick start

```lua
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/RayVinz/library/main/RayVinzUI.lua?cb=" .. tick()))()
UI:LoadLucide() -- enable named lucide icons ("house", "egg", ...)

local Window = UI:CreateWindow({
    Title    = "My Hub",         -- omit to auto-pull the game name
    Author   = "you",            -- faint "By ..." next to the title
    Version  = "v1.0.0",         -- shown as a tag
    Logo     = "rbxassetid://0", -- or a lucide name
    Loading  = { SubTitle = "Loading...", Duration = 2 },
    Changelog = { Version = "v1.0.0", Changes = { "First release" } },
    ToggleKey = Enum.KeyCode.RightShift,
    ConfigAutoSave = true,
})

Window:SidebarSection("Menu")
local Home = Window:Tab({ Title = "Home", Icon = "house" })

local Sec = Home:Section({ Title = "Controls", Icon = "sliders-horizontal" })
Sec:Toggle({ Title = "Auto Farm", Default = false, Callback = function(on) end })
Sec:Slider({ Title = "Speed", Min = 1, Max = 100, Default = 50, Callback = function(v) end })
Sec:Button({ Title = "Start", Callback = function()
    UI:Notify({ Title = "Started!", Type = "Success", Icon = "check" })
end })
```

---

## 📖 API

### `UI:CreateWindow(opts)` → `Window`
| opt | type | note |
|---|---|---|
| `Title` | string | omit → auto game name |
| `Author` | string | faint "By ..." |
| `Version` | string | version tag |
| `Tags` | `{{Text,Color}}` | extra tags |
| `Logo` | asset/lucide | hub icon |
| `Width` / `Height` | number | default 660 × 460 |
| `Loading` | `true` / `{Title,SubTitle,Duration}` | intro splash |
| `Changelog` | `{Title,Version,Changes}` | shown after loading |
| `ToggleKey` | `Enum.KeyCode` | hotkey to open/close |
| `ConfigAutoSave` | bool | auto-save + auto-load |
| `ConfigName` | string | default config name |
| `AutoFlag` | bool (default true) | auto-save every element |
| `Protect` | bool | re-inject if GUI removed |
| `Search` | bool (default true) | sidebar search |
| `OnReady` | function | fires after the window opens |

### Tabs & Sections
```lua
Window:SidebarSection("Menu")                       -- sidebar header
local Tab  = Window:Tab({ Title, Icon, Default })   -- Default=true → first page
Tab:Select()                                        -- open this tab
Tab:SetDot(true)                                    -- red notification dot (clears on open)
local Sec  = Tab:Section({ Title, Icon, Collapsible })
```

### Elements (all on a Section)
```lua
Sec:Toggle({ Title, Description, Default, Flag, Tooltip, Keybind, Callback })      -- { Get, Set }
Sec:Slider({ Title, Description, Min, Max, Default, Rounding, Suffix, Flag, Callback }) -- { Get, Set }
Sec:Dropdown({ Title, Options, Multi, Default, Search, Refresh, RefreshButton, Flag, Callback }) -- { Get, Set, Refresh }
Sec:Textbox({ Title, Default, Placeholder, Flag, Callback })                       -- { Get, Set }
Sec:Textarea({ Title, Placeholder, Height, Flag, Callback })                       -- { Get, Set }
Sec:NumberInput({ Title, Default, Min, Max, Step, Flag, Callback })                -- { Get, Set }
Sec:Keybind({ Title, Default, Flag, Callback })                                    -- { Get, Set }
Sec:ColorPicker({ Title, Default, Flag, Callback })                                -- { Get, Set }
Sec:Button({ Title, Icon, Description, Variant, Callback })        -- Icon → row style; else full-width
Sec:ButtonGroup({ Buttons = { {Title, Variant, Callback}, ... } })
Sec:Label("text")
Sec:Paragraph({ Title, Content })
Sec:Tags({ {Text, Color}, ... })
Sec:Divider("optional label")
Sec:Image({ Image, Height, ScaleType })                                           -- { Set }
Sec:Progress({ Title, Default })                                                   -- { Set(0..1) }
Sec:StatGrid({ {Label, Value, Icon}, ... })                                       -- { Set(label, value) }
Sec:SystemInfo({ Icons = {...} })                                                 -- live FPS/Ping/Executor/Players/Game/Time
Sec:UserInfo({ Name, Tag, TagColor, Avatar })                                     -- { Set(name, tag) }  — no args = real player
Sec:Banner({ Title, SubTitle, Color, Color2, Logo, LogoSize, Image, Height })
Sec:ConfigManager()                                                               -- create/select/load/delete/auto-load UI
Sec:HWID({ Callback })                                                            -- show + copy + reload HWID
```
> Any element with a value is saved by Config. Add `Flag = "name"` for a stable key, or let auto-flag handle it.

### Popups
```lua
UI:Notify({ Title, Content, Type = "Info"|"Success"|"Warning"|"Error", Icon, Duration,
            Actions = { {Title, Callback, Primary, Close} }, MaxVisible = 5 })
UI:Dialog({ Title, Content, Buttons = { {Title, Variant="Primary", Callback} } })
UI:Prompt({ Title, Content, Placeholder, Default, Callback = function(text) end })  -- input modal
local ld = UI:Loading({ Title, SubTitle, Logo })    -- ld.Set(0..1), ld.Close()
UI:Changelog({ Title, Version, Changes = { "line", ... } })
```

### Theme
```lua
UI:SetAccent("Pink")   -- Pink / Purple / Blue / Green / Red / Orange, or SetAccent(Color3, Color3)
UI:SetTheme("Midnight")-- Dark / Midnight / Light, or SetTheme({ Background=, Sidebar=, Text=, ... })
UI:RainbowAccent(true) -- animated; (true, 0.03) for faster
```

### Config
```lua
Sec:ConfigManager()             -- full UI (recommended)
UI:SaveConfig("name")           -- or no name = auto-load config
UI:LoadConfig("name")
UI:ListConfigs() / UI:DeleteConfig("name")
UI:SetAutoLoadConfig("name") / UI:GetAutoLoadConfig()
```

### Extras
```lua
UI:AntiSpy({ KickMessage = "..." })                 -- kick remote spies (DetectHooks=false by default)
UI:Watermark({ Text = "My Hub" })                   -- floating FPS/ping/time pill (draggable)
UI:CheckUpdate({ VersionUrl = "...", Current = "v1.0.0" })
UI:Toggle()    -- open/close with animation
UI:Unload()    -- remove the UI + all connections + blur
```

---

## 🛡️ AntiSpy
```lua
UI:AntiSpy({
    Interval = 1, RemoveGui = true, Kick = true,
    KickMessage = "remote spy detected",
    DetectHooks = false,  -- keep OFF (executors hook metamethods → false positives)
})
```
Catches SimpleSpy, Hydroxide, Octo-Spy, Turtle Spy, Cobalt, Utopia, RemoteLogger. Infinite Yield and normal executors are **not** flagged.

---

## 📱 Mobile
Works out of the box — the window auto-scales to the screen, the floating button (drag to move, tap to open/close) toggles it, and all controls support touch.

---

*Made by RayVinz.*

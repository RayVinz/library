--!nocheck
-- ============================================================
--  RayVinzUI — FULL EXAMPLE (รันอันนี้เพื่อเทสทุก component + หาบัค)
--  โหลดผ่าน jsDelivr เพื่อเลี่ยง cache ของ raw.githubusercontent
-- ============================================================
local UI = loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/RayVinz/library@main/RayVinzUI.lua"))()
UI:LoadLucide() -- ★ ต้องเรียกก่อน icon ถึงจะขึ้น (tab/section/notify/traffic-light)

-- ---------- Window ----------
local Window = UI:CreateWindow({
	-- ไม่ใส่ Title = ดึงชื่อเกมอัตโนมัติ
	Author  = "406933_ / RayVinz",
	Version = "v1.6.41",
	Tags    = { { Text = "Beta", Color = Color3.fromRGB(189, 147, 249) } },
	Logo    = "rbxassetid://124905448303407",
	Loading = { SubTitle = "Loading assets...", Duration = 2 },
})

-- ================= HOME =================
Window:SidebarSection("Menu")
local Home = Window:Tab({ Title = "Home", Icon = "house" })

local Hero = Home:Section({ Title = "Hub", Icon = "sparkles" })
Hero:Banner({ Title = "RayVinz Hub", SubTitle = "Liquid glass • v1.6.41", Color = Color3.fromRGB(255, 121, 198), Color2 = Color3.fromRGB(189, 147, 249) })

local Profile = Home:Section({ Title = "Welcome", Icon = "user" })
Profile:UserInfo({})                                           -- avatar + username จริง (ดึงอัตโนมัติ)

-- Theme switcher (เปลี่ยนสี accent สดๆ)
local ThemeSec = Home:Section({ Title = "Theme", Icon = "palette" })
ThemeSec:Button({ Title = "Pink",   Icon = "circle", Callback = function() UI:SetAccent("Pink") end })
ThemeSec:Button({ Title = "Purple", Icon = "circle", Callback = function() UI:SetAccent("Purple") end })
ThemeSec:Button({ Title = "Blue",   Icon = "circle", Callback = function() UI:SetAccent("Blue") end })
ThemeSec:Button({ Title = "Green",  Icon = "circle", Callback = function() UI:SetAccent("Green") end })

local Sys = Home:Section({ Title = "System Info", Icon = "activity" })
Sys:SystemInfo({ Icons = { FPS = "activity", Ping = "wifi", Executor = "terminal", Players = "users", Game = "gamepad-2", Time = "clock" } })

-- ================= ALL ELEMENTS (มี Description ทุกตัว) =================
Window:SidebarSection("Elements")
local Demo = Window:Tab({ Title = "All Elements", Icon = "layout-grid" })

local S1 = Demo:Section({ Title = "Inputs & Controls", Icon = "sliders-horizontal" })
S1:Toggle({ Title = "Auto Farm", Description = "ฟาร์มอัตโนมัติตอน AFK", Default = false, Callback = function(on)
	UI:Notify({ Title = on and "Started" or "Stopped", Type = on and "Success" or "Info", Icon = on and "play" or "pause" })
end })
S1:Slider({ Title = "Speed", Description = "ความเร็วในการ tween (1-100)", Min = 1, Max = 100, Default = 50, Callback = function(v) end })
S1:Dropdown({ Title = "Egg (single)", Description = "เลือกไข่ 1 อย่าง", Options = { "Classic", "Rare", "Legendary" }, Default = "Classic", Callback = function(v) end })
S1:Dropdown({ Title = "Targets (multi)", Description = "เลือกได้หลายอัน", Multi = true, Options = { "Noob", "Pro", "Boss", "Pet" }, Default = { "Pro" }, Callback = function(list)
	print("multi:", table.concat(list, ", "))
end })
S1:Textbox({ Title = "Username", Description = "พิมพ์ชื่อผู้เล่น", Placeholder = "type here...", Callback = function(v) end })
S1:Textarea({ Title = "Notes", Placeholder = "Enter text...", Callback = function(v) end })
S1:Keybind({ Title = "Toggle UI", Description = "ปุ่มเปิด/ปิด UI", Default = Enum.KeyCode.RightShift, Callback = function() Window.Window.Visible = not Window.Window.Visible end })
S1:ColorPicker({ Title = "Accent", Description = "สีหลักของธีม", Default = Color3.fromRGB(255, 121, 198), Callback = function(c) end })

local S2 = Demo:Section({ Title = "Buttons", Icon = "mouse-pointer-click" })
S2:Button({ Title = "Start Farming", Callback = function() UI:Notify({ Title = "Farming!", Type = "Success", Icon = "check" }) end }) -- full-width
S2:Button({ Title = "Notify Button", Description = "กดแล้วเด้ง notify", Icon = "bell", Callback = function()                        -- row-style + desc
	UI:Notify({ Title = "Row button clicked", Type = "Info", Icon = "bell" })
end })
S2:Button({ Title = "Open Dialog", Icon = "message-square", Callback = function()
	UI:Dialog({ Title = "Confirm", Content = "Start auto farming?",
		Buttons = { { Title = "Cancel" }, { Title = "Continue", Variant = "Primary", Callback = function()
			UI:Notify({ Title = "Confirmed", Type = "Success", Icon = "check" })
		end } } })
end })

local S3 = Demo:Section({ Title = "Display", Icon = "layout-list" })
S3:Label("นี่คือ Label ข้อความธรรมดา")
S3:Paragraph({ Title = "About", Content = "RayVinzUI — macOS-style UI library สำหรับ Roblox เขียนไฟล์เดียว ใช้ง่าย" })
S3:Tags({ { Text = "v1.6", Color = Color3.fromRGB(255, 214, 10) }, { Text = "UI", Color = Color3.fromRGB(48, 209, 88) }, { Text = "Premium", Color = Color3.fromRGB(189, 147, 249) } })

-- ================= COMBAT (เทส section หลาย tab) =================
Window:SidebarSection("Combat")
local Aim = Window:Tab({ Title = "Aimbot", Icon = "crosshair" })
local A1 = Aim:Section({ Title = "Aim Assist", Icon = "target" })
A1:Toggle({ Title = "Enable Aimbot", Description = "เล็งอัตโนมัติ", Default = false, Callback = function() end })
A1:Slider({ Title = "FOV", Description = "ระยะวงเล็ง", Min = 10, Max = 500, Default = 120, Callback = function() end })
A1:Dropdown({ Title = "Target Part", Options = { "Head", "Torso", "HumanoidRootPart" }, Default = "Head", Callback = function() end })

-- ================= NOTIFY TEST =================
Window:SidebarSection("Misc")
local NotifTab = Window:Tab({ Title = "Notify Test", Icon = "bell" })
local N = NotifTab:Section({ Title = "เทส notify ทุกแบบ", Icon = "bell-ring" })
N:Button({ Title = "Info",    Icon = "info",           Callback = function() UI:Notify({ Title = "Information", Content = "Config loaded.", Type = "Info" }) end })
N:Button({ Title = "Success", Icon = "circle-check",   Callback = function() UI:Notify({ Title = "Success", Content = "Auto farm started!", Type = "Success" }) end })
N:Button({ Title = "Warning", Icon = "triangle-alert", Callback = function() UI:Notify({ Title = "Warning", Content = "Low on resources.", Type = "Warning" }) end })
N:Button({ Title = "Error",   Icon = "circle-x",       Callback = function() UI:Notify({ Title = "Error", Content = "Failed to find plot.", Type = "Error" }) end })
N:Button({ Title = "Loading (test)", Icon = "loader", Callback = function()
	local ld = UI:Loading({ Title = "RayVinz Hub", SubTitle = "Reloading...", Logo = "rbxassetid://124905448303407" })
	task.delay(2, function() ld.Close() end)
end })

UI:Notify({ Title = "Loaded", Content = "RayVinz Hub is ready!", Type = "Success", Icon = "check", Duration = 4 })

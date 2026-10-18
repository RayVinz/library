--!nocheck
--[[  RayVinzUI — macOS-style UI library for Roblox (single file)
      local UI = loadstring(game:HttpGet("<raw url>"))()
      See README for the full API. ]]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer

-- ================= Theme =================
local Theme = {
	Background = Color3.fromRGB(20, 20, 28),
	Sidebar    = Color3.fromRGB(26, 26, 36),
	Card       = Color3.fromRGB(32, 32, 44),
	Elevated   = Color3.fromRGB(38, 38, 52),
	Select     = Color3.fromRGB(46, 46, 62),
	Field      = Color3.fromRGB(44, 44, 58),
	Text       = Color3.fromRGB(245, 245, 247),
	SubText    = Color3.fromRGB(152, 152, 157),
	Muted      = Color3.fromRGB(118, 118, 124),
	Accent     = Color3.fromRGB(255, 121, 198),
	Accent2    = Color3.fromRGB(189, 147, 249),
	AccentText = Color3.fromRGB(26, 16, 22),
	Green      = Color3.fromRGB(48, 209, 88),
	Info       = Color3.fromRGB(10, 132, 255),
	Warning    = Color3.fromRGB(255, 214, 10),
	Error      = Color3.fromRGB(255, 69, 58),
	White      = Color3.fromRGB(255, 255, 255),
}
local F  = Enum.Font.GothamMedium -- body (was Gotham) — fatter overall
local FM = Enum.Font.GothamBold   -- labels (was GothamMedium)
local FB = Enum.Font.GothamBold   -- titles / values

-- ================= helpers =================
local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
local function round(n, d) if d == nil then return math.floor(n + 0.5) end local m = 10 ^ d return math.floor(n * m + 0.5) / m end
local function indexOf(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end
-- base64 (for shareable config / theme "profile codes" — no executor funcs needed)
local b64c = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64encode(data)
	return ((data:gsub(".", function(x)
		local r, b = "", x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then return "" end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
		return b64c:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
local function b64decode(data)
	data = tostring(data):gsub("[^" .. b64c .. "=]", "")
	return (data:gsub("=", ""):gsub(".", function(x)
		local r, f = "", (b64c:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

-- ================= live retheme registry =================
-- Instead of scanning the tree later and guessing which elements used to be
-- which color (fragile: breaks the moment anything is mid-tween, and drifts
-- further every time it's called), every themed property is bound to its
-- Theme key *once*, at creation, by identity. SetTheme/SetAccent then just
-- set the live value straight from the registry -- no comparisons, so it's
-- correct no matter how many times or how fast you switch themes.
local ThemeRegistry = {} -- { {inst=Instance, prop="BackgroundColor3", role="Card"}, ... }
local ThemeGradients = {} -- { {inst=UIGradient, role1="Accent", role2="Accent2"}, ... }
local function roleOfColor(value)
	if typeof(value) ~= "Color3" then return nil end
	for key, v in pairs(Theme) do
		if typeof(v) == "Color3" and v == value then return key end
	end
	return nil
end
local TRACKED_COLOR_PROPS = { BackgroundColor3 = true, TextColor3 = true, ImageColor3 = true, Color = true }

local function new(class, props, parent)
	local i = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			i[k] = v
			if class == "UIGradient" and k == "Color" and typeof(v) == "ColorSequence" then
				local kps = v.Keypoints
				if kps and #kps == 2 then
					local r1, r2 = roleOfColor(kps[1].Value), roleOfColor(kps[2].Value)
					if r1 and r2 then table.insert(ThemeGradients, { inst = i, role1 = r1, role2 = r2 }) end
				end
			elseif TRACKED_COLOR_PROPS[k] then
				local role = roleOfColor(v)
				if role then table.insert(ThemeRegistry, { inst = i, prop = k, role = role }) end
			end
		end
	end
	if parent then i.Parent = parent end
	return i
end
-- call after SetTheme/SetAccent change Theme[...]: replays every binding directly, no guessing
-- only = optional set of roles to update (e.g. { Accent = true }); rainbow mode calls this
-- 10x a second, so skipping every non-accent element matters
local function applyThemeRegistry(only)
	for idx = #ThemeRegistry, 1, -1 do
		local e = ThemeRegistry[idx]
		if not e.inst.Parent then
			table.remove(ThemeRegistry, idx)
		elseif not only or only[e.role] then
			pcall(function() e.inst[e.prop] = Theme[e.role] end)
		end
	end
	for idx = #ThemeGradients, 1, -1 do
		local e = ThemeGradients[idx]
		if not e.inst.Parent then
			table.remove(ThemeGradients, idx)
		elseif not only or only[e.role1] or only[e.role2] then
			pcall(function() e.inst.Color = ColorSequence.new(Theme[e.role1], Theme[e.role2]) end)
		end
	end
end
local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, p) end
local function stroke(p, color, tr, th) return new("UIStroke", { Color = color or Theme.White, Transparency = tr == nil and 0.9 or tr, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p) end
local function grad(p, c1, c2, rot) return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 0 }, p) end
local function pad(p, t, r, b, l) return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t), PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t) }, p) end
local function vlist(p, gap, pad2) return new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap or 0), HorizontalAlignment = pad2 or Enum.HorizontalAlignment.Left }, p) end

-- left-aligned text that vertically centers and truncates
local function ltext(parent, text, size, color, font, xAlign)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color or Theme.Text,
		Font = font or FM, TextXAlignment = xAlign or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd, RichText = true }, parent)
end

-- MotionScale multiplies every tween duration. 0 = apply instantly (ReduceMotion /
-- PerformanceGuard pause animations when the game is lagging). 1 = normal speed.
local MotionScale = 1
local function tween(i, t, props)
	if MotionScale <= 0 then for k, v in pairs(props) do pcall(function() i[k] = v end) end return { Cancel = function() end, Play = function() end } end
	local tw = TweenService:Create(i, TweenInfo.new(t * MotionScale, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props) tw:Play() return tw
end

local function draggable(handle, target)
	local dragging, sp, si
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; sp = target.Position; si = inp.Position
			inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local d = inp.Position - si
			target.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
end

local function guiParent()
	local ok, h = pcall(function() return gethui() end)
	if ok and h then return h end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end
-- remove any previous RayVinzUI instances (so re-running the script doesn't stack GUIs)
local function cleanupOld()
	local spots = {}
	pcall(function() table.insert(spots, gethui()) end)
	pcall(function() table.insert(spots, game:GetService("CoreGui")) end)
	pcall(function() table.insert(spots, LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
	for _, p in ipairs(spots) do
		if p then
			for _, g in ipairs(p:GetChildren()) do
				if g.Name == "RayVinzUI" then pcall(function() g:Destroy() end) end
			end
		end
	end
	-- remove any leftover blur effect (it lives in Lighting, not under the GUI)
	pcall(function()
		for _, e in ipairs(game:GetService("Lighting"):GetChildren()) do
			if e.Name == "RayVinzBlur" then e:Destroy() end
		end
	end)
end

local function shadow(parent, tr, extra)
	return new("ImageLabel", { Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = tr or 0.4, ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450), Size = UDim2.new(1, extra or 90, 1, extra or 90),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 0 }, parent)
end

-- liquid-glass sheen: bright highlight at the top that fades down (glassy top edge)
local function glassSheen(frame, r, zi)
	local o = new("Frame", { Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Size = UDim2.new(1, 0, 1, 0), ZIndex = zi or 1 }, frame)
	corner(o, r or 12)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.42, 0.965), NumberSequenceKeypoint.new(1, 1) }) }, o)
	return o
end
-- soft neon glow (accent) behind an element
local function glow(parent, color, tr, scale, zi)
	return new("ImageLabel", { Name = "Glow", BackgroundTransparency = 1, Image = "rbxassetid://5028857084",
		ImageColor3 = color or Theme.Accent, ImageTransparency = tr or 0.55, Size = UDim2.fromScale(scale or 1.6, scale or 1.6),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = zi or 0 }, parent)
end

-- ================= icons =================
local IconPack = nil
local ActiveGui = nil
local ActiveFlags = nil
local function resolveIcon(icon)
	if not icon or icon == "" then return nil end
	if type(icon) == "number" then return { Image = "rbxassetid://" .. icon } end
	if type(icon) == "string" and string.find(icon, "rbxassetid://") == 1 then return { Image = icon } end
	if not IconPack then return nil end
	local name = icon; if type(name) == "string" then name = (name:gsub("^lucide:", "")) end
	if type(IconPack.Icon) == "function" then
		local ok, r = pcall(IconPack.Icon, icon)
		if ok and r and r[1] then return { Image = r[1], ImageRectSize = r[2] and r[2].ImageRectSize, ImageRectOffset = r[2] and r[2].ImageRectPosition } end
	end
	local d = IconPack[name]
	if type(d) == "table" and d.Image then local img = d.Image if type(img) == "number" then img = "rbxassetid://" .. img end return { Image = img, ImageRectSize = d.ImageRectSize, ImageRectOffset = d.ImageRectPosition }
	elseif type(d) == "number" then return { Image = "rbxassetid://" .. d }
	elseif type(d) == "string" then return { Image = d } end
	return nil
end
local function iconImage(parent, icon, size, color, pos, anchor)
	local img = new("ImageLabel", { BackgroundTransparency = 1, Size = size or UDim2.fromOffset(16, 16), ImageColor3 = color or Theme.SubText }, parent)
	if pos then img.Position = pos end
	if anchor then img.AnchorPoint = anchor end
	local r = resolveIcon(icon)
	if r then img.Image = r.Image if r.ImageRectSize then img.ImageRectSize = r.ImageRectSize end if r.ImageRectOffset then img.ImageRectOffset = r.ImageRectOffset end else img.Visible = false end
	return img
end

-- ================= Library =================
local RayVinzUI = {}
RayVinzUI.__index = RayVinzUI
RayVinzUI.Theme = Theme
function RayVinzUI:SetIcons(p)
	IconPack = p
	if type(p) == "table" and type(p.SetIconsType) == "function" then pcall(p.SetIconsType, "lucide") end
	return self
end
function RayVinzUI:LoadLucide(url)
	url = url or "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"
	local ok, p = pcall(function() return loadstring(game:HttpGet(url))() end)
	if ok and p then self:SetIcons(p) return true end
	return false
end

-- ---------- Window ----------
function RayVinzUI:CreateWindow(opts)
	opts = opts or {}
	if opts.Folder then RayVinzUI.SetFolder(self, opts.Folder) end
	if opts.KeySystem and opts.Folder and opts.KeySystem.Folder == nil then opts.KeySystem.Folder = opts.Folder end
	-- WindUI-style: CreateWindow({ KeySystem = { API = {...} } }) gates the window behind a key
	if opts.KeySystem then
		local ks = opts.KeySystem
		if ks.Title == nil then ks.Title = opts.Title end
		if ks.Logo == nil then ks.Logo = opts.Logo end
		if not RayVinzUI.KeySystem(self, ks) then error("[RayVinzUI] key system closed without a valid key", 0) end
	end
	opts.Logo = opts.Logo or "sparkles" -- default hub icon (needs UI:LoadLucide())
	opts.Version = opts.Version or opts.SubTitle or "v1.0.0"
	-- no Title given -> auto-pull the current game's name
	if not opts.Title then
		local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
		opts.Title = (ok and type(info) == "table" and info.Name) or "RayVinz Hub"
	end
	local self = setmetatable({}, { __index = RayVinzUI }); self._tabs = {}; self._flags = {}; self._conns = {}
	self._track = function(c) table.insert(self._conns, c); return c end
	self._configName = opts.ConfigName or "default"; ActiveFlags = self._flags
	self._autoSave = opts.ConfigAutoSave and true or false
	self._autoFlag = opts.AutoFlag ~= false -- auto-generate a Flag for every element (so config saves everything)
	self._loading = self._autoSave -- block auto-save until the first auto-load finishes
	do
		local pending = false
		self._queueSave = function()
			if pending or not self._autoSave or self._loading then return end
			pending = true
			task.delay(0.6, function() pending = false; if not self._loading then pcall(function() self:SaveConfig() end) end end)
		end
	end
	cleanupOld() -- destroy any previous RayVinzUI so re-running never stacks windows/buttons
	local gui = new("ScreenGui", { Name = "RayVinzUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true }, guiParent())
	self.Gui = gui; ActiveGui = gui
	local W, H = opts.Width or 660, opts.Height or 460

	-- holder (positioned/dragged) -> shadow + rounded window inside
	-- frosted-glass backdrop: blur the 3D scene behind the UI (iOS "liquid glass" look)
	local blur = nil
	pcall(function() blur = new("BlurEffect", { Name = "RayVinzBlur", Size = 0, Enabled = true }, game:GetService("Lighting")) end)
	self._blur = blur
	-- opts.Blur = false turns the background blur off, a number sets its strength (default 24)
	self._blurSize = opts.Blur == false and 0 or (type(opts.Blur) == "number" and opts.Blur or 24)
	local holder = new("Frame", { Name = "Window", Visible = false, Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, gui)
	self.Window = holder
	local sh = shadow(holder, 1, 48)
	-- CanvasGroup lets us fade the whole window (GroupTransparency) in one tween
	local win = new("CanvasGroup", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.24, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 1 }, holder)
	corner(win, 16); stroke(win, Theme.White, 0.72, 1.4); glassSheen(win, 16, 1)
	-- animated shimmering edge: a slowly-rotating accent gradient along the window border
	do
		local edgeStroke = new("UIStroke", { Thickness = 1.2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, win)
		local edgeGrad = new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Accent),
				ColorSequenceKeypoint.new(0.5, Theme.White),
				ColorSequenceKeypoint.new(1, Theme.Accent2),
			}),
		}, edgeStroke)
		self._track(game:GetService("RunService").Heartbeat:Connect(function(dt)
			if holder.Visible then edgeGrad.Rotation = (edgeGrad.Rotation + dt * 30) % 360 end
		end))
	end
	-- smooth open / close / minimize (scale + fade together, from the window's own center)
	local function showWin(animate)
		holder.Visible = true
		if blur then tween(blur, 0.34, { Size = self._blurSize }) end
		if animate then
			win.GroupTransparency = 1; sh.ImageTransparency = 1
			holder.Size = UDim2.fromOffset(math.floor(W * 0.9), math.floor(H * 0.9))
			tween(holder, 0.34, { Size = UDim2.fromOffset(W, H) })
			tween(win, 0.34, { GroupTransparency = 0 })
			tween(sh, 0.34, { ImageTransparency = 0.5 })
		else
			win.GroupTransparency = 0; sh.ImageTransparency = 0.5; holder.Size = UDim2.fromOffset(W, H)
		end
	end
	local function hideWin()
		if blur then tween(blur, 0.24, { Size = 0 }) end
		tween(holder, 0.24, { Size = UDim2.fromOffset(math.floor(W * 0.9), math.floor(H * 0.9)) })
		tween(win, 0.24, { GroupTransparency = 1 })
		tween(sh, 0.24, { ImageTransparency = 1 })
		task.delay(0.26, function() holder.Visible = false end)
	end
	self._show, self._hide = showWin, hideWin
	-- responsive: shrink the window to fit small screens / mobile
	local uiScale = new("UIScale", { Scale = 1 }, holder)
	local function fitScale()
		local cam = workspace and workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		uiScale.Scale = clamp(math.min(1, (vp.X - 24) / W, (vp.Y - 24) / H), 0.45, 1)
	end
	pcall(fitScale)
	pcall(function() workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale) end)

	-- title bar
	local title = new("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, win)
	local lights = new("Frame", { Size = UDim2.fromOffset(52, 14), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, title)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, lights)
	-- maximize toggle (green): swap between normal and a larger size
	-- maximize centers the window (it may have been dragged/resized off to one side) and
	-- restore puts back the exact size + position from before
	local maximized, restore = false, nil
	local function maximize()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		maximized = not maximized
		if maximized then
			restore = { W = W, H = H, Pos = holder.Position }
			W, H = math.floor(vp.X * 0.9), math.floor(vp.Y * 0.88)
			uiScale.Scale = 1
			tween(holder, 0.3, { Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5) })
		else
			local r = restore or { W = opts.Width or 660, H = opts.Height or 460, Pos = UDim2.fromScale(0.5, 0.5) }
			W, H = r.W, r.H
			pcall(fitScale)
			tween(holder, 0.3, { Size = UDim2.fromOffset(W, H), Position = r.Pos })
		end
	end
	local glyphs = { "x", "minus", "maximize-2" } -- lucide icons: close / minimize / expand
	local marks = {}
	for i, c in ipairs({ Color3.fromRGB(255, 95, 87), Color3.fromRGB(254, 188, 46), Color3.fromRGB(40, 200, 64) }) do
		local d = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(13, 13), BackgroundColor3 = c, LayoutOrder = i }, lights); corner(d, 7)
		local m = iconImage(d, glyphs[i], UDim2.fromOffset(9, 9), Color3.fromRGB(60, 30, 10), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)); m.ImageTransparency = 1; marks[i] = m
		-- red = destroy (confirm first, then fully unload); yellow = hide/minimize; green = maximize
		if i == 1 then d.MouseButton1Click:Connect(function()
			self:Dialog({ Title = "Close " .. (opts.Title or "UI") .. "?", Content = "This will fully close and unload the UI. You'll need to re-execute the script to open it again.",
				Buttons = { { Title = "Cancel" }, { Title = "Close", Variant = "Primary", Callback = function() self:Unload() end } } })
		end) end
		if i == 2 then d.MouseButton1Click:Connect(function() hideWin() end) end
		if i == 3 then d.MouseButton1Click:Connect(function() maximize() end) end
	end
	-- reveal all three glyphs while hovering the cluster (macOS behavior)
	lights.MouseEnter:Connect(function() for _, m in ipairs(marks) do tween(m, 0.12, { ImageTransparency = 0 }) end end)
	lights.MouseLeave:Connect(function() for _, m in ipairs(marks) do tween(m, 0.12, { ImageTransparency = 1 }) end end)
	-- left-aligned brand: logo + (map name + faint "By author") + version/tags row
	local brand = new("Frame", { Size = UDim2.new(1, -92, 1, 0), Position = UDim2.new(0, 80, 0, 0), BackgroundTransparency = 1 }, title)
	local blogo = new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, brand)
	-- a real logo image (rbxassetid/number) keeps its own colors on every theme -- only a
	-- named vector icon (e.g. "sparkles") gets tinted, since those are flat single-tone glyphs
	local logoIsCustomImage = type(opts.Logo) == "number"
		or (type(opts.Logo) == "string" and string.find(opts.Logo, "rbxassetid://") == 1)
	local blogoIcon = iconImage(blogo, opts.Logo, UDim2.fromOffset(38, 38),
		logoIsCustomImage and Theme.White or Theme.Text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	self._logoIcon = blogoIcon
	-- row 1: map name + "By author" (faint, thin, small)
	local r1 = new("Frame", { Size = UDim2.new(1, -48, 0, 16), Position = UDim2.new(0, 48, 0, 7), BackgroundTransparency = 1 }, brand)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), VerticalAlignment = Enum.VerticalAlignment.Bottom }, r1)
	local tt = ltext(r1, opts.Title or "RayVinz Hub", 14, Theme.Text, FB); tt.Size = UDim2.fromOffset(0, 16); tt.AutomaticSize = Enum.AutomaticSize.X; tt.LayoutOrder = 1
	if opts.Author then local au = ltext(r1, "By " .. opts.Author, 10, Theme.Muted, F); au.Size = UDim2.fromOffset(0, 13); au.AutomaticSize = Enum.AutomaticSize.X; au.LayoutOrder = 2 end
	-- row 2: version tag (+ extra tags)
	local r2 = new("Frame", { Size = UDim2.new(1, -48, 0, 15), Position = UDim2.new(0, 48, 0, 25), BackgroundTransparency = 1 }, brand)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center }, r2)
	local function titleTag(txt, col, i)
		local pill = new("Frame", { Size = UDim2.fromOffset(0, 15), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = col or Theme.White, BackgroundTransparency = 0.8, LayoutOrder = i }, r2); corner(pill, 7); pad(pill, 1, 7, 1, 7)
		local pl = ltext(pill, txt, 10, col or Theme.SubText, FM); pl.Size = UDim2.fromOffset(0, 13); pl.AutomaticSize = Enum.AutomaticSize.X
	end
	titleTag(opts.Version or opts.SubTitle or "v1.0.0", Theme.Accent, 1)
	if opts.Tags then for i, tg in ipairs(opts.Tags) do titleTag(tg.Text or tostring(tg), tg.Color, i + 1) end end
	draggable(title, holder)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 48), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.92, BorderSizePixel = 0 }, win)

	-- resize grip (bottom-right corner, iPadOS floating-window style): drag to resize,
	-- top-left corner stays put. opts.Resizable = false to disable, opts.MinSize/MaxSize = {w, h}
	if opts.Resizable ~= false then
		local minW, minH = (opts.MinSize and opts.MinSize[1]) or 480, (opts.MinSize and opts.MinSize[2]) or 340
		local maxW, maxH = (opts.MaxSize and opts.MaxSize[1]) or 1200, (opts.MaxSize and opts.MaxSize[2]) or 860
		-- iPad-style handle: a short thick arc just outside the window's rounded corner, sharing
		-- its center. A CanvasGroup does the clipping because ClipsDescendants doesn't clip
		-- UIStroke (the whole circle showed through before).
		local grip = new("TextButton", { Name = "ResizeHandle", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(36, 36),
			Position = UDim2.new(1, 8, 1, 8), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, ZIndex = 10 }, holder)
		local arcView = new("CanvasGroup", { Name = "ResizeArc", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -10, 1, -10),
			BackgroundTransparency = 1, ZIndex = 9 }, holder)
		local ring = new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(-6, -6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, arcView)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		local arcStroke = new("UIStroke", { Color = Color3.fromRGB(235, 235, 245), Transparency = 0.15, Thickness = 4.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
		grip.MouseEnter:Connect(function() tween(arcStroke, 0.15, { Color = Theme.Accent, Transparency = 0 }) end)
		grip.MouseLeave:Connect(function() tween(arcStroke, 0.15, { Color = Color3.fromRGB(235, 235, 245), Transparency = 0.15 }) end)
		local resizing, startInput, startSize, startAbsPos
		grip.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				-- AbsoluteSize includes the mobile UIScale; Size offsets don't, so divide it out
				resizing = true; startInput = inp.Position; startSize = holder.AbsoluteSize / uiScale.Scale; startAbsPos = holder.AbsolutePosition
			end
		end)
		self._track(UserInputService.InputChanged:Connect(function(inp)
			if resizing and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
				local s = uiScale.Scale
				local d = (inp.Position - startInput) / s
				-- never let the bottom-right corner go past the screen edge
				local vp = workspace.CurrentCamera.ViewportSize
				local capW = math.max(minW, math.min(maxW, (vp.X - startAbsPos.X - 8) / s))
				local capH = math.max(minH, math.min(maxH, (vp.Y - startAbsPos.Y - 8) / s))
				local newW = math.floor(clamp(startSize.X + d.X, minW, capW))
				local newH = math.floor(clamp(startSize.Y + d.Y, minH, capH))
				W, H = newW, newH -- so hide/show and restore keep the new size
				maximized = false
				holder.Size = UDim2.fromOffset(newW, newH)
				holder.Position = UDim2.fromOffset(startAbsPos.X + newW * s / 2, startAbsPos.Y + newH * s / 2)
			end
		end))
		self._track(UserInputService.InputEnded:Connect(function(inp)
			if resizing and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
				resizing = false
				self._queueSave()
			end
		end))
	end

	-- body: sidebar + content (glassy translucent sidebar)
	local sidebar = new("ScrollingFrame", { Name = "Sidebar", Size = UDim2.new(0, 190, 1, -49), Position = UDim2.new(0, 0, 0, 49), BackgroundColor3 = Theme.Sidebar, BackgroundTransparency = 0.25,
		BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, win)
	pad(sidebar, 14, 12, 12, 12); vlist(sidebar, 3)
	self.Sidebar = sidebar
	-- sidebar deep search: matches tab titles AND every setting/label inside every
	-- tab's page, so a buried toggle three tabs away is findable, not just tab names.
	-- opts.Search = false to disable.
	if opts.Search ~= false then
		local sb = new("Frame", { Name = "Search", Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.15, LayoutOrder = -3 }, sidebar); corner(sb, 8); stroke(sb, Theme.White, 0.85, 1)
		iconImage(sb, "search", UDim2.fromOffset(13, 13), Theme.Muted, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		local sbox = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 30, 0, 0), PlaceholderText = "Search...", PlaceholderColor3 = Theme.Muted, Text = "", TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, sb)
		local results = new("Frame", { Name = "SearchResults", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = -2 }, sidebar)
		vlist(results, 4)
		new("Frame", { Name = "SearchGap", Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 1, LayoutOrder = -1 }, sidebar)

		local function jumpTo(tab, inst)
			self:_select(tab)
			sbox.Text = ""
			task.defer(function()
				local ok, absY = pcall(function() return inst.AbsolutePosition.Y end)
				if ok then
					local target = tab._page.CanvasPosition.Y + (absY - tab._page.AbsolutePosition.Y) - 60
					tab._page.CanvasPosition = Vector2.new(0, math.max(target, 0))
				end
				local row = inst
				while row.Parent and row.Parent ~= tab._page do row = row.Parent end
				if row:IsA("GuiObject") then
					local hl = stroke(row, Theme.Accent, 0, 2)
					task.delay(0.05, function() tween(hl, 0.9, { Transparency = 1 }) end)
					task.delay(1, function() hl:Destroy() end)
				end
			end)
		end

		sbox:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(sbox.Text)
			for _, child in ipairs(results:GetChildren()) do
				if child:IsA("GuiObject") then child:Destroy() end
			end
			if q == "" then
				results.Visible = false
				for _, t in ipairs(self._tabs) do t._item.Visible = true end
				return
			end
			local deepMatches = {}
			for _, t in ipairs(self._tabs) do
				local titleMatch = string.find(string.lower(t._label.Text), q, 1, true) ~= nil
				local pageMatch = false
				for _, d in ipairs(t._page:GetDescendants()) do
					if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Name ~= "Dot" and d.Text ~= "" then
						if string.find(string.lower(d.Text), q, 1, true) then
							pageMatch = true
							if not titleMatch and #deepMatches < 8 then
								table.insert(deepMatches, { tab = t, inst = d })
							end
						end
					end
				end
				t._item.Visible = titleMatch or pageMatch
			end
			results.Visible = #deepMatches > 0
			for i, m in ipairs(deepMatches) do
				local row = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.2, LayoutOrder = i }, results)
				corner(row, 6); stroke(row, Theme.White, 0.88, 1)
				local lbl = ltext(row, m.inst.Text, 11, Theme.Text, FM); lbl.Position = UDim2.new(0, 8, 0, 0); lbl.Size = UDim2.new(1, -70, 1, 0)
				local tagl = ltext(row, m.tab._label.Text, 9, Theme.Muted, FM); tagl.Position = UDim2.new(1, -62, 0, 0); tagl.Size = UDim2.new(0, 56, 1, 0); tagl.TextXAlignment = Enum.TextXAlignment.Right
				row.MouseButton1Click:Connect(function() jumpTo(m.tab, m.inst) end)
			end
		end)
	end
	local content = new("Frame", { Name = "Content", Size = UDim2.new(1, -190, 1, -49), Position = UDim2.new(0, 190, 0, 49), BackgroundTransparency = 1 }, win)
	self.Content = content

	self:_mountMobile(opts.Logo)

	if opts.AntiAFK then self:AntiAFK(true) end
	if opts.ReExecute then self:ReExecuteOnTeleport(opts.ReExecute) end

	-- hotkey to toggle the window (animated, with blur) — opts.ToggleKey = Enum.KeyCode.RightShift
	if opts.ToggleKey then
		self._track(UserInputService.InputBegan:Connect(function(inp, gpe)
			if not gpe and inp.KeyCode == opts.ToggleKey then self:Toggle() end
		end))
	end

	-- auto-load saved config a frame after build (so every element exists first)
	-- load on start only when the user picked an auto-load config; auto-save still runs either way
	if opts.ConfigAutoSave then task.defer(function()
		local auto = self:GetAutoLoadConfig()
		if auto then pcall(function() self:LoadConfig(auto) end) else self._loading = false end
	end) end

	-- auto re-inject: if the GUI is externally un-parented (not destroyed), put it back
	if opts.Protect then
		self._track(gui.AncestryChanged:Connect(function(_, parent)
			if not parent then task.defer(function() pcall(function() gui.Parent = guiParent() end) end) end
		end))
	end

	-- intro: loading screen -> reveal window -> (optional) changelog. opts.Changelog = { Version=, Changes={} }
	local function afterReady()
		if opts.Changelog then task.wait(0.45); pcall(function() self:Changelog(opts.Changelog) end) end
		if opts.OnReady then task.spawn(opts.OnReady) end
	end
	if opts.Loading then
		local lo = type(opts.Loading) == "table" and opts.Loading or {}
		local loader = self:Loading({ Title = lo.Title or opts.Title or "RayVinz Hub", SubTitle = lo.SubTitle or "Loading assets...", Logo = opts.Logo, Blur = opts.Blur })
		task.delay(lo.Duration or 2, function() loader.Close() task.wait(0.25) showWin(true) afterReady() end)
	else
		showWin(true)
		task.defer(afterReady)
	end
	return self
end

function RayVinzUI:_mountMobile(logo)
	local btn = new("TextButton", { Name = "MobileToggle", Text = "", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 22, 0.5, -28), BackgroundColor3 = Color3.fromRGB(26, 26, 30), BackgroundTransparency = 0.28, AutoButtonColor = false }, self.Gui)
	corner(btn, 17); stroke(btn, Theme.White, 0.62, 1.2); glassSheen(btn, 17, 0)
	-- big logo, no pink box/glow
	iconImage(btn, logo, UDim2.fromOffset(40, 40), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	-- draggable, and a tap (no real drag) toggles the window
	local dragging, moved, sp, si
	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; moved = false; sp = btn.Position; si = inp.Position
		end
	end)
	self._track(UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local d = inp.Position - si
			if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
			btn.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end))
	self._track(UserInputService.InputEnded:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then if self.Window.Visible then self._hide() else self._show(true) end end
		end
	end))
	self.MobileButton = btn
end

function RayVinzUI:SidebarSection(name)
	local h = ltext(self.Sidebar, string.upper(name), 10, Theme.Muted, FB); h.Size = UDim2.new(1, 0, 0, 22); h.LayoutOrder = #self.Sidebar:GetChildren()
	pad(h, 8, 0, 4, 10)
	return h
end

-- ---------- Tab ----------
function RayVinzUI:Tab(opts)
    opts = opts or {}; local tab = {}
    local layoutOrderCount = 0
    pcall(function()
        layoutOrderCount = #self.Sidebar:GetChildren()
    end)

    local item = new("TextButton", { Name = "Tab", Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, LayoutOrder = layoutOrderCount }, self.Sidebar)
    corner(item, 8)
    
    local tbar = new("Frame", { Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 2 }, item); corner(tbar, 2)
    local ic = iconImage(item, opts.Icon, UDim2.fromOffset(16, 16), Theme.SubText, UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5)); ic.ZIndex = 2
    local lb = ltext(item, opts.Title or "Tab", 13, Theme.SubText, FM); lb.Position = UDim2.new(0, 38, 0, 0); lb.Size = UDim2.new(1, -48, 1, 0); lb.ZIndex = 2
    local dot = new("Frame", { Name = "Dot", Size = UDim2.fromOffset(7, 7), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Error, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, item); corner(dot, 4)
    
    local badge = new("Frame", { Name = "Badge", Size = UDim2.fromOffset(18, 16), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Accent, Visible = false, ZIndex = 3 }, item); corner(badge, 8)
    local badgeTxt = ltext(badge, "", 10, Theme.AccentText, FB, Enum.TextXAlignment.Center); badgeTxt.Size = UDim2.fromScale(1, 1); badgeTxt.ZIndex = 4
    
    tab._bar = tbar; tab._dot = dot; tab._badge = badge
    function tab:SetDot(on) self._dot.Visible = on and true or false end
    function tab:SetBadge(v)
        if v == nil or v == false or v == "" then self._badge.Visible = false; return end
        badgeTxt.Text = tostring(v); self._badge.Visible = true
        self._badge.Size = UDim2.fromOffset(math.max(18, #tostring(v) * 7 + 10), 16)
    end
    
    local page = new("ScrollingFrame", { Name = "Page", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Muted, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, self.Content)
    pad(page, 18, 18, 18, 18); vlist(page, 16)
    
    tab._item, tab._icon, tab._label, tab._page, tab._window = item, ic, lb, page, self
    function tab:Section(s) return self._window:_section(self._page, s) end
    function tab:Select() self._window:_select(self) end
    
    item.MouseButton1Click:Connect(function() self:_select(tab) end)
    table.insert(self._tabs, tab)
    if #self._tabs == 1 or opts.Default then self:_select(tab) end
    return tab
end
function RayVinzUI:_select(tab)
	for _, t in ipairs(self._tabs) do
		local on = t == tab
		t._page.Visible = on
		tween(t._item, 0.18, { BackgroundTransparency = on and 0.86 or 1 })
		t._label.TextColor3 = on and Theme.Text or Theme.SubText
		t._label.Font = on and FB or FM
		t._icon.ImageColor3 = on and Theme.Accent or Theme.SubText
		if t._bar then tween(t._bar, 0.18, { Size = UDim2.fromOffset(3, on and 18 or 0) }) end
		if on and t._dot then t._dot.Visible = false end -- clear the dot once opened
	end
end

-- ================= Section + elements =================
function RayVinzUI:_section(page, opts)
	opts = opts or {}; local section = { _gui = self.Gui, _window = self }
	local wflags = self._flags or {}
	local trackConn = self._track or function(c) return c end
	local win = self
	local autoN = 0
	-- register an element for Config. Uses o.Flag, or auto-generates "Section/Title" so
	-- EVERY element is saved by default (set opts.AutoFlag = false to require explicit Flags).
	local attachMenu, attachDepends -- forward-declared (defined after tip)
	local function registerFlag(o, ctl, kind)
		autoN = autoN + 1
		local flag = o.Flag
		if not flag and win._autoFlag then
			flag = (opts.Title or "Section") .. "/" .. (o.Title or ("item" .. autoN))
			if wflags[flag] then flag = flag .. "#" .. autoN end
		end
		local entry = { ctl = ctl, kind = kind, title = o.Title, section = opts.Title, page = page, inst = section._lastRow, default = o.Default }
		if flag then entry.flag = flag; wflags[flag] = entry end
		win._flagByO = win._flagByO or setmetatable({}, { __mode = "k" })
		win._flagByO[o] = entry
		pcall(function() entry.value = ctl.Get() end)
		win._controls = win._controls or {}; table.insert(win._controls, entry) -- for Spotlight
		if attachMenu then attachMenu(entry) end        -- right-click: Reset / Copy
		if o.DependsOn and attachDepends then attachDepends(o, entry) end
		return entry
	end
	-- wrap a callback: auto-save on change + catch errors (Error Inspector) + record Undo history
	local function autoCb(o)
		local cb = o.Callback
		o.Callback = function(...)
			local first = (...)
			if cb then
				local ok, err = pcall(cb, ...)
				if not ok then pcall(function() win:_reportError(o.Title or "element", err) end) end
			end
			if win._queueSave then win._queueSave() end
			local ent = win._flagByO and win._flagByO[o]
			if ent and not win._applyingHistory then pcall(function() win:_pushHistory(ent, first) end) end
		end
	end
	-- hover tooltip (parented to the ScreenGui so it escapes the card's clip)
	local function tip(guiObj, text)
		if not text or text == "" then return end
		local box
		guiObj.MouseEnter:Connect(function()
			if box then return end
			box = new("Frame", { Name = "Tip", BackgroundColor3 = Color3.fromRGB(26, 26, 30), BackgroundTransparency = 0.06, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 75 }, section._gui); corner(box, 7); stroke(box, Theme.White, 0.7, 1); pad(box, 4, 9, 4, 9)
			local tl = ltext(box, text, 11, Theme.Text, FM); tl.Size = UDim2.fromOffset(0, 16); tl.AutomaticSize = Enum.AutomaticSize.X; tl.ZIndex = 76
			local ap = guiObj.AbsolutePosition; box.Position = UDim2.fromOffset(ap.X, ap.Y - 30)
		end)
		guiObj.MouseLeave:Connect(function() if box then box:Destroy(); box = nil end end)
	end
	-- right-click / long-press context menu on a saved control row: Reset to default + Copy value
	attachMenu = function(entry)
		local r = entry.inst
		if not r then return end
		local menu, catch
		local function close() if menu then menu:Destroy(); menu = nil end if catch then catch:Destroy(); catch = nil end end
		local function open(x, y)
			close()
			catch = new("TextButton", { Name = "CtxCatch", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 89 }, section._gui)
			catch.MouseButton1Click:Connect(close)
			menu = new("Frame", { Name = "CtxMenu", BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.05, Size = UDim2.fromOffset(152, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(x, y), ZIndex = 90 }, section._gui)
			corner(menu, 10); stroke(menu, Theme.White, 0.75, 1); pad(menu, 5, 5, 5, 5); vlist(menu, 2)
			local function item(txt, icon, fn)
				local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, ZIndex = 91 }, menu); corner(b, 7)
				iconImage(b, icon, UDim2.fromOffset(14, 14), Theme.SubText, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5)).ZIndex = 92
				local l = ltext(b, txt, 12, Theme.Text, FM); l.Position = UDim2.new(0, 30, 0, 0); l.Size = UDim2.new(1, -36, 1, 0); l.ZIndex = 92
				b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.85 end)
				b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
				b.MouseButton1Click:Connect(function() pcall(fn); close() end)
			end
			if entry.default ~= nil then item("Reset to default", "rotate-ccw", function() entry.ctl.Set(entry.default) end) end
			item("Copy value", "copy", function()
				local ok, v = pcall(entry.ctl.Get); local s = ok and v or ""
				if typeof and typeof(s) == "Color3" then s = string.format("%d, %d, %d", math.floor(s.R * 255 + 0.5), math.floor(s.G * 255 + 0.5), math.floor(s.B * 255 + 0.5))
				elseif type(s) == "table" then s = table.concat(s, ", ")
				elseif type(s) ~= "string" then s = tostring(s) end
				pcall(function() if setclipboard then setclipboard(s) end end)
				win:Notify({ Title = "Copied", Content = entry.title or "value", Type = "Info", Icon = "copy", Duration = 2 })
			end)
		end
		r.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton2 then
				open(inp.Position.X, inp.Position.Y)
			elseif inp.UserInputType == Enum.UserInputType.Touch then
				local held = true
				inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then held = false end end)
				task.delay(0.45, function() if held then open(inp.Position.X, inp.Position.Y) end end)
			end
		end)
	end
	-- DependsOn: grey-out (or hide) a control until a master control's value matches.
	--   o.DependsOn = "OtherFlag"                         -- enabled while that flag is truthy
	--   o.DependsOn = { Flag = "aim", Value = true }      -- enabled only when aim == true
	--   o.DependsOn = { Flag = "mode", Predicate = fn, Hide = true }
	attachDepends = function(o, entry)
		local d = o.DependsOn
		if type(d) == "string" then d = { Flag = d } end
		local r = entry.inst
		if not r or type(d) ~= "table" then return end
		local cover
		local function master()
			if d.Ctl and d.Ctl.Get then local ok, v = pcall(d.Ctl.Get); return ok and v end
			if d.Flag then local e = wflags[d.Flag]; if e then local ok, v = pcall(e.ctl.Get); return ok and v end end
			return nil
		end
		local function test(v)
			if d.Predicate then local ok, r2 = pcall(d.Predicate, v); return (ok and r2) and true or false end
			if d.Value ~= nil then return v == d.Value end
			return v and true or false
		end
		local function apply(enabled)
			if d.Hide then r.Visible = enabled; return end
			if enabled then if cover then cover.Visible = false end
			else
				if not cover then cover = new("TextButton", { Name = "DepCover", Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 20, Active = true }, r); corner(cover, 10) end
				cover.Visible = true
			end
		end
		local state
		win._depends = win._depends or {}
		table.insert(win._depends, function() local en = test(master()); if en ~= state then state = en; apply(en) end end)
		if not win._depStarted then
			win._depStarted = true
			local acc, trk = 0, (win._track or function(c) return c end)
			trk(game:GetService("RunService").Heartbeat:Connect(function(dt)
				acc = acc + dt; if acc < 0.15 then return end; acc = 0
				for _, f in ipairs(win._depends or {}) do pcall(f) end
			end))
		end
	end
	local chev
	if opts.Title then
		local hrow = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = #page:GetChildren() }, page)
		local off = 0
		if opts.Icon then iconImage(hrow, opts.Icon, UDim2.fromOffset(13, 13), Theme.Muted, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5)); off = 18 end
		local hd = ltext(hrow, string.upper(opts.Title), 11, Theme.Muted, FB); hd.Position = UDim2.new(0, off, 0, 0); hd.Size = UDim2.new(1, -off - 16, 1, 0)
		if opts.Collapsible then
			chev = iconImage(hrow, "chevron-down", UDim2.fromOffset(13, 13), Theme.Muted, UDim2.new(1, -2, 0.5, 0), Vector2.new(1, 0.5))
			hrow.MouseButton1Click:Connect(function()
				section._collapsed = not section._collapsed
				section._card.Visible = not section._collapsed
				tween(chev, 0.18, { Rotation = section._collapsed and -90 or 0 })
			end)
		end
	end
	local card = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.22, ClipsDescendants = true, LayoutOrder = #page:GetChildren() }, page)
	corner(card, 12); stroke(card, Theme.White, 0.82, 1.2); grad(card, Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 210), 90); vlist(card, 0)
	section._card = card

	-- base row (adds a divider only BETWEEN rows, never above the first one)
	local rowCount = 0
	local function row(h)
		if rowCount > 0 then
			new("Frame", { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 0), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.93, BorderSizePixel = 0, LayoutOrder = #card:GetChildren() }, card)
		end
		rowCount = rowCount + 1
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, h), AutomaticSize = h == 0 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None, BackgroundTransparency = 1, LayoutOrder = #card:GetChildren() }, card)
		section._lastRow = f
		return f
	end
	-- left label (vertically centered); with a description it stacks title + grey subtext
	local function placeLabel(r, text, reserve, desc)
		if desc and desc ~= "" then
			local l = ltext(r, text, 13, Theme.Text, FM); l.Position = UDim2.new(0, 14, 0, 9); l.Size = UDim2.new(1, -(reserve + 28), 0, 16)
			local d = ltext(r, desc, 11, Theme.SubText, F); d.Position = UDim2.new(0, 14, 0, 26); d.Size = UDim2.new(1, -(reserve + 28), 0, 14)
			return l
		end
		local l = ltext(r, text, 13, Theme.Text, FM)
		l.Position = UDim2.new(0, 14, 0, 0); l.Size = UDim2.new(1, -(reserve + 28), 1, 0)
		return l
	end
	section._row = row

	-- Toggle
	function section:Toggle(o)
		o = o or {}; autoCb(o); local state = o.Default or false
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Toggle", 46, o.Description)
		-- glassy switch: translucent track, soft white edge, floating knob (no clipped glow halo)
		local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(46, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = state and Theme.Green or Theme.Select, BackgroundTransparency = 0.35 }, r); corner(sw, 14); stroke(sw, Theme.White, 0.7, 1)
		local knob = new("Frame", { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0, 0.5), Position = state and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Theme.White, ZIndex = 2 }, sw); corner(knob, 11)
		local offToken = 0
		local function set(v, fire)
			state = v
			tween(sw, 0.18, { BackgroundColor3 = v and Theme.Green or Theme.Select })
			tween(knob, 0.18, { Position = v and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
			-- AutoOff = seconds: auto-switch back off after a delay (timer), cancelled if toggled again
			if o.AutoOff then offToken = offToken + 1; if v then local my = offToken; task.delay(o.AutoOff, function() if my == offToken and state then set(false) end end) end end
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		sw.MouseButton1Click:Connect(function() set(not state) end)
		if o.Keybind then trackConn(UserInputService.InputBegan:Connect(function(inp, gpe) if not gpe and inp.KeyCode == o.Keybind then set(not state) end end)) end
		tip(r, o.Tooltip)
		local ctl = { Set = function(v) set(v) end, Get = function() return state end }
		registerFlag(o, ctl); return ctl
	end

	-- Button
	function section:Button(o)
		o = o or {}
		-- WindUI row-style button: label left, icon right, whole row clickable (when Icon/Style given)
		if o.Icon or o.Style == "Row" then
			local r = row(o.Description and 58 or 46)
			local lbl = placeLabel(r, o.Title or "Button", 40, o.Description)
			local ic = iconImage(r, o.Icon or "mouse-pointer-click", UDim2.fromOffset(16, 16), Theme.SubText, UDim2.new(1, -14, 0.5, 0), Vector2.new(1, 0.5))
			local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 3 }, r)
			btn.MouseEnter:Connect(function() tween(lbl, 0.12, { TextColor3 = Theme.Accent }) if ic.Visible then tween(ic, 0.12, { ImageColor3 = Theme.Accent }) end end)
			btn.MouseLeave:Connect(function() tween(lbl, 0.12, { TextColor3 = Theme.Text }) if ic.Visible then tween(ic, 0.12, { ImageColor3 = Theme.SubText }) end end)
			btn.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
			return btn
		end
		-- full-width accent button (hover scale + ripple + gradient)
		local r = row(50)
		local b = new("TextButton", { Text = o.Title or "Button", Font = FB, TextSize = 13, TextColor3 = Theme.AccentText, AutoButtonColor = false,
			Size = UDim2.new(1, -28, 0, 38), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Theme.Accent, ClipsDescendants = true }, r); corner(b, 9); grad(b, Theme.Accent, Theme.Accent2, 25)
		local sc = new("UIScale", { Scale = 1 }, b)
		b.MouseEnter:Connect(function() tween(sc, 0.12, { Scale = 1.015 }) end)
		b.MouseLeave:Connect(function() tween(sc, 0.12, { Scale = 1 }) end)
		b.MouseButton1Click:Connect(function()
			-- true circular ripple (square size + full corner, so it never stretches into a bar)
			local d = math.max(b.AbsoluteSize.X, b.AbsoluteSize.Y, 60) * 2.2
			local rip = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, Size = UDim2.fromOffset(0, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 }, b); corner(rip, 999)
			tween(rip, 0.45, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 })
			task.delay(0.47, function() rip:Destroy() end)
			if o.Callback then task.spawn(o.Callback) end
		end)
		tip(r, o.Tooltip)
		return b
	end

	-- Slider
	function section:Slider(o)
		o = o or {}; autoCb(o); local min = o.Min or 0; local max = o.Max or 100; local val = o.Default or min
		local r = row(o.Description and 66 or 54)
		local lbl = ltext(r, o.Title or "Slider", 13, Theme.Text, FM); lbl.Position = UDim2.new(0, 14, 0, 11); lbl.Size = UDim2.new(1, -90, 0, 16)
		if o.Description then local d = ltext(r, o.Description, 11, Theme.SubText, F); d.Position = UDim2.new(0, 14, 0, 28); d.Size = UDim2.new(1, -28, 0, 14) end
		local valLbl = ltext(r, "", 13, Theme.Accent, FB, Enum.TextXAlignment.Right); valLbl.AnchorPoint = Vector2.new(1, 0); valLbl.Position = UDim2.new(1, -14, 0, 11); valLbl.Size = UDim2.new(0, 60, 0, 16)
		local track = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -28, 0, 6), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.85 }, r); corner(track, 3)
		local fb = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, track); corner(fb, 3)
		local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Theme.White }, track); corner(knob, 8); stroke(knob, Theme.Accent, 0, 2)
		local function set(v, fire)
			v = clamp(v, min, max); v = round(v, o.Rounding); val = v
			local pct = max > min and (v - min) / (max - min) or 0
			fb.Size = UDim2.new(pct, 0, 1, 0); knob.Position = UDim2.new(pct, 0, 0.5, 0); valLbl.Text = tostring(v) .. (o.Suffix or "")
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		local dragging = false
		local function upd(px) set(min + (max - min) * clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)) end
		track.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true upd(i.Position.X) end end)
		trackConn(UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end end))
		trackConn(UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end))
		set(val, false)
		tip(r, o.Tooltip)
		local ctl = { Set = function(v) set(v) end, Get = function() return val end }
		registerFlag(o, ctl); return ctl
	end

	-- Dropdown
	function section:Dropdown(o)
		o = o or {}; autoCb(o); local options = o.Options or {}; local multi = o.Multi; local selected = multi and (o.Default or {}) or o.Default
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Dropdown", 150, o.Description)
		local box = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.4 }, r); corner(box, 9); stroke(box, Theme.White, 0.8, 1)
		local boxIcon = new("ImageLabel", { BackgroundTransparency = 1, Visible = false, Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 9, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ImageColor3 = Theme.Text, ZIndex = 2 }, box)
		local valTxt = ltext(box, "Select...", 12, Theme.Text, FM); valTxt.Position = UDim2.new(0, 10, 0, 0); valTxt.Size = UDim2.new(1, -28, 1, 0)
		iconImage(box, "chevron-down", UDim2.fromOffset(12, 12), Theme.SubText, UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5))
		local reposition, closeList, doRefresh
		if o.RefreshButton then
			local rb = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -24, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, ZIndex = 2 }, box)
			iconImage(rb, "refresh-cw", UDim2.fromOffset(13, 13), Theme.SubText, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			rb.MouseButton1Click:Connect(function() if doRefresh then doRefresh() end end)
			valTxt.Size = UDim2.new(1, -46, 1, 0)
		end
		-- CanvasGroup so we can fade the whole list on open/close
		local list = new("CanvasGroup", { Visible = false, BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.08, Size = UDim2.fromOffset(160, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 50 }, self._gui); corner(list, 11); stroke(list, Theme.White, 0.78, 1); pad(list, 6, 6, 6, 6); vlist(list, 2)
		-- fullscreen click-catcher: closes the list when you click/drag anywhere else
		local catcher = new("TextButton", { Name = "DropCatcher", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 49 }, self._gui)
		local tx, ty = 0, 0
		local searchQuery = ""
		local rightPad = o.RefreshButton and 46 or 28
		local function display()
			if multi then
				valTxt.Text = #selected > 0 and table.concat(selected, ", ") or "None"
				boxIcon.Visible = false
			else
				valTxt.Text = selected and tostring(selected) or "Select..."
				local ico = o.Icons and selected and o.Icons[selected]
				local r2 = ico and resolveIcon(ico)
				if r2 then
					boxIcon.Image = r2.Image
					boxIcon.ImageRectSize = r2.ImageRectSize or Vector2.new(0, 0)
					boxIcon.ImageRectOffset = r2.ImageRectOffset or Vector2.new(0, 0)
					boxIcon.Visible = true
				else boxIcon.Visible = false end
			end
			local left = boxIcon.Visible and 32 or 10
			valTxt.Position = UDim2.new(0, left, 0, 0)
			valTxt.Size = UDim2.new(1, -(left + rightPad), 1, 0)
		end
		local function rebuild()
			for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, opt in ipairs(options) do
				if searchQuery == "" or string.find(string.lower(tostring(opt)), searchQuery, 1, true) then
					local chosen = multi and (indexOf(selected, opt) ~= nil) or (selected == opt)
					local ob = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Accent, BackgroundTransparency = chosen and 0.82 or 1, LayoutOrder = i + 1 }, list); corner(ob, 7)
					-- optional per-option icon: o.Icons = { [optionText] = "iconName"/rbxassetid }
					local ico = o.Icons and o.Icons[opt]
					local tx = 10
					if ico then iconImage(ob, ico, UDim2.fromOffset(16, 16), chosen and Theme.Text or Theme.SubText, UDim2.new(0, 9, 0.5, 0), Vector2.new(0, 0.5)); tx = 33 end
					local ol = ltext(ob, tostring(opt), 12, chosen and Theme.Text or Theme.SubText, FM); ol.Position = UDim2.new(0, tx, 0, 0); ol.Size = UDim2.new(1, -(tx + 10), 1, 0)
					ob.MouseButton1Click:Connect(function()
						if multi then local idx = indexOf(selected, opt) if idx then table.remove(selected, idx) else table.insert(selected, opt) end rebuild() else selected = opt closeList() end
						display(); if o.Callback then task.spawn(o.Callback, selected) end
					end)
				end
			end
		end
		-- search box for long lists (auto when > 6 options, or Search = true)
		if o.Search or #options > 6 then
			local sf = new("Frame", { BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 0 }, list); corner(sf, 7); stroke(sf, Theme.White, 0.85, 1)
			local sbox = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0), PlaceholderText = "Search...", PlaceholderColor3 = Theme.Muted, Text = "", TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, sf)
			sbox:GetPropertyChangedSignal("Text"):Connect(function() searchQuery = string.lower(sbox.Text); rebuild() end)
		end
		reposition = function()
			tx, ty = box.AbsolutePosition.X, box.AbsolutePosition.Y + 34
			list.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X, 150), 0)
			if list.Visible then list.Position = UDim2.fromOffset(tx, ty) end
		end
		closeList = function()
			catcher.Visible = false
			tween(list, 0.14, { GroupTransparency = 1, Position = UDim2.fromOffset(tx, ty - 6) })
			task.delay(0.15, function() if list.GroupTransparency > 0.9 then list.Visible = false end end)
		end
		local function openList()
			-- re-fetch options every open (e.g. eggs that appeared/disappeared in workspace)
			if o.Refresh then local ok, nw = pcall(o.Refresh); if ok and type(nw) == "table" then options = nw end end
			reposition(); rebuild()
			list.GroupTransparency = 1; list.Position = UDim2.fromOffset(tx, ty - 6); list.Visible = true; catcher.Visible = true
			tween(list, 0.16, { GroupTransparency = 0, Position = UDim2.fromOffset(tx, ty) }) -- fade + slide down
		end
		box.MouseButton1Click:Connect(function() if list.Visible and list.GroupTransparency < 0.5 then closeList() else openList() end end)
		catcher.MouseButton1Click:Connect(closeList)
		box:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() if list.Visible then reposition() end end)
		display(); rebuild(); tip(r, o.Tooltip)
		doRefresh = function(newOpts)
			if type(newOpts) == "table" then options = newOpts
			elseif o.Refresh then local ok, nw = pcall(o.Refresh); if ok and type(nw) == "table" then options = nw end end
			if multi then local keep = {} for _, s in ipairs(selected) do if indexOf(options, s) then table.insert(keep, s) end end selected = keep
			elseif selected and not indexOf(options, selected) then selected = nil end
			display(); rebuild()
		end
		local ctl = {
			Set = function(v) selected = v display() rebuild() if o.Callback then task.spawn(o.Callback, selected) end end,
			Get = function() return selected end,
			Refresh = doRefresh, -- Refresh(newOptions) or Refresh() to re-pull via o.Refresh
		}
		registerFlag(o, ctl); return ctl
	end

	-- Textbox
	function section:Textbox(o)
		o = o or {}; autoCb(o)
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Input", 150, o.Description)
		local holder = new("Frame", { Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.4 }, r); corner(holder, 9); stroke(holder, Theme.White, 0.8, 1); pad(holder, 0, 10, 0, 10)
		local tb = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "", PlaceholderText = o.Placeholder or "...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, holder)
		tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
		local ctl = { Set = function(v) tb.Text = v end, Get = function() return tb.Text end }
		registerFlag(o, ctl); return ctl
	end

	-- Textarea (multi-line input: label on top, big box below)
	function section:Textarea(o)
		o = o or {}; autoCb(o)
		local r = row(0); pad(r, 12, 14, 14, 14); vlist(r, 8)
		local lbl = ltext(r, o.Title or "Input Textarea", 13, Theme.Text, FB); lbl.Size = UDim2.new(1, 0, 0, 16)
		local holder = new("Frame", { Size = UDim2.new(1, 0, 0, o.Height or 90), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.4 }, r); corner(holder, 10); stroke(holder, Theme.White, 0.8, 1); pad(holder, 9, 11, 9, 11)
		local tb = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "", PlaceholderText = o.Placeholder or "Enter Text...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true, TextWrapped = true, ClearTextOnFocus = false }, holder)
		tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
		local ctl = { Set = function(v) tb.Text = v end, Get = function() return tb.Text end }
		registerFlag(o, ctl); return ctl
	end

	-- Keybind
	function section:Keybind(o)
		o = o or {}; autoCb(o); local key = o.Default
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Keybind", 90, o.Description)
		local btn = new("TextButton", { Text = key and key.Name or "None", Font = FB, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(90, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.4 }, r); corner(btn, 9); stroke(btn, Theme.White, 0.8, 1)
		local listening = false
		btn.MouseButton1Click:Connect(function() listening = true btn.Text = "..." end)
		trackConn(UserInputService.InputBegan:Connect(function(input, gpe)
			if listening and input.UserInputType == Enum.UserInputType.Keyboard then key = input.KeyCode btn.Text = key.Name listening = false
			elseif not gpe and key and input.KeyCode == key then if o.Callback then task.spawn(o.Callback) end end
		end))
		local ctl = { Set = function(k) key = k; btn.Text = k and k.Name or "None" end, Get = function() return key end }
		registerFlag(o, ctl, "keybind"); return ctl
	end

	-- ColorPicker
	function section:ColorPicker(o)
		o = o or {}; autoCb(o); local color = o.Default or Theme.Accent; local h, s, v = color:ToHSV()
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Color", 44, o.Description)
		local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(44, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = color }, r); corner(sw, 7); stroke(sw, Theme.White, 0.8)
		local pop = new("Frame", { Visible = false, BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.06, Size = UDim2.fromOffset(200, 160), ZIndex = 60 }, self._gui); corner(pop, 12); stroke(pop, Theme.White, 0.78, 1); pad(pop, 10, 10, 10, 10); vlist(pop, 8)
		local sv = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = Color3.fromHSV(h, 1, 1), LayoutOrder = 1 }, pop); corner(sv, 6)
		grad(sv, Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1))
		local blk = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0 }, sv); corner(blk, 6)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, blk)
		local hue = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 }, pop); corner(hue, 7)
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)), ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)), ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)), ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)) }) }, hue)
		local function refresh(fire) color = Color3.fromHSV(h, s, v) sw.BackgroundColor3 = color sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1) if fire ~= false and o.Callback then task.spawn(o.Callback, color) end end
		local ds, dh = false, false
		local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
		local function pick(p)
			if ds then s = clamp((p.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1) v = 1 - clamp((p.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1) refresh() end
			if dh then h = clamp((p.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1) refresh() end
		end
		sv.InputBegan:Connect(function(i) if isPress(i) then ds = true pick(i.Position) end end)
		hue.InputBegan:Connect(function(i) if isPress(i) then dh = true pick(i.Position) end end)
		trackConn(UserInputService.InputEnded:Connect(function(i) if isPress(i) then ds = false dh = false end end))
		trackConn(UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then pick(i.Position) end
		end))
		sw.MouseButton1Click:Connect(function() pop.Position = UDim2.fromOffset(sw.AbsolutePosition.X - 160, sw.AbsolutePosition.Y + 30) pop.Visible = not pop.Visible end)
		refresh(false)
		local ctl = { Set = function(c) h, s, v = c:ToHSV() refresh() end, Get = function() return color end }
		registerFlag(o, ctl, "color"); return ctl
	end

	-- Label
	function section:Label(text)
		local r = row(0)
		local l = ltext(r, text, 13, Theme.SubText, F); l.Position = UDim2.new(0, 14, 0, 0); l.Size = UDim2.new(1, -28, 0, 0); l.AutomaticSize = Enum.AutomaticSize.Y; l.TextWrapped = true; l.TextYAlignment = Enum.TextYAlignment.Top
		pad(r, 11, 0, 11, 0)
		return r
	end

	-- UserInfo (profile card): avatar + name + tag, auto-filled from the player on join
	function section:UserInfo(o)
		o = o or {}
		local name = o.Name or (LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name)) or "Player"
		local sub  = o.Tag or (LocalPlayer and ("@" .. LocalPlayer.Name)) or ""
		local r = row(60)
		local av = new("ImageLabel", { Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Field, ScaleType = Enum.ScaleType.Crop }, r); corner(av, 21); stroke(av, Theme.Accent, 0.4, 1)
		-- avatar: custom image/asset, or the player's headshot
		local ic = o.Avatar and resolveIcon(o.Avatar)
		if ic then av.Image = ic.Image
		elseif LocalPlayer then av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150" end
		local tl = ltext(r, name, 14, Theme.Text, FB); tl.Position = UDim2.new(0, 66, 0, 13); tl.Size = UDim2.new(1, -80, 0, 18)
		local sl = ltext(r, sub, 11, o.TagColor or Theme.Accent, FM); sl.Position = UDim2.new(0, 66, 0, 33); sl.Size = UDim2.new(1, -80, 0, 14)
		return { Set = function(n, t) if n then tl.Text = n end if t then sl.Text = t end end }
	end

	-- Banner (gradient / image hero for the Home page)
	function section:Banner(o)
		o = o or {}
		local r = row(0)
		-- CanvasGroup masks children to the rounded corners (a plain Frame + ClipsDescendants
		-- only clips to the rectangle, so fill children show square corners)
		local b = new("CanvasGroup", { Size = UDim2.new(1, 0, 0, o.Height or 96), BackgroundColor3 = o.Color or Theme.Accent, ClipsDescendants = true }, r); corner(b, 12)
		grad(b, o.Color or Theme.Accent, o.Color2 or Theme.Accent2, o.Rotation or 35)
		if o.Image then new("ImageLabel", { BackgroundTransparency = 1, Image = o.Image, Size = UDim2.fromScale(1, 1), ImageTransparency = o.ImageTransparency or 0.15, ScaleType = Enum.ScaleType.Crop }, b) end
		new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, b) -- readability overlay
		-- big hub logo on the right (not touching the edge)
		if o.Logo then
			local ls = o.LogoSize or math.floor((o.Height or 96) * 0.62)
			iconImage(b, o.Logo, UDim2.fromOffset(ls, ls), Theme.White, UDim2.new(1, -18, 0.5, 0), Vector2.new(1, 0.5)).ZIndex = 4
		end
		local t1 = ltext(b, o.Title or "RayVinz Hub", 20, Theme.White, FB); t1.Position = UDim2.new(0, 16, 1, -48); t1.Size = UDim2.new(1, -32, 0, 24); t1.ZIndex = 3
		local t2 = ltext(b, o.SubTitle or "", 12, Color3.fromRGB(228, 228, 234), FM); t2.Position = UDim2.new(0, 16, 1, -26); t2.Size = UDim2.new(1, -32, 0, 16); t2.ZIndex = 3
		return r
	end

	-- Paragraph
	function section:Paragraph(o)
		o = o or {}
		local r = row(0); pad(r, 13, 14, 15, 14); vlist(r, 6)
		if o.Title then local t = ltext(r, o.Title, 14, Theme.Text, FB); t.Size = UDim2.new(1, 0, 0, 18) end
		local b = ltext(r, o.Content or "", 12, Theme.SubText, F); b.Size = UDim2.new(1, 0, 0, 0); b.AutomaticSize = Enum.AutomaticSize.Y; b.TextWrapped = true; b.TextYAlignment = Enum.TextYAlignment.Top
		return r
	end

	-- Tags
	function section:Tags(tags)
		local r = row(44)
		local wrap = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(1, -28, 0, 24) }, r)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, wrap)
		for i, t in ipairs(tags or {}) do
			local pill = new("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = t.Color or Theme.Accent, LayoutOrder = i }, wrap); corner(pill, 12); pad(pill, 5, 11, 5, 11)
			local pl = ltext(pill, t.Text or "tag", 11, t.TextColor or Theme.AccentText, FB); pl.Size = UDim2.fromOffset(0, 14); pl.AutomaticSize = Enum.AutomaticSize.X
		end
		return r
	end

	-- StatGrid
	function section:StatGrid(items)
		local r = row(0); pad(r, 13, 14, 13, 14); vlist(r, 10)
		local grid, rowN = {}, nil
		for i, it in ipairs(items or {}) do
			if (i - 1) % 2 == 0 then rowN = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = i }, r); new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12) }, rowN) end
			local c = new("Frame", { BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.55, Size = UDim2.new(0.5, -6, 1, 0), LayoutOrder = i }, rowN); corner(c, 12); stroke(c, Theme.White, 0.68, 1.2); grad(c, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200), 90); pad(c, 11, 12, 11, 12); vlist(c, 7)
			local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14) }, c)
			iconImage(top, it.Icon, UDim2.fromOffset(13, 13), Theme.SubText, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
			local tl = ltext(top, it.Label or "", 11, Theme.SubText, FM); tl.Position = UDim2.new(0, it.Icon and 19 or 0, 0, 0); tl.Size = UDim2.new(1, -19, 1, 0)
			local val = ltext(c, tostring(it.Value or "-"), 15, Theme.Text, FB); val.Size = UDim2.new(1, 0, 0, 18)
			grid[it.Label] = val
		end
		return { Set = function(label, value) if grid[label] then grid[label].Text = tostring(value) end end }
	end

	-- Stats: live stat cards (money, level, anything). Each item reads from Source (an
	-- IntValue/NumberValue/StringValue like leaderstats.Money), Source + Attribute, or a Get
	-- function polled every Interval seconds. Rate = true adds a "+1.2K/min" line.
	function section:Stats(o)
		o = o or {}
		local interval = o.Interval or 1
		local items = o.Items or {}
		local r = row(0); pad(r, 13, 14, 13, 14); vlist(r, 10)
		local anyRate = false
		for _, it in ipairs(items) do if it.Rate then anyRate = true end end
		local cardH = anyRate and 74 or 56

		local function short(n)
			local a = math.abs(n)
			for _, u in ipairs({ { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
				if a >= u[1] then return (string.format("%.2f", n / u[1]):gsub("%.?0+$", "")) .. u[2] end
			end
			return tostring(round(n, 2))
		end
		local function comma(n)
			local s = tostring(math.floor(math.abs(n) + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
			return (n < 0 and "-" or "") .. s
		end
		local function fmt(it, v)
			if type(it.Format) == "function" then local ok, s = pcall(it.Format, v) return ok and tostring(s) or "--" end
			if type(v) ~= "number" then return tostring(v) end
			if it.Format == "comma" then return comma(v) end
			if it.Format == "raw" then return tostring(v) end
			return short(v)
		end
		local function read(it)
			if it.Get then return pcall(it.Get) end
			if it.Source then
				if it.Attribute then return pcall(function() return it.Source:GetAttribute(it.Attribute) end) end
				return pcall(function() return it.Source.Value end)
			end
			return true, it.Value
		end

		local cards, byLabel, rowN = {}, {}, nil
		local function update(c)
			local ok, v = read(c.it)
			if not ok or v == nil then c.val.Text = "--" return end
			if v ~= c.last then
				if type(v) == "number" and type(c.last) == "number" then
					tween(c.val, 0.12, { TextColor3 = v > c.last and Theme.Green or Theme.Error })
					task.delay(0.45, function() if c.val.Parent then tween(c.val, 0.3, { TextColor3 = Theme.Text }) end end)
				end
				c.last = v
				c.val.Text = (c.it.Prefix or "") .. fmt(c.it, v) .. (c.it.Suffix or "")
			end
			if c.rate and type(v) == "number" then
				local now = os.clock()
				table.insert(c.samples, { now, v })
				while #c.samples > 2 and now - c.samples[1][1] > 60 do table.remove(c.samples, 1) end
				local first = c.samples[1]
				local dt = now - first[1]
				if dt >= 1 then
					local perMin = (v - first[2]) / dt * 60
					c.rate.Text = (perMin >= 0 and "+" or "-") .. short(math.abs(perMin)) .. "/min"
					c.rate.TextColor3 = perMin > 0 and Theme.Green or (perMin < 0 and Theme.Error or Theme.SubText)
				end
			end
		end

		for i, it in ipairs(items) do
			if (i - 1) % 2 == 0 then
				rowN = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, cardH), LayoutOrder = i }, r)
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12) }, rowN)
			end
			local c = new("Frame", { BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.55, Size = UDim2.new(0.5, -6, 1, 0), LayoutOrder = i }, rowN)
			corner(c, 12); stroke(c, Theme.White, 0.68, 1.2); grad(c, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200), 90); pad(c, 11, 12, 11, 12); vlist(c, 6)
			local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1 }, c)
			iconImage(top, it.Icon, UDim2.fromOffset(13, 13), it.Color or Theme.SubText, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
			local tl = ltext(top, it.Label or "", 11, Theme.SubText, FM); tl.Position = UDim2.new(0, it.Icon and 19 or 0, 0, 0); tl.Size = UDim2.new(1, -19, 1, 0)
			local val = ltext(c, "--", 15, Theme.Text, FB); val.Size = UDim2.new(1, 0, 0, 18); val.LayoutOrder = 2
			local rate
			if it.Rate then rate = ltext(c, "+0/min", 11, Theme.SubText, FM); rate.Size = UDim2.new(1, 0, 0, 13); rate.LayoutOrder = 3 end
			local card = { it = it, val = val, rate = rate, samples = {}, last = nil }
			table.insert(cards, card)
			if it.Label then byLabel[it.Label] = card end
			-- value objects / attributes update instantly instead of waiting for the next poll
			if it.Source and not it.Get then
				pcall(function()
					local sig = it.Attribute and it.Source:GetAttributeChangedSignal(it.Attribute) or it.Source.Changed
					trackConn(sig:Connect(function() update(card) end))
				end)
			end
			update(card)
		end

		local acc = 0
		trackConn(game:GetService("RunService").Heartbeat:Connect(function(dt)
			acc = acc + dt
			if acc < interval then return end
			acc = 0
			for _, c in ipairs(cards) do update(c) end
		end))

		return {
			Set = function(label, value) local c = byLabel[label] if c then c.it.Value = value; update(c) end end,
			Get = function(label) local c = byLabel[label] return c and c.last end,
		}
	end

	-- SystemInfo (live FPS / Ping / Players / Game / Time)
	function section:SystemInfo(o)
		o = o or {}; local ic = o.Icons or {}
		local exec = "Unknown"; pcall(function() if identifyexecutor then exec = (identifyexecutor()) or "Unknown" end end)
		local g = self:StatGrid({
			{ Label = "FPS", Value = "--", Icon = ic.FPS }, { Label = "Ping", Value = "--", Icon = ic.Ping },
			{ Label = "Executor", Value = exec, Icon = ic.Executor }, { Label = "Players", Value = "--", Icon = ic.Players },
			{ Label = "Game", Value = "--", Icon = ic.Game }, { Label = "Time", Value = "--", Icon = ic.Time },
		})
		task.spawn(function()
			local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
			g.Set("Game", (ok and info and info.Name) or "Unknown")
		end)
		local RunService = game:GetService("RunService"); local Players = game:GetService("Players")
		local acc, frames = 0, 0
		trackConn(RunService.Heartbeat:Connect(function(dt)
			frames = frames + 1; acc = acc + dt
			if acc >= 1 then
				g.Set("FPS", math.floor(frames / acc + 0.5)); frames = 0; acc = 0
				local ping = "--"
				pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
				g.Set("Ping", ping); g.Set("Players", #Players:GetPlayers()); g.Set("Time", os.date("%H:%M:%S"))
			end
		end))
		return g
	end

	-- Image
	function section:Image(o)
		o = o or {}
		local h = o.Height or 120
		local r = row(h + 20)
		local img = new("ImageLabel", { BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.5, Size = UDim2.new(1, -28, 0, h), Position = UDim2.new(0, 14, 0, 10), ScaleType = o.ScaleType or Enum.ScaleType.Fit }, r); corner(img, 10); stroke(img, Theme.White, 0.82, 1)
		local ic = resolveIcon(o.Image); img.Image = (ic and ic.Image) or o.Image or ""
		return { Set = function(v) local r2 = resolveIcon(v); img.Image = (r2 and r2.Image) or v or "" end }
	end

	-- Progress bar
	function section:Progress(o)
		o = o or {}
		local r = row(o.Title and 46 or 24)
		local y = o.Title and 26 or 9
		if o.Title then local lbl = ltext(r, o.Title, 13, Theme.Text, FM); lbl.Position = UDim2.new(0, 14, 0, 7); lbl.Size = UDim2.new(1, -28, 0, 16) end
		local track = new("Frame", { Size = UDim2.new(1, -28, 0, 8), Position = UDim2.new(0, 14, 0, y), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.85, BorderSizePixel = 0 }, r); corner(track, 4)
		local fill = new("Frame", { Size = UDim2.new(clamp(o.Default or 0, 0, 1), 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, track); corner(fill, 4); grad(fill, Theme.Accent, Theme.Accent2, 0)
		return { Set = function(p) tween(fill, 0.25, { Size = UDim2.new(clamp(p, 0, 1), 0, 1, 0) }) end }
	end

	-- Divider (optional centered label)
	function section:Divider(text)
		local r = row(text and 26 or 14)
		new("Frame", { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, r)
		if text then
			local lbl = ltext(r, " " .. text .. " ", 10, Theme.Muted, FB, Enum.TextXAlignment.Center); lbl.BackgroundColor3 = Theme.Card; lbl.BackgroundTransparency = 0.1; lbl.Position = UDim2.fromScale(0.5, 0.5); lbl.AnchorPoint = Vector2.new(0.5, 0.5); lbl.Size = UDim2.fromOffset(0, 16); lbl.AutomaticSize = Enum.AutomaticSize.X
		end
		return r
	end

	-- Button group (several buttons in one row)
	function section:ButtonGroup(o)
		o = o or {}
		local btns = o.Buttons or o
		local r = row(50)
		local wrap = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -28, 0, 38) }, r)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }, wrap)
		local n = math.max(#btns, 1)
		for i, b in ipairs(btns) do
			local primary = b.Variant == "Primary"
			local btn = new("TextButton", { Text = b.Title or "Button", Font = FB, TextSize = 13, TextColor3 = primary and Theme.AccentText or Theme.Text, AutoButtonColor = false, Size = UDim2.new(1 / n, -8, 1, 0), BackgroundColor3 = primary and Theme.Accent or Theme.Select, BackgroundTransparency = primary and 0 or 0.3, LayoutOrder = i }, wrap); corner(btn, 9)
			if primary then grad(btn, Theme.Accent, Theme.Accent2, 25) else stroke(btn, Theme.White, 0.8, 1) end
			btn.MouseButton1Click:Connect(function() if b.Callback then task.spawn(b.Callback) end end)
		end
		return r
	end

	-- Number input (+/- stepper)
	function section:NumberInput(o)
		o = o or {}; autoCb(o)
		local val = o.Default or 0; local step = o.Step or 1; local mn, mx = o.Min, o.Max
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Number", 108, o.Description)
		local box = new("Frame", { Size = UDim2.fromOffset(104, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundTransparency = 1 }, r)
		local minus = new("TextButton", { Text = "-", Font = FB, TextSize = 18, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.4 }, box); corner(minus, 9); stroke(minus, Theme.White, 0.8, 1)
		local plus = new("TextButton", { Text = "+", Font = FB, TextSize = 18, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.4 }, box); corner(plus, 9); stroke(plus, Theme.White, 0.8, 1)
		local vl = ltext(box, tostring(val), 13, Theme.Text, FB, Enum.TextXAlignment.Center); vl.Position = UDim2.fromScale(0.5, 0.5); vl.AnchorPoint = Vector2.new(0.5, 0.5); vl.Size = UDim2.fromOffset(44, 30)
		local function set(v, fire)
			if mn then v = math.max(mn, v) end; if mx then v = math.min(mx, v) end
			val = round(v, o.Rounding); vl.Text = tostring(val)
			if fire ~= false and o.Callback then task.spawn(o.Callback, val) end
		end
		minus.MouseButton1Click:Connect(function() set(val - step) end)
		plus.MouseButton1Click:Connect(function() set(val + step) end)
		local ctl = { Set = function(v) set(v) end, Get = function() return val end }
		registerFlag(o, ctl); return ctl
	end

	-- ConfigManager: create (named) / select / load / delete / auto-load  (one call builds the whole UI)
	function section:ConfigManager()
		local UI = self._window
		local nameBox = self:Textbox({ Title = "New config name", Placeholder = "my_config" })
		local dd = self:Dropdown({ Title = "Config", Options = UI:ListConfigs(), Refresh = function() return UI:ListConfigs() end })
		self:ButtonGroup({ Buttons = {
			{ Title = "Create", Variant = "Primary", Callback = function()
				local n = tostring(nameBox.Get() or ""):gsub("%s+", "_")
				if n ~= "" then UI:SaveConfig(n); dd.Refresh(UI:ListConfigs()); UI:Notify({ Title = "Config created", Content = n, Type = "Success", Icon = "check" })
				else UI:Notify({ Title = "Enter a name first", Type = "Warning", Icon = "alert-triangle" }) end
			end },
			{ Title = "Save", Callback = function() -- overwrite the selected config
				local n = dd.Get()
				if n then UI:SaveConfig(n); UI:Notify({ Title = "Saved (overwrite)", Content = n, Type = "Success", Icon = "save" })
				else UI:Notify({ Title = "Select a config first", Type = "Warning", Icon = "alert-triangle" }) end
			end },
		} })
		self:ButtonGroup({ Buttons = {
			{ Title = "Load", Callback = function()
				local n = dd.Get(); if n then UI:LoadConfig(n); UI:Notify({ Title = "Loaded", Content = n, Type = "Info", Icon = "download" }) end
			end },
			{ Title = "Delete", Callback = function()
				local n = dd.Get(); if n then UI:DeleteConfig(n); dd.Refresh(UI:ListConfigs()); UI:Notify({ Title = "Deleted", Content = n, Type = "Warning", Icon = "trash-2" }) end
			end },
		} })
		self:Dropdown({ Title = "Auto-load on open", Options = UI:ListConfigs(), Default = UI:GetAutoLoadConfig(), Refresh = function() return UI:ListConfigs() end,
			Callback = function(n) UI:SetAutoLoadConfig(n); UI:Notify({ Title = "Auto-load set", Content = n, Type = "Success", Icon = "check" }) end })
		return { Refresh = function() dd.Refresh(UI:ListConfigs()) end }
	end

	-- HWID: show + copy + reload (no rejoin). o.Callback(id) fires on reload (e.g. re-verify a key)
	function section:HWID(o)
		o = o or {}
		local UI = self._window
		local function get() local id; pcall(function() if gethwid then id = gethwid() end end); return id or "unavailable" end
		local r = row(0); pad(r, 11, 14, 10, 14); vlist(r, 5)
		local t = ltext(r, "HWID", 13, Theme.Text, FB); t.Size = UDim2.new(1, 0, 0, 16)
		local val = ltext(r, get(), 11, Theme.SubText, FM); val.Size = UDim2.new(1, 0, 0, 14); val.TextTruncate = Enum.TextTruncate.AtEnd
		self:ButtonGroup({ Buttons = {
			{ Title = "Copy", Callback = function() pcall(function() if setclipboard then setclipboard(get()) end end); UI:Notify({ Title = "Copied HWID", Type = "Info", Icon = "copy" }) end },
			{ Title = "Reload HWID", Variant = "Primary", Callback = function() val.Text = get(); if o.Callback then task.spawn(o.Callback, get()) end UI:Notify({ Title = "HWID reloaded", Type = "Success", Icon = "refresh-cw" }) end },
		} })
		return { Get = get, Reload = function() val.Text = get() return get() end }
	end

	-- Checkbox (square check, distinct from the switch-style Toggle)
	function section:Checkbox(o)
		o = o or {}; autoCb(o); local state = o.Default or false
		local r = row(o.Description and 58 or 46); placeLabel(r, o.Title or "Checkbox", 30, o.Description)
		local bx = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = state and Theme.Accent or Theme.Field, BackgroundTransparency = state and 0 or 0.4 }, r); corner(bx, 6); stroke(bx, Theme.White, 0.75, 1)
		local chk = iconImage(bx, "check", UDim2.fromOffset(14, 14), Theme.AccentText, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)); chk.Visible = state
		local function set(v, fire)
			state = v; chk.Visible = v
			tween(bx, 0.15, { BackgroundColor3 = v and Theme.Accent or Theme.Field, BackgroundTransparency = v and 0 or 0.4 })
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		bx.MouseButton1Click:Connect(function() set(not state) end)
		tip(r, o.Tooltip)
		local ctl = { Set = function(v) set(v) end, Get = function() return state end }
		registerFlag(o, ctl); return ctl
	end

	-- Radio group (choose one from a list; stacked rows, filled dot on the selected)
	function section:Radio(o)
		o = o or {}; autoCb(o); local opts2 = o.Options or {}; local selected = o.Default
		local r = row(0); pad(r, 10, 14, 10, 14); vlist(r, 6)
		if o.Title then local t = ltext(r, o.Title, 13, Theme.Text, FB); t.Size = UDim2.new(1, 0, 0, 16) end
		local dots = {}
		local function set(v, fire)
			selected = v
			for opt, d in pairs(dots) do
				local on = opt == selected
				tween(d.ring, 0.12, { BackgroundTransparency = on and 0 or 1 })
				d.lbl.TextColor3 = on and Theme.Text or Theme.SubText
			end
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		for i, opt in ipairs(opts2) do
			local ob = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i }, r)
			local circ = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.3 }, ob); corner(circ, 8); stroke(circ, Theme.White, 0.7, 1)
			local ring = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1 }, circ); corner(ring, 4)
			local lbl = ltext(ob, tostring(opt), 12, Theme.SubText, FM); lbl.Position = UDim2.new(0, 24, 0, 0); lbl.Size = UDim2.new(1, -24, 1, 0)
			dots[opt] = { ring = ring, lbl = lbl }
			ob.MouseButton1Click:Connect(function() set(opt) end)
		end
		set(selected, false)
		local ctl = { Set = function(v) set(v) end, Get = function() return selected end }
		registerFlag(o, ctl); return ctl
	end

	-- Segmented control (horizontal pill group, single select)
	function section:Segmented(o)
		o = o or {}; autoCb(o); local opts2 = o.Options or {}; local selected = o.Default or opts2[1]
		local r = row(o.Title and 58 or 44)
		if o.Title then local t = ltext(r, o.Title, 13, Theme.Text, FM); t.Position = UDim2.new(0, 14, 0, 8); t.Size = UDim2.new(1, -28, 0, 16) end
		local wrap = new("Frame", { BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.5, Size = UDim2.new(1, -28, 0, 28), Position = o.Title and UDim2.new(0, 14, 0, 26) or UDim2.new(0, 14, 0.5, -14) }, r); corner(wrap, 8); stroke(wrap, Theme.White, 0.85, 1); pad(wrap, 3, 3, 3, 3)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, wrap)
		local n = math.max(#opts2, 1); local segs = {}
		local function set(v, fire)
			selected = v
			for opt, b in pairs(segs) do
				local on = opt == selected
				tween(b, 0.14, { BackgroundTransparency = on and 0 or 1 })
				b.TextColor3 = on and Theme.AccentText or Theme.SubText
			end
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		for i, opt in ipairs(opts2) do
			local b = new("TextButton", { Text = tostring(opt), Font = FB, TextSize = 12, TextColor3 = Theme.SubText, AutoButtonColor = false, Size = UDim2.new(1 / n, -3, 1, 0), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, LayoutOrder = i }, wrap); corner(b, 6)
			segs[opt] = b
			b.MouseButton1Click:Connect(function() set(opt) end)
		end
		set(selected, false)
		local ctl = { Set = function(v) set(v) end, Get = function() return selected end }
		registerFlag(o, ctl); return ctl
	end

	-- Stepper (+/- number) — alias of NumberInput
	function section:Stepper(o) return self:NumberInput(o) end

	-- CodeBlock (monospace text block + Copy button)
	function section:CodeBlock(o)
		o = o or {}; local code = o.Code or o.Content or ""
		local r = row(0); pad(r, 12, 14, 14, 14); vlist(r, 8)
		local top = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1 }, r)
		local t = ltext(top, o.Title or "Code", 12, Theme.SubText, FB); t.Size = UDim2.new(1, -60, 1, 0)
		local cp = new("TextButton", { Text = "Copy", Font = FB, TextSize = 11, TextColor3 = Theme.Accent, AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(50, 16), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0) }, top)
		local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(16, 16, 22), BackgroundTransparency = 0.2 }, r); corner(box, 8); stroke(box, Theme.White, 0.88, 1); pad(box, 10, 12, 10, 12)
		local txt = ltext(box, code, 12, Color3.fromRGB(210, 220, 230), Enum.Font.Code); txt.Size = UDim2.new(1, 0, 0, 0); txt.AutomaticSize = Enum.AutomaticSize.Y; txt.TextWrapped = true; txt.TextYAlignment = Enum.TextYAlignment.Top; txt.TextTruncate = Enum.TextTruncate.None
		cp.MouseButton1Click:Connect(function() pcall(function() if setclipboard then setclipboard(txt.Text) end end); self._window:Notify({ Title = "Copied", Type = "Info", Icon = "copy", Duration = 2 }) end)
		return { Set = function(v) txt.Text = tostring(v) end, Get = function() return txt.Text end }
	end

	-- Graph: a live sparkline. ctl.Push(v) adds a point; or pass o.Update (polled every o.Interval s)
	function section:Graph(o)
		o = o or {}; local maxPts = o.Points or 40; local h = o.Height or 90
		local r = row(h + (o.Title and 28 or 14))
		if o.Title then local t = ltext(r, o.Title, 13, Theme.Text, FM); t.Position = UDim2.new(0, 14, 0, 7); t.Size = UDim2.new(1, -28, 0, 16) end
		local valLbl = ltext(r, "", 12, Theme.Accent, FB, Enum.TextXAlignment.Right); valLbl.Position = UDim2.new(1, -14, 0, 7); valLbl.AnchorPoint = Vector2.new(1, 0); valLbl.Size = UDim2.fromOffset(90, 16)
		local area = new("Frame", { Size = UDim2.new(1, -28, 0, h), Position = UDim2.new(0, 14, 0, o.Title and 26 or 8), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.55 }, r); corner(area, 8); stroke(area, Theme.White, 0.9, 1)
		local bars = {}
		for i = 1, maxPts do
			local b = new("Frame", { Size = UDim2.new(1 / maxPts, -1, 0, 2), Position = UDim2.new((i - 1) / maxPts, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, area); corner(b, 1); grad(b, Theme.Accent2, Theme.Accent, 90); bars[i] = b
		end
		local data = {}; local minV, maxV = o.Min, o.Max
		local function redraw()
			local lo, hi = minV, maxV
			if not lo or not hi then
				lo, hi = math.huge, -math.huge
				for _, v in ipairs(data) do lo = math.min(lo, v); hi = math.max(hi, v) end
				if lo == math.huge then lo, hi = 0, 1 end
			end
			if hi <= lo then hi = lo + 1 end
			for i = 1, maxPts do
				local v = data[#data - maxPts + i]
				local pct = v and clamp((v - lo) / (hi - lo), 0, 1) or 0
				bars[i].Size = UDim2.new(1 / maxPts, -1, pct, 0)
			end
		end
		local function push(v)
			v = tonumber(v) or 0
			table.insert(data, v); if #data > maxPts then table.remove(data, 1) end
			valLbl.Text = tostring(round(v, o.Rounding or 1)) .. (o.Suffix or ""); redraw()
		end
		if o.Update then
			local trk = self._window._track or function(c) return c end
			local acc, iv = 0, (o.Interval or 0.5)
			trk(game:GetService("RunService").Heartbeat:Connect(function(dt)
				acc = acc + dt; if acc < iv then return end; acc = 0
				local ok, v = pcall(o.Update); if ok and v then push(v) end
			end))
		end
		return { Push = push, Set = push, Clear = function() data = {}; redraw() end }
	end

	-- Table: columns + rows, click a header to sort, click a row to select
	function section:Table(o)
		o = o or {}; local cols = o.Columns or {}
		local r = row(0); pad(r, 10, 12, 12, 12); vlist(r, 6)
		if o.Title then local t = ltext(r, o.Title, 13, Theme.Text, FB); t.Size = UDim2.new(1, 0, 0, 16) end
		local nc = math.max(#cols, 1)
		local header = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.5 }, r); corner(header, 7); pad(header, 0, 8, 0, 8)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, header)
		local sortCol, sortAsc = nil, true
		local rowsHolder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, r); vlist(rowsHolder, 3)
		local data, selected, rebuild = {}, nil, nil
		for i, c in ipairs(cols) do
			local hb = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1 / nc, 0, 1, 0), BackgroundTransparency = 1, LayoutOrder = i }, header)
			local hl = ltext(hb, tostring(c), 11, Theme.SubText, FB); hl.Size = UDim2.new(1, 0, 1, 0)
			hb.MouseButton1Click:Connect(function()
				if sortCol == i then sortAsc = not sortAsc else sortCol = i; sortAsc = true end
				table.sort(data, function(a, b)
					local av, bv = a[i], b[i]
					if tonumber(av) and tonumber(bv) then av, bv = tonumber(av), tonumber(bv) else av, bv = tostring(av), tostring(bv) end
					if sortAsc then return av < bv else return av > bv end
				end)
				rebuild()
			end)
		end
		rebuild = function()
			for _, c in ipairs(rowsHolder:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for ri, rowData in ipairs(data) do
				local rb = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = (selected == ri) and Theme.Accent or Theme.Field, BackgroundTransparency = (selected == ri) and 0.72 or 0.6, LayoutOrder = ri }, rowsHolder); corner(rb, 6); pad(rb, 0, 8, 0, 8)
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, rb)
				for ci = 1, nc do
					local cell = new("Frame", { Size = UDim2.new(1 / nc, 0, 1, 0), BackgroundTransparency = 1, LayoutOrder = ci }, rb)
					ltext(cell, tostring(rowData[ci] ~= nil and rowData[ci] or ""), 11, (selected == ri) and Theme.Text or Theme.SubText, FM).Size = UDim2.new(1, 0, 1, 0)
				end
				rb.MouseButton1Click:Connect(function() selected = ri; rebuild(); if o.Callback then task.spawn(o.Callback, rowData, ri) end end)
			end
		end
		if o.Rows then data = o.Rows end
		rebuild()
		return {
			Add = function(vals) table.insert(data, vals); rebuild() end,
			SetRows = function(list) data = list or {}; selected = nil; rebuild() end,
			Clear = function() data = {}; selected = nil; rebuild() end,
			GetSelected = function() return selected and data[selected] or nil end,
		}
	end

	-- PlayerDropdown: a dropdown auto-populated with the current players (live on join/leave)
	function section:PlayerDropdown(o)
		o = o or {}
		local function names()
			local out = {}
			pcall(function() for _, p in ipairs(Players:GetPlayers()) do table.insert(out, p.Name) end end)
			if o.IncludeNone then table.insert(out, 1, "None") end
			return out
		end
		o.Options = names(); o.Refresh = names; if o.RefreshButton == nil then o.RefreshButton = true end
		if o.Title == nil then o.Title = "Player" end
		local ctl = self:Dropdown(o)
		local trk = self._window._track or function(c) return c end
		pcall(function()
			trk(Players.PlayerAdded:Connect(function() if ctl.Refresh then ctl.Refresh(names()) end end))
			trk(Players.PlayerRemoving:Connect(function() task.defer(function() if ctl.Refresh then ctl.Refresh(names()) end end) end))
		end)
		return ctl
	end

	-- TeamDropdown: a dropdown of the game's Teams
	function section:TeamDropdown(o)
		o = o or {}
		local function names()
			local out = {}
			pcall(function() for _, t in ipairs(game:GetService("Teams"):GetTeams()) do table.insert(out, t.Name) end end)
			return out
		end
		o.Options = names(); o.Refresh = names; if o.RefreshButton == nil then o.RefreshButton = true end
		if o.Title == nil then o.Title = "Team" end
		return self:Dropdown(o)
	end

	-- ThemeEditor: live color pickers for the main theme + accent, with a shareable theme code
	function section:ThemeEditor()
		local UI = self._window
		self:ColorPicker({ Title = "Accent", Default = Theme.Accent, Callback = function(c) UI:SetAccent(c, Theme.Accent2) end })
		self:ColorPicker({ Title = "Background", Default = Theme.Background, Callback = function(c) UI:SetTheme({ Background = c }) end })
		self:ColorPicker({ Title = "Card", Default = Theme.Card, Callback = function(c) UI:SetTheme({ Card = c }) end })
		self:ColorPicker({ Title = "Text", Default = Theme.Text, Callback = function(c) UI:SetTheme({ Text = c }) end })
		self:ButtonGroup({ Buttons = {
			{ Title = "Copy theme code", Variant = "Primary", Callback = function() pcall(function() if setclipboard then setclipboard(UI:GetThemeCode()) end end); UI:Notify({ Title = "Theme code copied", Type = "Success", Icon = "copy" }) end },
			{ Title = "Reset", Callback = function() UI:SetTheme("Dark"); UI:SetAccent("Pink") end },
		} })
		return {}
	end

	return section
end

-- ================= Notify / Dialog / Loading =================
function RayVinzUI:Notify(o)
	o = o or {}
	local colors = { Info = Theme.Info, Success = Theme.Green, Warning = Theme.Warning, Error = Theme.Error }
	local color = colors[o.Type or "Info"] or Theme.Info
	local defIcons = { Info = "info", Success = "check", Warning = "alert-triangle", Error = "x" }
	local gui = self.Gui or ActiveGui
	local holder = gui:FindFirstChild("NotifHolder")
	if not holder then
		-- bottom-right stack (where notifications usually live), newest at the bottom
		holder = new("Frame", { Name = "NotifHolder", BackgroundTransparency = 1, Size = UDim2.new(0, 310, 1, -40), Position = UDim2.new(1, -20, 1, -20), AnchorPoint = Vector2.new(1, 1) }, gui)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right }, holder)
	end
	-- max-visible queue: drop the oldest when the stack is full
	local maxV = o.MaxVisible or 5
	local cgs = {}
	for _, c in ipairs(holder:GetChildren()) do if c.ClassName == "CanvasGroup" then table.insert(cgs, c) end end
	if #cgs >= maxV then table.sort(cgs, function(a, b) return a.LayoutOrder < b.LayoutOrder end); pcall(function() cgs[1]:Destroy() end) end
	-- Figma style: [colored icon square] [title + message]. The card height is DRIVEN from the
	-- measured text height (never AutomaticSize on the card + a scale child — that ballooned it).
	local card = new("CanvasGroup", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.fromRGB(26, 26, 30), BackgroundTransparency = 0.22, GroupTransparency = 1, ClipsDescendants = true, LayoutOrder = math.floor(tick() % 1e7) }, holder)
	corner(card, 14); stroke(card, Theme.White, 0.66, 1.2); glassSheen(card, 14, 1)
	local iconBox = new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, BackgroundTransparency = 0.72 }, card); corner(iconBox, 9)
	iconImage(iconBox, o.Icon or defIcons[o.Type or "Info"], UDim2.fromOffset(18, 18), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	-- dismiss (X)
	local closeBtn = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -9, 0, 9), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 4 }, card)
	iconImage(closeBtn, "x", UDim2.fromOffset(12, 12), Theme.Muted, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local col = new("Frame", { Size = UDim2.new(1, -88, 0, 0), Position = UDim2.new(0, 56, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card); vlist(col, 2)
	local tl = ltext(col, o.Title or "Notification", 13, Theme.Text, FB); tl.Size = UDim2.new(1, 0, 0, 16); tl.LayoutOrder = 1
	if o.Content and o.Content ~= "" then
		local msg = ltext(col, o.Content, 11, Theme.SubText, F); msg.LayoutOrder = 2; msg.Size = UDim2.new(1, 0, 0, 0); msg.AutomaticSize = Enum.AutomaticSize.Y; msg.TextWrapped = true; msg.TextYAlignment = Enum.TextYAlignment.Top
	end
	local function sync() local h = col.AbsoluteSize.Y or 0 if h < 34 then h = 34 end card.Size = UDim2.new(1, 0, 0, h + 22) end
	col:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync); task.defer(sync)
	tween(card, 0.28, { GroupTransparency = 0 }) -- fade in
	local dismissed = false
	local function dismiss() if dismissed then return end dismissed = true tween(card, 0.22, { GroupTransparency = 1 }) task.wait(0.24) pcall(function() card:Destroy() end) end
	-- action buttons (e.g. { { Title = "Undo", Callback = fn } }); Close = false keeps the toast open
	if o.Actions and #o.Actions > 0 then
		local arow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 3 }, col)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, arow)
		for i, a in ipairs(o.Actions) do
			local ab = new("TextButton", { Text = a.Title or "OK", Font = FB, TextSize = 11, TextColor3 = a.Primary and Theme.AccentText or Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = a.Primary and Theme.Accent or Theme.Select, BackgroundTransparency = a.Primary and 0 or 0.25, LayoutOrder = i }, arow); corner(ab, 7); pad(ab, 0, 12, 0, 12)
			ab.MouseButton1Click:Connect(function() if a.Callback then task.spawn(a.Callback) end if a.Close ~= false then task.spawn(dismiss) end end)
		end
	end
	closeBtn.MouseButton1Click:Connect(function() task.spawn(dismiss) end)
	task.delay(o.Duration or 4, dismiss)
	return card
end

function RayVinzUI:Dialog(o)
	o = o or {}
	local gui = self.Gui or ActiveGui
	local overlay = new("Frame", { Name = "Dialog", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 80 }, gui)
	local box = new("Frame", { Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.06, ClipsDescendants = true, ZIndex = 81 }, overlay); corner(box, 18); stroke(box, Theme.White, 0.78, 1); pad(box, 18, 20, 18, 20); vlist(box, 14)
	local t = ltext(box, o.Title or "Dialog", 15, Theme.Text, FB); t.Size = UDim2.new(1, 0, 0, 20); t.LayoutOrder = 1
	local body = ltext(box, o.Content or "", 13, Theme.SubText, F); body.LayoutOrder = 2; body.Size = UDim2.new(1, 0, 0, 0); body.AutomaticSize = Enum.AutomaticSize.Y; body.TextWrapped = true; body.TextYAlignment = Enum.TextYAlignment.Top
	local btns = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3 }, box)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center }, btns)
	for i, bd in ipairs(o.Buttons or { { Title = "OK" } }) do
		local primary = bd.Variant == "Primary"
		local b = new("TextButton", { Text = bd.Title or "OK", Font = FB, TextSize = 13, TextColor3 = primary and Theme.AccentText or Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = primary and Theme.Accent or Theme.Select, LayoutOrder = i }, btns); corner(b, 9); pad(b, 0, 18, 0, 18)
		b.MouseButton1Click:Connect(function() overlay:Destroy() if bd.Callback then task.spawn(bd.Callback) end end)
	end
	return overlay
end

-- input dialog (modal with a textbox). o.Callback(text) on confirm
function RayVinzUI:Prompt(o)
	o = o or {}
	local gui = self.Gui or ActiveGui
	local overlay = new("Frame", { Name = "Prompt", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 82 }, gui)
	local box = new("Frame", { Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.06, ClipsDescendants = true, ZIndex = 83 }, overlay); corner(box, 18); stroke(box, Theme.White, 0.78, 1); pad(box, 18, 20, 18, 20); vlist(box, 12)
	local t = ltext(box, o.Title or "Input", 15, Theme.Text, FB); t.Size = UDim2.new(1, 0, 0, 20); t.LayoutOrder = 1
	if o.Content and o.Content ~= "" then local c = ltext(box, o.Content, 12, Theme.SubText, F); c.LayoutOrder = 2; c.Size = UDim2.new(1, 0, 0, 0); c.AutomaticSize = Enum.AutomaticSize.Y; c.TextWrapped = true; c.TextYAlignment = Enum.TextYAlignment.Top end
	local field = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.3, LayoutOrder = 3 }, box); corner(field, 9); stroke(field, Theme.White, 0.8, 1); pad(field, 0, 12, 0, 12)
	local tb = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "", PlaceholderText = o.Placeholder or "type here...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FM, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, field)
	local btns = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 4 }, box)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center }, btns)
	local cancel = new("TextButton", { Text = o.CancelText or "Cancel", Font = FB, TextSize = 13, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.Select, LayoutOrder = 1 }, btns); corner(cancel, 9); pad(cancel, 0, 18, 0, 18)
	local confirm = new("TextButton", { Text = o.ConfirmText or "Confirm", Font = FB, TextSize = 13, TextColor3 = Theme.AccentText, AutoButtonColor = false, Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.Accent, LayoutOrder = 2 }, btns); corner(confirm, 9); pad(confirm, 0, 18, 0, 18); grad(confirm, Theme.Accent, Theme.Accent2, 25)
	local function done(v) overlay:Destroy() if v ~= nil and o.Callback then task.spawn(o.Callback, v) elseif v == nil and o.OnCancel then task.spawn(o.OnCancel) end end
	cancel.MouseButton1Click:Connect(function() done(nil) end)
	confirm.MouseButton1Click:Connect(function() done(tb.Text) end)
	tb.FocusLost:Connect(function(enter) if enter then done(tb.Text) end end)
	task.defer(function() pcall(function() tb:CaptureFocus() end) end)
	return overlay
end

-- floating watermark (draggable glass pill, auto FPS/ping/time). returns { Set, SetVisible, Destroy }
function RayVinzUI:Watermark(o)
	o = o or {}
	local gui = self.Gui or ActiveGui
	-- default below the Roblox topbar + performance-stats bar (y=120); override with o.Position
	local wm = new("CanvasGroup", { Name = "Watermark", Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Position = o.Position or UDim2.new(0, 16, 0, 120), BackgroundColor3 = Color3.fromRGB(26, 26, 30), BackgroundTransparency = 0.18, ZIndex = 85 }, gui); corner(wm, 9); stroke(wm, Theme.White, 0.58, 1.2); glassSheen(wm, 9, 0); pad(wm, 0, 13, 0, 13)
	local lbl = ltext(wm, o.Text or "RayVinz Hub", 12, Theme.Text, FB); lbl.Size = UDim2.new(0, 0, 1, 0); lbl.AutomaticSize = Enum.AutomaticSize.X; lbl.ZIndex = 2
	draggable(wm, wm)
	local track = self._track or function(c) return c end
	if o.Auto ~= false then
		local acc, frames, fps = 0, 0, 0
		track(game:GetService("RunService").Heartbeat:Connect(function(dt)
			frames = frames + 1; acc = acc + dt
			if acc >= 1 then
				fps = math.floor(frames / acc + 0.5); frames = 0; acc = 0
				local ping = "--"; pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. "ms" end)
				lbl.Text = (o.Text or "RayVinz Hub") .. "  |  " .. fps .. " fps  |  " .. ping .. "  |  " .. os.date("%H:%M:%S")
			end
		end))
	end
	return { Set = function(t) lbl.Text = t end, SetVisible = function(v) wm.Visible = v and true or false end, Destroy = function() pcall(function() wm:Destroy() end) end }
end

-- update checker: fetch a remote version string and compare. o = { VersionUrl, Current, OnUpdate }
function RayVinzUI:CheckUpdate(o)
	o = o or {}
	task.spawn(function()
		local ok, remote = pcall(function() return game:HttpGet(o.VersionUrl) end)
		if not ok or not remote then return end
		remote = tostring(remote):gsub("%s+", "")
		if o.Current and remote ~= "" and remote ~= tostring(o.Current) then
			if o.OnUpdate then task.spawn(o.OnUpdate, remote)
			else self:Notify({ Title = "Update available", Content = "New version: " .. remote, Type = "Warning", Icon = "download", Duration = 8 }) end
		end
	end)
	return self
end

function RayVinzUI:Loading(o)
	o = o or {}
	local gui = self.Gui or ActiveGui
	-- frosted glass loader: blur the scene + a translucent glass card
	local lblur = nil
	if o.Blur ~= false then
		pcall(function() lblur = new("BlurEffect", { Name = "RayVinzBlur", Size = 0, Enabled = true }, game:GetService("Lighting")) end)
		if lblur then tween(lblur, 0.3, { Size = type(o.Blur) == "number" and o.Blur or 22 }) end
	end
	local overlay = new("Frame", { Name = "Loading", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 90 }, gui)
	tween(overlay, 0.25, { BackgroundTransparency = 0.35 })
	local card = new("CanvasGroup", { Size = UDim2.fromOffset(292, 74), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(26, 26, 30), BackgroundTransparency = 0.28, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 91 }, overlay); corner(card, 16); stroke(card, Theme.White, 0.68, 1.2); glassSheen(card, 16, 1)
	tween(card, 0.3, { GroupTransparency = 0 })
	-- progress bar along the very top edge
	local track = new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, card)
	local fb = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, track); grad(fb, Theme.Accent, Theme.Accent2, 0)
	tween(fb, 2.2, { Size = UDim2.new(0.92, 0, 1, 0) }) -- auto loading animation
	-- logo (big, no pink box)
	iconImage(card, o.Logo, UDim2.fromOffset(44, 44), Theme.White, UDim2.new(0, 14, 0.5, 2), Vector2.new(0, 0.5))
	-- title + subtitle (left of logo)
	local t1 = ltext(card, o.Title or "RayVinz Hub", 14, Theme.Text, FB); t1.Position = UDim2.new(0, 66, 0, 17); t1.Size = UDim2.new(1, -80, 0, 18)
	local t2 = ltext(card, o.SubTitle or "Loading...", 11, Theme.SubText, F); t2.Position = UDim2.new(0, 66, 0, 38); t2.Size = UDim2.new(1, -80, 0, 14)
	return { Set = function(p) tween(fb, 0.3, { Size = UDim2.new(clamp(p, 0, 1), 0, 1, 0) }) end, Close = function() tween(card, 0.25, { GroupTransparency = 1 }) tween(overlay, 0.3, { BackgroundTransparency = 1 }) if lblur then tween(lblur, 0.3, { Size = 0 }) end task.wait(0.32) overlay:Destroy() if lblur then pcall(function() lblur:Destroy() end) end end }
end

-- ================= Theme / accent switcher =================
RayVinzUI.AccentPresets = {
	Pink   = { Color3.fromRGB(255, 121, 198), Color3.fromRGB(189, 147, 249) },
	Purple = { Color3.fromRGB(189, 147, 249), Color3.fromRGB(139, 123, 255) },
	Blue   = { Color3.fromRGB(10, 132, 255),  Color3.fromRGB(94, 180, 255) },
	Green  = { Color3.fromRGB(48, 209, 88),   Color3.fromRGB(120, 230, 150) },
	Red    = { Color3.fromRGB(255, 69, 58),   Color3.fromRGB(255, 130, 120) },
	Orange = { Color3.fromRGB(255, 159, 10),  Color3.fromRGB(255, 196, 90) },
}
-- change the accent live (recolors existing accent-colored instances in the window)
function RayVinzUI:SetAccent(color, color2)
	if type(color) == "string" then local p = RayVinzUI.AccentPresets[color]; if p then color, color2 = p[1], p[2] end end
	Theme.Accent = color or Theme.Accent
	Theme.Accent2 = color2 or Theme.Accent2
	applyThemeRegistry({ Accent = true, Accent2 = true })
	return self
end
-- full theme presets + live theme swap (not just accent)
RayVinzUI.ThemePresets = {
	Dark     = { Background = Color3.fromRGB(28, 28, 30), Sidebar = Color3.fromRGB(36, 36, 39), Card = Color3.fromRGB(44, 44, 46), Elevated = Color3.fromRGB(50, 50, 53), Select = Color3.fromRGB(60, 60, 63), Field = Color3.fromRGB(58, 58, 60), Text = Color3.fromRGB(245, 245, 247), SubText = Color3.fromRGB(152, 152, 157) },
	Midnight = { Background = Color3.fromRGB(16, 18, 27), Sidebar = Color3.fromRGB(22, 25, 37), Card = Color3.fromRGB(28, 32, 46), Elevated = Color3.fromRGB(34, 39, 56), Select = Color3.fromRGB(44, 50, 70), Field = Color3.fromRGB(40, 45, 64), Text = Color3.fromRGB(235, 238, 250), SubText = Color3.fromRGB(140, 148, 170) },
	Light    = { Background = Color3.fromRGB(242, 242, 245), Sidebar = Color3.fromRGB(232, 232, 237), Card = Color3.fromRGB(252, 252, 255), Elevated = Color3.fromRGB(246, 246, 250), Select = Color3.fromRGB(224, 224, 230), Field = Color3.fromRGB(236, 236, 241), Text = Color3.fromRGB(28, 28, 32), SubText = Color3.fromRGB(110, 110, 120) },
}
function RayVinzUI:SetTheme(t)
	if type(t) == "string" then t = RayVinzUI.ThemePresets[t] end
	if type(t) ~= "table" then return self end
	for _, k in ipairs({ "Background", "Sidebar", "Card", "Elevated", "Select", "Field", "Text", "SubText", "Muted" }) do
		if t[k] then Theme[k] = t[k] end
	end
	applyThemeRegistry() -- direct role -> instance replay; safe to call back-to-back as many times as you want
	return self
end
-- animated rainbow accent (opt-in). UI:RainbowAccent(true) / UI:RainbowAccent(false)
function RayVinzUI:RainbowAccent(enable, speed)
	if self._rainbow then pcall(function() self._rainbow:Disconnect() end); self._rainbow = nil end
	if enable == false then return self end
	speed = speed or 0.012 -- hue step per 0.1s (~8s per full cycle); pass a bigger number for faster
	local hue, acc = 0, 0
	local track = self._track or function(c) return c end
	self._rainbow = track(game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc < 0.1 then return end
		acc = 0; hue = (hue + speed) % 1
		self:SetAccent(Color3.fromHSV(hue, 0.7, 1), Color3.fromHSV((hue + 0.08) % 1, 0.7, 1))
	end))
	return self
end
-- one-shot changelog dialog: UI:Changelog({ Title=, Version=, Changes = { "line", ... } })
function RayVinzUI:Changelog(o)
	o = o or {}
	local body = type(o.Changes) == "table" and ("• " .. table.concat(o.Changes, "\n• ")) or tostring(o.Content or o.Changes or "")
	return self:Dialog({
		Title = (o.Title or "What's New") .. (o.Version and ("  " .. o.Version) or ""),
		Content = body,
		Buttons = { { Title = "Got it", Variant = "Primary" } },
	})
end

-- ================= Hub folder (configs + saved key) =================
-- Every file the library writes goes in workspace/<HubFolder>/. Set it with
-- CreateWindow({ Folder = "MyHub" }), KeySystem({ Folder = "MyHub" }) or UI:SetFolder("MyHub").
local HubFolder = "RayVinz"
local function ensureFolder()
	if makefolder and isfolder and not isfolder(HubFolder) then makefolder(HubFolder) end
end
function RayVinzUI:SetFolder(name)
	name = tostring(name or ""):gsub('[\\/:*?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name ~= "" then HubFolder = name end
	pcall(ensureFolder)
	return self
end
function RayVinzUI:GetFolder() return HubFolder end

-- ================= Config (save / load element values by Flag) =================
-- Give elements a Flag = "unique_name", then UI:SaveConfig() / UI:LoadConfig()
function RayVinzUI:SaveConfig(name)
	name = name or self:GetAutoLoadConfig() or self._configName or "default" -- auto-save writes to the auto-load config
	if type(writefile) ~= "function" then return false, "executor has no writefile" end
	local data = {}
	for flag, e in pairs(self._flags or ActiveFlags or {}) do
		local ok, v = pcall(e.ctl.Get)
		if ok then
			if e.kind == "keybind" then v = v and v.Name
			elseif e.kind == "color" and v then v = { R = v.R, G = v.G, B = v.B } end
			data[flag] = v
		end
	end
	local ok = pcall(function()
		ensureFolder()
		writefile(HubFolder .. "/" .. name .. ".json", game:GetService("HttpService"):JSONEncode(data))
	end)
	return ok
end
function RayVinzUI:LoadConfig(name)
	name = name or self:GetAutoLoadConfig() or self._configName or "default"
	self._loading = true -- suppress auto-save while applying values (so it can't overwrite with defaults)
	task.delay(0.8, function() self._loading = false end)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
	local path = HubFolder .. "/" .. name .. ".json"
	if not isfile(path) then return false end
	local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(readfile(path)) end)
	if not ok or type(data) ~= "table" then return false end
	for flag, v in pairs(data) do
		local e = (self._flags or ActiveFlags or {})[flag]
		if e then
			if e.kind == "keybind" then pcall(function() e.ctl.Set(Enum.KeyCode[v]) end)
			elseif e.kind == "color" and type(v) == "table" then pcall(function() e.ctl.Set(Color3.new(v.R, v.G, v.B)) end)
			else pcall(function() e.ctl.Set(v) end) end
		end
	end
	return true
end
-- list saved config names (files in the hub folder)
function RayVinzUI:ListConfigs()
	local out = {}
	pcall(function()
		if type(listfiles) == "function" and isfolder and isfolder(HubFolder) then
			for _, f in ipairs(listfiles(HubFolder)) do
				local nm = tostring(f):match("([^/\\]+)%.json$")
				if nm and nm ~= "_autoload" then table.insert(out, nm) end
			end
		end
	end)
	return out
end
function RayVinzUI:DeleteConfig(name)
	if not name or name == "" then return false end
	return (pcall(function() if delfile and isfile and isfile(HubFolder .. "/" .. name .. ".json") then delfile(HubFolder .. "/" .. name .. ".json") end end))
end
function RayVinzUI:SetAutoLoadConfig(name)
	pcall(function()
		ensureFolder()
		if name and name ~= "" and type(writefile) == "function" then writefile(HubFolder .. "/_autoload.txt", name)
		elseif delfile and isfile and isfile(HubFolder .. "/_autoload.txt") then delfile(HubFolder .. "/_autoload.txt") end
	end)
	return self
end
function RayVinzUI:GetAutoLoadConfig()
	local name
	pcall(function() if isfile and isfile(HubFolder .. "/_autoload.txt") and readfile then name = readfile(HubFolder .. "/_autoload.txt") end end)
	if name == "" then name = nil end
	return name
end

-- ================= Window control: Toggle / Unload =================
function RayVinzUI:Toggle(show)
	if show == nil then show = not (self.Window and self.Window.Visible) end
	if show then if self._show then self._show(true) end else if self._hide then self._hide() end end
	return self
end
-- fully remove the UI: disconnect tracked connections, destroy GUI + blur (no leaks on re-run)
function RayVinzUI:Unload()
	for _, c in ipairs(self._conns or {}) do pcall(function() c:Disconnect() end) end
	self._conns = {}
	-- destroyed descendants keep their Parent, so drop the theme bindings explicitly
	table.clear(ThemeRegistry); table.clear(ThemeGradients)
	if self._blur then pcall(function() self._blur:Destroy() end) end
	pcall(function() if self.Gui then self.Gui:Destroy() end end)
	pcall(function()
		for _, e in ipairs(game:GetService("Lighting"):GetChildren()) do if e.Name == "RayVinzBlur" then e:Destroy() end end
	end)
end

-- Window:SetBlur(false) / SetBlur(true) / SetBlur(12): change the background blur live
function RayVinzUI:SetBlur(v)
	self._blurSize = v == false and 0 or (type(v) == "number" and v or 24)
	if self._blur and self.Window and self.Window.Visible then tween(self._blur, 0.25, { Size = self._blurSize }) end
	return self
end

-- ================= Anti-AFK / reopen after teleport =================
-- UI:AntiAFK(true) stops the 20-minute idle kick; UI:AntiAFK(false) turns it off
function RayVinzUI:AntiAFK(enable)
	if self._antiAfk then pcall(function() self._antiAfk:Disconnect() end); self._antiAfk = nil end
	if enable == false then return self end
	local vu = game:GetService("VirtualUser")
	local track = self._track or function(c) return c end
	self._antiAfk = track(LocalPlayer.Idled:Connect(function()
		pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
	end))
	return self
end
-- Runs `code` again in the next server after a teleport / in-game rejoin (needs queue_on_teleport).
-- A full leave + join from the website starts a new client, which only an autoexec folder covers.
function RayVinzUI:ReExecuteOnTeleport(code)
	local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	if type(code) ~= "string" or code == "" or not queue then return false end
	local queued = false
	local track = self._track or function(c) return c end
	track(LocalPlayer.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Started and not queued then
			queued = true
			pcall(queue, code)
		end
	end))
	return true
end

-- ================= Key System =================
-- Glass key gate shown before the hub. Yields until the user is done; returns true when a
-- key was accepted, false if they closed it.
--   local ok = UI:KeySystem({
--       Title = "RayVinz Hub", SubTitle = "Key System", Logo = "rbxassetid://...",
--       Verify = function(key) return key == "abc" end, -- or Keys = { "abc", "def" }
--       KeyLink = "https://your.site/getkey",           -- "Get a key" copies this
--       SupportedGames = { [1234567] = true },          -- optional, by PlaceId
--       Links = { { Title = "Discord", Content = "discord.gg/xxx", Icon = "message-circle" } },
--       SaveKey = true,                                 -- remember a working key
--       Folder = "MyHub", FileName = "key",             -- saves to workspace/MyHub/key.txt
--       API = {                                         -- or let a key service check it:
--           { Type = "luarmor", ScriptId = "...", KeyLink = "https://...", LoadScript = true },
--           { Type = "luaprot", ScriptId = "...", KeyLink = "https://luaprot.net/ad/...", LoadScript = true },
--           { Type = "pandadevelopment", ServiceId = "..." },
--           { Type = "junkiedevelopment", ServiceId = "...", ApiKey = "...", Provider = "..." },
--           { Type = "custom", Name = "LuaProt", Verify = function(key) ... end, Link = "https://..." },
--       },
--   })
--   if not ok then return end

-- Key services. Each returns { Name, Verify(key) -> valid, message, Link() -> url, OnValid(key)? }
local KeyServices = {}
local function hwid()
	local ok, h = pcall(function() return gethwid and gethwid() end)
	return tostring((ok and h) or LocalPlayer.UserId)
end
KeyServices.luarmor = function(cfg)
	local api = loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
	api.script_id = cfg.ScriptId
	return {
		Name = "Luarmor",
		Verify = function(key)
			local res = api.check_key(key)
			if res.code == "KEY_VALID" then return true, "Whitelisted!" end
			if res.code == "KEY_HWID_LOCKED" then return false, "Key is linked to another device" end
			if res.code == "KEY_INCORRECT" or res.code == "KEY_INVALID" then return false, "Key is wrong or deleted" end
			return false, tostring(res.message or res.code)
		end,
		Link = function() return cfg.KeyLink or cfg.Discord end,
		-- Luarmor reads the key from the script_key global
		OnValid = function(key)
			script_key = key
			pcall(function() getgenv().script_key = key end)
			if cfg.LoadScript then api.load_script() end
		end,
	}
end
KeyServices.pandadevelopment = function(cfg)
	local http = game:GetService("HttpService")
	local req = request or http_request or (syn and syn.request)
	local service = http:UrlEncode(tostring(cfg.ServiceId))
	return {
		Name = "Panda Development",
		Verify = function(key)
			if not req then return false, "Your executor has no request()" end
			local ok, res = pcall(req, { Url = "https://pandadevelopment.net/v2_validation?key=" .. http:UrlEncode(key) .. "&service=" .. service .. "&hwid=" .. http:UrlEncode(hwid()), Method = "GET" })
			if not ok or not res or not res.Success then return false, "Couldn't reach Panda" end
			local ok2, data = pcall(function() return http:JSONDecode(res.Body) end)
			if not ok2 or type(data) ~= "table" then return false, "Bad response from Panda" end
			if data.V2_Authentication == "success" then return true, "Authenticated" end
			return false, (data.Key_Information and data.Key_Information.Notes) or "Invalid key"
		end,
		Link = function() return "https://pandadevelopment.net/getkey?service=" .. service .. "&hwid=" .. http:UrlEncode(hwid()) end,
	}
end
-- LuaProt key-check SDK (docs.luaprot.net -> Key Check Library). checkKey binds an unassigned key
-- to the current HWID. ScriptId must be a string: 20-digit ids don't fit in a Lua number.
KeyServices.luaprot = function(cfg)
	if type(cfg.ScriptId) ~= "string" then error("LuaProt ScriptId must be a string in quotes") end
	local sdk = loadstring(game:HttpGet("https://sdk.luaprot.net/"))()
	sdk.scriptId = cfg.ScriptId
	return {
		Name = "LuaProt",
		Verify = function(key)
			local res = sdk:checkKey(key)
			if type(res) ~= "table" then return false, "No response from LuaProt" end
			if res.status == "VALID" then return true, "Key valid" end
			return false, tostring(res.message or res.status)
		end,
		Link = function() return cfg.KeyLink end,
		OnValid = function() if cfg.LoadScript then sdk:loadScript() end end,
	}
end
-- Junkie's own SDK must be loaded first; it provides the JunkieProtected global
KeyServices.junkiedevelopment = function(cfg)
	local jp = JunkieProtected or (getgenv and getgenv().JunkieProtected)
	if not jp then error("load the Junkie SDK before KeySystem") end
	jp.API_KEY, jp.PROVIDER, jp.SERVICE_ID = cfg.ApiKey, cfg.Provider, cfg.ServiceId
	return {
		Name = "Junkie Development",
		Verify = function(key)
			local kl = jp.IsKeylessMode and jp.IsKeylessMode()
			if kl and kl.keyless_mode then return true, "Keyless mode" end
			if jp.ValidateKey({ Key = key }) == "valid" then return true, "Key is valid!" end
			return false, "Invalid key"
		end,
		Link = function() return jp.GetKeyLink() end,
	}
end
KeyServices.custom = function(cfg)
	return {
		Name = cfg.Name or cfg.Title or "Key",
		Verify = cfg.Verify,
		Link = function() if type(cfg.Link) == "function" then return cfg.Link() end return cfg.Link end,
		OnValid = cfg.OnValid,
	}
end

function RayVinzUI:KeySystem(o)
	o = o or {}
	if o.Folder then RayVinzUI.SetFolder(self, o.Folder) end
	-- key file: <Folder>/<FileName>.txt. A FileName containing "/" is used as a full path.
	local fname = o.FileName or "key"
	local saveFile = (string.find(fname, "/", 1, true) and fname or (HubFolder .. "/" .. fname)) .. ".txt"
	local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
	local services = {}
	for _, cfg in ipairs(o.API or {}) do
		local make = KeyServices[string.lower(tostring(cfg.Type or "custom"))]
		if not make then
			warn("[RayVinzUI] unknown key service type: " .. tostring(cfg.Type))
		else
			local ok, svc = pcall(make, cfg)
			if ok and svc then svc.cfg = cfg; table.insert(services, svc)
			else warn("[RayVinzUI] key service '" .. tostring(cfg.Type) .. "' failed to start: " .. tostring(svc)) end
		end
	end
	-- returns valid, message, service. Verify may return (valid, message); message goes to Status
	local function check(key)
		if key == "" then return false, "Enter a key" end
		if #services > 0 then
			local lastMsg
			for _, svc in ipairs(services) do
				local ok, valid, msg = pcall(svc.Verify, key)
				if ok and valid then return true, msg, svc end
				lastMsg = ok and msg or "Check failed"
			end
			return false, lastMsg
		end
		if o.Verify then
			local ok, valid, msg = pcall(o.Verify, key)
			if not ok then return false, "Check failed" end
			return valid and true or false, msg
		end
		if o.Keys then for _, k in ipairs(o.Keys) do if k == key then return true end end end
		return false
	end
	local function accepted(key, svc)
		if svc and svc.OnValid then task.spawn(svc.OnValid, key) end
		if o.OnSuccess then task.spawn(o.OnSuccess, key) end
	end
	if o.SaveKey and isfile and readfile then
		local ok, saved = pcall(function() return isfile(saveFile) and readfile(saveFile) or nil end)
		if ok and saved then
			local valid, _, svc = check(trim(saved))
			if valid then accepted(trim(saved), svc) return true end
		end
	end

	pcall(function()
		for _, p in ipairs({ guiParent() }) do local old = p:FindFirstChild("RayVinzKey") if old then old:Destroy() end end
	end)
	local gui = new("ScreenGui", { Name = "RayVinzKey", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 100 }, guiParent())
	local blur
	if o.Blur ~= false then
		pcall(function() blur = new("BlurEffect", { Name = "RayVinzBlur", Size = 0 }, game:GetService("Lighting")) end)
		if blur then tween(blur, 0.3, { Size = type(o.Blur) == "number" and o.Blur or 20 }) end
	end

	local W, H = 640, 340
	local holder = new("Frame", { Size = UDim2.fromOffset(math.floor(W * 0.94), math.floor(H * 0.94)), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, gui)
	local uiScale = new("UIScale", { Scale = 1 }, holder)
	pcall(function() local vp = workspace.CurrentCamera.ViewportSize uiScale.Scale = clamp(math.min(1, (vp.X - 24) / W, (vp.Y - 24) / H), 0.45, 1) end)
	local sh = shadow(holder, 1, 60)
	local card = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.18, GroupTransparency = 1 }, holder)
	corner(card, 18); stroke(card, Theme.White, 0.75, 1.2); glassSheen(card, 18, 1)
	-- soft accent light from the bottom-left corner (a gradient, no image asset to show hard edges)
	local glowF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, card); corner(glowF, 18)
	new("UIGradient", { Rotation = -45, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.3, 0.95), NumberSequenceKeypoint.new(1, 1) }) }, glowF)

	local function button(parent, text, icon, primary, pos, size)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Position = pos, Size = size, BackgroundColor3 = primary and Theme.Accent or Theme.Field, BackgroundTransparency = primary and 0.05 or 0.4 }, parent)
		corner(b, 12); stroke(b, Theme.White, primary and 0.8 or 0.86, 1)
		local col = primary and Theme.AccentText or Theme.Text
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0) }, b)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
		local ic = iconImage(row, icon, UDim2.fromOffset(16, 16), col); ic.LayoutOrder = 1
		local lb = ltext(row, text, 14, col, FM); lb.LayoutOrder = 2; lb.Size = UDim2.fromOffset(0, 20); lb.AutomaticSize = Enum.AutomaticSize.X
		local base = b.BackgroundTransparency
		b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundTransparency = math.max(base - 0.15, 0) }) end)
		b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundTransparency = base }) end)
		return b, lb
	end

	-- ---------- left column ----------
	local left = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 24), Size = UDim2.new(0, 330, 1, -48) }, card)
	local brand = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48) }, left)
	local logo = o.Logo or "sparkles"
	local logoIsImage = type(logo) == "number" or (type(logo) == "string" and string.find(logo, "rbxassetid://") == 1)
	iconImage(brand, logo, UDim2.fromOffset(44, 44), logoIsImage and Theme.White or Theme.Accent, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
	local tl = ltext(brand, o.Title or "RayVinz Hub", 22, Theme.Text, FB); tl.Position = UDim2.fromOffset(56, 0); tl.Size = UDim2.new(1, -56, 0, 26)
	local st = ltext(brand, o.SubTitle or "Key System", 13, Theme.SubText, F); st.Position = UDim2.fromOffset(56, 27); st.Size = UDim2.new(1, -56, 0, 18)
	draggable(brand, holder)

	local kl = ltext(left, "License key", 12, Theme.SubText, F); kl.Position = UDim2.fromOffset(0, 80); kl.Size = UDim2.new(1, 0, 0, 16)
	local field = new("Frame", { Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.45 }, left)
	corner(field, 12); local fieldStroke = stroke(field, Theme.White, 0.82, 1)
	iconImage(field, "key-round", UDim2.fromOffset(18, 18), Theme.SubText, UDim2.new(0, 16, 0.5, 0), Vector2.new(0, 0.5))
	local box = new("TextBox", { BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -58, 1, 0), Text = "", PlaceholderText = o.Placeholder or "Paste your key here",
		PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = F, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd }, field)
	box.Focused:Connect(function() tween(fieldStroke, 0.15, { Color = Theme.Accent, Transparency = 0.3 }) end)
	box.FocusLost:Connect(function() tween(fieldStroke, 0.15, { Color = Theme.White, Transparency = 0.82 }) end)

	local submitBtn, submitTxt = button(left, "Submit", "arrow-right", true, UDim2.fromOffset(0, 164), UDim2.new(0.5, -6, 0, 46))
	local getBtn, getTxt = button(left, o.GetKeyText or "Get a key", "globe", false, UDim2.new(0.5, 6, 0, 164), UDim2.new(0.5, -6, 0, 46))

	local welcome = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, 44) }, left)
	local av = new("ImageLabel", { Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.3 }, welcome); corner(av, 22); stroke(av, Theme.Accent, 0.35, 1.5)
	task.spawn(function()
		local ok, img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
		if ok and img then av.Image = img end
	end)
	local wb = ltext(welcome, "Welcome Back", 12, Theme.SubText, F); wb.Position = UDim2.fromOffset(56, 4); wb.Size = UDim2.new(1, -56, 0, 16)
	local wn = ltext(welcome, (LocalPlayer and LocalPlayer.DisplayName or "Player") .. "!", 15, Theme.Text, FB); wn.Position = UDim2.fromOffset(56, 21); wn.Size = UDim2.new(1, -56, 0, 20)

	new("Frame", { Position = UDim2.fromOffset(376, 24), Size = UDim2.new(0, 1, 1, -48), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, card)

	-- ---------- right column ----------
	local right = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(396, 22), Size = UDim2.new(0, 220, 1, -44) }, card)
	local dg = ltext(right, "Detected game", 12, Theme.SubText, F); dg.Position = UDim2.fromOffset(0, 6); dg.Size = UDim2.new(1, -64, 0, 16)
	local closeB = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, 0, 0, 2), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1 }, right)
	iconImage(closeB, "x", UDim2.fromOffset(16, 16), Theme.SubText, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local moonB = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -32, 0, 2), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1 }, right)
	iconImage(moonB, "moon", UDim2.fromOffset(16, 16), Theme.SubText, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))

	local gcard = new("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.45 }, right)
	corner(gcard, 14); stroke(gcard, Theme.White, 0.86, 1)
	local thumb = new("ImageLabel", { Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Field, BackgroundTransparency = 0.2, ScaleType = Enum.ScaleType.Crop }, gcard); corner(thumb, 10)
	local gname = ltext(gcard, "Unknown game", 14, Theme.Text, FB); gname.Position = UDim2.fromOffset(70, 14); gname.Size = UDim2.new(1, -80, 0, 18)
	local supported = o.SupportedGames == nil or o.SupportedGames[game.PlaceId] == true
	local gstat = ltext(gcard, o.SupportedGames == nil and "Detected" or (supported and "Supported" or "Not in our list"), 12, supported and Theme.Green or Theme.SubText, F)
	gstat.Position = UDim2.fromOffset(70, 36); gstat.Size = UDim2.new(1, -80, 0, 16)
	task.spawn(function()
		local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
		if ok and type(info) == "table" then
			if info.Name then gname.Text = info.Name end
			if info.IconImageAssetId and info.IconImageAssetId ~= 0 then thumb.Image = "rbxassetid://" .. info.IconImageAssetId end
		end
	end)

	local function infoRow(y, label, value, color)
		local l = ltext(right, label, 12, Theme.SubText, F); l.Position = UDim2.fromOffset(0, y); l.Size = UDim2.new(0.5, 0, 0, 18)
		local v = ltext(right, value, 12, color or Theme.Text, FM, Enum.TextXAlignment.Right); v.Position = UDim2.new(0.5, 0, 0, y); v.Size = UDim2.new(0.5, 0, 0, 18)
		return v
	end
	local exec = "Unknown"
	pcall(function() if identifyexecutor then exec = tostring((identifyexecutor())) end end)
	infoRow(112, "Executor", exec)
	local statusVal = infoRow(136, "Status", "Key required", Theme.Warning)
	new("Frame", { Position = UDim2.fromOffset(0, 164), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, right)

	local links = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 176), Size = UDim2.new(1, 0, 1, -176), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, right)
	vlist(links, 8)
	-- one card per key service (copies that service's get-key link), then the user's own links
	local cards = {}
	for _, svc in ipairs(services) do
		table.insert(cards, { Title = svc.cfg.Title or svc.Name, Content = svc.cfg.Desc or "Click to copy key link", Icon = svc.cfg.Icon or "key-round", GetLink = svc.Link })
	end
	for _, lk in ipairs(o.Links or {}) do table.insert(cards, lk) end
	for i, lk in ipairs(cards) do
		local lc = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.45, LayoutOrder = i }, links)
		corner(lc, 12); stroke(lc, Theme.White, 0.88, 1)
		iconImage(lc, lk.Icon or "link", UDim2.fromOffset(20, 20), Theme.Accent, UDim2.new(0, 14, 0.5, 0), Vector2.new(0, 0.5))
		local lt = ltext(lc, lk.Title or "Link", 13, Theme.Text, FB); lt.Position = UDim2.fromOffset(48, 9); lt.Size = UDim2.new(1, -58, 0, 17)
		local ls = ltext(lc, lk.Content or "", 11, Theme.SubText, F); ls.Position = UDim2.fromOffset(48, 27); ls.Size = UDim2.new(1, -58, 0, 15)
		lc.MouseEnter:Connect(function() tween(lc, 0.12, { BackgroundTransparency = 0.25 }) end)
		lc.MouseLeave:Connect(function() tween(lc, 0.12, { BackgroundTransparency = 0.45 }) end)
		lc.MouseButton1Click:Connect(function()
			pcall(function()
				local link = lk.GetLink and lk.GetLink() or lk.Url or lk.Content
				if link then setclipboard(tostring(link)) end
			end)
			if lk.Callback then task.spawn(lk.Callback) end
			ls.Text = "Copied to clipboard!"
			task.delay(1.4, function() ls.Text = lk.Content or "" end)
		end)
	end

	-- ---------- behaviour ----------
	local result = nil
	local acceptedKey, acceptedSvc
	local done = Instance.new("BindableEvent")
	local function close(ok)
		if result ~= nil then return end
		result = ok
		if blur then tween(blur, 0.25, { Size = 0 }) end
		tween(card, 0.25, { GroupTransparency = 1 }); tween(sh, 0.25, { ImageTransparency = 1 })
		tween(holder, 0.25, { Size = UDim2.fromOffset(math.floor(W * 0.94), math.floor(H * 0.94)) })
		task.delay(0.28, function()
			pcall(function() gui:Destroy() end)
			pcall(function() if blur then blur:Destroy() end end)
			done:Fire()
		end)
	end
	local function shake()
		local base = holder.Position
		task.spawn(function()
			for _, x in ipairs({ -10, 9, -6, 4, 0 }) do
				tween(holder, 0.05, { Position = UDim2.new(base.X.Scale, base.X.Offset + x, base.Y.Scale, base.Y.Offset) })
				task.wait(0.05)
			end
		end)
	end
	local busy = false
	local function submit()
		if busy or result ~= nil then return end
		local key = trim(box.Text)
		busy = true; submitTxt.Text = "Checking..."
		statusVal.Text = "Checking..."; statusVal.TextColor3 = Theme.SubText
		local ok, msg, svc = check(key)
		busy = false; submitTxt.Text = "Submit"
		if ok then
			statusVal.Text = msg or "Key valid"; statusVal.TextColor3 = Theme.Green
			tween(fieldStroke, 0.2, { Color = Theme.Green, Transparency = 0.2 })
			if o.SaveKey and writefile then
				pcall(function()
					local dir = saveFile:match("^(.*)/[^/]*$")
					if dir and makefolder and isfolder and not isfolder(dir) then makefolder(dir) end
					writefile(saveFile, key)
				end)
			end
			acceptedKey, acceptedSvc = key, svc
			task.delay(0.6, function() close(true) end)
		else
			statusVal.Text = msg or "Invalid key"; statusVal.TextColor3 = Theme.Error
			tween(fieldStroke, 0.2, { Color = Theme.Error, Transparency = 0.2 })
			shake()
			task.delay(1.2, function() if result == nil then tween(fieldStroke, 0.3, { Color = Theme.White, Transparency = 0.82 }) end end)
		end
	end
	submitBtn.MouseButton1Click:Connect(function() task.spawn(submit) end)
	box.FocusLost:Connect(function(enter) if enter then task.spawn(submit) end end)
	getBtn.MouseButton1Click:Connect(function()
		pcall(function()
			local link
			if o.KeyLink then link = type(o.KeyLink) == "function" and o.KeyLink() or o.KeyLink
			elseif services[1] then link = services[1].Link() end
			if link then setclipboard(tostring(link)) end
		end)
		if o.OnGetKey then task.spawn(o.OnGetKey) end
		getTxt.Text = "Link copied!"
		task.delay(1.5, function() getTxt.Text = o.GetKeyText or "Get a key" end)
	end)
	closeB.MouseButton1Click:Connect(function() close(false) end)
	local savedTheme, light = nil, false
	moonB.MouseButton1Click:Connect(function()
		light = not light
		if light then
			savedTheme = {}
			for _, k in ipairs({ "Background", "Sidebar", "Card", "Elevated", "Select", "Field", "Text", "SubText", "Muted" }) do savedTheme[k] = Theme[k] end
			self:SetTheme("Light")
		elseif savedTheme then
			self:SetTheme(savedTheme)
		end
	end)

	tween(holder, 0.34, { Size = UDim2.fromOffset(W, H) })
	tween(card, 0.34, { GroupTransparency = 0 })
	tween(sh, 0.34, { ImageTransparency = 0.5 })

	done.Event:Wait()
	done:Destroy()
	if result == true then accepted(acceptedKey, acceptedSvc) end
	return result == true
end

-- ================= AntiSpy (protect your own script from remote spies / hooks) =================
-- Detects known remote-spy GUIs and common function hooks, then (optionally) kicks the player.
-- o = {
--   Interval    = 1,          -- seconds between scans
--   RemoveGui   = true,       -- destroy known spy GUIs when found
--   Kick        = true,       -- LocalPlayer:Kick(...) when a spy/hook is detected
--   KickMessage = "...",      -- message shown on the kick screen
--   Callback    = function(reasons) end, -- called before kicking
-- }
function RayVinzUI:AntiSpy(o)
	o = o or {}
	local interval = o.Interval or 1
	local removeGui = o.RemoveGui ~= false
	local doKick = o.Kick ~= false
	local doDetectHooks = o.DetectHooks == true -- OFF by default: IY / executors hook metamethods too (false positives)
	local kickMsg = o.KickMessage or "Close your remote spy and rejoin."
	local spyNames = {
		"simplespy", "hydroxide", "remotespy", "remote-spy", "cobalt",
		"utopiaspy", "remotelogger", "octospy", "turtlespy",
	}
	local function isSpyName(name)
		local n = string.lower(name or "")
		for _, s in ipairs(spyNames) do if string.find(n, s, 1, true) then return true end end
		return false
	end
	-- title signatures UNIQUE to spies (verified NOT present in Infinite Yield's command
	-- list, so these can't false-positive on IY like "simplespy"/"remotespy"/"cobalt" would)
	local spyTitles = { "octo~spy", "turtle spy", "hydroxide", "utopia spy" }
	local function hasSpyText(gui)
		local hit, count = false, 0
		pcall(function()
			for _, d in ipairs(gui:GetDescendants()) do
				count = count + 1
				if count > 700 then return end -- don't crawl huge core GUIs
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					local t = string.lower(d.Text or "")
					for _, s in ipairs(spyTitles) do if string.find(t, s, 1, true) then hit = true return end end
				end
			end
		end)
		return hit
	end
	local function consider(g, found)
		if g.Name == "RayVinzUI" then return found end
		if string.find(string.lower(g.Name), "roblox", 1, true) then return found end -- skip Roblox core GUIs
		if isSpyName(g.Name) or hasSpyText(g) then
			if removeGui then pcall(function() g:Destroy() end) end
			return true
		end
		return found
	end
	local function scanSpyGuis()
		local found = false
		local spots = {}
		pcall(function() table.insert(spots, gethui()) end)
		pcall(function() table.insert(spots, game:GetService("CoreGui")) end)
		pcall(function() table.insert(spots, LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)
		for _, p in ipairs(spots) do
			if p then
				local ok, kids = pcall(function() return p:GetChildren() end)
				if ok then for _, g in ipairs(kids) do found = consider(g, found) end end
			end
		end
		-- hidden / protected GUIs (e.g. Turtle Spy) parented to nil
		pcall(function()
			if type(getnilinstances) == "function" then
				for _, inst in ipairs(getnilinstances()) do
					local ok, cls = pcall(function() return inst.ClassName end)
					if ok and cls == "ScreenGui" then found = consider(inst, found) end
				end
			end
		end)
		return found
	end
	local function detectHooks()
		local reasons = {}
		if type(iscclosure) ~= "function" then return reasons end -- executor can't tell -> skip
		local ok, nc = pcall(function() return getrawmetatable(game).__namecall end)
		if ok and nc and not iscclosure(nc) then table.insert(reasons, "__namecall hooked") end
		local ok2, fs = pcall(function() return Instance.new("RemoteEvent").FireServer end)
		if ok2 and fs and not iscclosure(fs) then table.insert(reasons, "FireServer hooked") end
		local ok3, idx = pcall(function() return getrawmetatable(game).__index end)
		if ok3 and idx and not iscclosure(idx) then table.insert(reasons, "__index hooked") end
		return reasons
	end
	-- Roblox's kick screen always shows "Disconnected" plus a moderator line before our text.
	-- Executors can reach CoreGui, so rewrite its labels to show only our title + message.
	-- o.KickTitle = false keeps Roblox's normal screen.
	local function restyleKickScreen()
		if o.KickTitle == false then return end
		local title = o.KickTitle or "Remote Spy Detected"
		task.spawn(function()
			local ok, prompt = pcall(function()
				return game:GetService("CoreGui"):WaitForChild("RobloxPromptGui", 5):WaitForChild("promptOverlay", 5):WaitForChild("ErrorPrompt", 5)
			end)
			if not ok or not prompt then return end
			-- Roblox can set the text a moment after the prompt appears, so apply it a few times
			for _ = 1, 20 do
				pcall(function()
					for _, d in ipairs(prompt:GetDescendants()) do
						if d:IsA("TextLabel") then
							if d.Name == "ErrorTitle" then d.Text = title
							elseif d.Name == "ErrorMessage" then d.Text = kickMsg end
						end
					end
				end)
				task.wait(0.1)
			end
		end)
	end
	local function react(reasons)
		pcall(function() warn("[RayVinz] spy detected: " .. table.concat(reasons, ", ")) end)
		if o.Callback then pcall(o.Callback, reasons) end
		if doKick then
			pcall(function() LocalPlayer:Kick(kickMsg) end)
			restyleKickScreen()
		end
	end
	pcall(function() warn("[RayVinz] AntiSpy active (kick=" .. tostring(doKick) .. ", hooks=" .. tostring(doDetectHooks) .. ")") end)
	task.spawn(function()
		while true do
			local reasons = doDetectHooks and detectHooks() or {}
			if scanSpyGuis() then table.insert(reasons, "remote spy GUI found") end
			if #reasons > 0 then react(reasons) if doKick then break end end
			task.wait(interval)
		end
	end)
	return { Scan = function() local r = detectHooks(); if scanSpyGuis() then table.insert(r, "remote spy GUI found") end return r end }
end

-- ================= Error Inspector =================
-- Any element callback that errors shows a red toast with the message instead of failing silently.
function RayVinzUI:_reportError(where, err)
	local now = os.clock()
	self._errLast = self._errLast or {}
	if self._errLast[where] and now - self._errLast[where] < 2 then return end -- throttle spam
	self._errLast[where] = now
	local msg = tostring(err):gsub("^.-:%d+:%s*", "")
	self:Notify({ Title = "Error in " .. tostring(where), Content = msg, Type = "Error", Icon = "alert-octagon", Duration = 6 })
end

-- ================= Undo / Redo (Ctrl+Z / Ctrl+Y) =================
function RayVinzUI:_ensureHistoryKeys()
	if self._histKeys then return end
	self._histKeys = true
	local trk = self._track or function(c) return c end
	trk(UserInputService.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		local ctrl = false
		pcall(function() ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta) or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta) end)
		if not ctrl then return end
		if inp.KeyCode == Enum.KeyCode.Z then self:Undo()
		elseif inp.KeyCode == Enum.KeyCode.Y then self:Redo() end
	end))
end
function RayVinzUI:_pushHistory(entry, newVal)
	if self._loading or not entry or entry.kind == "keybind" then return end
	self._undo = self._undo or {}; self._redo = {}
	table.insert(self._undo, { entry = entry, old = entry.value, new = newVal })
	if #self._undo > 60 then table.remove(self._undo, 1) end
	entry.value = newVal
	self:_ensureHistoryKeys()
end
function RayVinzUI:Undo()
	local u = self._undo and self._undo[#self._undo]; if not u then return end
	table.remove(self._undo)
	self._applyingHistory = true; pcall(function() u.entry.ctl.Set(u.old) end); u.entry.value = u.old; self._applyingHistory = false
	self._redo = self._redo or {}; table.insert(self._redo, u)
	self:Notify({ Title = "Undo", Content = u.entry.title or "", Type = "Info", Icon = "rotate-ccw", Duration = 1.5 })
	return self
end
function RayVinzUI:Redo()
	local r = self._redo and self._redo[#self._redo]; if not r then return end
	table.remove(self._redo)
	self._applyingHistory = true; pcall(function() r.entry.ctl.Set(r.new) end); r.entry.value = r.new; self._applyingHistory = false
	self._undo = self._undo or {}; table.insert(self._undo, r)
	return self
end

-- ================= Reduce Motion / Performance Guard =================
-- ReduceMotion(true) makes every animation instant (accessibility / low-end devices).
function RayVinzUI:ReduceMotion(on) MotionScale = (on == false) and 1 or 0; return self end
-- PerformanceGuard watches FPS; below MinFPS it pauses animations + blur, and restores on recovery.
function RayVinzUI:PerformanceGuard(o)
	if self._perfGuard then pcall(function() self._perfGuard:Disconnect() end); self._perfGuard = nil end
	if o == false then MotionScale = 1; return self end
	o = o or {}
	local threshold = o.MinFPS or 30
	local trk = self._track or function(c) return c end
	local acc, frames, low = 0, 0, false
	self._perfGuard = trk(game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc = acc + dt; frames = frames + 1
		if acc < 1 then return end
		local fps = frames / math.max(acc, 0.001); acc, frames = 0, 0
		if fps < threshold and not low then
			low = true; if self._pgBlur == nil then self._pgBlur = self._blurSize end
			MotionScale = 0; pcall(function() self:SetBlur(false) end)
		elseif fps >= threshold + 10 and low then
			low = false; MotionScale = 1; pcall(function() self:SetBlur(self._pgBlur or 24) end)
		end
	end))
	return self
end

-- ================= Theme editor helpers / shareable codes =================
function RayVinzUI:AddTheme(name, tbl) if type(name) == "string" and type(tbl) == "table" then RayVinzUI.ThemePresets[name] = tbl end return self end
function RayVinzUI:GetThemeCode()
	local function hex(c) return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
	local t = {}
	for _, k in ipairs({ "Background", "Sidebar", "Card", "Elevated", "Select", "Field", "Text", "SubText", "Accent", "Accent2" }) do if Theme[k] then t[k] = hex(Theme[k]) end end
	local ok, code = pcall(function() return b64encode(game:GetService("HttpService"):JSONEncode(t)) end)
	return ok and code or ""
end
function RayVinzUI:LoadThemeCode(code)
	local ok, raw = pcall(function() return game:GetService("HttpService"):JSONDecode(b64decode(code)) end)
	if not ok or type(raw) ~= "table" then return false end
	local function col(h) return Color3.fromRGB(tonumber(h:sub(1, 2), 16) or 0, tonumber(h:sub(3, 4), 16) or 0, tonumber(h:sub(5, 6), 16) or 0) end
	local th = {}
	for k, v in pairs(raw) do if k ~= "Accent" and k ~= "Accent2" then th[k] = col(v) end end
	self:SetTheme(th)
	if raw.Accent then self:SetAccent(col(raw.Accent), raw.Accent2 and col(raw.Accent2) or nil) end
	return true
end

-- ================= Shareable config "profile codes" =================
-- GetConfigCode() -> a base64 string of all current element values. LoadConfigCode(code) applies it.
function RayVinzUI:GetConfigCode()
	local data = {}
	for flag, e in pairs(self._flags or ActiveFlags or {}) do
		local ok, v = pcall(e.ctl.Get)
		if ok then
			if e.kind == "keybind" then v = v and v.Name
			elseif e.kind == "color" and v then v = { R = v.R, G = v.G, B = v.B } end
			data[flag] = v
		end
	end
	local ok, code = pcall(function() return b64encode(game:GetService("HttpService"):JSONEncode(data)) end)
	return ok and code or ""
end
function RayVinzUI:LoadConfigCode(code)
	local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(b64decode(code)) end)
	if not ok or type(data) ~= "table" then return false end
	self._loading = true; task.delay(0.8, function() self._loading = false end)
	for flag, v in pairs(data) do
		local e = (self._flags or ActiveFlags or {})[flag]
		if e then
			if e.kind == "keybind" then pcall(function() e.ctl.Set(Enum.KeyCode[v]) end)
			elseif e.kind == "color" and type(v) == "table" then pcall(function() e.ctl.Set(Color3.new(v.R, v.G, v.B)) end)
			else pcall(function() e.ctl.Set(v) end) end
		end
	end
	return true
end

-- ================= Spotlight / Command palette (Ctrl/Cmd+K) =================
-- Register custom actions with UI:Command({ Title=, Description=, Icon=, Callback= }).
function RayVinzUI:Command(o)
	o = o or {}
	self._commands = self._commands or {}
	table.insert(self._commands, { title = o.Title or "Command", desc = o.Description or o.Desc, icon = o.Icon, callback = o.Callback })
	return self
end
function RayVinzUI:_jumpTo(tab, inst)
	self:_select(tab)
	if not inst then return end
	task.defer(function()
		pcall(function()
			local target = tab._page.CanvasPosition.Y + (inst.AbsolutePosition.Y - tab._page.AbsolutePosition.Y) - 60
			tab._page.CanvasPosition = Vector2.new(0, math.max(target, 0))
		end)
		local rowi = inst
		while rowi.Parent and rowi.Parent ~= tab._page do rowi = rowi.Parent end
		if rowi and rowi:IsA("GuiObject") then
			local hl = stroke(rowi, Theme.Accent, 0, 2)
			task.delay(0.05, function() tween(hl, 0.9, { Transparency = 1 }) end)
			task.delay(1, function() pcall(function() hl:Destroy() end) end)
		end
	end)
end
-- Build (once) the Spotlight overlay and bind Ctrl/Cmd+K (+ optional opts.Key). opts.Open opens it now.
function RayVinzUI:Spotlight(opts)
	opts = opts or {}
	if self._spotlight then if opts.Open then self._spotlight.open() end return self._spotlight end
	local gui = self.Gui or ActiveGui
	local overlay = new("Frame", { Name = "Spotlight", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 95 }, gui)
	local bgBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 95 }, overlay)
	local panel = new("Frame", { Size = UDim2.fromOffset(460, 54), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.04, ZIndex = 96 }, overlay); corner(panel, 14); stroke(panel, Theme.White, 0.7, 1.2); glassSheen(panel, 14, 96)
	iconImage(panel, "search", UDim2.fromOffset(18, 18), Theme.SubText, UDim2.new(0, 16, 0.5, 0), Vector2.new(0, 0.5)).ZIndex = 98
	local input = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -56, 1, 0), Position = UDim2.new(0, 44, 0, 0), PlaceholderText = opts.Placeholder or "Search settings & commands…  (e.g. walk speed 50, godmode on)", PlaceholderColor3 = Theme.Muted, Text = "", TextColor3 = Theme.Text, Font = FM, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 98 }, panel)
	local results = new("ScrollingFrame", { Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y, Position = UDim2.new(0.5, 0, 0, 182), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Theme.Elevated, BackgroundTransparency = 0.06, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Muted, CanvasSize = UDim2.new(), Visible = false, ZIndex = 96 }, overlay); corner(results, 12); stroke(results, Theme.White, 0.8, 1); pad(results, 6, 6, 6, 6); vlist(results, 3)
	local items, firstRun = {}, nil
	local function close() overlay.Visible = false; input.Text = ""; firstRun = nil end
	local function open() overlay.Visible = true; results.Visible = false; tween(overlay, 0.15, { BackgroundTransparency = 0.45 }); pcall(function() input:CaptureFocus() end) end
	local function tabOfPage(page) for _, t in ipairs(self._tabs) do if t._page == page then return t end end end
	local function addItem(i, icon, title, sub, run)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 97 }, results); corner(b, 8)
		iconImage(b, icon or "chevron-right", UDim2.fromOffset(15, 15), Theme.SubText, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5)).ZIndex = 98
		local tl = ltext(b, title, 13, Theme.Text, FM); tl.Position = UDim2.new(0, 34, 0, sub and 4 or 0); tl.Size = UDim2.new(1, -44, 0, sub and 16 or 36); tl.ZIndex = 98
		if sub then local sl = ltext(b, sub, 10, Theme.Muted, F); sl.Position = UDim2.new(0, 34, 0, 19); sl.Size = UDim2.new(1, -44, 0, 12); sl.ZIndex = 98 end
		b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.85 end)
		b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
		b.MouseButton1Click:Connect(run)
		table.insert(items, b); return b
	end
	local function refresh()
		for _, it in ipairs(items) do pcall(function() it:Destroy() end) end
		items = {}; firstRun = nil
		local q = string.lower(input.Text):gsub("%s+$", "")
		if q == "" then results.Visible = false; return end
		local base, valTok = q:match("^(.-)%s+([%w%.]+)$")
		local matches = {}
		local function consider(kind, label, data)
			local hay = string.lower(label or "")
			local hit = string.find(hay, q, 1, true)
			local bHit = base and string.find(hay, base, 1, true)
			if hit or bHit then table.insert(matches, { kind = kind, label = label, data = data, rank = hit and 0 or 1 }) end
		end
		for _, c in ipairs(self._commands or {}) do consider("cmd", c.title, c) end
		for _, e in ipairs(self._controls or {}) do if e.title then consider("ctl", e.title, e) end end
		for _, t in ipairs(self._tabs) do consider("tab", t._label.Text, t) end
		table.sort(matches, function(a, b) return a.rank < b.rank end)
		local n = 0
		for _, m in ipairs(matches) do
			n = n + 1; if n > 8 then break end
			local icon, title, sub, run
			if m.kind == "cmd" then
				icon, title, sub = m.data.icon or "terminal", m.data.title, m.data.desc or "Command"
				run = function() close(); if m.data.callback then task.spawn(m.data.callback) end end
			elseif m.kind == "tab" then
				icon, title, sub = "layout-grid", m.label, "Go to tab"
				run = function() close(); self:_select(m.data) end
			else
				local e = m.data; icon, title, sub = "sliders-horizontal", e.title, e.section and ("in " .. e.section) or "Setting"
				run = function()
					close()
					local _, cur = pcall(e.ctl.Get)
					if valTok and e.ctl.Set then
						local num = tonumber(valTok)
						if num ~= nil and type(cur) == "number" then pcall(function() e.ctl.Set(num) end); self:Notify({ Title = e.title, Content = "set to " .. tostring(num), Type = "Success", Icon = "check", Duration = 2 }); return end
						local bv = (valTok == "on" or valTok == "true" or valTok == "yes") and true or ((valTok == "off" or valTok == "false" or valTok == "no") and false or nil)
						if bv ~= nil and type(cur) == "boolean" then pcall(function() e.ctl.Set(bv) end); self:Notify({ Title = e.title, Content = bv and "on" or "off", Type = "Success", Icon = "check", Duration = 2 }); return end
					end
					if type(cur) == "boolean" and e.ctl.Set then
						pcall(function() e.ctl.Set(not cur) end); self:Notify({ Title = e.title, Content = (not cur) and "on" or "off", Type = "Info", Icon = "check", Duration = 2 })
					else
						local tb = tabOfPage(e.page); if tb then self:_jumpTo(tb, e.inst) end
					end
				end
			end
			addItem(n, icon, title, sub, run)
			if not firstRun then firstRun = run end
		end
		results.Visible = n > 0
	end
	input:GetPropertyChangedSignal("Text"):Connect(refresh)
	bgBtn.MouseButton1Click:Connect(close)
	local trk = self._track or function(c) return c end
	trk(UserInputService.InputBegan:Connect(function(inp, gpe)
		if inp.KeyCode == Enum.KeyCode.Escape and overlay.Visible then close(); return end
		if inp.KeyCode == Enum.KeyCode.Return and overlay.Visible and firstRun then firstRun(); return end
		if gpe then return end
		if opts.Key and inp.KeyCode == opts.Key then open(); return end
		local ctrl = false
		pcall(function() ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta) or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta) end)
		if ctrl and inp.KeyCode == Enum.KeyCode.K then open() end
	end))
	self._spotlight = { open = open, close = close, refresh = refresh, instance = overlay }
	if opts.Open then open() end
	return self._spotlight
end

return setmetatable({}, { __index = RayVinzUI })

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
	Background = Color3.fromRGB(28, 28, 30),
	Sidebar    = Color3.fromRGB(36, 36, 39),
	Card       = Color3.fromRGB(44, 44, 46),
	Elevated   = Color3.fromRGB(50, 50, 53),
	Select     = Color3.fromRGB(60, 60, 63),
	Field      = Color3.fromRGB(58, 58, 60),
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

local function new(class, props, parent)
	local i = Instance.new(class)
	if props then for k, v in pairs(props) do i[k] = v end end
	if parent then i.Parent = parent end
	return i
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

local function tween(i, t, props) local tw = TweenService:Create(i, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props) tw:Play() return tw end

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
end

local function shadow(parent, tr, extra)
	return new("ImageLabel", { Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = tr or 0.4, ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450), Size = UDim2.new(1, extra or 90, 1, extra or 90),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 0 }, parent)
end

-- ================= icons =================
local IconPack = nil
local ActiveGui = nil
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
	opts.Logo = opts.Logo or "sparkles" -- default hub icon (needs UI:LoadLucide())
	opts.Version = opts.Version or opts.SubTitle or "v1.0.0"
	-- no Title given -> auto-pull the current game's name
	if not opts.Title then
		local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
		opts.Title = (ok and type(info) == "table" and info.Name) or "RayVinz Hub"
	end
	local self = setmetatable({}, { __index = RayVinzUI }); self._tabs = {}
	cleanupOld() -- destroy any previous RayVinzUI so re-running never stacks windows/buttons
	local gui = new("ScreenGui", { Name = "RayVinzUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true }, guiParent())
	self.Gui = gui; ActiveGui = gui
	local W, H = opts.Width or 660, opts.Height or 460

	-- holder (positioned/dragged) -> shadow + rounded window inside
	local holder = new("Frame", { Name = "Window", Visible = false, Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, gui)
	self.Window = holder
	local sh = shadow(holder, 1, 48)
	-- CanvasGroup lets us fade the whole window (GroupTransparency) in one tween
	local win = new("CanvasGroup", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.06, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 1 }, holder)
	corner(win, 14); stroke(win, Theme.White, 0.9)
	-- smooth open / close / minimize (scale + fade together, from the window's own center)
	local function showWin(animate)
		holder.Visible = true
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
		tween(holder, 0.24, { Size = UDim2.fromOffset(math.floor(W * 0.9), math.floor(H * 0.9)) })
		tween(win, 0.24, { GroupTransparency = 1 })
		tween(sh, 0.24, { ImageTransparency = 1 })
		task.delay(0.26, function() holder.Visible = false end)
	end
	self._show, self._hide = showWin, hideWin

	-- title bar
	local title = new("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, win)
	local lights = new("Frame", { Size = UDim2.fromOffset(52, 14), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, title)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, lights)
	-- maximize toggle (green): swap between normal and a larger size
	local maximized = false
	local function maximize()
		local cam = workspace.CurrentCamera
		local sx = (cam and cam.ViewportSize.X or 1280) * 0.9
		local sy = (cam and cam.ViewportSize.Y or 720) * 0.88
		maximized = not maximized
		W, H = maximized and math.floor(sx) or (opts.Width or 660), maximized and math.floor(sy) or (opts.Height or 460)
		tween(holder, 0.3, { Size = UDim2.fromOffset(W, H) })
	end
	local glyphs = { "x", "minus", "maximize-2" } -- lucide icons: close / minimize / expand
	local marks = {}
	for i, c in ipairs({ Color3.fromRGB(255, 95, 87), Color3.fromRGB(254, 188, 46), Color3.fromRGB(40, 200, 64) }) do
		local d = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(13, 13), BackgroundColor3 = c, LayoutOrder = i }, lights); corner(d, 7)
		local m = iconImage(d, glyphs[i], UDim2.fromOffset(9, 9), Color3.fromRGB(60, 30, 10), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)); m.ImageTransparency = 1; marks[i] = m
		if i == 1 then d.MouseButton1Click:Connect(function() hideWin() end) end
		if i == 2 then d.MouseButton1Click:Connect(function() hideWin() end) end
		if i == 3 then d.MouseButton1Click:Connect(function() maximize() end) end
	end
	-- reveal all three glyphs while hovering the cluster (macOS behavior)
	lights.MouseEnter:Connect(function() for _, m in ipairs(marks) do tween(m, 0.12, { ImageTransparency = 0 }) end end)
	lights.MouseLeave:Connect(function() for _, m in ipairs(marks) do tween(m, 0.12, { ImageTransparency = 1 }) end end)
	-- left-aligned brand: logo + (map name + faint "By author") + version/tags row
	local brand = new("Frame", { Size = UDim2.new(1, -92, 1, 0), Position = UDim2.new(0, 80, 0, 0), BackgroundTransparency = 1 }, title)
	local blogo = new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, brand)
	iconImage(blogo, opts.Logo, UDim2.fromOffset(38, 38), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
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

	-- body: sidebar + content
	local sidebar = new("ScrollingFrame", { Name = "Sidebar", Size = UDim2.new(0, 190, 1, -49), Position = UDim2.new(0, 0, 0, 49), BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, win)
	pad(sidebar, 14, 12, 12, 12); vlist(sidebar, 3)
	self.Sidebar = sidebar
	local content = new("Frame", { Name = "Content", Size = UDim2.new(1, -190, 1, -49), Position = UDim2.new(0, 190, 0, 49), BackgroundTransparency = 1 }, win)
	self.Content = content

	self:_mountMobile(opts.Logo)

	-- intro: play a loading screen, then reveal the window (opts.Loading = true or { Title, SubTitle, Duration })
	if opts.Loading then
		local lo = type(opts.Loading) == "table" and opts.Loading or {}
		local loader = self:Loading({ Title = lo.Title or opts.Title or "RayVinz Hub", SubTitle = lo.SubTitle or "Loading assets...", Logo = opts.Logo })
		task.delay(lo.Duration or 2, function() loader.Close() task.wait(0.25) showWin(true) end)
	else
		showWin(true)
	end
	return self
end

function RayVinzUI:_mountMobile(logo)
	local btn = new("TextButton", { Name = "MobileToggle", Text = "", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 22, 0.5, -28), BackgroundColor3 = Color3.fromRGB(22, 22, 24), AutoButtonColor = false }, self.Gui)
	corner(btn, 16); stroke(btn, Theme.White, 0.82, 1)
	-- big logo, no pink box/glow
	iconImage(btn, logo, UDim2.fromOffset(40, 40), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	-- draggable, and a tap (no real drag) toggles the window
	local dragging, moved, sp, si
	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; moved = false; sp = btn.Position; si = inp.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local d = inp.Position - si
			if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
			btn.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if not moved then if self.Window.Visible then self._hide() else self._show(true) end end
		end
	end)
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
	local item = new("TextButton", { Name = "Tab", Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1, LayoutOrder = #self.Sidebar:GetChildren() }, self.Sidebar)
	corner(item, 8)
	local ic = iconImage(item, opts.Icon, UDim2.fromOffset(16, 16), Theme.SubText, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
	local lb = ltext(item, opts.Title or "Tab", 13, Theme.SubText, FM); lb.Position = UDim2.new(0, 36, 0, 0); lb.Size = UDim2.new(1, -46, 1, 0)
	local page = new("ScrollingFrame", { Name = "Page", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Muted, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, self.Content)
	pad(page, 18, 18, 18, 18); vlist(page, 16)
	tab._item, tab._icon, tab._label, tab._page, tab._window = item, ic, lb, page, self
	function tab:Section(s) return self._window:_section(self._page, s) end
	item.MouseButton1Click:Connect(function() self:_select(tab) end)
	table.insert(self._tabs, tab)
	if #self._tabs == 1 then self:_select(tab) end
	return tab
end
function RayVinzUI:_select(tab)
	for _, t in ipairs(self._tabs) do
		local on = t == tab
		t._page.Visible = on
		tween(t._item, 0.18, { BackgroundTransparency = on and 0.85 or 1 })
		t._label.TextColor3 = on and Theme.Text or Theme.SubText
		t._label.Font = on and FB or FM
		t._icon.ImageColor3 = on and Theme.Accent or Theme.SubText
	end
end

-- ================= Section + elements =================
function RayVinzUI:_section(page, opts)
	opts = opts or {}; local section = { _gui = self.Gui }
	if opts.Title then
		local hrow = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = #page:GetChildren() }, page)
		local off = 0
		if opts.Icon then iconImage(hrow, opts.Icon, UDim2.fromOffset(13, 13), Theme.Muted, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5)); off = 18 end
		local hd = ltext(hrow, string.upper(opts.Title), 11, Theme.Muted, FB); hd.Position = UDim2.new(0, off, 0, 0); hd.Size = UDim2.new(1, -off, 1, 0)
	end
	local card = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, ClipsDescendants = true, LayoutOrder = #page:GetChildren() }, page)
	corner(card, 12); stroke(card, Theme.White, 0.94); vlist(card, 0)
	section._card = card

	-- base row (adds a divider only BETWEEN rows, never above the first one)
	local rowCount = 0
	local function row(h)
		if rowCount > 0 then
			new("Frame", { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 0), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.93, BorderSizePixel = 0, LayoutOrder = #card:GetChildren() }, card)
		end
		rowCount = rowCount + 1
		return new("Frame", { Size = UDim2.new(1, 0, 0, h), AutomaticSize = h == 0 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None, BackgroundTransparency = 1, LayoutOrder = #card:GetChildren() }, card)
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
		o = o or {}; local state = o.Default or false
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Toggle", 46, o.Description)
		local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(46, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = state and Theme.Green or Theme.Select }, r); corner(sw, 14)
		local knob = new("Frame", { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0, 0.5), Position = state and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = Theme.White }, sw); corner(knob, 12)
		local function set(v, fire)
			state = v
			tween(sw, 0.18, { BackgroundColor3 = v and Theme.Green or Theme.Select })
			tween(knob, 0.18, { Position = v and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		sw.MouseButton1Click:Connect(function() set(not state) end)
		return { Set = function(v) set(v) end, Get = function() return state end }
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
		-- full-width accent button
		local r = row(50)
		local b = new("TextButton", { Text = o.Title or "Button", Font = FB, TextSize = 13, TextColor3 = Theme.AccentText, AutoButtonColor = false,
			Size = UDim2.new(1, -28, 0, 38), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Theme.Accent }, r); corner(b, 9)
		b.MouseButton1Click:Connect(function()
			tween(b, 0.08, { BackgroundColor3 = Color3.fromRGB(224, 95, 172) }); task.wait(0.1); tween(b, 0.12, { BackgroundColor3 = Theme.Accent })
			if o.Callback then task.spawn(o.Callback) end
		end)
		return b
	end

	-- Slider
	function section:Slider(o)
		o = o or {}; local min = o.Min or 0; local max = o.Max or 100; local val = o.Default or min
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
		UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end end)
		UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
		set(val, false)
		return { Set = function(v) set(v) end, Get = function() return val end }
	end

	-- Dropdown
	function section:Dropdown(o)
		o = o or {}; local options = o.Options or {}; local multi = o.Multi; local selected = multi and (o.Default or {}) or o.Default
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Dropdown", 150, o.Description)
		local box = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field }, r); corner(box, 8)
		local valTxt = ltext(box, "Select...", 12, Theme.Text, FM); valTxt.Position = UDim2.new(0, 10, 0, 0); valTxt.Size = UDim2.new(1, -28, 1, 0)
		iconImage(box, "chevron-down", UDim2.fromOffset(12, 12), Theme.SubText, UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5))
		-- CanvasGroup so we can fade the whole list on open/close
		local list = new("CanvasGroup", { Visible = false, BackgroundColor3 = Theme.Elevated, Size = UDim2.fromOffset(160, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 50 }, self._gui); corner(list, 10); stroke(list, Theme.White, 0.88); pad(list, 6, 6, 6, 6); vlist(list, 2)
		-- fullscreen click-catcher: closes the list when you click/drag anywhere else
		local catcher = new("TextButton", { Name = "DropCatcher", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 49 }, self._gui)
		local tx, ty = 0, 0
		local reposition, closeList
		local function display() if multi then valTxt.Text = #selected > 0 and table.concat(selected, ", ") or "None" else valTxt.Text = selected and tostring(selected) or "Select..." end end
		local function rebuild()
			for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, opt in ipairs(options) do
				local chosen = multi and (indexOf(selected, opt) ~= nil) or (selected == opt)
				local ob = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Accent, BackgroundTransparency = chosen and 0.82 or 1, LayoutOrder = i }, list); corner(ob, 7)
				local ol = ltext(ob, tostring(opt), 12, chosen and Theme.Text or Theme.SubText, FM); ol.Position = UDim2.new(0, 10, 0, 0); ol.Size = UDim2.new(1, -20, 1, 0)
				ob.MouseButton1Click:Connect(function()
					if multi then local idx = indexOf(selected, opt) if idx then table.remove(selected, idx) else table.insert(selected, opt) end rebuild() else selected = opt closeList() end
					display(); if o.Callback then task.spawn(o.Callback, selected) end
				end)
			end
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
			reposition(); rebuild()
			list.GroupTransparency = 1; list.Position = UDim2.fromOffset(tx, ty - 6); list.Visible = true; catcher.Visible = true
			tween(list, 0.16, { GroupTransparency = 0, Position = UDim2.fromOffset(tx, ty) }) -- fade + slide down
		end
		box.MouseButton1Click:Connect(function() if list.Visible and list.GroupTransparency < 0.5 then closeList() else openList() end end)
		catcher.MouseButton1Click:Connect(closeList)
		box:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() if list.Visible then reposition() end end)
		display(); rebuild()
		return { Set = function(v) selected = v display() rebuild() if o.Callback then task.spawn(o.Callback, selected) end end, Get = function() return selected end }
	end

	-- Textbox
	function section:Textbox(o)
		o = o or {}
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Input", 150, o.Description)
		local holder = new("Frame", { Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field }, r); corner(holder, 8); pad(holder, 0, 10, 0, 10)
		local tb = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "", PlaceholderText = o.Placeholder or "...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, holder)
		tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
		return { Set = function(v) tb.Text = v end, Get = function() return tb.Text end }
	end

	-- Textarea (multi-line input: label on top, big box below)
	function section:Textarea(o)
		o = o or {}
		local r = row(0); pad(r, 12, 14, 14, 14); vlist(r, 8)
		local lbl = ltext(r, o.Title or "Input Textarea", 13, Theme.Text, FB); lbl.Size = UDim2.new(1, 0, 0, 16)
		local holder = new("Frame", { Size = UDim2.new(1, 0, 0, o.Height or 90), BackgroundColor3 = Theme.Field }, r); corner(holder, 8); stroke(holder, Theme.White, 0.92, 1); pad(holder, 9, 11, 9, 11)
		local tb = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "", PlaceholderText = o.Placeholder or "Enter Text...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true, TextWrapped = true, ClearTextOnFocus = false }, holder)
		tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
		return { Set = function(v) tb.Text = v end, Get = function() return tb.Text end }
	end

	-- Keybind
	function section:Keybind(o)
		o = o or {}; local key = o.Default
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Keybind", 90, o.Description)
		local btn = new("TextButton", { Text = key and key.Name or "None", Font = FB, TextSize = 12, TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(90, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field }, r); corner(btn, 8)
		local listening = false
		btn.MouseButton1Click:Connect(function() listening = true btn.Text = "..." end)
		UserInputService.InputBegan:Connect(function(input, gpe)
			if listening and input.UserInputType == Enum.UserInputType.Keyboard then key = input.KeyCode btn.Text = key.Name listening = false
			elseif not gpe and key and input.KeyCode == key then if o.Callback then task.spawn(o.Callback) end end
		end)
		return { Get = function() return key end }
	end

	-- ColorPicker
	function section:ColorPicker(o)
		o = o or {}; local color = o.Default or Theme.Accent; local h, s, v = color:ToHSV()
		local r = row(o.Description and 58 or 48); placeLabel(r, o.Title or "Color", 44, o.Description)
		local sw = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(44, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = color }, r); corner(sw, 7); stroke(sw, Theme.White, 0.8)
		local pop = new("Frame", { Visible = false, BackgroundColor3 = Theme.Elevated, Size = UDim2.fromOffset(200, 160), ZIndex = 60 }, self._gui); corner(pop, 10); stroke(pop, Theme.White, 0.88); pad(pop, 10, 10, 10, 10); vlist(pop, 8)
		local sv = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 108), BackgroundColor3 = Color3.fromHSV(h, 1, 1), LayoutOrder = 1 }, pop); corner(sv, 6)
		grad(sv, Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1))
		local blk = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0 }, sv); corner(blk, 6)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, blk)
		local hue = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 }, pop); corner(hue, 7)
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)), ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)), ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)), ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)) }) }, hue)
		local function refresh(fire) color = Color3.fromHSV(h, s, v) sw.BackgroundColor3 = color sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1) if fire ~= false and o.Callback then task.spawn(o.Callback, color) end end
		local ds, dh = false, false
		sv.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then ds = true end end)
		hue.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dh = true end end)
		UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then ds = false dh = false end end)
		UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if ds then s = clamp((i.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1) v = 1 - clamp((i.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1) refresh() end
			if dh then h = clamp((i.Position.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1) refresh() end
		end)
		sw.MouseButton1Click:Connect(function() pop.Position = UDim2.fromOffset(sw.AbsolutePosition.X - 160, sw.AbsolutePosition.Y + 30) pop.Visible = not pop.Visible end)
		refresh(false)
		return { Set = function(c) h, s, v = c:ToHSV() refresh() end, Get = function() return color end }
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
			local c = new("Frame", { BackgroundColor3 = Theme.Elevated, Size = UDim2.new(0.5, -6, 1, 0), LayoutOrder = i }, rowN); corner(c, 10); stroke(c, Theme.White, 0.95); pad(c, 11, 12, 11, 12); vlist(c, 7)
			local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14) }, c)
			iconImage(top, it.Icon, UDim2.fromOffset(13, 13), Theme.SubText, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
			local tl = ltext(top, it.Label or "", 11, Theme.SubText, FM); tl.Position = UDim2.new(0, it.Icon and 19 or 0, 0, 0); tl.Size = UDim2.new(1, -19, 1, 0)
			local val = ltext(c, tostring(it.Value or "-"), 15, Theme.Text, FB); val.Size = UDim2.new(1, 0, 0, 18)
			grid[it.Label] = val
		end
		return { Set = function(label, value) if grid[label] then grid[label].Text = tostring(value) end end }
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
		RunService.Heartbeat:Connect(function(dt)
			frames = frames + 1; acc = acc + dt
			if acc >= 1 then
				g.Set("FPS", math.floor(frames / acc + 0.5)); frames = 0; acc = 0
				local ping = "--"
				pcall(function() ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
				g.Set("Ping", ping); g.Set("Players", #Players:GetPlayers()); g.Set("Time", os.date("%H:%M:%S"))
			end
		end)
		return g
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
	-- Figma style: [colored icon square] [title + message]. The card height is DRIVEN from the
	-- measured text height (never AutomaticSize on the card + a scale child — that ballooned it).
	local card = new("CanvasGroup", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.fromRGB(22, 22, 24), BackgroundTransparency = 0.02, GroupTransparency = 1, ClipsDescendants = true, LayoutOrder = math.floor(tick() % 1e7) }, holder)
	corner(card, 13); stroke(card, Theme.White, 0.9, 1)
	local iconBox = new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, BackgroundTransparency = 0.78 }, card); corner(iconBox, 9)
	iconImage(iconBox, o.Icon or defIcons[o.Type or "Info"], UDim2.fromOffset(18, 18), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local col = new("Frame", { Size = UDim2.new(1, -72, 0, 0), Position = UDim2.new(0, 56, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card); vlist(col, 2)
	local tl = ltext(col, o.Title or "Notification", 13, Theme.Text, FB); tl.Size = UDim2.new(1, 0, 0, 16); tl.LayoutOrder = 1
	if o.Content and o.Content ~= "" then
		local msg = ltext(col, o.Content, 11, Theme.SubText, F); msg.LayoutOrder = 2; msg.Size = UDim2.new(1, 0, 0, 0); msg.AutomaticSize = Enum.AutomaticSize.Y; msg.TextWrapped = true; msg.TextYAlignment = Enum.TextYAlignment.Top
	end
	local function sync() local h = col.AbsoluteSize.Y or 0 if h < 34 then h = 34 end card.Size = UDim2.new(1, 0, 0, h + 22) end
	col:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync); task.defer(sync)
	tween(card, 0.28, { GroupTransparency = 0 }) -- fade in
	local dur = o.Duration or 4
	task.delay(dur, function() tween(card, 0.25, { GroupTransparency = 1 }) task.wait(0.3) card:Destroy() end)
	return card
end

function RayVinzUI:Dialog(o)
	o = o or {}
	local gui = self.Gui or ActiveGui
	local overlay = new("Frame", { Name = "Dialog", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 80 }, gui)
	local box = new("Frame", { Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Elevated, ClipsDescendants = true, ZIndex = 81 }, overlay); corner(box, 16); stroke(box, Theme.White, 0.9); pad(box, 18, 20, 18, 20); vlist(box, 14)
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

function RayVinzUI:Loading(o)
	o = o or {}
	local gui = self.Gui or ActiveGui
	-- dim backdrop + small compact card (Figma style): progress bar on top, logo + text in a row
	local overlay = new("Frame", { Name = "Loading", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 90 }, gui)
	tween(overlay, 0.25, { BackgroundTransparency = 0.45 })
	local card = new("CanvasGroup", { Size = UDim2.fromOffset(290, 72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(22, 22, 24), BackgroundTransparency = 0.02, GroupTransparency = 1, ClipsDescendants = true, ZIndex = 91 }, overlay); corner(card, 14); stroke(card, Theme.White, 0.9, 1)
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
	return { Set = function(p) tween(fb, 0.3, { Size = UDim2.new(clamp(p, 0, 1), 0, 1, 0) }) end, Close = function() tween(card, 0.25, { GroupTransparency = 1 }) tween(overlay, 0.3, { BackgroundTransparency = 1 }) task.wait(0.32) overlay:Destroy() end }
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
	local kickMsg = o.KickMessage or "remote spy detected\nไม่ได้แดกกูหรอกควาย"
	local spyNames = {
		"simplespy", "hydroxide", "remotespy", "remote-spy", "cobalt",
		"utopiaspy", "remotelogger", "octospy", "turtlespy",
	}
	-- visible window titles (caught even if the GUI name is randomized)
	local spyTitles = {
		"octo~spy", "octo spy", "turtle spy", "simplespy", "simple spy",
		"remote spy", "remotespy", "hydroxide", "cobalt", "utopia spy",
	}
	local function isSpyName(name)
		local n = string.lower(name or "")
		for _, s in ipairs(spyNames) do if string.find(n, s, 1, true) then return true end end
		return false
	end
	local function hasSpyText(gui)
		local hit = false
		pcall(function()
			for _, d in ipairs(gui:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					local t = string.lower(d.Text or "")
					for _, s in ipairs(spyTitles) do if string.find(t, s, 1, true) then hit = true return end end
				end
			end
		end)
		return hit
	end
	local function consider(g, found, allowText)
		if g.Name == "RayVinzUI" then return found end
		local cls = (pcall(function() return g.ClassName end)) and g.ClassName or ""
		local nameHit = isSpyName(g.Name)
		if not nameHit and cls ~= "ScreenGui" then return found end -- text-scan only ScreenGuis
		if nameHit or (allowText and hasSpyText(g)) then
			if removeGui then pcall(function() g:Destroy() end) end
			return true
		end
		return found
	end
	local function scanSpyGuis()
		local found = false
		-- 1) exploit zones: CoreGui + hidden-ui (name + title text)
		for _, getter in ipairs({ function() return gethui() end, function() return game:GetService("CoreGui") end }) do
			local ok, p = pcall(getter)
			if ok and p then
				local ok2, kids = pcall(function() return p:GetChildren() end)
				if ok2 then for _, g in ipairs(kids) do found = consider(g, found, true) end end
			end
		end
		-- 2) PlayerGui: name-match ONLY (it holds the game's own GUIs -> no text scan)
		pcall(function()
			local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if pg then for _, g in ipairs(pg:GetChildren()) do found = consider(g, found, false) end end
		end)
		-- 3) hidden / protected GUIs (e.g. Turtle Spy) parented to nil (name + text)
		pcall(function()
			if type(getnilinstances) == "function" then
				for _, inst in ipairs(getnilinstances()) do
					local ok, cls = pcall(function() return inst.ClassName end)
					if ok and cls == "ScreenGui" then found = consider(inst, found, true) end
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
	local function react(reasons)
		pcall(function() warn("[RayVinz] spy detected: " .. table.concat(reasons, ", ")) end)
		if o.Callback then pcall(o.Callback, reasons) end
		if doKick then pcall(function() LocalPlayer:Kick(kickMsg) end) end
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

return setmetatable({}, { __index = RayVinzUI })

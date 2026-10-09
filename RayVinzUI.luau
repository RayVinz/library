--!nocheck
--[[
	RayVinzUI — a macOS-style UI library for Roblox
	Single-file. Load with:
		local UI = loadstring(game:HttpGet("https://your/RayVinzUI.luau"))()

	API ---------------------------------------------------------------
	local Window = UI:CreateWindow({ Title=, SubTitle=, Width=, Height= })
	UI:SetIcons(pack)  |  UI:LoadLucide(url)   -- external icons (optional)

	Window:SidebarSection("Menu")
	local Tab = Window:Tab({ Title=, Icon= })
	Window:Notify({ Title=, Content=, Type="Info|Success|Warning|Error", Icon=, Duration= })
	Window:Dialog({ Title=, Content=, Buttons={ {Title=,Callback=,Variant=}, ... } })
	local close = UI:Loading({ Title=, SubTitle= })   -- returns :Set(0..1) / :Close()

	local Sec = Tab:Section({ Title= })
	Sec:Toggle({ Title=, Default=, Callback= })            -> { Set, Get }
	Sec:Button({ Title=, Callback= })
	Sec:Slider({ Title=, Min=, Max=, Default=, Rounding=, Suffix=, Callback= }) -> { Set, Get }
	Sec:Dropdown({ Title=, Options={}, Default=, Multi=, Callback= })            -> { Set, Get }
	Sec:Textbox({ Title=, Placeholder=, Default=, Callback= })                   -> { Set, Get }
	Sec:Keybind({ Title=, Default=Enum.KeyCode.X, Callback= })                   -> { Get }
	Sec:ColorPicker({ Title=, Default=Color3, Callback= })                       -> { Set, Get }
	Sec:Paragraph({ Title=, Content= })
	Sec:Tags({ {Text=, Color=} , ... })
	Sec:StatGrid({ {Label=,Value=}, ... })                                      -> { Set(label,value) }
--]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- =====================================================================
-- Theme
-- =====================================================================
local Theme = {
	Background = Color3.fromRGB(28, 28, 30),
	Sidebar    = Color3.fromRGB(36, 36, 39),
	Card       = Color3.fromRGB(44, 44, 46),
	Elevated   = Color3.fromRGB(50, 50, 53),
	Select     = Color3.fromRGB(58, 58, 60),
	Field      = Color3.fromRGB(58, 58, 60),
	Text       = Color3.fromRGB(245, 245, 247),
	SubText    = Color3.fromRGB(152, 152, 157),
	Muted      = Color3.fromRGB(110, 110, 115),
	Accent     = Color3.fromRGB(255, 121, 198),
	AccentText = Color3.fromRGB(26, 16, 22),
	Green      = Color3.fromRGB(48, 209, 88),
	Info       = Color3.fromRGB(10, 132, 255),
	Warning    = Color3.fromRGB(255, 214, 10),
	Error      = Color3.fromRGB(255, 69, 58),
	Stroke     = Color3.fromRGB(255, 255, 255),
}

-- =====================================================================
-- Helpers
-- =====================================================================
local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
local function round(n, dec)
	if dec == nil then return math.floor(n + 0.5) end
	local m = 10 ^ dec
	return math.floor(n * m + 0.5) / m
end
local function indexOf(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end

local function Create(class, props, children)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do if k ~= "Parent" then inst[k] = v end end
	end
	if children then for _, c in ipairs(children) do c.Parent = inst end end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function Corner(r, p) return Create("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
local function Stroke(p, color, tr, th)
	return Create("UIStroke", { Color = color or Theme.Stroke,
		Transparency = tr == nil and 0.92 or tr, Thickness = th or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
end
local function Padding(p, t, r, b, l)
	return Create("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t),
		PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t), Parent = p })
end
local function VList(p, gap)
	return Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap or 0), Parent = p })
end
local function HList(p, gap, align)
	return Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, gap or 0), Parent = p })
end
local function Label(p, text, size, color, font, align)
	return Create("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size,
		TextColor3 = color or Theme.Text, Font = font or Enum.Font.GothamMedium,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.XY, Parent = p })
end
local function Tween(inst, time, props)
	local tw = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end
local function MakeDraggable(handle, target)
	local dragging, startPos, startInput
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; startPos = target.Position; startInput = input.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startInput
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end
local function screenGuiParent()
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- =====================================================================
-- Icons (external / Lucide support)
-- =====================================================================
local IconPack = nil
local function resolveIcon(icon)
	if not icon or icon == "" then return nil end
	if type(icon) == "number" then return { Image = "rbxassetid://" .. icon } end
	if type(icon) == "string" and string.find(icon, "rbxassetid://") == 1 then return { Image = icon } end
	if not IconPack then return nil end
	local name = icon
	if type(name) == "string" then name = (name:gsub("^lucide:", "")) end
	if type(IconPack.Icon) == "function" then
		local ok, r = pcall(IconPack.Icon, icon)
		if ok and r and r[1] then
			return { Image = r[1], ImageRectSize = r[2] and r[2].ImageRectSize, ImageRectOffset = r[2] and r[2].ImageRectPosition }
		end
	end
	local d = IconPack[name]
	if type(d) == "table" and d.Image then
		local img = d.Image; if type(img) == "number" then img = "rbxassetid://" .. img end
		return { Image = img, ImageRectSize = d.ImageRectSize, ImageRectOffset = d.ImageRectPosition }
	elseif type(d) == "number" then return { Image = "rbxassetid://" .. d }
	elseif type(d) == "string" then return { Image = d } end
	return nil
end
local function applyIcon(img, icon)
	local r = resolveIcon(icon)
	if r then
		img.Image = r.Image
		if r.ImageRectSize then img.ImageRectSize = r.ImageRectSize end
		if r.ImageRectOffset then img.ImageRectOffset = r.ImageRectOffset end
		img.Visible = true
	else img.Visible = false end
	return img
end

-- =====================================================================
-- Library
-- =====================================================================
local RayVinzUI = {}
RayVinzUI.__index = RayVinzUI
RayVinzUI.Theme = Theme

function RayVinzUI:SetIcons(pack) IconPack = pack; return self end
function RayVinzUI:LoadLucide(url)
	local ok, pack = pcall(function() return loadstring(game:HttpGet(url))() end)
	if ok and pack then IconPack = pack; return true end
	return false
end

-- ---------- Window ----------
function RayVinzUI:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({}, { __index = RayVinzUI })
	self._tabs = {}

	local gui = Create("ScreenGui", { Name = "RayVinzUI", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, Parent = screenGuiParent() })
	self.Gui = gui

	local win = Create("Frame", { Name = "Window", Size = UDim2.fromOffset(opts.Width or 660, opts.Height or 460),
		Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background, Parent = gui })
	Corner(14, win); Stroke(win, Theme.Stroke, 0.9)
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Parent = win })
	self.Window = win

	-- title bar
	local title = Create("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1, LayoutOrder = 1, Parent = win })
	Padding(title, 0, 16, 0, 16); HList(title, 12)
	local lights = Create("Frame", { Name = "Lights", Size = UDim2.fromOffset(52, 12), BackgroundTransparency = 1, LayoutOrder = 1, Parent = title })
	HList(lights, 8)
	for i, c in ipairs({ Color3.fromRGB(255, 95, 87), Color3.fromRGB(254, 188, 46), Color3.fromRGB(40, 200, 64) }) do
		local dot = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = c, LayoutOrder = i, Parent = lights })
		Corner(6, dot)
		if i == 1 then dot.MouseButton1Click:Connect(function() gui:Destroy() end) end
		if i == 2 then dot.MouseButton1Click:Connect(function() win.Visible = false end) end
	end
	local cluster = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -120, 1, 0), LayoutOrder = 2, Parent = title })
	HList(cluster, 9, Enum.HorizontalAlignment.Center)
	local tt = Label(cluster, opts.Title or "RayVinz Hub", 14, Theme.Text, Enum.Font.GothamBold); tt.LayoutOrder = 1
	if opts.SubTitle then
		local pill = Create("Frame", { BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.9, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = cluster })
		Corner(10, pill); Padding(pill, 3, 8, 3, 8)
		Label(pill, opts.SubTitle, 10, Theme.SubText, Enum.Font.GothamMedium)
	end
	MakeDraggable(title, win)
	Create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.92, BorderSizePixel = 0, LayoutOrder = 2, Parent = win })

	-- body
	local body = Create("Frame", { Name = "Body", Size = UDim2.new(1, 0, 1, -49), BackgroundTransparency = 1, LayoutOrder = 3, Parent = win })
	HList(body, 0)
	local sidebar = Create("ScrollingFrame", { Name = "Sidebar", Size = UDim2.new(0, 190, 1, 0), BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
	Padding(sidebar, 14, 12, 12, 12); VList(sidebar, 3)
	self.Sidebar = sidebar
	local content = Create("Frame", { Name = "Content", Size = UDim2.new(1, -190, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = body })
	self.Content = content

	self:_mountMobileButton(opts.Logo)
	return self
end

function RayVinzUI:_mountMobileButton(logo)
	local btn = Create("TextButton", { Name = "MobileToggle", Text = "", Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(0, 20, 0.5, -28), BackgroundColor3 = Theme.Background, AutoButtonColor = false, Parent = self.Gui })
	Corner(16, btn); Stroke(btn, Theme.Accent, 0, 2)
	local img = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = btn })
	applyIcon(img, logo or "rbxassetid://124905448303407")
	btn.MouseButton1Click:Connect(function() self.Window.Visible = not self.Window.Visible end)
	self.MobileButton = btn
end

function RayVinzUI:SidebarSection(name)
	local h = Label(self.Sidebar, string.upper(name), 10, Theme.Muted, Enum.Font.GothamBold)
	h.LayoutOrder = #self.Sidebar:GetChildren(); Padding(h, 8, 0, 4, 10)
	return h
end

-- ---------- Tab ----------
function RayVinzUI:Tab(opts)
	opts = opts or {}
	local tab = {}
	local item = Create("TextButton", { Name = "Tab", Text = "", AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1,
		LayoutOrder = #self.Sidebar:GetChildren(), Parent = self.Sidebar })
	Corner(8, item); Padding(item, 0, 10, 0, 10); HList(item, 10)
	local icon = Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), ImageColor3 = Theme.SubText, LayoutOrder = 1, Parent = item })
	applyIcon(icon, opts.Icon)
	local label = Label(item, opts.Title or "Tab", 13, Theme.SubText, Enum.Font.GothamMedium); label.LayoutOrder = 2

	local page = Create("ScrollingFrame", { Name = "Page", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		BorderSizePixel = 0, Visible = false, ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Muted,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = self.Content })
	Padding(page, 18, 18, 18, 18); VList(page, 16)

	tab._item, tab._icon, tab._label, tab._page, tab._window = item, icon, label, page, self
	function tab:Section(s) return self._window:_section(self._page, s) end
	item.MouseButton1Click:Connect(function() self:_selectTab(tab) end)
	table.insert(self._tabs, tab)
	if #self._tabs == 1 then self:_selectTab(tab) end
	return tab
end

function RayVinzUI:_selectTab(tab)
	for _, t in ipairs(self._tabs) do
		local on = (t == tab)
		t._page.Visible = on
		Tween(t._item, 0.18, { BackgroundTransparency = on and 0.85 or 1 })
		t._label.TextColor3 = on and Theme.Text or Theme.SubText
		t._icon.ImageColor3 = on and Theme.Accent or Theme.SubText
		t._label.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
	end
end

-- =====================================================================
-- Section + elements
-- =====================================================================
function RayVinzUI:_section(page, opts)
	opts = opts or {}
	local section = { _gui = self.Gui }

	if opts.Title then
		local head = Label(page, string.upper(opts.Title), 11, Theme.Muted, Enum.Font.GothamBold)
		head.LayoutOrder = #page:GetChildren()
	end
	local card = Create("Frame", { Name = "SectionCard", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Card, LayoutOrder = #page:GetChildren(), Parent = page })
	Corner(12, card); Stroke(card, Theme.Stroke, 0.95); VList(card, 0)
	section._card = card

	local function row(height, vertical)
		local r = Create("Frame", { Size = UDim2.new(1, 0, 0, height), AutomaticSize = height == 0 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
			BackgroundTransparency = 1, LayoutOrder = #card:GetChildren(), Parent = card })
		Padding(r, vertical and 12 or 0, 14, vertical and 12 or 0, 14)
		if vertical then VList(r, 8) else HList(r, 10) end
		if #card:GetChildren() > 1 then
			local d = Create("Frame", { Size = UDim2.new(1, -14, 0, 1), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.93,
				BorderSizePixel = 0, Position = UDim2.new(0, 14, 0, 0), LayoutOrder = r.LayoutOrder, Parent = card })
			r.LayoutOrder = r.LayoutOrder + 1
		end
		return r
	end
	section._row = row

	local function titleCol(r, title, desc)
		local col = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = r })
		VList(col, 1)
		Label(col, title or "", 13, Theme.Text, Enum.Font.GothamMedium)
		if desc then local d = Label(col, desc, 11, Theme.SubText, Enum.Font.Gotham); d.TextWrapped = true; d.Size = UDim2.new(1, 0, 0, 0); d.AutomaticSize = Enum.AutomaticSize.Y end
		return col
	end

	-- Toggle
	function section:Toggle(o)
		o = o or {}; local state = o.Default or false
		local r = self._row(o.Desc and 56 or 48)
		titleCol(r, o.Title or "Toggle", o.Desc)
		local sw = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(46, 28),
			BackgroundColor3 = state and Theme.Green or Theme.Select, LayoutOrder = 2, Parent = r })
		Corner(14, sw)
		local knob = Create("Frame", { Size = UDim2.fromOffset(24, 24),
			Position = state and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = sw })
		Corner(12, knob)
		local function set(v, fire)
			state = v
			Tween(sw, 0.18, { BackgroundColor3 = v and Theme.Green or Theme.Select })
			Tween(knob, 0.18, { Position = v and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		sw.MouseButton1Click:Connect(function() set(not state) end)
		return { Set = function(v) set(v) end, Get = function() return state end }
	end

	-- Button
	function section:Button(o)
		o = o or {}
		local r = self._row(50)
		local b = Create("TextButton", { Text = o.Title or "Button", Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = Theme.AccentText, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = Theme.Accent, LayoutOrder = 1, Parent = r })
		Corner(9, b)
		b.MouseButton1Click:Connect(function()
			Tween(b, 0.08, { BackgroundColor3 = Color3.fromRGB(224, 95, 172) })
			task.wait(0.1); Tween(b, 0.12, { BackgroundColor3 = Theme.Accent })
			if o.Callback then task.spawn(o.Callback) end
		end)
		return b
	end

	-- Slider
	function section:Slider(o)
		o = o or {}; local min = o.Min or 0; local max = o.Max or 100; local val = o.Default or min
		local r = self._row(56, true)
		local top = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = r })
		HList(top, 0)
		local lbl = Label(top, o.Title or "Slider", 13, Theme.Text, Enum.Font.GothamMedium); lbl.LayoutOrder = 1; lbl.Size = UDim2.new(1, -50, 1, 0); lbl.AutomaticSize = Enum.AutomaticSize.None
		local valLbl = Label(top, tostring(val), 13, Theme.Accent, Enum.Font.GothamBold, Enum.TextXAlignment.Right); valLbl.LayoutOrder = 2; valLbl.Size = UDim2.new(0, 50, 1, 0); valLbl.AutomaticSize = Enum.AutomaticSize.None
		local track = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.86, LayoutOrder = 2, Parent = r })
		Corner(3, track)
		local fillB = Create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track }); Corner(3, fillB)
		local knob = Create("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = track })
		Corner(8, knob); Stroke(knob, Theme.Accent, 0, 2)
		local function set(v, fire)
			v = clamp(v, min, max); v = round(v, o.Rounding); val = v
			local pct = (max > min) and (v - min) / (max - min) or 0
			fillB.Size = UDim2.new(pct, 0, 1, 0); knob.Position = UDim2.new(pct, 0, 0.5, 0)
			valLbl.Text = tostring(v) .. (o.Suffix or "")
			if fire ~= false and o.Callback then task.spawn(o.Callback, v) end
		end
		local dragging = false
		local function upd(px)
			local rel = clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			set(min + (max - min) * rel)
		end
		track.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; upd(i.Position.X) end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then upd(i.Position.X) end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
		end)
		set(val, false)
		return { Set = function(v) set(v) end, Get = function() return val end }
	end

	-- Dropdown
	function section:Dropdown(o)
		o = o or {}; local options = o.Options or {}; local multi = o.Multi
		local selected = multi and (o.Default or {}) or o.Default
		local r = self._row(48)
		local lbl = Label(r, o.Title or "Dropdown", 13, Theme.Text, Enum.Font.GothamMedium); lbl.LayoutOrder = 1; lbl.Size = UDim2.new(1, -140, 1, 0); lbl.AutomaticSize = Enum.AutomaticSize.None
		local box = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(0, 140, 0, 30), BackgroundColor3 = Theme.Field, LayoutOrder = 2, Parent = r })
		Corner(8, box); Padding(box, 0, 8, 0, 10); HList(box, 6)
		local valTxt = Label(box, "Select...", 12, Theme.Text, Enum.Font.GothamMedium); valTxt.LayoutOrder = 1; valTxt.Size = UDim2.new(1, -16, 1, 0); valTxt.AutomaticSize = Enum.AutomaticSize.None; valTxt.TextTruncate = Enum.TextTruncate.AtEnd
		local chev = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 12), ImageColor3 = Theme.SubText, LayoutOrder = 2, Parent = box })
		applyIcon(chev, "chevron-down")

		local list = Create("Frame", { Visible = false, BackgroundColor3 = Theme.Elevated, Size = UDim2.new(0, 160, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 50, Parent = self._gui })
		Corner(10, list); Stroke(list, Theme.Stroke, 0.9); Padding(list, 6, 6, 6, 6); VList(list, 2)
		local function display()
			if multi then
				local t = {}; for _, v in ipairs(selected) do table.insert(t, v) end
				valTxt.Text = #t > 0 and table.concat(t, ", ") or "None"
			else valTxt.Text = selected and tostring(selected) or "Select..." end
		end
		local function fire()
			if o.Callback then task.spawn(o.Callback, selected) end
		end
		local function rebuild()
			for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, opt in ipairs(options) do
				local chosen = multi and (indexOf(selected, opt) ~= nil) or (selected == opt)
				local ob = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30),
					BackgroundColor3 = Theme.Accent, BackgroundTransparency = chosen and 0.82 or 1, LayoutOrder = i, Parent = list })
				Corner(7, ob); Padding(ob, 0, 10, 0, 10); HList(ob, 8)
				Label(ob, tostring(opt), 12, chosen and Theme.Text or Theme.SubText, Enum.Font.GothamMedium)
				ob.MouseButton1Click:Connect(function()
					if multi then
						local idx = indexOf(selected, opt)
						if idx then table.remove(selected, idx) else table.insert(selected, opt) end
						rebuild()
					else selected = opt; list.Visible = false end
					display(); fire()
				end)
			end
		end
		box.MouseButton1Click:Connect(function()
			list.Position = UDim2.fromOffset(box.AbsolutePosition.X - 20, box.AbsolutePosition.Y + 34)
			list.Size = UDim2.new(0, math.max(box.AbsoluteSize.X, 160), 0, 0)
			list.Visible = not list.Visible
			if list.Visible then rebuild() end
		end)
		display(); rebuild()
		return { Set = function(v) selected = v; display(); rebuild(); fire() end, Get = function() return selected end }
	end

	-- Textbox
	function section:Textbox(o)
		o = o or {}
		local r = self._row(48)
		local lbl = Label(r, o.Title or "Input", 13, Theme.Text, Enum.Font.GothamMedium); lbl.LayoutOrder = 1; lbl.Size = UDim2.new(1, -150, 1, 0); lbl.AutomaticSize = Enum.AutomaticSize.None
		local holder = Create("Frame", { BackgroundColor3 = Theme.Field, Size = UDim2.new(0, 150, 0, 30), LayoutOrder = 2, Parent = r })
		Corner(8, holder); Padding(holder, 0, 10, 0, 10)
		local tb = Create("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "",
			PlaceholderText = o.Placeholder or "...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = holder })
		tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
		return { Set = function(v) tb.Text = v end, Get = function() return tb.Text end }
	end

	-- Keybind
	function section:Keybind(o)
		o = o or {}; local key = o.Default
		local r = self._row(48)
		local lbl = Label(r, o.Title or "Keybind", 13, Theme.Text, Enum.Font.GothamMedium); lbl.LayoutOrder = 1; lbl.Size = UDim2.new(1, -110, 1, 0); lbl.AutomaticSize = Enum.AutomaticSize.None
		local btn = Create("TextButton", { Text = key and tostring(key.Name) or "None", Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = Theme.Text, AutoButtonColor = false, Size = UDim2.new(0, 110, 0, 30), BackgroundColor3 = Theme.Field, LayoutOrder = 2, Parent = r })
		Corner(8, btn)
		local listening = false
		btn.MouseButton1Click:Connect(function() listening = true; btn.Text = "..." end)
		UserInputService.InputBegan:Connect(function(input, gpe)
			if listening and input.UserInputType == Enum.UserInputType.Keyboard then
				key = input.KeyCode; btn.Text = tostring(key.Name); listening = false
			elseif not gpe and key and input.KeyCode == key then
				if o.Callback then task.spawn(o.Callback) end
			end
		end)
		return { Get = function() return key end }
	end

	-- ColorPicker (compact HSV)
	function section:ColorPicker(o)
		o = o or {}; local color = o.Default or Color3.fromRGB(255, 121, 198)
		local h, s, v = color:ToHSV()
		local r = self._row(48)
		local lbl = Label(r, o.Title or "Color", 13, Theme.Text, Enum.Font.GothamMedium); lbl.LayoutOrder = 1; lbl.Size = UDim2.new(1, -50, 1, 0); lbl.AutomaticSize = Enum.AutomaticSize.None
		local swatch = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 26), BackgroundColor3 = color, LayoutOrder = 2, Parent = r })
		Corner(7, swatch); Stroke(swatch, Theme.Stroke, 0.8)

		local pop = Create("Frame", { Visible = false, BackgroundColor3 = Theme.Elevated, Size = UDim2.fromOffset(200, 170), ZIndex = 60, Parent = self._gui })
		Corner(10, pop); Stroke(pop, Theme.Stroke, 0.9); Padding(pop, 10, 10, 10, 10); VList(pop, 8)
		local sv = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.fromHSV(h, 1, 1), LayoutOrder = 1, Parent = pop })
		Corner(6, sv)
		Create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h, 1, 1)), Parent = sv })
		local blackOv = Create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, Parent = sv }); Corner(6, blackOv)
		Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackOv })
		local hue = Create("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = pop }); Corner(7, hue)
		Create("UIGradient", { Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)), ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)) }), Parent = hue })
		local function refresh(fire)
			color = Color3.fromHSV(h, s, v); swatch.BackgroundColor3 = color; sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			if fire ~= false and o.Callback then task.spawn(o.Callback, color) end
		end
		local dragSV, dragH = false, false
		sv.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = true end end)
		hue.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragH = true end end)
		UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = false; dragH = false end end)
		UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if dragSV then s = clamp((i.Position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1); v = 1 - clamp((i.Position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1); refresh() end
			if dragH then h = clamp((i.Position.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1); refresh() end
		end)
		swatch.MouseButton1Click:Connect(function()
			pop.Position = UDim2.fromOffset(swatch.AbsolutePosition.X - 160, swatch.AbsolutePosition.Y + 30); pop.Visible = not pop.Visible
		end)
		refresh(false)
		return { Set = function(c) h, s, v = c:ToHSV(); refresh() end, Get = function() return color end }
	end

	-- Label (simple text row)
	function section:Label(text)
		local r = self._row(40)
		Label(r, text, 13, Theme.SubText, Enum.Font.Gotham)
		return r
	end

	-- Paragraph
	function section:Paragraph(o)
		o = o or {}
		local r = self._row(0, true)
		if o.Title then Label(r, o.Title, 14, Theme.Text, Enum.Font.GothamBold) end
		local body = Label(r, o.Content or "", 12, Theme.SubText, Enum.Font.Gotham)
		body.TextWrapped = true; body.Size = UDim2.new(1, 0, 0, 0); body.AutomaticSize = Enum.AutomaticSize.Y
		return r
	end

	-- Tags
	function section:Tags(tags)
		local r = self._row(44)
		local wrap = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = r }); HList(wrap, 8)
		for i, t in ipairs(tags or {}) do
			local pill = Create("Frame", { BackgroundColor3 = t.Color or Theme.Accent, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, Parent = wrap })
			Corner(12, pill); Padding(pill, 5, 11, 5, 11)
			Label(pill, t.Text or "tag", 11, t.TextColor or Theme.AccentText, Enum.Font.GothamBold)
		end
		return r
	end

	-- StatGrid (System Info)
	function section:StatGrid(items)
		local r = self._row(0, true)
		local grid = {}
		local rowN
		for i, it in ipairs(items or {}) do
			if (i - 1) % 2 == 0 then
				rowN = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = r })
				HList(rowN, 12)
			end
			local c = Create("Frame", { BackgroundColor3 = Theme.Elevated, Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = rowN })
			Corner(10, c); Stroke(c, Theme.Stroke, 0.95); Padding(c, 12, 13, 12, 13); VList(c, 8)
			local top = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Parent = c }); HList(top, 8)
			local ic = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), ImageColor3 = Theme.SubText, LayoutOrder = 1, Parent = top }); applyIcon(ic, it.Icon)
			Label(top, it.Label or "", 11, Theme.SubText, Enum.Font.GothamMedium).LayoutOrder = 2
			local val = Label(c, tostring(it.Value or "-"), 15, Theme.Text, Enum.Font.GothamBold)
			grid[it.Label] = val
		end
		return { Set = function(label, value) if grid[label] then grid[label].Text = tostring(value) end end }
	end

	return section
end

-- =====================================================================
-- Notify / Dialog / Loading
-- =====================================================================
function RayVinzUI:Notify(o)
	o = o or {}
	local colors = { Info = Theme.Info, Success = Theme.Green, Warning = Theme.Warning, Error = Theme.Error }
	local color = colors[o.Type or "Info"] or Theme.Info
	local holder = self.Gui:FindFirstChild("NotifHolder")
	if not holder then
		holder = Create("Frame", { Name = "NotifHolder", BackgroundTransparency = 1, Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -340, 0, 20), Parent = self.Gui })
		Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), Parent = holder })
	end
	local card = Create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, LayoutOrder = tick(), Parent = holder })
	Corner(12, card); Stroke(card, Theme.Stroke, 0.95)
	local bar = Create("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, 0, 0, 8), BackgroundColor3 = color, BorderSizePixel = 0, Parent = card }); Corner(2, bar)
	Padding(card, 12, 14, 12, 14); VList(card, 6)
	local top = Create("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card }); HList(top, 8)
	if o.Icon then local ni = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), ImageColor3 = color, LayoutOrder = 1, Parent = top }); applyIcon(ni, o.Icon) end
	Label(top, o.Title or "Notification", 13, color, Enum.Font.GothamBold).LayoutOrder = 2
	local msg = Label(card, o.Content or "", 11, Theme.SubText, Enum.Font.Gotham); msg.LayoutOrder = 2; msg.TextWrapped = true; msg.Size = UDim2.new(1, 0, 0, 0); msg.AutomaticSize = Enum.AutomaticSize.Y
	local track = Create("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.88, BorderSizePixel = 0, LayoutOrder = 3, Parent = card }); Corner(2, track)
	local fb = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = track }); Corner(2, fb)
	local dur = o.Duration or 4
	Tween(fb, dur, { Size = UDim2.new(0, 0, 1, 0) })
	task.delay(dur, function() Tween(card, 0.25, { BackgroundTransparency = 1 }); task.wait(0.3); card:Destroy() end)
	return card
end

function RayVinzUI:Dialog(o)
	o = o or {}
	local overlay = Create("Frame", { Name = "Dialog", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 80, Parent = self.Gui })
	local box = Create("Frame", { Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Elevated, ZIndex = 81, Parent = overlay })
	Corner(16, box); Stroke(box, Theme.Stroke, 0.9); Padding(box, 18, 20, 18, 20); VList(box, 14)
	local head = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = box }); HList(head, 10)
	Label(head, o.Title or "Dialog", 15, Theme.Text, Enum.Font.GothamBold)
	local body = Label(box, o.Content or "", 13, Theme.SubText, Enum.Font.Gotham); body.LayoutOrder = 2; body.TextWrapped = true; body.Size = UDim2.new(1, 0, 0, 0); body.AutomaticSize = Enum.AutomaticSize.Y
	local btns = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3, Parent = box }); HList(btns, 10, Enum.HorizontalAlignment.Right)
	for i, bd in ipairs(o.Buttons or { { Title = "OK" } }) do
		local accent = bd.Variant == "Primary"
		local b = Create("TextButton", { Text = bd.Title or "OK", Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = accent and Theme.AccentText or Theme.Text, AutoButtonColor = false, Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = accent and Theme.Accent or Theme.Select, LayoutOrder = i, Parent = btns })
		Corner(9, b); Padding(b, 0, 18, 0, 18)
		b.MouseButton1Click:Connect(function() overlay:Destroy(); if bd.Callback then task.spawn(bd.Callback) end end)
	end
	return overlay
end

function RayVinzUI:Loading(o)
	o = o or {}
	local overlay = Create("Frame", { Name = "Loading", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Background, ZIndex = 90, Parent = self.Gui })
	local box = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(320, 90), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = overlay })
	VList(box, 14)
	local row = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = box }); HList(row, 12)
	local ic = Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(38, 38), LayoutOrder = 1, Parent = row }); applyIcon(ic, o.Logo or "rbxassetid://124905448303407")
	local col = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0), LayoutOrder = 2, Parent = row }); VList(col, 2)
	Label(col, o.Title or "RayVinz Hub", 15, Theme.Text, Enum.Font.GothamBold)
	Label(col, o.SubTitle or "Loading...", 12, Theme.SubText, Enum.Font.Gotham)
	local track = Create("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Theme.Stroke, BackgroundTransparency = 0.85, BorderSizePixel = 0, LayoutOrder = 2, Parent = box }); Corner(3, track)
	local fb = Create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track }); Corner(3, fb)
	return {
		Set = function(p) Tween(fb, 0.3, { Size = UDim2.new(clamp(p, 0, 1), 0, 1, 0) }) end,
		Close = function() Tween(overlay, 0.3, { BackgroundTransparency = 1 }); task.wait(0.35); overlay:Destroy() end,
	}
end

return setmetatable({}, { __index = RayVinzUI })

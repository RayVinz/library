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
local F  = Enum.Font.Gotham
local FM = Enum.Font.GothamMedium
local FB = Enum.Font.GothamBold

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
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- ================= icons =================
local IconPack = nil
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
function RayVinzUI:SetIcons(p) IconPack = p; return self end
function RayVinzUI:LoadLucide(url) local ok, p = pcall(function() return loadstring(game:HttpGet(url))() end) if ok and p then IconPack = p return true end return false end

-- ---------- Window ----------
function RayVinzUI:CreateWindow(opts)
	opts = opts or {}
	local self = setmetatable({}, { __index = RayVinzUI }); self._tabs = {}
	local gui = new("ScreenGui", { Name = "RayVinzUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true }, guiParent())
	self.Gui = gui

	local win = new("Frame", { Name = "Window", Size = UDim2.fromOffset(opts.Width or 660, opts.Height or 460),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Background, ClipsContent = true }, gui)
	corner(win, 14); stroke(win, Theme.White, 0.9)
	self.Window = win

	-- title bar
	local title = new("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, win)
	local lights = new("Frame", { Size = UDim2.fromOffset(52, 12), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1 }, title)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, lights)
	for i, c in ipairs({ Color3.fromRGB(255, 95, 87), Color3.fromRGB(254, 188, 46), Color3.fromRGB(40, 200, 64) }) do
		local d = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = c, LayoutOrder = i }, lights); corner(d, 6)
		if i == 1 then d.MouseButton1Click:Connect(function() gui:Destroy() end) end
		if i == 2 then d.MouseButton1Click:Connect(function() win.Visible = false end) end
	end
	-- centered logo + title + version pill
	local cluster = new("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, title)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 9), VerticalAlignment = Enum.VerticalAlignment.Center }, cluster)
	local logo = new("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Theme.Accent, LayoutOrder = 1 }, cluster); corner(logo, 6); grad(logo, Theme.Accent, Theme.Accent2, 45)
	iconImage(logo, opts.Logo, UDim2.fromOffset(14, 14), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local tt = ltext(cluster, opts.Title or "RayVinz Hub", 14, Theme.Text, FB); tt.Size = UDim2.fromOffset(0, 22); tt.AutomaticSize = Enum.AutomaticSize.X; tt.LayoutOrder = 2
	if opts.SubTitle then
		local pill = new("Frame", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.White, BackgroundTransparency = 0.9, LayoutOrder = 3 }, cluster); corner(pill, 10); pad(pill, 3, 8, 3, 8)
		local pl = ltext(pill, opts.SubTitle, 10, Theme.SubText, FM); pl.Size = UDim2.fromOffset(0, 14); pl.AutomaticSize = Enum.AutomaticSize.X
	end
	draggable(title, win)
	new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 48), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.92, BorderSizePixel = 0 }, win)

	-- body: sidebar + content
	local sidebar = new("ScrollingFrame", { Name = "Sidebar", Size = UDim2.new(0, 190, 1, -49), Position = UDim2.new(0, 0, 0, 49), BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, win)
	pad(sidebar, 14, 12, 12, 12); vlist(sidebar, 3)
	self.Sidebar = sidebar
	local content = new("Frame", { Name = "Content", Size = UDim2.new(1, -190, 1, -49), Position = UDim2.new(0, 190, 0, 49), BackgroundTransparency = 1 }, win)
	self.Content = content

	self:_mountMobile(opts.Logo)
	return self
end

function RayVinzUI:_mountMobile(logo)
	local btn = new("TextButton", { Name = "MobileToggle", Text = "", Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, 22, 0.5, -29), BackgroundColor3 = Theme.Background, AutoButtonColor = false }, self.Gui)
	corner(btn, 17); stroke(btn, Theme.Accent, 0, 2)
	grad(btn, Color3.fromRGB(42, 33, 48), Color3.fromRGB(23, 20, 28), 115)
	-- soft glow
	new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ImageColor3 = Theme.Accent, ImageTransparency = 0.35,
		Size = UDim2.fromScale(1.9, 1.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 0 }, btn)
	local lg = new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Accent }, btn); corner(lg, 10); grad(lg, Theme.Accent, Theme.Accent2, 45)
	iconImage(lg, logo, UDim2.fromOffset(22, 22), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	btn.MouseButton1Click:Connect(function() self.Window.Visible = not self.Window.Visible end)
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
	if opts.Title then local hd = ltext(page, string.upper(opts.Title), 11, Theme.Muted, FB); hd.Size = UDim2.new(1, 0, 0, 14); hd.LayoutOrder = #page:GetChildren() end
	local card = new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, ClipsContent = true, LayoutOrder = #page:GetChildren() }, page)
	corner(card, 12); stroke(card, Theme.White, 0.94); vlist(card, 0)
	section._card = card

	-- base row (handles the divider automatically)
	local function row(h)
		if #card:GetChildren() > 2 then
			new("Frame", { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.new(0, 14, 0, 0), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.93, BorderSizePixel = 0, LayoutOrder = #card:GetChildren() }, card)
		end
		return new("Frame", { Size = UDim2.new(1, 0, 0, h), AutomaticSize = h == 0 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None, BackgroundTransparency = 1, LayoutOrder = #card:GetChildren() }, card)
	end
	-- left label (vertically centered), reserves space on the right for a control
	local function leftLabel(r, text, reserve)
		return ltext(r, text, 13, Theme.Text, FM), nil
	end
	local function placeLabel(r, text, reserve)
		local l = ltext(r, text, 13, Theme.Text, FM)
		l.Position = UDim2.new(0, 14, 0, 0); l.Size = UDim2.new(1, -(reserve + 28), 1, 0)
		return l
	end
	section._row = row

	-- Toggle
	function section:Toggle(o)
		o = o or {}; local state = o.Default or false
		local r = row(48); placeLabel(r, o.Title or "Toggle", 46)
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
		local r = row(54)
		local lbl = ltext(r, o.Title or "Slider", 13, Theme.Text, FM); lbl.Position = UDim2.new(0, 14, 0, 11); lbl.Size = UDim2.new(1, -90, 0, 16)
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
		local r = row(48); placeLabel(r, o.Title or "Dropdown", 150)
		local box = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field }, r); corner(box, 8)
		local valTxt = ltext(box, "Select...", 12, Theme.Text, FM); valTxt.Position = UDim2.new(0, 10, 0, 0); valTxt.Size = UDim2.new(1, -28, 1, 0)
		iconImage(box, "chevron-down", UDim2.fromOffset(12, 12), Theme.SubText, UDim2.new(1, -8, 0.5, 0), Vector2.new(1, 0.5))
		local list = new("Frame", { Visible = false, BackgroundColor3 = Theme.Elevated, Size = UDim2.fromOffset(160, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsContent = true, ZIndex = 50 }, self._gui); corner(list, 10); stroke(list, Theme.White, 0.88); pad(list, 6, 6, 6, 6); vlist(list, 2)
		local function display() if multi then valTxt.Text = #selected > 0 and table.concat(selected, ", ") or "None" else valTxt.Text = selected and tostring(selected) or "Select..." end end
		local function rebuild()
			for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			for i, opt in ipairs(options) do
				local chosen = multi and (indexOf(selected, opt) ~= nil) or (selected == opt)
				local ob = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Accent, BackgroundTransparency = chosen and 0.82 or 1, LayoutOrder = i }, list); corner(ob, 7)
				local ol = ltext(ob, tostring(opt), 12, chosen and Theme.Text or Theme.SubText, FM); ol.Position = UDim2.new(0, 10, 0, 0); ol.Size = UDim2.new(1, -20, 1, 0)
				ob.MouseButton1Click:Connect(function()
					if multi then local idx = indexOf(selected, opt) if idx then table.remove(selected, idx) else table.insert(selected, opt) end rebuild() else selected = opt list.Visible = false end
					display(); if o.Callback then task.spawn(o.Callback, selected) end
				end)
			end
		end
		box.MouseButton1Click:Connect(function()
			list.Position = UDim2.fromOffset(box.AbsolutePosition.X, box.AbsolutePosition.Y + 34); list.Size = UDim2.fromOffset(math.max(box.AbsoluteSize.X, 150), 0); list.Visible = not list.Visible
			if list.Visible then rebuild() end
		end)
		display(); rebuild()
		return { Set = function(v) selected = v display() rebuild() if o.Callback then task.spawn(o.Callback, selected) end end, Get = function() return selected end }
	end

	-- Textbox
	function section:Textbox(o)
		o = o or {}
		local r = row(48); placeLabel(r, o.Title or "Input", 150)
		local holder = new("Frame", { Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = Theme.Field }, r); corner(holder, 8); pad(holder, 0, 10, 0, 10)
		local tb = new("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = o.Default or "", PlaceholderText = o.Placeholder or "...", PlaceholderColor3 = Theme.Muted, TextColor3 = Theme.Text, Font = FM, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, holder)
		tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
		return { Set = function(v) tb.Text = v end, Get = function() return tb.Text end }
	end

	-- Keybind
	function section:Keybind(o)
		o = o or {}; local key = o.Default
		local r = row(48); placeLabel(r, o.Title or "Keybind", 90)
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
		local r = row(48); placeLabel(r, o.Title or "Color", 44)
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

	return section
end

-- ================= Notify / Dialog / Loading =================
function RayVinzUI:Notify(o)
	o = o or {}
	local colors = { Info = Theme.Info, Success = Theme.Green, Warning = Theme.Warning, Error = Theme.Error }
	local color = colors[o.Type or "Info"] or Theme.Info
	local holder = self.Gui:FindFirstChild("NotifHolder")
	if not holder then holder = new("Frame", { Name = "NotifHolder", BackgroundTransparency = 1, Size = UDim2.new(0, 320, 1, -40), Position = UDim2.new(1, -340, 0, 20) }, self.Gui) new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, holder) end
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Card, ClipsContent = true, LayoutOrder = tick() }, holder); corner(card, 12); stroke(card, Theme.White, 0.94)
	new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, 0, 0, 8), BackgroundColor3 = color, BorderSizePixel = 0 }, card)
	pad(card, 12, 14, 12, 14); vlist(card, 6)
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1 }, card)
	local off = 0
	if o.Icon then iconImage(top, o.Icon, UDim2.fromOffset(16, 16), color, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5)) off = 24 end
	local tl = ltext(top, o.Title or "Notification", 13, color, FB); tl.Position = UDim2.new(0, off, 0, 0); tl.Size = UDim2.new(1, -off, 1, 0)
	local msg = ltext(card, o.Content or "", 11, Theme.SubText, F); msg.LayoutOrder = 2; msg.Size = UDim2.new(1, 0, 0, 0); msg.AutomaticSize = Enum.AutomaticSize.Y; msg.TextWrapped = true; msg.TextYAlignment = Enum.TextYAlignment.Top
	local track = new("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.88, BorderSizePixel = 0, LayoutOrder = 3 }, card); corner(track, 2)
	local fb = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, track); corner(fb, 2)
	local dur = o.Duration or 4
	tween(fb, dur, { Size = UDim2.new(0, 0, 1, 0) })
	task.delay(dur, function() tween(card, 0.25, { BackgroundTransparency = 1 }) task.wait(0.3) card:Destroy() end)
	return card
end

function RayVinzUI:Dialog(o)
	o = o or {}
	local overlay = new("Frame", { Name = "Dialog", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 80 }, self.Gui)
	local box = new("Frame", { Size = UDim2.fromOffset(360, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Elevated, ClipsContent = true, ZIndex = 81 }, overlay); corner(box, 16); stroke(box, Theme.White, 0.9); pad(box, 18, 20, 18, 20); vlist(box, 14)
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
	local overlay = new("Frame", { Name = "Loading", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Background, ZIndex = 90 }, self.Gui)
	local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(320, 90), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) }, overlay); vlist(box, 14)
	local rowf = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1 }, box)
	local lg = new("Frame", { Size = UDim2.fromOffset(38, 38), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Theme.Accent }, rowf); corner(lg, 11); grad(lg, Theme.Accent, Theme.Accent2, 45)
	iconImage(lg, o.Logo, UDim2.fromOffset(24, 24), Theme.White, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local t1 = ltext(rowf, o.Title or "RayVinz Hub", 15, Theme.Text, FB); t1.Position = UDim2.new(0, 50, 0, 4); t1.Size = UDim2.new(1, -50, 0, 18)
	local t2 = ltext(rowf, o.SubTitle or "Loading...", 12, Theme.SubText, F); t2.Position = UDim2.new(0, 50, 0, 22); t2.Size = UDim2.new(1, -50, 0, 14)
	local track = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Theme.White, BackgroundTransparency = 0.85, BorderSizePixel = 0, LayoutOrder = 2 }, box); corner(track, 3)
	local fb = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 }, track); corner(fb, 3)
	return { Set = function(p) tween(fb, 0.3, { Size = UDim2.new(clamp(p, 0, 1), 0, 1, 0) }) end, Close = function() tween(overlay, 0.3, { BackgroundTransparency = 1 }) task.wait(0.35) overlay:Destroy() end }
end

return setmetatable({}, { __index = RayVinzUI })

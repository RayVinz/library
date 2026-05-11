--[[
    ██████╗  █████╗ ██╗   ██╗██╗   ██╗██╗███╗   ██╗███████╗
    ██╔══██╗██╔══██╗╚██╗ ██╔╝██║   ██║██║████╗  ██║╚══███╔╝
    ██████╔╝███████║ ╚████╔╝ ██║   ██║██║██╔██╗ ██║  ███╔╝
    ██╔══██╗██╔══██║  ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╗██║ ███╔╝
    ██║  ██║██║  ██║   ██║    ╚████╔╝ ██║██║ ╚████║███████╗
    ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝     ╚═══╝  ╚═╝╚═╝  ╚═══╝╚══════╝
    UI Library v1.2 — Minimal Modern + Mobile Ready
    • Readable text  • UIStroke on every element
    • Touch + Mouse  • Desktop sidebar / Mobile bottom tabs
    by RayVinz
--]]

local RayVinzLib = {}
RayVinzLib.__index = RayVinzLib

-- ══════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- ══════════════════════════════════════════════
-- DEVICE DETECTION
-- ══════════════════════════════════════════════
local IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- ══════════════════════════════════════════════
-- ICONS  (Footagesus/Icons)
-- ══════════════════════════════════════════════
local Icons = nil
pcall(function()
    Icons = loadstring(game:HttpGetAsync(
        "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"
    ))()
    Icons.SetIconsType("lucide")
end)

-- ══════════════════════════════════════════════
-- THEME — high-contrast, readable
-- ══════════════════════════════════════════════
local T = {
    BG          = Color3.fromRGB(6,   2,   14),   -- window bg
    Panel       = Color3.fromRGB(12,  4,   24),   -- sidebar / section
    Card        = Color3.fromRGB(18,  6,   34),   -- element row bg
    CardHover   = Color3.fromRGB(28,  10,  52),   -- hover state
    Border      = Color3.fromRGB(50,  15,  90),   -- subtle border
    BorderBright= Color3.fromRGB(90,  30,  160),  -- focused border
    Accent      = Color3.fromRGB(255, 38,  60),   -- red
    AccentAlt   = Color3.fromRGB(160, 60,  255),  -- purple
    Text        = Color3.fromRGB(245, 235, 255),  -- primary text (bright)
    TextSub     = Color3.fromRGB(180, 160, 210),  -- secondary text
    TextDim     = Color3.fromRGB(110, 85,  150),  -- muted / labels
    Success     = Color3.fromRGB(0,   210, 110),
    Warning     = Color3.fromRGB(255, 180, 0),
    Error       = Color3.fromRGB(255, 55,  70),
}

-- ══════════════════════════════════════════════
-- CORE UTILITIES
-- ══════════════════════════════════════════════
local function Tween(obj, props, t, style, dir)
    TweenService:Create(obj, TweenInfo.new(
        t or 0.16,
        style or Enum.EasingStyle.Quad,
        dir   or Enum.EasingDirection.Out
    ), props):Play()
end

local function New(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = o end
    return o
end

local function Gradient(parent, cA, cB, rot)
    return New("UIGradient", {
        Color    = ColorSequence.new{
            ColorSequenceKeypoint.new(0, cA),
            ColorSequenceKeypoint.new(1, cB)
        },
        Rotation = rot or 0,
        Parent   = parent
    })
end

-- Input type helpers
local function isClick(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch
end
local function isRelease(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end

-- ── DRAG (mouse + touch) ─────────────────────
local function MakeDraggable(handle, target)
    local dragging, dragStart, startPos, lastInput

    handle.InputBegan:Connect(function(i)
        if not isClick(i) then return end
        dragging  = true
        dragStart = i.Position
        startPos  = target.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end)
    handle.InputChanged:Connect(function(i)
        if isMove(i) then lastInput = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and isMove(i) then
            local d = i.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if isRelease(i) then dragging = false end
    end)
end

-- ── SCAN-BEAM SWEEP ANIMATION ────────────────
local function Sweep(frame, color, speed)
    if not frame or not frame.Parent then return end
    color = color or T.Accent
    speed = speed or 0.45
    local beam = New("Frame", {
        Size = UDim2.new(1,0,1,0), BackgroundColor3 = color,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ZIndex = frame.ZIndex + 20, Parent = frame
    })
    local grad = New("UIGradient", {
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0,    1),
            NumberSequenceKeypoint.new(0.42, 1),
            NumberSequenceKeypoint.new(0.48, 0.08),
            NumberSequenceKeypoint.new(0.50, 0),
            NumberSequenceKeypoint.new(0.52, 0.08),
            NumberSequenceKeypoint.new(0.58, 1),
            NumberSequenceKeypoint.new(1,    1),
        },
        Offset = Vector2.new(-1.2, 0),
        Parent = beam
    })
    local tw = TweenService:Create(grad,
        TweenInfo.new(speed, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        { Offset = Vector2.new(1.2, 0) }
    )
    tw:Play()
    tw.Completed:Connect(function() beam:Destroy() end)
end

-- ── ICON HELPER ──────────────────────────────
local function Icon(parent, name, sz, color, zIdx)
    sz = sz or 15; color = color or T.AccentAlt; zIdx = zIdx or 5
    if Icons then
        local ok, img = pcall(function() return Icons.GetIcon(name) end)
        if ok and img and type(img) == "string" then
            return New("ImageLabel", {
                Image = img, ImageColor3 = color,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, sz, 0, sz),
                ZIndex = zIdx, Parent = parent
            })
        end
    end
    -- fallback dot
    return New("Frame", {
        Size = UDim2.new(0,4,0,4), BackgroundColor3 = color,
        BorderSizePixel = 0, ZIndex = zIdx, Parent = parent
    })
end

-- ══════════════════════════════════════════════
-- CREATE WINDOW
-- ══════════════════════════════════════════════
function RayVinzLib:CreateWindow(cfg)
    cfg = cfg or {}
    local title    = cfg.Title    or "RayVinz"
    local subtitle = cfg.Subtitle or "Hub"
    local version  = cfg.Version  or "v1.0"
    local accent   = cfg.Accent   or T.Accent

    -- Responsive sizing
    local SIDEBAR_W  = IsMobile and 0   or 152
    local WIN_W      = IsMobile and 360 or 600
    local WIN_H      = IsMobile and 440 or 400
    local TOPBAR_H   = 38
    local BOTTOM_TAB = IsMobile and 46  or 0

    local gui = New("ScreenGui", {
        Name = "RayVinzLib", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999, IgnoreGuiInset = true,
        Parent = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer.PlayerGui
    })

    -- ── MAIN FRAME ───────────────────────────
    local main = New("Frame", {
        Name = "Main",
        Size = UDim2.new(0, WIN_W, 0, WIN_H),
        Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
        BackgroundColor3 = T.BG,
        BorderSizePixel = 0, ClipsDescendants = true,
        Parent = gui
    })
    -- Outer glow stroke
    New("UIStroke", { Color = T.AccentAlt, Thickness = 1.5, Transparency = 0.45, Parent = main })

    -- ── TOP BAR ──────────────────────────────
    local topbar = New("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, TOPBAR_H),
        BackgroundColor3 = T.Panel,
        BorderSizePixel = 0, ZIndex = 10, Parent = main
    })
    -- Bottom accent line
    local topLine = New("Frame", {
        Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 11, Parent = topbar
    })
    Gradient(topLine, accent, T.AccentAlt, 0)

    -- Icon + Title
    local iconSize  = cfg.Icon and 22 or 0
    local iconPad   = cfg.Icon and 8  or 0

    if cfg.Icon then
        local iconImg = New("ImageLabel", {
            Image                 = cfg.Icon,
            BackgroundTransparency = 1,
            Size                  = UDim2.new(0, iconSize, 0, iconSize),
            Position              = UDim2.new(0, 10, 0.5, -iconSize/2),
            ZIndex                = 12,
            Parent                = topbar
        })
        -- glow stroke around icon
        New("UIStroke", {
            Color        = accent,
            Thickness    = 1,
            Transparency = 0.5,
            Parent       = iconImg
        })
    end

    local titleX = 10 + iconSize + iconPad
    New("TextLabel", {
        Text = title, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(0, titleX, 0, 0),
        ZIndex = 11, Parent = topbar
    })
    New("TextLabel", {
        Text = "/ "..subtitle, Font = Enum.Font.Gotham, TextSize = 10,
        TextColor3 = T.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(0, titleX + 76, 0, 0),
        ZIndex = 11, Parent = topbar
    })

    -- Version badge
    local vb = New("Frame", {
        Size = UDim2.new(0,46,0,18), Position = UDim2.new(1,-120,0.5,-9),
        BackgroundColor3 = Color3.fromRGB(18,5,38),
        BorderSizePixel = 0, ZIndex = 11, Parent = topbar
    })
    New("UIStroke", { Color = T.AccentAlt, Thickness = 1, Transparency = 0.5, Parent = vb })
    New("TextLabel", {
        Text = version, Font = Enum.Font.RobotoMono, TextSize = 9,
        TextColor3 = T.AccentAlt, BackgroundTransparency = 1,
        Size = UDim2.new(1,0,1,0), ZIndex = 12, Parent = vb
    })

    -- Minimize
    local minBtn = New("TextButton", {
        Text = "─", Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = T.TextDim, BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 36, 1, 0), Position = UDim2.new(1,-72,0,0),
        ZIndex = 11, Parent = topbar
    })
    -- Close
    local closeBtn = New("TextButton", {
        Text = "✕", Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = T.TextDim, BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 36, 1, 0), Position = UDim2.new(1,-36,0,0),
        ZIndex = 11, Parent = topbar
    })
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = T.Accent end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = T.TextDim end)
    closeBtn.Activated:Connect(function()
        Sweep(topbar, T.Accent, 0.22)
        Tween(main, { Size = UDim2.new(0,WIN_W,0,0) }, 0.2)
        task.delay(0.22, function() gui:Destroy() end)
    end)
    minBtn.MouseEnter:Connect(function() minBtn.TextColor3 = T.AccentAlt end)
    minBtn.MouseLeave:Connect(function() minBtn.TextColor3 = T.TextDim end)

    MakeDraggable(topbar, main)

    -- ── BODY ─────────────────────────────────
    local body = New("Frame", {
        Name = "Body",
        Size = UDim2.new(1,0,1, -(TOPBAR_H + BOTTOM_TAB)),
        Position = UDim2.new(0,0,0,TOPBAR_H),
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = main
    })

    local minimized = false
    minBtn.Activated:Connect(function()
        minimized = not minimized
        body.Visible = not minimized
        Sweep(topbar, T.AccentAlt, 0.28)
        Tween(main, { Size = minimized and UDim2.new(0,WIN_W,0,TOPBAR_H)
                                        or  UDim2.new(0,WIN_W,0,WIN_H) }, 0.2)
    end)

    -- ── CONTENT AREA (right side / full on mobile) ──
    local contentArea = New("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
        Position = UDim2.new(0, SIDEBAR_W, 0, 0),
        BackgroundColor3 = T.BG,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = body
    })

    -- ── SIDEBAR (desktop only) ────────────────
    local tabScroll, tabsData = nil, {}
    if not IsMobile then
        local sidebar = New("Frame", {
            Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, 0),
            BackgroundColor3 = T.Panel,
            BorderSizePixel = 0, ZIndex = 5, Parent = body
        })
        -- right border
        local sb = New("Frame", {
            Size = UDim2.new(0,1,1,0), Position = UDim2.new(1,-1,0,0),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0, ZIndex = 6, Parent = sidebar
        })
        Gradient(sb, accent, T.AccentAlt, 90)

        tabScroll = New("ScrollingFrame", {
            Size = UDim2.new(1,0,1,-10), Position = UDim2.new(0,0,0,10),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = T.AccentAlt,
            ScrollBarImageTransparency = 0.5,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 6, Parent = sidebar
        })
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,3), Parent = tabScroll })
        New("UIPadding", { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), Parent = tabScroll })
    else
        -- ── MOBILE BOTTOM TAB BAR ────────────────
        local bottomBar = New("Frame", {
            Name = "BottomBar",
            Size = UDim2.new(1,0,0,BOTTOM_TAB),
            Position = UDim2.new(0,0,1,-BOTTOM_TAB),
            BackgroundColor3 = T.Panel,
            BorderSizePixel = 0, ZIndex = 5, Parent = main
        })
        New("Frame", {
            Size = UDim2.new(1,0,0,1),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0, ZIndex = 6, Parent = bottomBar
        })
        tabScroll = New("Frame", {
            Name = "TabList",
            Size = UDim2.new(1,0,1,0),
            BackgroundTransparency = 1,
            ZIndex = 6, Parent = bottomBar
        })
        New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0,2), Parent = tabScroll
        })
    end

    -- ── NOTIFICATION HOLDER ───────────────────
    local notifHolder = New("Frame", {
        Name = "Notifications",
        Size = UDim2.new(0,240,1,-10),
        Position = UDim2.new(1,-250,0,5),
        BackgroundTransparency = 1, ZIndex = 200, Parent = gui
    })
    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0,5), Parent = notifHolder
    })

    -- ══════════════════════════════════════════
    -- WINDOW OBJECT
    -- ══════════════════════════════════════════
    local window = {
        _gui = gui, _main = main, _tabScroll = tabScroll,
        _content = contentArea, _notifHolder = notifHolder,
        _accent = accent, _tabs = {},
    }

    function window:SetIconPack(pack) if Icons then Icons.SetIconsType(pack) end end

    -- ══ ADD PAGE ══════════════════════════════
    function window:AddPage(name, iconName)
        local isFirst = #self._tabs == 0

        local tabBtn
        if not IsMobile then
            -- Desktop sidebar tab
            tabBtn = New("TextButton", {
                Text = "", Size = UDim2.new(1,0,0,38),
                BackgroundColor3 = T.CardHover,
                BackgroundTransparency = isFirst and 0.3 or 1,
                BorderSizePixel = 0, ZIndex = 7, Parent = self._tabScroll
            })
            New("UIStroke", {
                Color = isFirst and accent or T.Border,
                Thickness = 1, Transparency = isFirst and 0.3 or 0.7,
                Parent = tabBtn
            })

            -- Active bar
            local strip = New("Frame", {
                Size = UDim2.new(0,2,0.55,0), Position = UDim2.new(0,0,0.225,0),
                BackgroundColor3 = accent,
                BackgroundTransparency = isFirst and 0 or 1,
                BorderSizePixel = 0, ZIndex = 8, Parent = tabBtn
            })

            -- Icon
            local tabIco
            if iconName and Icons then
                tabIco = Icon(tabBtn, iconName, 14,
                    isFirst and accent or T.TextDim, 8)
                tabIco.Position = UDim2.new(0,10,0.5,-7)
            end

            -- Label
            local tabLbl = New("TextLabel", {
                Text = name, Font = Enum.Font.GothamBold, TextSize = 11,
                TextColor3 = isFirst and T.Text or T.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Size = UDim2.new(1,-36,1,0), Position = UDim2.new(0,30,0,0),
                ZIndex = 8, Parent = tabBtn
            })

            -- Page
            local page = New("ScrollingFrame", {
                Name = "Page_"..name,
                Size = UDim2.new(1,0,1,0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 3, ScrollBarImageColor3 = T.AccentAlt,
                ScrollBarImageTransparency = 0.5,
                CanvasSize = UDim2.new(0,0,0,0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                Visible = isFirst, ClipsDescendants = true,
                Parent = self._content
            })
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,8), Parent = page })
            New("UIPadding", {
                PaddingTop = UDim.new(0,10), PaddingLeft = UDim.new(0,10),
                PaddingRight = UDim.new(0,10), PaddingBottom = UDim.new(0,10), Parent = page
            })

            local td = {
                btn = tabBtn, strip = strip, ico = tabIco,
                lbl = tabLbl, page = page,
                stroke = tabBtn:FindFirstChildOfClass("UIStroke")
            }
            table.insert(self._tabs, td)

            local function selectTab()
                for _, t in ipairs(self._tabs) do
                    Tween(t.btn, { BackgroundTransparency = 1 }, 0.14)
                    Tween(t.strip, { BackgroundTransparency = 1 }, 0.14)
                    if t.stroke then t.stroke.Color = T.Border; t.stroke.Transparency = 0.7 end
                    if t.ico then t.ico.ImageColor3 = T.TextDim end
                    t.lbl.TextColor3 = T.TextDim
                    t.page.Visible = false
                end
                Tween(tabBtn, { BackgroundTransparency = 0.3, BackgroundColor3 = T.CardHover }, 0.14)
                Tween(td.stroke, { Transparency = 0.3 }, 0.14)
                td.stroke.Color = accent
                Tween(strip, { BackgroundTransparency = 0 }, 0.14)
                if tabIco then tabIco.ImageColor3 = accent end
                tabLbl.TextColor3 = T.Text
                page.Visible = true
                Sweep(tabBtn, accent, 0.38)
            end

            tabBtn.Activated:Connect(selectTab)
            tabBtn.MouseEnter:Connect(function()
                if strip.BackgroundTransparency ~= 0 then
                    Tween(tabBtn, { BackgroundTransparency = 0.65, BackgroundColor3 = T.CardHover }, 0.12)
                end
            end)
            tabBtn.MouseLeave:Connect(function()
                if strip.BackgroundTransparency ~= 0 then
                    Tween(tabBtn, { BackgroundTransparency = 1 }, 0.12)
                end
            end)

            -- Page object builder
            local pageObj = { _frame = page, _acc = accent }
            self:_buildPage(pageObj)
            return pageObj

        else
            -- ── MOBILE BOTTOM TAB ─────────────────
            local tabW = math.floor((WIN_W - 16) / math.max(1, 1)) -- will resize after all tabs added
            tabBtn = New("TextButton", {
                Text = name, Font = Enum.Font.GothamBold, TextSize = 10,
                TextColor3 = isFirst and accent or T.TextDim,
                BackgroundColor3 = T.CardHover,
                BackgroundTransparency = isFirst and 0.3 or 1,
                BorderSizePixel = 0,
                Size = UDim2.new(0, 80, 1, -4),
                ZIndex = 7, Parent = self._tabScroll
            })
            New("UICorner", { CornerRadius = UDim.new(0,4), Parent = tabBtn })

            local page = New("ScrollingFrame", {
                Name = "Page_"..name,
                Size = UDim2.new(1,0,1,0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 3, ScrollBarImageColor3 = T.AccentAlt,
                ScrollBarImageTransparency = 0.5,
                CanvasSize = UDim2.new(0,0,0,0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                Visible = isFirst, ClipsDescendants = true,
                Parent = self._content
            })
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,8), Parent = page })
            New("UIPadding", {
                PaddingTop = UDim.new(0,10), PaddingLeft = UDim.new(0,10),
                PaddingRight = UDim.new(0,10), PaddingBottom = UDim.new(0,10), Parent = page
            })

            local td = { btn = tabBtn, page = page }
            table.insert(self._tabs, td)

            local function selectMobile()
                for _, t in ipairs(self._tabs) do
                    t.btn.TextColor3 = T.TextDim
                    Tween(t.btn, { BackgroundTransparency = 1 }, 0.14)
                    t.page.Visible = false
                end
                tabBtn.TextColor3 = accent
                Tween(tabBtn, { BackgroundTransparency = 0.3 }, 0.14)
                page.Visible = true
            end

            tabBtn.Activated:Connect(selectMobile)

            local pageObj = { _frame = page, _acc = accent }
            self:_buildPage(pageObj)
            return pageObj
        end
    end

    -- ══ BUILD PAGE (shared desktop/mobile) ════
    function window:_buildPage(pageObj)
        local acc = self._accent

        function pageObj:AddSection(name)
            -- Section wrapper
            local sec_wrap = New("Frame", {
                Name = "Sec_"..name,
                Size = UDim2.new(1,0,0,0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = T.Panel,
                BorderSizePixel = 0,
                Parent = self._frame
            })
            New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.3, Parent = sec_wrap })

            -- Section title bar
            local SEC_H = 34
            local secHead = New("Frame", {
                Size = UDim2.new(1,0,0,SEC_H),
                BackgroundColor3 = Color3.fromRGB(20, 6, 40),
                BackgroundTransparency = 0,
                BorderSizePixel = 0, ZIndex = 2, Parent = sec_wrap
            })
            -- left accent bar (taller, more visible)
            New("Frame", {
                Size = UDim2.new(0,3,0.65,0), Position = UDim2.new(0,0,0.175,0),
                BackgroundColor3 = acc, BorderSizePixel = 0, ZIndex = 3, Parent = secHead
            })
            -- section label
            New("TextLabel", {
                Text = "[ " .. name:upper() .. " ]",
                Font = Enum.Font.GothamBold, TextSize = 11,
                TextColor3 = T.TextSub, TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Size = UDim2.new(1,-14,1,0), Position = UDim2.new(0,12,0,0),
                ZIndex = 3, Parent = secHead
            })
            -- bottom gradient divider
            local divLine = New("Frame", {
                Size = UDim2.new(1,0,0,1), Position = UDim2.new(0,0,1,-1),
                BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 2, Parent = secHead
            })
            Gradient(divLine, acc, T.AccentAlt, 0)

            -- Elements container
            local elems = New("Frame", {
                Name = "Elems",
                Size = UDim2.new(1,0,0,0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.new(0,0,0,SEC_H),
                BackgroundTransparency = 1, ZIndex = 2, Parent = sec_wrap
            })
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,2), Parent = elems })
            New("UIPadding", {
                PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8),
                PaddingBottom = UDim.new(0,8), Parent = elems
            })

            -- ══ SECTION OBJECT ═════════════════
            local sec = { _e = elems, _acc = acc }

            -- ── Element row factory ─────────────
            -- Every row: tall enough for touch (min 40px), UIStroke border
            local function Row(h, autoH)
                local r = New("Frame", {
                    Size = UDim2.new(1,0,0, h or 40),
                    AutomaticSize = autoH and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
                    BackgroundColor3 = T.Card,
                    BackgroundTransparency = 0.1,
                    BorderSizePixel = 0, ZIndex = 3, Parent = sec._e
                })
                New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.5, Parent = r })
                return r
            end

            -- ── Name label (primary text) ───────
            local function LabelPrimary(parent, text, xScale, xOff)
                return New("TextLabel", {
                    Text = text, Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(xScale or 0.55, 0, 1, 0),
                    Position = UDim2.new(0, xOff or 10, 0, 0),
                    ZIndex = 4, Parent = parent
                })
            end

            -- ── Right value label ───────────────
            local function LabelRight(parent, text)
                return New("TextLabel", {
                    Text = text, Font = Enum.Font.RobotoMono, TextSize = 10,
                    TextColor3 = acc, TextXAlignment = Enum.TextXAlignment.Right,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0,70,1,0), Position = UDim2.new(1,-76,0,0),
                    ZIndex = 4, Parent = parent
                })
            end

            -- ── Hover tween helpers ─────────────
            local function Hover(row, btn)
                local function on()
                    Tween(row, { BackgroundColor3 = T.CardHover, BackgroundTransparency = 0 }, 0.12)
                    local s = row:FindFirstChildOfClass("UIStroke")
                    if s then Tween(s, { Transparency = 0.2 }, 0.12) end
                end
                local function off()
                    Tween(row, { BackgroundColor3 = T.Card, BackgroundTransparency = 0.1 }, 0.12)
                    local s = row:FindFirstChildOfClass("UIStroke")
                    if s then Tween(s, { Transparency = 0.5 }, 0.12) end
                end
                btn.MouseEnter:Connect(on)
                btn.MouseLeave:Connect(off)
            end

            -- ────────────────────────────────────
            -- BUTTON
            -- ────────────────────────────────────
            function sec:AddButton(cfg)
                cfg = cfg or {}
                local hasDesc = cfg.Description ~= nil
                local row = Row(hasDesc and 50 or 40)

                local btn = New("TextButton", {
                    Text = "", Size = UDim2.new(1,0,1,0),
                    BackgroundTransparency = 1, BorderSizePixel = 0,
                    ZIndex = 4, Parent = row
                })

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(btn, cfg.Icon, 15, T.AccentAlt, 5)
                    ic.Position = UDim2.new(0,10, 0.5, hasDesc and -15 or -7)
                    lx = 32
                end

                New("TextLabel", {
                    Text = cfg.Name or "Button", Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1,-90,0, hasDesc and 20 or 40),
                    Position = UDim2.new(0,lx,0, hasDesc and 6 or 0),
                    ZIndex = 5, Parent = btn
                })
                if hasDesc then
                    New("TextLabel", {
                        Text = cfg.Description, Font = Enum.Font.Gotham, TextSize = 10,
                        TextColor3 = T.TextSub, TextXAlignment = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1,-90,0,18),
                        Position = UDim2.new(0,lx,0,26),
                        ZIndex = 5, Parent = btn
                    })
                end

                -- Run badge
                local runBadge = New("Frame", {
                    Size = UDim2.new(0,46,0,20),
                    Position = UDim2.new(1,-52,0.5,-10),
                    BackgroundColor3 = T.BG,
                    BorderSizePixel = 0, ZIndex = 5, Parent = btn
                })
                New("UIStroke", { Color = T.AccentAlt, Thickness = 1, Transparency = 0.3, Parent = runBadge })
                local runLbl = New("TextLabel", {
                    Text = "RUN", Font = Enum.Font.RobotoMono, TextSize = 9,
                    TextColor3 = T.AccentAlt, BackgroundTransparency = 1,
                    Size = UDim2.new(1,0,1,0), ZIndex = 6, Parent = runBadge
                })

                btn.Activated:Connect(function()
                    Sweep(row, acc, 0.40)
                    Tween(runBadge, { BackgroundColor3 = acc }, 0.08)
                    Tween(runLbl,   { TextColor3 = T.Text    }, 0.08)
                    task.delay(0.32, function()
                        Tween(runBadge, { BackgroundColor3 = T.BG      }, 0.2)
                        Tween(runLbl,   { TextColor3 = T.AccentAlt     }, 0.2)
                    end)
                    if cfg.Callback then task.spawn(cfg.Callback) end
                end)
                Hover(row, btn)

                return { Fire = function() if cfg.Callback then task.spawn(cfg.Callback) end end }
            end

            -- ────────────────────────────────────
            -- TOGGLE
            -- ────────────────────────────────────
            function sec:AddToggle(cfg)
                cfg = cfg or {}
                local state = cfg.Default or false
                local row   = Row(40)

                local btn = New("TextButton", {
                    Text = "", Size = UDim2.new(1,0,1,0),
                    BackgroundTransparency = 1, BorderSizePixel = 0,
                    ZIndex = 4, Parent = row
                })

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(btn, cfg.Icon, 15, T.AccentAlt, 5)
                    ic.Position = UDim2.new(0,10,0.5,-7); lx = 32
                end
                LabelPrimary(btn, cfg.Name or "Toggle", 0.6, lx)

                -- Track (pill shape, 2px corner)
                local track = New("Frame", {
                    Size = UDim2.new(0,40,0,20),
                    Position = UDim2.new(1,-50,0.5,-10),
                    BackgroundColor3 = T.Border,
                    BorderSizePixel = 0, ZIndex = 5, Parent = btn
                })
                New("UICorner", { CornerRadius = UDim.new(0,3), Parent = track })
                New("UIStroke", { Color = T.BorderBright, Thickness = 1, Transparency = 0.6, Parent = track })

                -- Knob
                local knob = New("Frame", {
                    Size = UDim2.new(0,14,0,14),
                    Position = UDim2.new(0,3,0.5,-7),
                    BackgroundColor3 = T.TextDim,
                    BorderSizePixel = 0, ZIndex = 6, Parent = track
                })
                New("UICorner", { CornerRadius = UDim.new(0,2), Parent = knob })

                local function applyState(s, silent)
                    state = s
                    if state then
                        Tween(knob,  { Position = UDim2.new(0,23,0.5,-7), BackgroundColor3 = acc }, 0.16)
                        Tween(track, { BackgroundColor3 = Color3.fromRGB(40,5,80) }, 0.16)
                        Sweep(row, acc, 0.35)
                    else
                        Tween(knob,  { Position = UDim2.new(0,3,0.5,-7), BackgroundColor3 = T.TextDim }, 0.16)
                        Tween(track, { BackgroundColor3 = T.Border }, 0.16)
                        Sweep(row, T.AccentAlt, 0.35)
                    end
                    if not silent and cfg.Callback then cfg.Callback(state) end
                end
                applyState(state, true)

                btn.Activated:Connect(function() applyState(not state) end)
                Hover(row, btn)

                local o = {}
                function o:Set(v) applyState(v, true) end
                function o:Get() return state end
                return o
            end

            -- ────────────────────────────────────
            -- SLIDER
            -- ────────────────────────────────────
            function sec:AddSlider(cfg)
                cfg = cfg or {}
                local mn  = cfg.Min or 0
                local mx  = cfg.Max or 100
                local inc = cfg.Increment or 1
                local sfx = cfg.Suffix or ""
                local val = math.clamp(cfg.Default or mn, mn, mx)
                local row = Row(52)

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(row, cfg.Icon, 14, T.AccentAlt, 4)
                    ic.Position = UDim2.new(0,10,0,10); lx = 30
                end

                New("TextLabel", {
                    Text = cfg.Name or "Slider", Font = Enum.Font.GothamBold, TextSize = 12,
                    TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1,-80,0,24),
                    Position = UDim2.new(0,lx,0,6),
                    ZIndex = 4, Parent = row
                })

                local valLbl = New("TextLabel", {
                    Text = tostring(val)..sfx, Font = Enum.Font.RobotoMono, TextSize = 11,
                    TextColor3 = acc, TextXAlignment = Enum.TextXAlignment.Right,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0,64,0,24), Position = UDim2.new(1,-70,0,6),
                    ZIndex = 4, Parent = row
                })

                -- Track bg
                local trackBG = New("Frame", {
                    Size = UDim2.new(1,-20,0,4),
                    Position = UDim2.new(0,10,1,-14),
                    BackgroundColor3 = T.Border,
                    BorderSizePixel = 0, ZIndex = 4, Parent = row
                })
                New("UIStroke", { Color = T.BorderBright, Thickness = 1, Transparency = 0.6, Parent = trackBG })

                local fill = New("Frame", {
                    Size = UDim2.new((val-mn)/(mx-mn),0,1,0),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0, ZIndex = 5, Parent = trackBG
                })
                Gradient(fill, acc, T.AccentAlt, 0)

                local knob = New("Frame", {
                    Size = UDim2.new(0,10,0,10),
                    Position = UDim2.new((val-mn)/(mx-mn),-5,0.5,-5),
                    BackgroundColor3 = T.Text,
                    BorderSizePixel = 0, ZIndex = 6, Parent = trackBG
                })
                New("UIStroke", { Color = acc, Thickness = 1.5, Transparency = 0.2, Parent = knob })

                local dragging = false
                local function snap(v) return math.clamp(math.floor(v/inc+0.5)*inc, mn, mx) end
                local function updateVal(input)
                    local rx = trackBG.AbsolutePosition.X
                    local rw = trackBG.AbsoluteSize.X
                    val = snap(mn + math.clamp((input.Position.X - rx)/rw, 0, 1)*(mx-mn))
                    local p = (val-mn)/(mx-mn)
                    fill.Size = UDim2.new(p,0,1,0)
                    knob.Position = UDim2.new(p,-5,0.5,-5)
                    valLbl.Text = tostring(val)..sfx
                    if cfg.Callback then cfg.Callback(val) end
                end

                trackBG.InputBegan:Connect(function(i)
                    if isClick(i) then dragging = true; Sweep(row,acc,0.28); updateVal(i) end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if dragging and isMove(i) then updateVal(i) end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if isRelease(i) then dragging = false end
                end)

                local o = {}
                function o:Set(v)
                    val = math.clamp(v,mn,mx)
                    local p = (val-mn)/(mx-mn)
                    fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,-5,0.5,-5)
                    valLbl.Text = tostring(val)..sfx
                end
                function o:Get() return val end
                return o
            end

            -- ────────────────────────────────────
            -- DROPDOWN
            -- ────────────────────────────────────
            function sec:AddDropdown(cfg)
                cfg = cfg or {}
                local opts = cfg.Options or {}
                local sel  = cfg.Default or (opts[1] or "None")
                local open = false
                local IH   = 36   -- item height (touch-friendly)

                local wrapper = New("Frame", {
                    Size = UDim2.new(1,0,0,40),
                    BackgroundColor3 = T.Card, BackgroundTransparency = 0.1,
                    BorderSizePixel = 0, ClipsDescendants = true,
                    ZIndex = 3, Parent = sec._e
                })
                New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.5, Parent = wrapper })

                local hdr = New("TextButton", {
                    Text = "", Size = UDim2.new(1,0,0,40),
                    BackgroundTransparency = 1, BorderSizePixel = 0,
                    ZIndex = 4, Parent = wrapper
                })

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(hdr, cfg.Icon, 14, T.AccentAlt, 5)
                    ic.Position = UDim2.new(0,10,0.5,-7); lx = 30
                end
                LabelPrimary(hdr, cfg.Name or "Dropdown", 0.42, lx)

                local selLbl = New("TextLabel", {
                    Text = sel, Font = Enum.Font.Gotham, TextSize = 11,
                    TextColor3 = acc, TextXAlignment = Enum.TextXAlignment.Right,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.4,-26,1,0), Position = UDim2.new(0.55,0,0,0),
                    ZIndex = 4, Parent = hdr
                })
                local arrow = New("TextLabel", {
                    Text = "▾", Font = Enum.Font.GothamBold, TextSize = 11,
                    TextColor3 = T.TextDim, BackgroundTransparency = 1,
                    Size = UDim2.new(0,22,1,0), Position = UDim2.new(1,-22,0,0),
                    ZIndex = 4, Parent = hdr
                })

                -- Options panel
                local panel = New("Frame", {
                    Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,0,40),
                    BackgroundColor3 = T.Panel, BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Visible = false, ZIndex = 10, Parent = wrapper
                })
                New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.3, Parent = panel })
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

                local function buildOpts()
                    for _, c in pairs(panel:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for _, opt in ipairs(opts) do
                        local ob = New("TextButton", {
                            Text = opt, Font = Enum.Font.Gotham, TextSize = 11,
                            TextColor3 = (opt == sel) and acc or T.TextSub,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            BackgroundColor3 = T.Card, BackgroundTransparency = 1,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1,0,0,IH), ZIndex = 11, Parent = panel
                        })
                        New("UIPadding", { PaddingLeft = UDim.new(0,14), Parent = ob })
                        ob.Activated:Connect(function()
                            sel = opt; selLbl.Text = opt
                            open = false; wrapper.ClipsDescendants = true
                            wrapper.Size = UDim2.new(1,0,0,40)
                            panel.Visible = false; arrow.Text = "▾"
                            buildOpts()
                            Sweep(wrapper, acc, 0.36)
                            if cfg.Callback then cfg.Callback(sel) end
                        end)
                        ob.MouseEnter:Connect(function()
                            Tween(ob, { BackgroundColor3 = T.CardHover, BackgroundTransparency = 0 }, 0.1)
                        end)
                        ob.MouseLeave:Connect(function() Tween(ob, { BackgroundTransparency = 1 }, 0.1) end)
                    end
                end
                buildOpts()

                hdr.Activated:Connect(function()
                    open = not open
                    if open then
                        wrapper.ClipsDescendants = false
                        wrapper.Size = UDim2.new(1,0,0, 40 + #opts*IH)
                        panel.Visible = true; arrow.Text = "▴"
                        Sweep(wrapper, T.AccentAlt, 0.3)
                    else
                        wrapper.ClipsDescendants = true
                        wrapper.Size = UDim2.new(1,0,0,40)
                        panel.Visible = false; arrow.Text = "▾"
                    end
                end)
                hdr.MouseEnter:Connect(function()
                    Tween(wrapper, { BackgroundColor3 = T.CardHover, BackgroundTransparency = 0 }, 0.12)
                end)
                hdr.MouseLeave:Connect(function()
                    Tween(wrapper, { BackgroundColor3 = T.Card, BackgroundTransparency = 0.1 }, 0.12)
                end)

                local o = {}
                function o:Set(v) sel = v; selLbl.Text = v; buildOpts() end
                function o:Get() return sel end
                function o:Refresh(n) opts = n; buildOpts() end
                return o
            end

            -- ────────────────────────────────────
            -- INPUT
            -- ────────────────────────────────────
            function sec:AddInput(cfg)
                cfg = cfg or {}
                local row = Row(40)

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(row, cfg.Icon, 14, T.AccentAlt, 4)
                    ic.Position = UDim2.new(0,10,0.5,-7); lx = 30
                end
                LabelPrimary(row, cfg.Name or "Input", 0.36, lx)

                local box = New("TextBox", {
                    Text = cfg.Default or "",
                    PlaceholderText = cfg.Placeholder or "type here...",
                    Font = Enum.Font.Gotham, TextSize = 11,
                    TextColor3 = T.Text, PlaceholderColor3 = T.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BackgroundColor3 = T.BG, BackgroundTransparency = 0,
                    BorderSizePixel = 0, ClearTextOnFocus = false,
                    Size = UDim2.new(0.58,0,0.65,0), Position = UDim2.new(0.4,0,0.175,0),
                    ZIndex = 4, Parent = row
                })
                New("UIPadding", { PaddingLeft = UDim.new(0,6), Parent = box })
                local stroke = New("UIStroke", { Color = T.Border, Thickness = 1, Parent = box })

                box.Focused:Connect(function()
                    Tween(stroke, { Color = acc, Transparency = 0 }, 0.15)
                    Sweep(row, acc, 0.3)
                end)
                box.FocusLost:Connect(function(e)
                    Tween(stroke, { Color = T.Border }, 0.15)
                    if cfg.Callback then cfg.Callback(box.Text, e) end
                end)

                local o = {}
                function o:Set(v) box.Text = v end
                function o:Get() return box.Text end
                return o
            end

            -- ────────────────────────────────────
            -- KEYBIND
            -- ────────────────────────────────────
            function sec:AddKeybind(cfg)
                cfg = cfg or {}
                local key       = cfg.Default or Enum.KeyCode.Unknown
                local listening = false
                local row       = Row(40)

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(row, cfg.Icon, 14, T.AccentAlt, 4)
                    ic.Position = UDim2.new(0,10,0.5,-7); lx = 30
                end
                LabelPrimary(row, cfg.Name or "Keybind", 0.55, lx)

                local badge = New("TextButton", {
                    Text = key.Name, Font = Enum.Font.RobotoMono, TextSize = 10,
                    TextColor3 = acc, BackgroundColor3 = T.BG,
                    BackgroundTransparency = 0, BorderSizePixel = 0,
                    Size = UDim2.new(0,76,0,24),
                    Position = UDim2.new(1,-82,0.5,-12),
                    ZIndex = 4, Parent = row
                })
                New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.4, Parent = badge })

                badge.Activated:Connect(function()
                    listening = true; badge.Text = "..."; badge.TextColor3 = T.Warning
                    Sweep(row, T.Warning, 0.3)
                end)
                UserInputService.InputBegan:Connect(function(inp, gp)
                    if listening and not gp and inp.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false; key = inp.KeyCode
                        badge.Text = key.Name; badge.TextColor3 = acc
                        Sweep(row, acc, 0.35)
                        if cfg.Callback then cfg.Callback(key) end
                    elseif not listening and not gp and inp.KeyCode == key then
                        if cfg.OnPress then task.spawn(cfg.OnPress) end
                    end
                end)

                local o = {}
                function o:Get() return key end
                function o:Set(k) key = k; badge.Text = k.Name end
                return o
            end

            -- ────────────────────────────────────
            -- COLORPICKER
            -- ────────────────────────────────────
            function sec:AddColorpicker(cfg)
                cfg = cfg or {}
                local color = cfg.Default or Color3.fromRGB(255,38,60)
                local open  = false
                local row   = Row(40)

                local lx = 10
                if cfg.Icon then
                    local ic = Icon(row, cfg.Icon, 14, T.AccentAlt, 4)
                    ic.Position = UDim2.new(0,10,0.5,-7); lx = 30
                end
                LabelPrimary(row, cfg.Name or "Color", 0.6, lx)

                local prev = New("TextButton", {
                    Text = "", Size = UDim2.new(0,28,0,22),
                    Position = UDim2.new(1,-34,0.5,-11),
                    BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 4, Parent = row
                })
                New("UIStroke", { Color = T.BorderBright, Thickness = 1, Transparency = 0.3, Parent = prev })

                local panel = New("Frame", {
                    Size = UDim2.new(1,0,0, 18*3+4*2+14),
                    BackgroundColor3 = T.Panel,
                    BorderSizePixel = 0, ZIndex = 3, Visible = false,
                    Parent = sec._e
                })
                New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.3, Parent = panel })
                New("UIPadding", { PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10), PaddingTop = UDim.new(0,8), PaddingBottom = UDim.new(0,8), Parent = panel })
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,5), Parent = panel })

                local rgb = {color.R*255, color.G*255, color.B*255}
                local sli = {}
                local function upd()
                    color = Color3.fromRGB(rgb[1],rgb[2],rgb[3])
                    prev.BackgroundColor3 = color
                    if cfg.Callback then cfg.Callback(color) end
                end
                for i, ch in ipairs({"R","G","B"}) do
                    local cr = New("Frame", {Size = UDim2.new(1,0,0,18), BackgroundTransparency=1, ZIndex=4, Parent=panel})
                    New("TextLabel",{Text=ch,Font=Enum.Font.RobotoMono,TextSize=10,TextColor3=T.TextDim,BackgroundTransparency=1,Size=UDim2.new(0,14,1,0),ZIndex=5,Parent=cr})
                    local ct = New("Frame",{Size=UDim2.new(1,-40,0,4),Position=UDim2.new(0,16,0.5,-2),BackgroundColor3=T.Border,BorderSizePixel=0,ZIndex=5,Parent=cr})
                    local cf = New("Frame",{Size=UDim2.new(rgb[i]/255,0,1,0),BackgroundColor3=acc,BorderSizePixel=0,ZIndex=6,Parent=ct})
                    local ck = New("Frame",{Size=UDim2.new(0,8,0,8),Position=UDim2.new(rgb[i]/255,-4,0.5,-4),BackgroundColor3=T.Text,BorderSizePixel=0,ZIndex=7,Parent=ct})
                    New("UIStroke",{Color=acc,Thickness=1.5,Transparency=0.3,Parent=ck})
                    local cv = New("TextLabel",{Text=tostring(math.floor(rgb[i])),Font=Enum.Font.RobotoMono,TextSize=9,TextColor3=acc,BackgroundTransparency=1,Size=UDim2.new(0,24,1,0),Position=UDim2.new(1,2,0,0),ZIndex=5,Parent=cr})
                    local d2=false; local mi=i
                    local function go(inp)
                        local p=math.clamp((inp.Position.X-ct.AbsolutePosition.X)/ct.AbsoluteSize.X,0,1)
                        rgb[mi]=p*255;cf.Size=UDim2.new(p,0,1,0);ck.Position=UDim2.new(p,-4,0.5,-4);cv.Text=tostring(math.floor(rgb[mi]));upd()
                    end
                    ct.InputBegan:Connect(function(inp) if isClick(inp) then d2=true;go(inp) end end)
                    UserInputService.InputChanged:Connect(function(inp) if d2 and isMove(inp) then go(inp) end end)
                    UserInputService.InputEnded:Connect(function(inp) if isRelease(inp) then d2=false end end)
                    sli[i]={f=cf,k=ck,l=cv}
                end

                prev.Activated:Connect(function()
                    open = not open; panel.Visible = open
                    if open then Sweep(panel,acc,0.4) end
                end)

                local o = {}
                function o:Get() return color end
                function o:Set(c)
                    color=c; prev.BackgroundColor3=c
                    rgb={c.R*255,c.G*255,c.B*255}
                    for i,s in ipairs(sli) do
                        local p=rgb[i]/255
                        s.f.Size=UDim2.new(p,0,1,0);s.k.Position=UDim2.new(p,-4,0.5,-4);s.l.Text=tostring(math.floor(rgb[i]))
                    end
                end
                return o
            end

            -- ────────────────────────────────────
            -- PARAGRAPH
            -- ────────────────────────────────────
            function sec:AddParagraph(cfg)
                cfg = cfg or {}
                local f = New("Frame", {
                    Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = T.Card, BackgroundTransparency = 0.1,
                    BorderSizePixel = 0, ZIndex = 3, Parent = sec._e
                })
                New("UIStroke", { Color = T.Border, Thickness = 1, Transparency = 0.5, Parent = f })
                New("UIPadding", {
                    PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),
                    PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,10),Parent=f
                })
                local inner = New("Frame", {Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=4,Parent=f})
                New("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4),Parent=inner})
                if cfg.Title then
                    New("TextLabel",{Text=cfg.Title,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=T.Text,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=4,Parent=inner})
                end
                if cfg.Content then
                    New("TextLabel",{Text=cfg.Content,Font=Enum.Font.Gotham,TextSize=11,TextColor3=T.TextSub,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,ZIndex=4,Parent=inner})
                end
            end

            -- ────────────────────────────────────
            -- DIVIDER
            -- ────────────────────────────────────
            function sec:AddDivider()
                local d = New("Frame", {
                    Size=UDim2.new(1,-16,0,1),
                    BackgroundColor3=Color3.new(1,1,1),
                    BorderSizePixel=0,ZIndex=3,Parent=sec._e
                })
                Gradient(d, acc, T.AccentAlt, 0)
            end

            -- ────────────────────────────────────
            -- SPACE
            -- ────────────────────────────────────
            function sec:AddSpace(h)
                New("Frame",{Size=UDim2.new(1,0,0,h or 8),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3,Parent=sec._e})
            end

            return sec
        end -- AddSection
    end -- _buildPage

    -- ══ NOTIFY ════════════════════════════════
    function window:Notify(cfg)
        cfg = cfg or {}
        local nt  = cfg.Type or "info"
        local nc  = (nt=="success" and T.Success) or (nt=="warning" and T.Warning)
                 or (nt=="error"   and T.Error)   or T.AccentAlt
        local dur = cfg.Duration or 4

        local card = New("Frame", {
            Name = "Notif", Size = UDim2.new(1,0,0,64),
            BackgroundColor3 = T.Panel, BorderSizePixel = 0,
            ClipsDescendants = true, ZIndex = 200, Parent = self._notifHolder
        })
        New("UIStroke", { Color = nc, Thickness = 1.5, Transparency = 0.35, Parent = card })
        New("Frame", { Size=UDim2.new(0,3,1,0), BackgroundColor3=nc, BorderSizePixel=0, ZIndex=201, Parent=card })

        if cfg.Icon and Icons then
            local ni = Icon(card, cfg.Icon, 16, nc, 201)
            ni.Position = UDim2.new(1,-22,0.5,-8)
        end

        New("TextLabel",{Text=cfg.Title or "Notification",Font=Enum.Font.GothamBold,TextSize=12,TextColor3=T.Text,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Size=UDim2.new(1,-38,0,22),Position=UDim2.new(0,14,0,9),ZIndex=201,Parent=card})
        New("TextLabel",{Text=cfg.Content or "",Font=Enum.Font.Gotham,TextSize=10,TextColor3=T.TextSub,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,BackgroundTransparency=1,Size=UDim2.new(1,-38,0,22),Position=UDim2.new(0,14,0,31),ZIndex=201,Parent=card})

        local pgBG = New("Frame",{Size=UDim2.new(1,-14,0,2),Position=UDim2.new(0,14,1,-4),BackgroundColor3=T.Border,BorderSizePixel=0,ZIndex=201,Parent=card})
        local pgFl = New("Frame",{Size=UDim2.new(1,0,1,0),BackgroundColor3=nc,BorderSizePixel=0,ZIndex=202,Parent=pgBG})

        Sweep(card, nc, 0.48)
        Tween(pgFl, { Size=UDim2.new(0,0,1,0) }, dur, Enum.EasingStyle.Linear)
        task.delay(dur, function()
            Tween(card, { BackgroundTransparency=1, Size=UDim2.new(1,0,0,0) }, 0.26)
            task.delay(0.28, function() card:Destroy() end)
        end)
    end

    function window:Destroy() self._gui:Destroy() end

    -- ══════════════════════════════════════════
    -- INTRO ANIMATION
    -- cfg.Intro = true  (default on)
    -- cfg.Intro = false (skip)
    -- ══════════════════════════════════════════
    if cfg.Intro ~= false then
        main.Visible = false  -- hide until intro finishes

        -- ── Full-screen intro overlay ─────────
        local overlay = New("Frame", {
            Name             = "Intro",
            Size             = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0,
            ZIndex           = 900,
            BorderSizePixel  = 0,
            Parent           = gui
        })

        -- Subtle grid background
        New("Frame", {
            Size = UDim2.new(1,0,1,0),
            BackgroundTransparency = 1,
            ZIndex = 901,
            Parent = overlay
        })

        -- Scan lines overlay
        New("Frame", {
            Size = UDim2.new(1,0,1,0),
            BackgroundColor3 = Color3.fromRGB(0,0,0),
            BackgroundTransparency = 0.88,
            ZIndex = 901,
            BorderSizePixel = 0,
            Parent = overlay
        })

        -- Center container — everything lives inside this 220px tall box
        local CW = IsMobile and 260 or 300
        local CH = cfg.Icon and 130 or 100
        local center = New("Frame", {
            Size = UDim2.new(0, CW, 0, CH),
            Position = UDim2.new(0.5, -CW/2, 0.5, -CH/2),
            BackgroundTransparency = 1, ZIndex = 902, Parent = overlay
        })

        -- Top accent bar
        local topAccent = New("Frame", {
            Size = UDim2.new(0, 0, 0, 1),
            Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0, ZIndex = 903, Parent = center
        })
        Gradient(topAccent, accent, T.AccentAlt, 0)

        -- Bottom accent bar
        local botAccent = New("Frame", {
            Size = UDim2.new(0, 0, 0, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0, ZIndex = 903, Parent = center
        })
        Gradient(botAccent, T.AccentAlt, accent, 0)

        -- Icon (if provided) — small, above title
        local contentOffY = 8
        if cfg.Icon then
            local introIcon = New("ImageLabel", {
                Image = cfg.Icon,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 28, 0, 28),
                Position = UDim2.new(0.5, -14, 0, contentOffY),
                ImageTransparency = 1,
                ZIndex = 903, Parent = center
            })
            Tween(introIcon, { ImageTransparency = 0 }, 0.4)
            contentOffY = contentOffY + 34
        end

        -- Hub name — glitch-reveal
        local nameLabel = New("TextLabel", {
            Text = "",
            Font = Enum.Font.GothamBlack,
            TextSize = IsMobile and 20 or 24,
            TextColor3 = T.Text,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, contentOffY),
            ZIndex = 903, Parent = center
        })

        -- Subtitle
        local subLabel = New("TextLabel", {
            Text = "",
            Font = Enum.Font.RobotoMono,
            TextSize = 9,
            TextColor3 = T.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.new(0, 0, 0, contentOffY + 31),
            ZIndex = 903, Parent = center
        })

        -- Progress track
        local progTrack = New("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, -20),
            BackgroundColor3 = T.Border,
            BorderSizePixel = 0, ZIndex = 903, Parent = center
        })
        local progFill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0, ZIndex = 904, Parent = progTrack
        })
        Gradient(progFill, accent, T.AccentAlt, 0)

        -- Status text
        local statusLabel = New("TextLabel", {
            Text = "INITIALIZING...",
            Font = Enum.Font.RobotoMono,
            TextSize = 8,
            TextColor3 = T.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 12),
            Position = UDim2.new(0, 0, 1, -12),
            ZIndex = 903, Parent = center
        })

        -- Version bottom-right of overlay
        New("TextLabel", {
            Text = version,
            Font = Enum.Font.RobotoMono,
            TextSize = 8,
            TextColor3 = T.TextDim,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -16, 0, 14),
            Position = UDim2.new(0, 0, 1, -18),
            ZIndex = 902, Parent = overlay
        })

        -- ── RUN THE SEQUENCE ─────────────────
        task.spawn(function()
            local GLITCH = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@!%&?"
            local titleUp = title:upper()

            -- Expand accent bars
            Tween(topAccent, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 0) }, 0.3)
            Tween(botAccent, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0) }, 0.3)
            task.wait(0.22)

            -- Glitch reveal title
            local FRAMES = 18
            for f = 1, FRAMES do
                local out = ""
                local ratio = f / FRAMES
                for i = 1, #titleUp do
                    if i / #titleUp <= ratio then
                        out = out .. titleUp:sub(i, i)
                    else
                        local r = math.random(1, #GLITCH)
                        out = out .. GLITCH:sub(r, r)
                    end
                end
                nameLabel.Text = out
                if math.random() < 0.25 then
                    nameLabel.TextColor3 = math.random() < 0.5 and accent or T.AccentAlt
                else
                    nameLabel.TextColor3 = T.Text
                end
                task.wait(0.030)
            end
            nameLabel.Text       = titleUp
            nameLabel.TextColor3 = T.Text
            subLabel.Text        = subtitle:upper()

            task.wait(0.08)

            -- Progress fill + status messages
            local statuses  = { "LOADING MODULES...", "CONNECTING...", "VERIFYING...", "READY" }
            local fillTime  = 0.50
            Tween(progFill, { Size = UDim2.new(1, 0, 1, 0) }, fillTime, Enum.EasingStyle.Quad)
            for _, s in ipairs(statuses) do
                statusLabel.Text = s
                task.wait(fillTime / #statuses)
            end

            task.wait(0.12)

            -- Sweep flash
            Sweep(overlay, accent, 0.32)
            task.wait(0.16)

            -- Contract bars
            Tween(topAccent, { Size = UDim2.new(0, 0, 0, 1), Position = UDim2.new(0.5, 0, 0, 0) }, 0.24)
            Tween(botAccent, { Size = UDim2.new(0, 0, 0, 1), Position = UDim2.new(0.5, 0, 1, 0) }, 0.24)

            -- Fade out overlay (fix: split TextLabel and ImageLabel properly)
            Tween(overlay, { BackgroundTransparency = 1 }, 0.28)
            for _, c in pairs(overlay:GetDescendants()) do
                if c:IsA("TextLabel") then
                    Tween(c, { TextTransparency = 1 }, 0.26)
                elseif c:IsA("ImageLabel") then
                    Tween(c, { ImageTransparency = 1 }, 0.26)
                elseif c:IsA("Frame") then
                    Tween(c, { BackgroundTransparency = 1 }, 0.26)
                end
            end
            task.wait(0.30)
            overlay:Destroy()

            -- ── Pop-in the main window ────────
            main.Visible  = true
            main.Size     = UDim2.new(0, WIN_W * 0.6, 0, WIN_H * 0.6)
            main.Position = UDim2.new(0.5, -(WIN_W * 0.6)/2, 0.5, -(WIN_H * 0.6)/2)
            main.BackgroundTransparency = 1

            Tween(main, {
                Size     = UDim2.new(0, WIN_W, 0, WIN_H),
                Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2),
                BackgroundTransparency = 0,
            }, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

            -- Restore UIStroke after transparency reset
            local stroke = main:FindFirstChildOfClass("UIStroke")
            if stroke then
                stroke.Transparency = 1
                Tween(stroke, { Transparency = 0.45 }, 0.28)
            end
        end)
    end

    return window
end

return RayVinzLib

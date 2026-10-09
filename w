--============================================================
--  Furwon Hub — Clean Card UI
--============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--============================================================
-- 1) 설정
--============================================================
local Settings = {
    enabled=false, fovRadius=220, maxDistance=900,
    visibleOnly=false, ignoreTeams=true, showFov=true,
    aimSpeed=0.85, fireRate=0.12, autoFire=true,
    scanInterval=0.08, keepMargin=100,
    espEnabled=false, espShowDist=true, espShowHp=true,
    espMaxDist=1000, espShowEnemy=true, espShowAlly=true,
    espShowNeutral=true,
}

--============================================================
-- 2) 상태
--============================================================
local State = {
    target=nil, targetChar=nil, anyInFov=false,
    lastScan=0, lastFire=0,
    originalCam=camera.CameraType, camLocked=false,
    espTags={},
}

--============================================================
-- 3) 팀 판정
--============================================================
local function getRelation(other)
    if not player.Team or not other.Team then return "neutral" end
    if player.Team == other.Team then return "ally" end
    return "enemy"
end
local function relationColor(rel)
    if rel=="enemy" then return Color3.fromRGB(255,70,70)
    elseif rel=="ally" then return Color3.fromRGB(80,160,255)
    else return Color3.fromRGB(90,230,120) end
end
local function shouldEspShow(rel)
    if rel=="enemy" then return Settings.espShowEnemy end
    if rel=="ally"  then return Settings.espShowAlly end
    return Settings.espShowNeutral
end

--============================================================
-- 4) 팔레트
--============================================================
local C = {
    bg      = Color3.fromRGB(20,21,26),
    card    = Color3.fromRGB(30,32,40),
    cardHi  = Color3.fromRGB(40,42,52),
    stroke  = Color3.fromRGB(56,58,70),
    text    = Color3.fromRGB(235,238,246),
    dim     = Color3.fromRGB(150,154,168),
    accent  = Color3.fromRGB(90,170,255),
    green   = Color3.fromRGB(80,210,130),
    red     = Color3.fromRGB(255,90,100),
    blue    = Color3.fromRGB(90,160,255),
    off     = Color3.fromRGB(60,63,76),
}

--============================================================
-- 5) GUI 루트
--============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FurwonHubUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- FOV 링
local fovFrame = Instance.new("Frame")
fovFrame.AnchorPoint = Vector2.new(0.5,0.5)
fovFrame.Position = UDim2.fromScale(0.5,0.5)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = false
fovFrame.ZIndex = 1
fovFrame.Parent = gui
local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 2
fovStroke.Color = C.accent
fovStroke.Transparency = 0.35
fovStroke.Parent = fovFrame
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1,0)

local function updateFovVisual()
    fovFrame.Size = UDim2.fromOffset(Settings.fovRadius*2, Settings.fovRadius*2)
    fovFrame.Visible = Settings.showFov and Settings.enabled
end
updateFovVisual()

--============================================================
-- 6) 플로팅 토글 버튼
--============================================================
local fab = Instance.new("TextButton")
fab.Size = UDim2.fromOffset(56,56)
fab.Position = UDim2.new(0, 20, 0, 20)
fab.BackgroundColor3 = C.card
fab.BorderSizePixel = 0
fab.Text = "💥"
fab.TextColor3 = C.accent
fab.Font = Enum.Font.GothamBold
fab.TextSize = 26
fab.AutoButtonColor = false
fab.ZIndex = 20
fab.Visible = false
fab.Parent = gui
Instance.new("UICorner", fab).CornerRadius = UDim.new(1,0)
local fabStroke = Instance.new("UIStroke")
fabStroke.Color = C.stroke
fabStroke.Thickness = 1.5
fabStroke.Parent = fab

local fabDot = Instance.new("Frame")
fabDot.AnchorPoint = Vector2.new(1,0)
fabDot.Position = UDim2.new(1, -4, 0, 4)
fabDot.Size = UDim2.fromOffset(12,12)
fabDot.BackgroundColor3 = C.red
fabDot.BorderSizePixel = 0
fabDot.ZIndex = 21
fabDot.Parent = fab
Instance.new("UICorner", fabDot).CornerRadius = UDim.new(1,0)
local fabDotStroke = Instance.new("UIStroke")
fabDotStroke.Color = C.card
fabDotStroke.Thickness = 2
fabDotStroke.Parent = fabDot

local function refreshFabDot()
    fabDot.BackgroundColor3 = (Settings.enabled or Settings.espEnabled) and C.green or C.red
end
refreshFabDot()

--============================================================
-- 6-1) FAB 드래그
--============================================================
local fabDragging = false
local fabStartPos, fabStartMouse = nil, nil
local fabMoved = false

fab.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        fabDragging = true
        fabMoved = false
        fabStartPos = fab.Position
        fabStartMouse = input.Position
    end
end)

fab.InputChanged:Connect(function(input)
    if not fabDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - fabStartMouse
        if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
            fabMoved = true
        end
        if fabMoved then
            fab.Position = UDim2.new(
                fabStartPos.X.Scale, fabStartPos.X.Offset + delta.X,
                fabStartPos.Y.Scale, fabStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

fab.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        fabDragging = false
    end
end)

--============================================================
-- 7) 메인 패널
--============================================================
local PW, PH = 340, 500
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(PW, PH)
panel.Position = UDim2.new(0, 90, 0, 20)
panel.BackgroundColor3 = C.bg
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 30
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,18)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = C.stroke
panelStroke.Thickness = 1
panelStroke.Transparency = 0.1
panelStroke.Parent = panel

-- 헤더
local header = Instance.new("TextButton")
header.Size = UDim2.new(1,0,0,52)
header.BackgroundTransparency = 1
header.Text = ""
header.AutoButtonColor = false
header.ZIndex = 31
header.Parent = panel

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(32,32)
logo.Position = UDim2.new(0, 16, 0.5, -16)
logo.BackgroundColor3 = C.accent
logo.BorderSizePixel = 0
logo.ZIndex = 32
logo.Parent = header
Instance.new("UICorner", logo).CornerRadius = UDim.new(0,10)

local logoIcon = Instance.new("TextLabel")
logoIcon.Size = UDim2.new(1,0,1,0)
logoIcon.BackgroundTransparency = 1
logoIcon.Text = "🎯"
logoIcon.TextSize = 16
logoIcon.ZIndex = 33
logoIcon.Parent = logo

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -110, 0, 20)
titleLbl.Position = UDim2.new(0, 58, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Furwon Hub"
titleLbl.TextColor3 = C.text
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 15
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 32
titleLbl.Parent = header

local subLbl = Instance.new("TextLabel")
subLbl.Size = UDim2.new(1, -110, 0, 14)
subLbl.Position = UDim2.new(0, 58, 0, 28)
subLbl.BackgroundTransparency = 1
subLbl.Text = "에임봇 & ESP"
subLbl.TextColor3 = C.dim
subLbl.Font = Enum.Font.Gotham
subLbl.TextSize = 10
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 32
subLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28,28)
closeBtn.Position = UDim2.new(1, -40, 0.5, -14)
closeBtn.BackgroundColor3 = C.card
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = C.dim
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.ZIndex = 34
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1,0)

--============================================================
-- 7-1) 헤더 드래그
--============================================================
local panelDragging = false
local panelStartPos, panelStartMouse = nil, nil

local function clampPanelPosition(newPos)
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local x = newPos.X.Offset
    local y = newPos.Y.Offset
    x = math.clamp(x, -(PW - 80), vp.X - 80)
    y = math.clamp(y, 0, vp.Y - 40)
    return UDim2.new(0, x, 0, y)
end

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging = true
        panelStartPos = panel.Position
        panelStartMouse = input.Position
    end
end)

header.InputChanged:Connect(function(input)
    if not panelDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - panelStartMouse
        local newPos = UDim2.new(
            panelStartPos.X.Scale, panelStartPos.X.Offset + delta.X,
            panelStartPos.Y.Scale, panelStartPos.Y.Offset + delta.Y
        )
        panel.Position = clampPanelPosition(newPos)
    end
end)

header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging = false
    end
end)

-- 탭 바
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 36)
tabBar.Position = UDim2.new(0, 12, 0, 60)
tabBar.BackgroundColor3 = C.card
tabBar.BorderSizePixel = 0
tabBar.ZIndex = 31
tabBar.Parent = panel
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0,12)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0,4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local function makeTab(order, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5,-4,1,0)
    b.BackgroundColor3 = C.card
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = C.dim
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.LayoutOrder = order
    b.AutoButtonColor = false
    b.ZIndex = 32
    b.Parent = tabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,10)
    return b
end

local tabAim = makeTab(1, "🎯  에임봇")
local tabEsp = makeTab(2, "👁  ESP")

-- 페이지 프레임
local pageHolder = Instance.new("Frame")
pageHolder.Size = UDim2.new(1, -24, 1, -176)
pageHolder.Position = UDim2.new(0, 12, 0, 106)
pageHolder.BackgroundTransparency = 1
pageHolder.ZIndex = 31
pageHolder.Parent = panel

local pageAim = Instance.new("ScrollingFrame")
pageAim.Size = UDim2.new(1,0,1,0)
pageAim.BackgroundTransparency = 1
pageAim.BorderSizePixel = 0
pageAim.ScrollBarThickness = 3
pageAim.ScrollBarImageColor3 = C.stroke
pageAim.CanvasSize = UDim2.new(0,0,0,0)
pageAim.AutomaticCanvasSize = Enum.AutomaticSize.Y
pageAim.ZIndex = 31
pageAim.Parent = pageHolder
local aimLay = Instance.new("UIListLayout")
aimLay.Padding = UDim.new(0,8)
aimLay.SortOrder = Enum.SortOrder.LayoutOrder
aimLay.Parent = pageAim

local pageEsp = Instance.new("ScrollingFrame")
pageEsp.Size = UDim2.new(1,0,1,0)
pageEsp.BackgroundTransparency = 1
pageEsp.BorderSizePixel = 0
pageEsp.ScrollBarThickness = 3
pageEsp.ScrollBarImageColor3 = C.stroke
pageEsp.CanvasSize = UDim2.new(0,0,0,0)
pageEsp.AutomaticCanvasSize = Enum.AutomaticSize.Y
pageEsp.Visible = false
pageEsp.ZIndex = 31
pageEsp.Parent = pageHolder
local espLay = Instance.new("UIListLayout")
espLay.Padding = UDim.new(0,8)
espLay.SortOrder = Enum.SortOrder.LayoutOrder
espLay.Parent = pageEsp

local function selectTab(which)
    if which=="aim" then
        pageAim.Visible=true; pageEsp.Visible=false
        tabAim.BackgroundTransparency=0
        tabAim.BackgroundColor3=C.accent
        tabAim.TextColor3=Color3.fromRGB(255,255,255)
        tabEsp.BackgroundTransparency=1
        tabEsp.TextColor3=C.dim
    else
        pageAim.Visible=false; pageEsp.Visible=true
        tabEsp.BackgroundTransparency=0
        tabEsp.BackgroundColor3=C.accent
        tabEsp.TextColor3=Color3.fromRGB(255,255,255)
        tabAim.BackgroundTransparency=1
        tabAim.TextColor3=C.dim
    end
end
selectTab("aim")
tabAim.MouseButton1Click:Connect(function() selectTab("aim") end)
tabEsp.MouseButton1Click:Connect(function() selectTab("esp") end)

-- 하단 상태 표시
local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, -24, 0, 32)
footer.Position = UDim2.new(0, 12, 1, -44)
footer.BackgroundColor3 = C.card
footer.BorderSizePixel = 0
footer.ZIndex = 31
footer.Parent = panel
Instance.new("UICorner", footer).CornerRadius = UDim.new(0,10)

local footerLbl = Instance.new("TextLabel")
footerLbl.Size = UDim2.new(1, -20, 1, 0)
footerLbl.Position = UDim2.new(0, 12, 0, 0)
footerLbl.BackgroundTransparency = 1
footerLbl.Text = "AIM OFF  ·  ESP OFF"
footerLbl.TextColor3 = C.dim
footerLbl.Font = Enum.Font.GothamBold
footerLbl.TextSize = 11
footerLbl.TextXAlignment = Enum.TextXAlignment.Left
footerLbl.ZIndex = 32
footerLbl.Parent = footer

task.spawn(function()
    while footerLbl.Parent do
        footerLbl.Text = string.format("AIM %s  ·  ESP %s",
            Settings.enabled and "ON" or "OFF",
            Settings.espEnabled and "ON" or "OFF")
        footerLbl.TextColor3 = (Settings.enabled or Settings.espEnabled) and C.green or C.dim
        refreshFabDot()
        task.wait(0.3)
    end
end)

--============================================================
-- 8) 패널 열기/닫기 (애니메이션)
--============================================================
local function setPanel(v)
    if v then
        panel.Visible = true
        panel.Size = UDim2.fromOffset(0,0)
        panel.BackgroundTransparency = 1
        panelStroke.Transparency = 1
        TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(PW, PH),
            BackgroundTransparency = 0,
        }):Play()
        TweenService:Create(panelStroke, TweenInfo.new(0.25), {
            Transparency = 0.1,
        }):Play()
    else
        local t = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0,0),
            BackgroundTransparency = 1,
        })
        t:Play()
        t.Completed:Connect(function()
            panel.Visible = false
        end)
    end
end

fab.MouseButton1Click:Connect(function()
    if fabMoved then return end
    setPanel(not panel.Visible)
end)
closeBtn.MouseButton1Click:Connect(function() setPanel(false) end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        setPanel(not panel.Visible)
    end
end)

--============================================================
-- 9) UI 컴포넌트
--============================================================
local function makeCard(parent, order)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,0,0,0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C.card
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 32
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,14)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0,10)
    pad.PaddingBottom = UDim.new(0,10)
    pad.PaddingLeft = UDim.new(0,12)
    pad.PaddingRight = UDim.new(0,12)
    pad.Parent = card

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0,6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = card

    return card
end

local function makeSectionTitle(parent, text, order)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,0,16)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = C.dim
    t.Font = Enum.Font.GothamBold
    t.TextSize = 10
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.LayoutOrder = order
    t.ZIndex = 33
    t.Parent = parent
    return t
end

local function makeRow(parent, order)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1,0,0,28)
    r.BackgroundTransparency = 1
    r.LayoutOrder = order
    r.ZIndex = 33
    r.Parent = parent
    return r
end

local function makeRowLabel(row, text, color)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.55,0,1,0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or C.text
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 34
    l.Parent = row
    return l
end

local function makeSwitch(row, init, cb)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromOffset(42,22)
    bg.AnchorPoint = Vector2.new(1,0.5)
    bg.Position = UDim2.new(1,0,0.5,0)
    bg.BackgroundColor3 = init and C.accent or C.off
    bg.BorderSizePixel = 0
    bg.ZIndex = 34
    bg.Parent = row
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(16,16)
    knob.Position = init and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 35
    knob.Parent = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 36
    btn.Parent = bg

    local v = init
    btn.MouseButton1Click:Connect(function()
        v = not v
        bg.BackgroundColor3 = v and C.accent or C.off
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
        }):Play()
        if cb then cb(v) end
    end)
end

-- 스테퍼 ( − 값 + )
local function makeStepper(row, initVal, minV, maxV, step, fmt, onChange)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0.5,-4,1,0)
    holder.AnchorPoint = Vector2.new(1,0.5)
    holder.Position = UDim2.new(1,0,0.5,0)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 34
    holder.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.5,0,1,0)
    valLbl.Position = UDim2.new(0.25,0,0,0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = fmt(initVal)
    valLbl.TextColor3 = C.accent
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 12
    valLbl.ZIndex = 35
    valLbl.Parent = holder

    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0.2,0,0.8,0)
    minus.Position = UDim2.new(0,0,0.1,0)
    minus.BackgroundColor3 = C.cardHi
    minus.BorderSizePixel = 0
    minus.Text = "−"
    minus.TextColor3 = C.text
    minus.Font = Enum.Font.GothamBold
    minus.TextSize = 14
    minus.AutoButtonColor = false
    minus.ZIndex = 35
    minus.Parent = holder
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,8)

    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0.2,0,0.8,0)
    plus.Position = UDim2.new(0.8,0,0.1,0)
    plus.BackgroundColor3 = C.cardHi
    plus.BorderSizePixel = 0
    plus.Text = "+"
    plus.TextColor3 = C.text
    plus.Font = Enum.Font.GothamBold
    plus.TextSize = 14
    plus.AutoButtonColor = false
    plus.ZIndex = 35
    plus.Parent = holder
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,8)

    local v = initVal
    local function apply()
        v = math.clamp(v, minV, maxV)
        valLbl.Text = fmt(v)
        if onChange then onChange(v) end
    end
    minus.MouseButton1Click:Connect(function()
        v = v - step; apply()
    end)
    plus.MouseButton1Click:Connect(function()
        v = v + step; apply()
    end)
end

--============================================================
-- 10) 에임봇 페이지
--============================================================
do
    local card = makeCard(pageAim, 1)
    makeSectionTitle(card, "핵심", 1)
    local r = makeRow(card, 2)
    local l = makeRowLabel(r, "에임봇")
    l.Font = Enum.Font.GothamBold
    makeSwitch(r, Settings.enabled, function(v)
        Settings.enabled = v
        updateFovVisual()
        if not v then State.target, State.targetChar = nil, nil end
    end)
    local r2 = makeRow(card, 3)
    makeRowLabel(r2, "자동 발사")
    makeSwitch(r2, Settings.autoFire, function(v) Settings.autoFire = v end)
    local r3 = makeRow(card, 4)
    makeRowLabel(r3, "FOV 원 표시")
    makeSwitch(r3, Settings.showFov, function(v)
        Settings.showFov = v
        updateFovVisual()
    end)
end

do
    local card = makeCard(pageAim, 2)
    makeSectionTitle(card, "수치", 1)

    local r1 = makeRow(card, 2)
    makeRowLabel(r1, "FOV 반경")
    makeStepper(r1, Settings.fovRadius, 20, 800, 10,
        function(v) return tostring(v) end,
        function(v) Settings.fovRadius = v; updateFovVisual() end)

    local r2 = makeRow(card, 3)
    makeRowLabel(r2, "조준 속도")
    makeStepper(r2, Settings.aimSpeed, 0.1, 1.0, 0.05,
        function(v) return string.format("%.2f", v) end,
        function(v) Settings.aimSpeed = v end)

    local r3 = makeRow(card, 4)
    makeRowLabel(r3, "발사 간격")
    makeStepper(r3, Settings.fireRate, 0.05, 1.0, 0.01,
        function(v) return string.format("%.2fs", v) end,
        function(v) Settings.fireRate = v end)
end

do
    local card = makeCard(pageAim, 3)
    makeSectionTitle(card, "판정", 1)
    local r1 = makeRow(card, 2)
    makeRowLabel(r1, "시야 내 적만")
    makeSwitch(r1, Settings.visibleOnly, function(v) Settings.visibleOnly = v end)
    local r2 = makeRow(card, 3)
    makeRowLabel(r2, "아군 무시 (조준)")
    makeSwitch(r2, Settings.ignoreTeams, function(v) Settings.ignoreTeams = v end)
end

--============================================================
-- 11) ESP 페이지
--============================================================
do
    local card = makeCard(pageEsp, 1)
    makeSectionTitle(card, "핵심", 1)
    local r1 = makeRow(card, 2)
    local l1 = makeRowLabel(r1, "ESP 표시")
    l1.Font = Enum.Font.GothamBold
    makeSwitch(r1, Settings.espEnabled, function(v)
        Settings.espEnabled = v
        if not v then
            for _, data in pairs(State.espTags) do
                if data and data.gui then data.gui:Destroy() end
            end
            State.espTags = {}
        end
    end)
    local r2 = makeRow(card, 3)
    makeRowLabel(r2, "거리 표시")
    makeSwitch(r2, Settings.espShowDist, function(v) Settings.espShowDist = v end)
    local r3 = makeRow(card, 4)
    makeRowLabel(r3, "체력바 표시")
    makeSwitch(r3, Settings.espShowHp, function(v) Settings.espShowHp = v end)
end

do
    local card = makeCard(pageEsp, 2)
    makeSectionTitle(card, "수치", 1)
    local r1 = makeRow(card, 2)
    makeRowLabel(r1, "최대 거리")
    makeStepper(r1, Settings.espMaxDist, 100, 5000, 100,
        function(v) return tostring(v) end,
        function(v) Settings.espMaxDist = v end)
end

do
    local card = makeCard(pageEsp, 3)
    makeSectionTitle(card, "팀 구분 표시", 1)
    local r1 = makeRow(card, 2)
    makeRowLabel(r1, "적 표시", C.red)
    makeSwitch(r1, Settings.espShowEnemy, function(v) Settings.espShowEnemy = v end)
    local r2 = makeRow(card, 3)
    makeRowLabel(r2, "아군 표시", C.blue)
    makeSwitch(r2, Settings.espShowAlly, function(v) Settings.espShowAlly = v end)
    local r3 = makeRow(card, 4)
    makeRowLabel(r3, "팀 없음 표시", C.green)
    makeSwitch(r3, Settings.espShowNeutral, function(v) Settings.espShowNeutral = v end)
end

--============================================================
-- 12) 타겟 함수
--============================================================
local function getHead(char)
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getScreenDist(worldPos)
    local sp, onScreen = camera:WorldToViewportPoint(worldPos)
    if not onScreen then return nil end
    local center = camera.ViewportSize * 0.5
    return (Vector2.new(sp.X, sp.Y) - center).Magnitude
end

local function hasLineOfSight(targetChar, targetPos)
    if not Settings.visibleOnly then return true end
    local origin = camera.CFrame.Position
    local dir = targetPos - origin
    if dir.Magnitude < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { camera, player.Character }
    params.IgnoreWater = true
    local result = workspace:Raycast(origin, dir, params)
    if not result then return false end
    return result.Instance:FindFirstAncestorOfClass("Model") == targetChar
end

local function shouldKeep(char, head)
    if not char or not char.Parent then return false end
    if not head or not head.Parent then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local camPos = camera.CFrame.Position
    if (head.Position - camPos).Magnitude > Settings.maxDistance then return false end
    local sd = getScreenDist(head.Position)
    if not sd then return false end
    if sd > (Settings.fovRadius + Settings.keepMargin) then return false end
    return true
end

local function scanNew()
    local best, bestChar, bestScore = nil, nil, math.huge
    local anyInFov = false
    local camPos = camera.CFrame.Position
    for _, other in Players:GetPlayers() do
        if other == player then continue end
        if Settings.ignoreTeams and player.Team and player.Team == other.Team then
            continue
        end
        local char = other.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local head = getHead(char)
        if not head then continue end
        if (head.Position - camPos).Magnitude > Settings.maxDistance then continue end
        local sd = getScreenDist(head.Position)
        if not sd then continue end
        if sd > Settings.fovRadius then continue end
        anyInFov = true
        if Settings.visibleOnly and not hasLineOfSight(char, head.Position) then
            continue
        end
        if sd < bestScore then
            bestScore = sd; best = head; bestChar = char
        end
    end
    return best, bestChar, anyInFov
end

--============================================================
-- 13) 자동 발사
--============================================================
local function tryFire()
    local char = player.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    else
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(0,0,0,true,game,1)
        task.wait()
        vim:SendMouseButtonEvent(0,0,0,false,game,1)
    end
end

--============================================================
-- 14) 카메라 락
--============================================================
local function lockCamera()
    if State.camLocked then return end
    local cur = camera.CameraType
    if cur ~= Enum.CameraType.Scriptable then
        State.originalCam = cur
    end
    camera.CameraType = Enum.CameraType.Scriptable
    State.camLocked = true
end

local function unlockCamera()
    if not State.camLocked then return end
    camera.CameraType = State.originalCam
    State.camLocked = false
end

--============================================================
-- 15) ESP 시스템
--============================================================
local function createEspTag(other, char)
    local head = char:FindFirstChild("Head")
    if not head then return nil end
    local old = State.espTags[other]
    if old and old.gui then old.gui:Destroy() end

    local rel = getRelation(other)
    local baseColor = relationColor(rel)

    local bg = Instance.new("BillboardGui")
    bg.Name = "EspTag"
    bg.Adornee = head
    bg.Size = UDim2.fromOffset(160,44)
    bg.StudsOffset = Vector3.new(0,2.2,0)
    bg.AlwaysOnTop = true
    bg.MaxDistance = Settings.espMaxDist
    bg.Parent = gui

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1,0,0,16)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = string.format("[%s] %s",
        rel=="enemy" and "적" or (rel=="ally" and "아군" or "중립"),
        other.Name)
    nameLbl.TextColor3 = baseColor
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.Parent = bg

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1,0,0,14)
    distLbl.Position = UDim2.new(0,0,0,16)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = ""
    distLbl.TextColor3 = Color3.fromRGB(255,220,120)
    distLbl.Font = Enum.Font.Gotham
    distLbl.TextSize = 11
    distLbl.TextStrokeTransparency = 0.3
    distLbl.Visible = Settings.espShowDist
    distLbl.Parent = bg

    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(1,0,0,4)
    hpBg.Position = UDim2.new(0,0,0,32)
    hpBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    hpBg.BorderSizePixel = 0
    hpBg.Visible = Settings.espShowHp
    hpBg.Parent = bg

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1,0,1,0)
    hpFill.BackgroundColor3 = Color3.fromRGB(50,220,90)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg

    return {
        gui=bg, nameLbl=nameLbl, distLbl=distLbl,
        hpBg=hpBg, hpFill=hpFill, relation=rel,
    }
end

local function updateEspTag(other, data)
    if not data or not data.gui or not data.gui.Parent then return end
    local char = other.Character
    if not char then data.gui.Enabled = false; return end
    local head = char:FindFirstChild("Head")
    if not head then data.gui.Enabled = false; return end

    data.gui.Enabled = true
    data.gui.Adornee = head

    local camPos = camera.CFrame.Position
    local dist = (head.Position - camPos).Magnitude
    if Settings.espShowDist then
        data.distLbl.Visible = true
        data.distLbl.Text = string.format("[%dm]", math.floor(dist))
    else
        data.distLbl.Visible = false
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if Settings.espShowHp and hum then
        data.hpBg.Visible = true
        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth,1), 0, 1)
        data.hpFill.Size = UDim2.new(ratio,0,1,0)
        if ratio > 0.6 then
            data.hpFill.BackgroundColor3 = Color3.fromRGB(50,220,90)
        elseif ratio > 0.3 then
            data.hpFill.BackgroundColor3 = Color3.fromRGB(240,200,60)
        else
            data.hpFill.BackgroundColor3 = Color3.fromRGB(240,70,70)
        end
    else
        data.hpBg.Visible = false
    end

    local baseColor = relationColor(data.relation)
    local sd = getScreenDist(head.Position)
    if sd and sd <= Settings.fovRadius then
        data.nameLbl.TextColor3 = Color3.fromRGB(
            math.min(baseColor.R*255 + 60, 255),
            math.min(baseColor.G*255 + 60, 255),
            math.min(baseColor.B*255 + 60, 255)
        )
    else
        data.nameLbl.TextColor3 = baseColor
    end
end

local function cleanupEspTag(other)
    local data = State.espTags[other]
    if data and data.gui then data.gui:Destroy() end
    State.espTags[other] = nil
end

Players.PlayerRemoving:Connect(function(other)
    cleanupEspTag(other)
end)

--============================================================
-- 16) 메인 루프
--============================================================
RunService.RenderStepped:Connect(function(dt)
    -- ESP
    if Settings.espEnabled then
        for _, other in Players:GetPlayers() do
            if other == player then continue end
            local rel = getRelation(other)
            if not shouldEspShow(rel) then
                cleanupEspTag(other); continue
            end
            local char = other.Character
            if not char then cleanupEspTag(other); continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then cleanupEspTag(other); continue end
            local data = State.espTags[other]
            if not data or not data.gui or not data.gui.Parent then
                data = createEspTag(other, char)
                State.espTags[other] = data
            end
            if data then updateEspTag(other, data) end
        end
    end

    -- 에임봇
    if not Settings.enabled then
        if State.camLocked then unlockCamera() end
        State.target, State.targetChar = nil, nil
        State.anyInFov = false
        fovStroke.Color = C.accent
        return
    end

    local now = os.clock()
    local needScan = (now - State.lastScan) >= Settings.scanInterval
    local keep = false
    if State.target and State.targetChar then
        keep = shouldKeep(State.targetChar, State.target)
    end

    if not keep and needScan then
        State.lastScan = now
        local t, c, any = scanNew()
        if t then
            State.target = t; State.targetChar = c; State.anyInFov = true
        else
            State.target, State.targetChar = nil, nil
            State.anyInFov = any
        end
    elseif keep then
        State.anyInFov = true
    end

    fovStroke.Color = State.anyInFov and C.red or C.accent

    if State.target and State.target.Parent then
        lockCamera()
        local camPos = camera.CFrame.Position
        local desiredRot = CFrame.lookAt(camPos, State.target.Position)
        local alpha = math.clamp(Settings.aimSpeed * dt * 60, 0, 1)
        local newRot = (camera.CFrame - camPos):Lerp(desiredRot - camPos, alpha)
        camera.CFrame = CFrame.new(camPos) * newRot
        if Settings.autoFire and (now - State.lastFire) >= Settings.fireRate then
            State.lastFire = now
            tryFire()
        end
    else
        if State.camLocked then unlockCamera() end
    end
end)

--============================================================
-- 17) 리스폰 / 카메라 변경
--============================================================
player.CharacterAdded:Connect(function()
    task.wait(0.2)
    camera = workspace.CurrentCamera
    State.camLocked = false
    State.target, State.targetChar = nil, nil
    fovFrame.Visible = Settings.showFov and Settings.enabled
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = workspace.CurrentCamera
    State.camLocked = false
end)

--============================================================
-- 18) 로딩 화면
--============================================================
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "FurwonHubLoading"
loadingGui.ResetOnSpawn = false
loadingGui.IgnoreGuiInset = true
loadingGui.DisplayOrder = 999
loadingGui.Parent = player:WaitForChild("PlayerGui")

local loadBg = Instance.new("Frame")
loadBg.Size = UDim2.new(1,0,1,0)
loadBg.BackgroundColor3 = Color3.fromRGB(12,13,18)
loadBg.BackgroundTransparency = 1
loadBg.BorderSizePixel = 0
loadBg.ZIndex = 1
loadBg.Parent = loadingGui

local loadCard = Instance.new("Frame")
loadCard.AnchorPoint = Vector2.new(0.5,0.5)
loadCard.Position = UDim2.new(0.5,0,0.5,0)
loadCard.Size = UDim2.fromOffset(300, 300)
loadCard.BackgroundColor3 = Color3.fromRGB(20,21,26)
loadCard.BackgroundTransparency = 1
loadCard.BorderSizePixel = 0
loadCard.ZIndex = 2
loadCard.Parent = loadBg
Instance.new("UICorner", loadCard).CornerRadius = UDim.new(0, 20)
local loadStroke = Instance.new("UIStroke")
loadStroke.Color = Color3.fromRGB(56,58,70)
loadStroke.Thickness = 1
loadStroke.Transparency = 1
loadStroke.Parent = loadCard

local loadLogo = Instance.new("Frame")
loadLogo.AnchorPoint = Vector2.new(0.5,0)
loadLogo.Position = UDim2.new(0.5,0,0,26)
loadLogo.Size = UDim2.fromOffset(56,56)
loadLogo.BackgroundColor3 = Color3.fromRGB(90,170,255)
loadLogo.BackgroundTransparency = 1
loadLogo.BorderSizePixel = 0
loadLogo.ZIndex = 3
loadLogo.Parent = loadCard
Instance.new("UICorner", loadLogo).CornerRadius = UDim.new(0,16)

local loadLogoIcon = Instance.new("TextLabel")
loadLogoIcon.Size = UDim2.new(1,0,1,0)
loadLogoIcon.BackgroundTransparency = 1
loadLogoIcon.Text = "💥"
loadLogoIcon.TextSize = 28
loadLogoIcon.TextTransparency = 1
loadLogoIcon.ZIndex = 4
loadLogoIcon.Parent = loadLogo

local loadTitle = Instance.new("TextLabel")
loadTitle.AnchorPoint = Vector2.new(0.5,0)
loadTitle.Position = UDim2.new(0.5,0,0,94)
loadTitle.Size = UDim2.new(1,0,0,22)
loadTitle.BackgroundTransparency = 1
loadTitle.Text = "Furwon Hub"
loadTitle.TextColor3 = Color3.fromRGB(235,238,246)
loadTitle.Font = Enum.Font.GothamBold
loadTitle.TextSize = 18
loadTitle.TextTransparency = 1
loadTitle.ZIndex = 3
loadTitle.Parent = loadCard

local loadSub = Instance.new("TextLabel")
loadSub.AnchorPoint = Vector2.new(0.5,0)
loadSub.Position = UDim2.new(0.5,0,0,118)
loadSub.Size = UDim2.new(1,0,0,14)
loadSub.BackgroundTransparency = 1
loadSub.Text = "에임봇 & ESP 로딩 중..."
loadSub.TextColor3 = Color3.fromRGB(150,154,168)
loadSub.Font = Enum.Font.Gotham
loadSub.TextSize = 11
loadSub.TextTransparency = 1
loadSub.ZIndex = 3
loadSub.Parent = loadCard

local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5,0)
barBg.Position = UDim2.new(0.5,0,0,160)
barBg.Size = UDim2.new(1,-48,0,6)
barBg.BackgroundColor3 = Color3.fromRGB(40,42,52)
barBg.BackgroundTransparency = 1
barBg.BorderSizePixel = 0
barBg.ZIndex = 3
barBg.Parent = loadCard
Instance.new("UICorner", barBg).CornerRadius = UDim.new(1,0)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0,0,1,0)
barFill.BackgroundColor3 = Color3.fromRGB(90,170,255)
barFill.BackgroundTransparency = 1
barFill.BorderSizePixel = 0
barFill.ZIndex = 4
barFill.Parent = barBg
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1,0)

local barPct = Instance.new("TextLabel")
barPct.AnchorPoint = Vector2.new(0.5,0)
barPct.Position = UDim2.new(0.5,0,0,172)
barPct.Size = UDim2.new(1,0,0,14)
barPct.BackgroundTransparency = 1
barPct.Text = "0%"
barPct.TextColor3 = Color3.fromRGB(150,154,168)
barPct.Font = Enum.Font.GothamBold
barPct.TextSize = 11
barPct.TextTransparency = 1
barPct.ZIndex = 3
barPct.Parent = loadCard

local spinner = Instance.new("Frame")
spinner.AnchorPoint = Vector2.new(0.5,0)
spinner.Position = UDim2.new(0.5,0,0,200)
spinner.Size = UDim2.fromOffset(48,48)
spinner.BackgroundTransparency = 1
spinner.ZIndex = 3
spinner.Parent = loadCard

local spinBox = Instance.new("Frame")
spinBox.AnchorPoint = Vector2.new(0.5,0.5)
spinBox.Position = UDim2.new(0.5,0,0.5,0)
spinBox.Size = UDim2.fromOffset(40,40)
spinBox.BackgroundColor3 = Color3.fromRGB(235,238,246)
spinBox.BackgroundTransparency = 1
spinBox.BorderSizePixel = 0
spinBox.ZIndex = 4
spinBox.Parent = spinner
Instance.new("UICorner", spinBox).CornerRadius = UDim.new(0, 8)

local spinHole = Instance.new("Frame")
spinHole.AnchorPoint = Vector2.new(0.5,0.5)
spinHole.Position = UDim2.new(0.5,0,0.5,0)
spinHole.Size = UDim2.fromOffset(14,14)
spinHole.BackgroundColor3 = Color3.fromRGB(20,21,26)
spinHole.BorderSizePixel = 0
spinHole.ZIndex = 5
spinHole.Parent = spinBox
Instance.new("UICorner", spinHole).CornerRadius = UDim.new(0, 3)

local function fadeInLoading()
    TweenService:Create(loadBg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(loadCard, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(loadLogo, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(loadLogoIcon, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    TweenService:Create(loadTitle, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    TweenService:Create(loadSub, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    TweenService:Create(spinBox, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(barBg, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(barFill, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(barPct, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    TweenService:Create(loadStroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
end

local function fadeOutLoading()
    TweenService:Create(loadBg, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadCard, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadLogo, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    TweenService:Create(loadLogoIcon, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
    TweenService:Create(loadTitle, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
    TweenService:Create(loadSub, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
    TweenService:Create(spinBox, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    TweenService:Create(barBg, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    TweenService:Create(barFill, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    TweenService:Create(barPct, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
    TweenService:Create(loadStroke, TweenInfo.new(0.35), {Transparency = 1}):Play()
end

task.spawn(function()
    while spinner.Parent do
        spinBox.Rotation = (spinBox.Rotation + 6) % 360
        task.wait(0.02)
    end
end)

fadeInLoading()
task.wait(0.3)

local totalTime = 2.0
local elapsed = 0
while elapsed < totalTime do
    elapsed = elapsed + task.wait()
    local pct = math.clamp(elapsed / totalTime, 0, 1)
    barFill.Size = UDim2.new(pct, 0, 1, 0)
    barPct.Text = string.format("%d%%", math.floor(pct * 100))
end

barFill.Size = UDim2.new(1, 0, 1, 0)
barPct.Text = "100%"
loadSub.Text = "준비 완료!"
task.wait(0.3)

fadeOutLoading()
task.wait(0.4)

loadingGui:Destroy()

--============================================================
-- 19) 키 시스템
--============================================================
local CORRECT_KEY = "Furwon"

local keyGui = Instance.new("ScreenGui")
keyGui.Name = "FurwonHubKey"
keyGui.ResetOnSpawn = false
keyGui.IgnoreGuiInset = true
keyGui.DisplayOrder = 998
keyGui.Parent = player:WaitForChild("PlayerGui")

local keyBg = Instance.new("Frame")
keyBg.Size = UDim2.new(1,0,1,0)
keyBg.BackgroundColor3 = Color3.fromRGB(12,13,18)
keyBg.BackgroundTransparency = 0
keyBg.BorderSizePixel = 0
keyBg.ZIndex = 1
keyBg.Parent = keyGui

local keyCard = Instance.new("Frame")
keyCard.AnchorPoint = Vector2.new(0.5,0.5)
keyCard.Position = UDim2.new(0.5,0,0.5,0)
keyCard.Size = UDim2.fromOffset(300, 240)
keyCard.BackgroundColor3 = Color3.fromRGB(20,21,26)
keyCard.BorderSizePixel = 0
keyCard.ZIndex = 2
keyCard.Parent = keyBg
Instance.new("UICorner", keyCard).CornerRadius = UDim.new(0, 20)
local keyStroke = Instance.new("UIStroke")
keyStroke.Color = Color3.fromRGB(56,58,70)
keyStroke.Thickness = 1
keyStroke.Parent = keyCard

local keyLogo = Instance.new("Frame")
keyLogo.AnchorPoint = Vector2.new(0.5,0)
keyLogo.Position = UDim2.new(0.5,0,0,22)
keyLogo.Size = UDim2.fromOffset(56,56)
keyLogo.BackgroundColor3 = Color3.fromRGB(90,170,255)
keyLogo.BorderSizePixel = 0
keyLogo.ZIndex = 3
keyLogo.Parent = keyCard
Instance.new("UICorner", keyLogo).CornerRadius = UDim.new(0,16)

local keyLogoIcon = Instance.new("TextLabel")
keyLogoIcon.Size = UDim2.new(1,0,1,0)
keyLogoIcon.BackgroundTransparency = 1
keyLogoIcon.Text = "💥"
keyLogoIcon.TextSize = 28
keyLogoIcon.ZIndex = 4
keyLogoIcon.Parent = keyLogo

local keyTitle = Instance.new("TextLabel")
keyTitle.AnchorPoint = Vector2.new(0.5,0)
keyTitle.Position = UDim2.new(0.5,0,0,88)
keyTitle.Size = UDim2.new(1,0,0,22)
keyTitle.BackgroundTransparency = 1
keyTitle.Text = "Furwon Hub"
keyTitle.TextColor3 = Color3.fromRGB(235,238,246)
keyTitle.Font = Enum.Font.GothamBold
keyTitle.TextSize = 18
keyTitle.ZIndex = 3
keyTitle.Parent = keyCard

local keySub = Instance.new("TextLabel")
keySub.AnchorPoint = Vector2.new(0.5,0)
keySub.Position = UDim2.new(0.5,0,0,110)
keySub.Size = UDim2.new(1,0,0,14)
keySub.BackgroundTransparency = 1
keySub.Text = "키를 입력해 주세요"
keySub.TextColor3 = Color3.fromRGB(150,154,168)
keySub.Font = Enum.Font.Gotham
keySub.TextSize = 11
keySub.ZIndex = 3
keySub.Parent = keyCard

local keyBox = Instance.new("Frame")
keyBox.AnchorPoint = Vector2.new(0.5,0)
keyBox.Position = UDim2.new(0.5,0,0,138)
keyBox.Size = UDim2.new(1,-60,0,34)
keyBox.BackgroundColor3 = Color3.fromRGB(30,32,40)
keyBox.BorderSizePixel = 0
keyBox.ZIndex = 3
keyBox.Parent = keyCard
Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0,10)
local keyBoxStroke = Instance.new("UIStroke")
keyBoxStroke.Color = Color3.fromRGB(56,58,70)
keyBoxStroke.Thickness = 1
keyBoxStroke.Parent = keyBox

local keyInput = Instance.new("TextBox")
keyInput.Size = UDim2.new(1,-20,1,0)
keyInput.Position = UDim2.new(0,10,0,0)
keyInput.BackgroundTransparency = 1
keyInput.Text = ""
keyInput.PlaceholderText = "여기에 키 입력..."
keyInput.PlaceholderColor3 = Color3.fromRGB(120,124,138)
keyInput.TextColor3 = Color3.fromRGB(235,238,246)
keyInput.Font = Enum.Font.Gotham
keyInput.TextSize = 13
keyInput.ClearTextOnFocus = false
keyInput.ZIndex = 4
keyInput.Parent = keyBox

local keyStatus = Instance.new("TextLabel")
keyStatus.AnchorPoint = Vector2.new(0.5,0)
keyStatus.Position = UDim2.new(0.5,0,0,180)
keyStatus.Size = UDim2.new(1,0,0,16)
keyStatus.BackgroundTransparency = 1
keyStatus.Text = ""
keyStatus.TextColor3 = Color3.fromRGB(255,80,90)
keyStatus.Font = Enum.Font.GothamBold
keyStatus.TextSize = 12
keyStatus.ZIndex = 3
keyStatus.Parent = keyCard

local keyBtn = Instance.new("TextButton")
keyBtn.AnchorPoint = Vector2.new(0.5,0)
keyBtn.Position = UDim2.new(0.5,0,0,204)
keyBtn.Size = UDim2.new(1,-60,0,32)
keyBtn.BackgroundColor3 = Color3.fromRGB(90,170,255)
keyBtn.BorderSizePixel = 0
keyBtn.Text = "확인"
keyBtn.TextColor3 = Color3.fromRGB(255,255,255)
keyBtn.Font = Enum.Font.GothamBold
keyBtn.TextSize = 13
keyBtn.AutoButtonColor = false
keyBtn.ZIndex = 3
keyBtn.Parent = keyCard
Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0,10)

local function trySubmitKey()
    if keyInput.Text == CORRECT_KEY then
        keyStatus.Text = ""
        TweenService:Create(keyBg, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(keyCard, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(keyLogo, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(keyLogoIcon, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(keyTitle, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(keySub, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(keyBox, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(keyInput, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(keyBtn, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(keyStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
        TweenService:Create(keyBoxStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
        task.wait(0.35)
        keyGui:Destroy()
        fab.Visible = true
    else
        keyStatus.Text = "일치하지 않습니다."
        local origX = keyCard.Position.X.Offset
        for i=1,3 do
            keyCard.Position = UDim2.new(0.5, origX - 8, 0.5, 0)
            task.wait(0.05)
            keyCard.Position = UDim2.new(0.5, origX + 8, 0.5, 0)
            task.wait(0.05)
        end
        keyCard.Position = UDim2.new(0.5, origX, 0.5, 0)
    end
end

keyBtn.MouseButton1Click:Connect(trySubmitKey)
keyInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then trySubmitKey() end
end)

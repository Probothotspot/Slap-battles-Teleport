--[[
═══════════════════════════════════════════════════════════════════════════════
                 BARREL HUB UI ENGINE (Barrel-mastery-GUI.lua)
═══════════════════════════════════════════════════════════════════════════════
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local HubUI = {}
HubUI.__index = HubUI

-- 1. Стили и палитра
local Theme = {
    Bg        = Color3.fromRGB(15, 12, 22),
    Panel     = Color3.fromRGB(24, 18, 38),
    PanelSoft = Color3.fromRGB(35, 28, 55),
    PanelDim  = Color3.fromRGB(20, 15, 30),
    Line      = Color3.fromRGB(75, 55, 120),
    Purple    = Color3.fromRGB(160, 60, 255),
    Fuchsia   = Color3.fromRGB(225, 80, 255),
    Text      = Color3.fromRGB(255, 255, 255),
    Dim       = Color3.fromRGB(200, 190, 220),
    Green     = Color3.fromRGB(46, 204, 113),
    GreenBtn  = Color3.fromRGB(39, 174, 96),
    Red       = Color3.fromRGB(231, 76, 60),
    RedBtn    = Color3.fromRGB(192, 57, 43),
    Amber     = Color3.fromRGB(241, 196, 15),
}

local FONT      = Enum.Font.Gotham
local FONT_MED  = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local function create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        if k ~= "Parent" then inst[k] = v end
    end
    if props.Parent then inst.Parent = props.Parent end
    return inst
end

local function tween(obj, duration, goal, style)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        goal
    )
    tw:Play()
    return tw
end

local function corner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function pill(parent)
    return create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

local function spinGradient(gradient, seconds, maid)
    local alive = true
    local worker = task.spawn(function()
        while alive and gradient and gradient.Parent do
            gradient.Rotation = 0
            local tw = TweenService:Create(
                gradient,
                TweenInfo.new(seconds, Enum.EasingStyle.Linear),
                { Rotation = 360 }
            )
            tw:Play()
            tw.Completed:Wait()
        end
    end)
    maid:Give(worker)
    maid:Give(function() alive = false end)
end

local function makeDraggable(handle, target, maid)
    local dragging = false
    local dragStart = Vector2.zero
    local startPos  = target.Position

    maid:Give(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos  = target.Position
        end
    end))

    maid:Give(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    maid:Give(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- 2. Конструктор HubUI
function HubUI.new(config)
    local self = setmetatable({}, HubUI)
    
    self.Config = config or {}
    self.Maid = config.Maid
    self.OnStartFeature = config.OnStartFeature or function() end
    self.OnStopFeature = config.OnStopFeature or function() end
    self.OnRoleChange = config.OnRoleChange or function() end
    self.OnAccountInput = config.OnAccountInput or function() end
    self.OnShutdown = config.OnShutdown or function() end
    
    self.AccountRefs = {}
    self.FeatureCards = {}
    self.Minimized = false
    
    local guiParent = (typeof(gethui) == "function" and gethui()) 
        or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui")) 
        or LocalPlayer:WaitForChild("PlayerGui")

    local previous = guiParent:FindFirstChild("BarrelMasteryHub")
    if previous then previous:Destroy() end

    self.ScreenGui = create("ScreenGui", {
        Name = "BarrelMasteryHub",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 9999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = guiParent
    })
    
    if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, self.ScreenGui)
    end
    self.Maid:Give(self.ScreenGui)

    return self
end

-- 3. Диагностика (Preloader)
function HubUI:RunPreloader(checks, onComplete)
    local Preloader = create("CanvasGroup", {
        Name = "Preloader",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(250, 150),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        GroupTransparency = 0,
        Parent = self.ScreenGui,
    })
    corner(Preloader, 10)

    local preStroke = create("UIStroke", {
        Color = Theme.Purple,
        Thickness = 1.5,
        Parent = Preloader,
    })
    spinGradient(create("UIGradient", {
        Color = ColorSequence.new(Theme.Purple, Theme.Fuchsia),
        Parent = preStroke,
    }), 3, self.Maid)

    create("TextLabel", {
        Position = UDim2.new(0, 10, 0, 8),
        Size = UDim2.new(1, -20, 0, 16),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        TextSize = 11,
        TextColor3 = Theme.Text,
        Text = "BARREL HUB · LOADING",
        Parent = Preloader,
    })

    local CheckRows = {}
    for i, def in ipairs(checks) do
        local rowY = 30 + (i - 1) * 19
        local stateLbl = create("TextLabel", {
            Position = UDim2.new(0, 12, 0, rowY),
            Size = UDim2.fromOffset(16, 16),
            BackgroundTransparency = 1,
            Font = FONT_BOLD,
            TextSize = 10,
            TextColor3 = Theme.Text,
            Text = "○",
            Parent = Preloader,
        })
        create("TextLabel", {
            Position = UDim2.new(0, 32, 0, rowY),
            Size = UDim2.new(1, -40, 0, 16),
            BackgroundTransparency = 1,
            Font = FONT_MED,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = def.label,
            Parent = Preloader,
        })
        CheckRows[def.key] = { state = stateLbl, runner = def.fn }
    end

    local progressWrap = create("Frame", {
        Position = UDim2.new(0, 10, 0, 130),
        Size = UDim2.new(1, -20, 0, 5),
        BackgroundColor3 = Theme.PanelSoft,
        BorderSizePixel = 0,
        Parent = Preloader,
    })
    pill(progressWrap)
    local progressFill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Purple,
        BorderSizePixel = 0,
        Parent = progressWrap,
    })
    pill(progressFill)
    create("UIGradient", {
        Color = ColorSequence.new(Theme.Purple, Theme.Fuchsia),
        Parent = progressFill,
    })

    task.spawn(function()
        local total = #checks
        for i, def in ipairs(checks) do
            local row = CheckRows[def.key]
            row.state.Text = "…"
            row.state.TextColor3 = Theme.Amber

            local passed = false
            if type(row.runner) == "function" then
                local ok, res = pcall(row.runner)
                passed = ok and res
            end
            task.wait(0.12)

            tween(progressFill, 0.2, { Size = UDim2.new(i / total, 0, 1, 0) })

            if passed then
                row.state.Text = "✅"
                row.state.TextColor3 = Theme.Green
            else
                row.state.Text = "❌"
                row.state.TextColor3 = Theme.Red
                task.wait(2)
                self.Maid:Clean()
                return
            end
            task.wait(0.08)
        end

        task.wait(0.15)
        local preFade = tween(Preloader, 0.25, { GroupTransparency = 1 })
        preFade.Completed:Wait()
        Preloader:Destroy()

        if onComplete then onComplete() end
    end)
end

-- 4. Главное окно
function HubUI:BuildMain(featuresList)
    local EXPANDED_SIZE  = UDim2.fromOffset(250, 150)
    local COLLAPSED_SIZE = UDim2.fromOffset(250, 26)

    self.Main = create("CanvasGroup", {
        Name = "Hub",
        Visible = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = EXPANDED_SIZE,
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        Parent = self.ScreenGui,
    })
    corner(self.Main, 8)

    local mainStroke = create("UIStroke", {
        Color = Theme.Purple,
        Thickness = 1.2,
        Parent = self.Main,
    })
    spinGradient(create("UIGradient", {
        Color = ColorSequence.new(Theme.Purple, Theme.Fuchsia, Theme.Purple),
        Parent = mainStroke,
    }), 4, self.Maid)

    -- Header
    local Header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Parent = self.Main,
    })

    create("TextLabel", {
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0, 170, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT_BOLD,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
        Text = "Slap Battles | Barrel Hub",
        Parent = Header,
    })

    local function headerButton(glyph, xOffset)
        local btn = create("TextButton", {
            Position = UDim2.new(1, xOffset, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = Theme.PanelSoft,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = FONT_BOLD,
            TextSize = 10,
            TextColor3 = Theme.Text,
            Text = glyph,
            Parent = Header,
        })
        corner(btn, 4)
        return btn
    end

    local CloseBtn = headerButton("❌", -6)
    local MinBtn = headerButton("-", -28)

    -- Scrolling Frame
    self.ScrollBody = create("ScrollingFrame", {
        Name = "ScrollBody",
        Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 1, -26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Purple,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = self.Main,
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 6),
        Parent = self.ScrollBody,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = self.ScrollBody,
    })

    local function sectionTitle(text, order)
        return create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            Font = FONT_BOLD,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = text,
            LayoutOrder = order,
            Parent = self.ScrollBody,
        })
    end

    local function buildAccountRow(title, slotKey, order)
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = self.ScrollBody,
            Name = slotKey .. "Row",
        })

        create("TextLabel", {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 90, 0, 12),
            BackgroundTransparency = 1,
            Font = FONT_BOLD,
            TextSize = 8.5,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = title .. " ACC",
            Parent = row,
        })

        local tagFrame = create("Frame", {
            Position = UDim2.new(1, 0, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.fromOffset(130, 13),
            BackgroundColor3 = Theme.PanelSoft,
            BorderSizePixel = 0,
            Parent = row,
        })
        pill(tagFrame)
        local tagLbl = create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Font = FONT_BOLD,
            TextSize = 7.5,
            TextColor3 = Theme.Text,
            Text = "Not found", -- Исправлено на Not found
            Parent = tagFrame,
        })

        local box = create("TextBox", {
            Position = UDim2.new(0, 0, 0, 14),
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundColor3 = Theme.PanelSoft,
            BorderSizePixel = 0,
            Font = FONT_MED,
            TextSize = 9.5,
            TextColor3 = Theme.Text,
            PlaceholderText = "Enter " .. title:lower() .. " username…",
            PlaceholderColor3 = Theme.Dim,
            Text = "",
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        corner(box, 4)
        create("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = box })

        self.AccountRefs[slotKey] = {
            Row = row,
            Box = box,
            Tag = { Frame = tagFrame, Label = tagLbl },
        }

        self.Maid:Give(box.FocusLost:Connect(function()
            local trimmed = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
            box.Text = trimmed
            self.OnAccountInput(slotKey, trimmed)
        end))
    end

    -- Секция аккаунтов
    sectionTitle("● ACCOUNT BINDING", 1)
    buildAccountRow("MAIN", "Main", 2)
    buildAccountRow("ALT", "Alt", 3)

    -- Секция ролей
    sectionTitle("● ROLE SELECTOR", 4)
    local toggleTrack = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = Theme.PanelSoft,
        BorderSizePixel = 0,
        LayoutOrder = 5,
        Parent = self.ScrollBody,
    })
    corner(toggleTrack, 6)

    self.RoleIndicator = create("Frame", {
        Position = UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(0.5, -3, 1, -4),
        BackgroundColor3 = Theme.Purple,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = toggleTrack,
    })
    corner(self.RoleIndicator, 4)

    local function roleButton(text, xScale)
        return create("TextButton", {
            Position = UDim2.new(xScale, 0, 0, 0),
            Size = UDim2.new(0.5, 0, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = FONT_BOLD,
            TextSize = 8.5,
            TextColor3 = Theme.Text,
            Text = text,
            ZIndex = 2,
            Parent = toggleTrack,
        })
    end
    local RoleBtnMain = roleButton("MAIN MODE", 0)
    local RoleBtnAlt  = roleButton("ALT MODE", 0.5)

    self.Maid:Give(RoleBtnMain.MouseButton1Click:Connect(function() self.OnRoleChange("Main") end))
    self.Maid:Give(RoleBtnAlt.MouseButton1Click:Connect(function() self.OnRoleChange("Alt") end))

    -- Секция фичей
    sectionTitle("● FEATURES", 6)
    local function buildFeaturesGroup(role, order)
        local grp = create("Frame", {
            Name = role .. "Features",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = order,
            Parent = self.ScrollBody,
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = grp,
        })
        return grp
    end

    self.FeaturesMainGroup = buildFeaturesGroup("Main", 7)
    self.FeaturesAltGroup  = buildFeaturesGroup("Alt", 8)

    local function actionButton(text, xOffset, bgColor, parent)
        local btn = create("TextButton", {
            Position = UDim2.new(1, xOffset, 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            Size = UDim2.fromOffset(40, 18),
            BackgroundColor3 = bgColor,
            BorderSizePixel = 0,
            AutoButtonColor = true,
            Font = FONT_BOLD,
            TextSize = 8,
            TextColor3 = Theme.Text,
            Text = text,
            Parent = parent,
        })
        corner(btn, 4)
        return btn
    end

    local function buildFeatureCard(def, parent, order)
        local card = create("Frame", {
            Name = def.Id,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.PanelSoft,
            BorderSizePixel = 0,
            LayoutOrder = order,
            Parent = parent,
        })
        corner(card, 6)

        local dot = create("Frame", {
            Position = UDim2.new(0, 6, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.fromOffset(6, 6),
            BackgroundColor3 = Theme.Dim,
            BorderSizePixel = 0,
            Parent = card,
        })
        pill(dot)

        create("TextLabel", {
            Position = UDim2.new(0, 16, 0, 3),
            Size = UDim2.new(0, 125, 0, 12),
            BackgroundTransparency = 1,
            Font = FONT_MED,
            TextSize = 8.5,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = def.Name,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = card,
        })
        local stateLbl = create("TextLabel", {
            Position = UDim2.new(0, 16, 0, 15),
            Size = UDim2.new(0, 125, 0, 10),
            BackgroundTransparency = 1,
            Font = FONT_BOLD,
            TextSize = 7.5,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Theme.Text,
            Text = "● IDLE",
            Parent = card,
        })

        local startBtn = actionButton("START", -48, Theme.GreenBtn, card)
        local stopBtn = actionButton("STOP", -4, Theme.RedBtn, card)

        self.Maid:Give(startBtn.MouseButton1Click:Connect(function()
            self.OnStartFeature(def.Id)
        end))
        self.Maid:Give(stopBtn.MouseButton1Click:Connect(function()
            self.OnStopFeature(def.Id)
        end))

        self.FeatureCards[def.Id] = { Dot = dot, Label = stateLbl }
    end

    for i, def in ipairs(featuresList) do
        local parentGrp = (def.Role == "Main") and self.FeaturesMainGroup or self.FeaturesAltGroup
        buildFeatureCard(def, parentGrp, i)
    end

    -- Status Bar
    local statusBar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = 9,
        Parent = self.ScrollBody,
    })
    self.StatusLabel = create("TextLabel", {
        Position = UDim2.new(0, 4, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        BackgroundTransparency = 1,
        Font = FONT_MED,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
        Text = "Status: Ready",
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = statusBar,
    })

    makeDraggable(Header, self.Main, self.Maid)

    self.Maid:Give(MinBtn.MouseButton1Click:Connect(function()
        self.Minimized = not self.Minimized
        MinBtn.Text = self.Minimized and "+" or "-"
        if self.Minimized then
            self.ScrollBody.Visible = false
            tween(self.Main, 0.2, { Size = COLLAPSED_SIZE })
        else
            local tw = tween(self.Main, 0.2, { Size = EXPANDED_SIZE })
            tw.Completed:Wait()
            self.ScrollBody.Visible = true
        end
    end))

    self.Maid:Give(CloseBtn.MouseButton1Click:Connect(function()
        self.OnShutdown()
    end))

    self.Main.Visible = true
    self.Main.GroupTransparency = 1
    tween(self.Main, 0.3, { GroupTransparency = 0 })
end

-- 5. Методы обновления состояний
local CARD_STATES = {
    idle    = { color = Theme.Dim,   text = "● IDLE" },
    loading = { color = Theme.Amber, text = "● STARTING" },
    active  = { color = Theme.Green, text = "● ACTIVE" },
    error   = { color = Theme.Red,   text = "● ERROR" },
}

function HubUI:SetCardState(id, state)
    local card = self.FeatureCards[id]
    if not card then return end
    local conf = CARD_STATES[state] or CARD_STATES.idle
    card.Dot.BackgroundColor3 = conf.color
    card.Label.Text = conf.text
    card.Label.TextColor3 = Theme.Text
end

function HubUI:SetStatus(msg)
    if self.StatusLabel then
        self.StatusLabel.Text = msg
    end
end

local TAG_STYLES = {
    idle = { text = Theme.Text, bg = Color3.fromRGB(45, 35, 65) },
    ok   = { text = Theme.Text, bg = Theme.GreenBtn },
    err  = { text = Theme.Text, bg = Theme.RedBtn },
    you  = { text = Theme.Text, bg = Theme.Purple },
}

function HubUI:SetAccountTag(slotKey, kind, text)
    local refs = self.AccountRefs[slotKey]
    if not refs then return end
    local s = TAG_STYLES[kind] or TAG_STYLES.idle
    refs.Tag.Frame.BackgroundColor3 = s.bg
    refs.Tag.Label.TextColor3 = s.text
    refs.Tag.Label.Text = text
end

function HubUI:SetAccountBox(slotKey, text, editable, isCurrentPlayer)
    local refs = self.AccountRefs[slotKey]
    if not refs then return end
    refs.Box.TextEditable = editable
    refs.Box.ClearTextOnFocus = editable
    refs.Box.Text = text
    refs.Box.BackgroundColor3 = isCurrentPlayer and Theme.PanelDim or Theme.PanelSoft
end

function HubUI:SetRoleUI(role)
    tween(self.RoleIndicator, 0.25, {
        Position = role == "Main" and UDim2.new(0, 2, 0, 2) or UDim2.new(0.5, 1, 0, 2),
    })
    self.FeaturesMainGroup.Visible = (role == "Main")
    self.FeaturesAltGroup.Visible  = (role == "Alt")
end

function HubUI:Destroy()
    if self.Main then
        local fade = tween(self.Main, 0.2, { GroupTransparency = 1 })
        fade.Completed:Wait()
    end
    self.Maid:Clean()
end

return HubUI

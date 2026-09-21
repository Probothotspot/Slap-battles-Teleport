--[[
    ========================================================================
    MODULE: GUI - Auto-Build-BABFT-Gui.lua
    STYLE: SPRB // V5.1 (Build A Boat For Treasure Auto-Build & Tools)
    COMPATIBILITY: Delta, Fluxus, Codex, Arceus X, Wave, PC & Mobile
    ========================================================================
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local AutoBuildUI = {}
AutoBuildUI.__index = AutoBuildUI

-- Цветовая палитра SPRB V5.1
local Theme = {
    Background = Color3.fromRGB(18, 14, 28),
    Header = Color3.fromRGB(25, 18, 42),
    Sidebar = Color3.fromRGB(22, 16, 36),
    TabInactive = Color3.fromRGB(32, 24, 52),
    TabActive = Color3.fromRGB(110, 52, 210),
    Container = Color3.fromRGB(24, 18, 40),
    CardBg = Color3.fromRGB(28, 22, 46),
    InputBg = Color3.fromRGB(15, 11, 24),
    Accent = Color3.fromRGB(128, 60, 230),
    AccentGlow = Color3.fromRGB(160, 85, 255),
    AccentDark = Color3.fromRGB(85, 35, 160),
    Success = Color3.fromRGB(46, 204, 113),
    Danger = Color3.fromRGB(231, 76, 60),
    Text = Color3.fromRGB(245, 245, 255),
    TextMuted = Color3.fromRGB(165, 155, 190),
    Border = Color3.fromRGB(70, 45, 115),
    BorderLight = Color3.fromRGB(105, 65, 170),
    GridLine = Color3.fromRGB(45, 32, 75)
}

-- Вспомогательные функции UI
local function createCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

local function createStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = color or Theme.Border
    stroke.Thickness = thickness or 1
    stroke.Parent = parent
    return stroke
end

local function tween(object, properties, duration)
    local info = TweenInfo.new(duration or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local anim = TweenService:Create(object, info, properties)
    anim:Play()
    return anim
end

-- Конструктор UI
function AutoBuildUI.new(config)
    config = config or {}
    local self = setmetatable({}, AutoBuildUI)

    self.Title = config.Title or "SPRB // V5.1"
    self.ActiveTab = "BUILD"
    self.Callbacks = config.Callbacks or {}
    self.ExcludedBlocks = {}

    -- Защищенный контейнер под мобильные эксплойты
    local guiParent = LocalPlayer:WaitForChild("PlayerGui")
    if (gethui and typeof(gethui) == "function") then
        guiParent = gethui()
    elseif (CoreGui and (run_on_client or syn)) then
        pcall(function() guiParent = CoreGui end)
    end

    if guiParent:FindFirstChild("SPRB_AutoBuild_Gui") then
        guiParent.SPRB_AutoBuild_Gui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SPRB_AutoBuild_Gui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = guiParent
    self.ScreenGui = ScreenGui

    -- Основное окно
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 520, 0, 340)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -170)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    self.MainFrame = MainFrame
    createCorner(MainFrame, 8)
    createStroke(MainFrame, Theme.BorderLight, 1.2)

    -- Масштабирование под экран телефона
    local UIScale = Instance.new("UIScale")
    UIScale.Scale = config.UIScale or 1.0
    UIScale.Parent = MainFrame
    self.UIScale = UIScale

    -- Фоновая сетка (Grid)
    local GridBg = Instance.new("ImageLabel")
    GridBg.Name = "GridBackground"
    GridBg.Size = UDim2.new(1, 0, 1, 0)
    GridBg.BackgroundTransparency = 1
    GridBg.Image = "rbxassetid://6071575925"
    GridBg.ImageColor3 = Theme.GridLine
    GridBg.ImageTransparency = 0.78
    GridBg.ScaleType = Enum.ScaleType.Tile
    GridBg.TileSize = UDim2.new(0, 24, 0, 24)
    GridBg.ZIndex = 1
    GridBg.Parent = MainFrame

    -- Создание компонентов
    self:BuildTopBar()
    self:BuildSidebar()

    -- Контейнер страниц
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Position = UDim2.new(0, 105, 0, 36)
    ContentFrame.Size = UDim2.new(1, -110, 1, -41)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ZIndex = 2
    ContentFrame.Parent = MainFrame
    self.ContentFrame = ContentFrame

    self.Pages = {}
    self:BuildBlocksPage()
    self:BuildBuildPage()
    self:BuildExploitPage()
    self:BuildSettingsPage()

    self:SwitchTab("BUILD")
    self:EnableTouchDrag(self.TopBar, MainFrame)

    return self
end

-- Перемещение окна пальцем / курсором
function AutoBuildUI:EnableTouchDrag(dragHandle, targetFrame)
    local dragging = false
    local dragInput, mousePos, framePos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = targetFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            targetFrame.Position = UDim2.new(
                framePos.X.Scale,
                framePos.X.Offset + delta.X,
                framePos.Y.Scale,
                framePos.Y.Offset + delta.Y
            )
        end
    end)
end

-- 1. Шапка (TopBar)
function AutoBuildUI:BuildTopBar()
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 34)
    TopBar.BackgroundColor3 = Theme.Header
    TopBar.BorderSizePixel = 0
    TopBar.ZIndex = 3
    TopBar.Parent = self.MainFrame
    self.TopBar = TopBar

    -- Аватарка игрока
    local AvatarImg = Instance.new("ImageLabel")
    AvatarImg.Size = UDim2.new(0, 24, 0, 24)
    AvatarImg.Position = UDim2.new(0, 7, 0, 5)
    AvatarImg.BackgroundColor3 = Theme.Sidebar
    AvatarImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    AvatarImg.ZIndex = 4
    AvatarImg.Parent = TopBar
    createCorner(AvatarImg, 4)
    createStroke(AvatarImg, Theme.Accent, 1)

    -- Название
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 200, 1, 0)
    TitleLabel.Position = UDim2.new(0, 38, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = self.Title
    TitleLabel.TextColor3 = Theme.Text
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.ZIndex = 4
    TitleLabel.Parent = TopBar

    -- Кнопка [-]
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0, 26, 0, 22)
    MinBtn.Position = UDim2.new(1, -58, 0, 6)
    MinBtn.BackgroundColor3 = Theme.TabInactive
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Theme.Text
    MinBtn.TextSize = 14
    MinBtn.ZIndex = 4
    MinBtn.Parent = TopBar
    createCorner(MinBtn, 4)

    -- Кнопка [X]
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 26, 0, 22)
    CloseBtn.Position = UDim2.new(1, -29, 0, 6)
    CloseBtn.BackgroundColor3 = Theme.TabInactive
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "x"
    CloseBtn.TextColor3 = Theme.Text
    CloseBtn.TextSize = 13
    CloseBtn.ZIndex = 4
    CloseBtn.Parent = TopBar
    createCorner(CloseBtn, 4)

    local isMinimized = false
    MinBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        tween(self.MainFrame, { Size = isMinimized and UDim2.new(0, 520, 0, 34) or UDim2.new(0, 520, 0, 340) })
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        self:Toggle(false)
    end)
end

-- 2. Боковое меню (Sidebar)
function AutoBuildUI:BuildSidebar()
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 95, 1, -34)
    Sidebar.Position = UDim2.new(0, 5, 0, 37)
    Sidebar.BackgroundTransparency = 1
    Sidebar.ZIndex = 3
    Sidebar.Parent = self.MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 5)
    UIListLayout.Parent = Sidebar

    self.TabButtons = {}
    local tabs = {
        { Id = "BLOCKS", Name = "BLOCKS", Order = 1 },
        { Id = "BUILD", Name = "BUILD", Order = 2 },
        { Id = "EXPLOIT", Name = "EXPLOIT", Order = 3 },
        { Id = "SETTINGS", Name = "SETTINGS", Order = 4 }
    }

    for _, tabData in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. tabData.Id
        btn.Size = UDim2.new(1, 0, 0, 48)
        btn.LayoutOrder = tabData.Order
        btn.BackgroundColor3 = Theme.TabInactive
        btn.Font = Enum.Font.GothamBold
        btn.Text = tabData.Name
        btn.TextColor3 = Theme.TextMuted
        btn.TextSize = 11
        btn.ZIndex = 4
        btn.Parent = Sidebar
        createCorner(btn, 6)
        local stroke = createStroke(btn, Theme.Border, 1)

        btn.MouseButton1Click:Connect(function()
            self:SwitchTab(tabData.Id)
        end)

        self.TabButtons[tabData.Id] = { Button = btn, Stroke = stroke }
    end
end

function AutoBuildUI:SwitchTab(tabId)
    self.ActiveTab = tabId
    for id, tabObj in pairs(self.TabButtons) do
        local isCurrent = (id == tabId)
        tween(tabObj.Button, {
            BackgroundColor3 = isCurrent and Theme.TabActive or Theme.TabInactive,
            TextColor3 = isCurrent and Theme.Text or Theme.TextMuted
        })
        tabObj.Stroke.Color = isCurrent and Theme.AccentGlow or Theme.Border
    end

    for pageId, pageFrame in pairs(self.Pages) do
        pageFrame.Visible = (pageId == tabId)
    end
end

-- 3. Страница: BUILD (Auto-Build & Saver)
function AutoBuildUI:BuildBuildPage()
    local page = Instance.new("Frame")
    page.Name = "Page_BUILD"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = self.ContentFrame
    self.Pages["BUILD"] = page

    -- Статус и прогресс бар
    local StatusCard = Instance.new("Frame")
    StatusCard.Size = UDim2.new(1, 0, 0, 48)
    StatusCard.BackgroundColor3 = Theme.CardBg
    StatusCard.Parent = page
    createCorner(StatusCard, 6)
    createStroke(StatusCard, Theme.Border, 1)

    self.StatusTitle = Instance.new("TextLabel")
    self.StatusTitle.Size = UDim2.new(1, -12, 0, 15)
    self.StatusTitle.Position = UDim2.new(0, 8, 0, 4)
    self.StatusTitle.BackgroundTransparency = 1
    self.StatusTitle.Font = Enum.Font.GothamBold
    self.StatusTitle.Text = "Ready"
    self.StatusTitle.TextColor3 = Theme.Text
    self.StatusTitle.TextSize = 11
    self.StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusTitle.Parent = StatusCard

    self.StatusSubtitle = Instance.new("TextLabel")
    self.StatusSubtitle.Size = UDim2.new(0.6, 0, 0, 14)
    self.StatusSubtitle.Position = UDim2.new(0, 8, 0, 18)
    self.StatusSubtitle.BackgroundTransparency = 1
    self.StatusSubtitle.Font = Enum.Font.Gotham
    self.StatusSubtitle.Text = "Ready to build"
    self.StatusSubtitle.TextColor3 = Theme.TextMuted
    self.StatusSubtitle.TextSize = 10
    self.StatusSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusSubtitle.Parent = StatusCard

    self.PercentLabel = Instance.new("TextLabel")
    self.PercentLabel.Size = UDim2.new(0, 50, 0, 14)
    self.PercentLabel.Position = UDim2.new(0.5, -25, 0, 18)
    self.PercentLabel.BackgroundTransparency = 1
    self.PercentLabel.Font = Enum.Font.GothamBold
    self.PercentLabel.Text = "0%"
    self.PercentLabel.TextColor3 = Theme.Text
    self.PercentLabel.TextSize = 10
    self.PercentLabel.Parent = StatusCard

    local ProgressBg = Instance.new("Frame")
    ProgressBg.Size = UDim2.new(1, -16, 0, 6)
    ProgressBg.Position = UDim2.new(0, 8, 0, 35)
    ProgressBg.BackgroundColor3 = Theme.InputBg
    ProgressBg.Parent = StatusCard
    createCorner(ProgressBg, 3)

    self.ProgressBar = Instance.new("Frame")
    self.ProgressBar.Size = UDim2.new(0, 0, 1, 0)
    self.ProgressBar.BackgroundColor3 = Theme.Accent
    self.ProgressBar.Parent = ProgressBg
    createCorner(self.ProgressBar, 3)

    -- Переключатель [ BUILD ] / [ SAVER ]
    local ModeSwitchFrame = Instance.new("Frame")
    ModeSwitchFrame.Size = UDim2.new(1, 0, 0, 26)
    ModeSwitchFrame.Position = UDim2.new(0, 0, 0, 52)
    ModeSwitchFrame.BackgroundColor3 = Theme.InputBg
    ModeSwitchFrame.Parent = page
    createCorner(ModeSwitchFrame, 5)
    createStroke(ModeSwitchFrame, Theme.Border, 1)

    local BuildModeBtn = Instance.new("TextButton")
    BuildModeBtn.Size = UDim2.new(0.5, -2, 1, -2)
    BuildModeBtn.Position = UDim2.new(0, 1, 0, 1)
    BuildModeBtn.BackgroundColor3 = Theme.TabActive
    BuildModeBtn.Font = Enum.Font.GothamBold
    BuildModeBtn.Text = "BUILD"
    BuildModeBtn.TextColor3 = Theme.Text
    BuildModeBtn.TextSize = 10
    BuildModeBtn.Parent = ModeSwitchFrame
    createCorner(BuildModeBtn, 4)

    local SaverModeBtn = Instance.new("TextButton")
    SaverModeBtn.Size = UDim2.new(0.5, -2, 1, -2)
    SaverModeBtn.Position = UDim2.new(0.5, 1, 0, 1)
    SaverModeBtn.BackgroundTransparency = 1
    SaverModeBtn.Font = Enum.Font.GothamBold
    SaverModeBtn.Text = "SAVER"
    SaverModeBtn.TextColor3 = Theme.TextMuted
    SaverModeBtn.TextSize = 10
    SaverModeBtn.Parent = ModeSwitchFrame
    createCorner(SaverModeBtn, 4)

    -- Контейнер BUILD
    local BuildScroll = Instance.new("ScrollingFrame")
    BuildScroll.Size = UDim2.new(1, 0, 1, -84)
    BuildScroll.Position = UDim2.new(0, 0, 0, 82)
    BuildScroll.BackgroundTransparency = 1
    BuildScroll.BorderSizePixel = 0
    BuildScroll.ScrollBarThickness = 3
    BuildScroll.ScrollBarImageColor3 = Theme.Accent
    BuildScroll.CanvasSize = UDim2.new(0, 0, 0, 360)
    BuildScroll.Parent = page

    local bLayout = Instance.new("UIListLayout")
    bLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bLayout.Padding = UDim.new(0, 5)
    bLayout.Parent = BuildScroll

    local function makeLabel(text, parent)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = text
        lbl.TextColor3 = Theme.TextMuted
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
        return lbl
    end

    makeLabel("BUILD FILES", BuildScroll)

    self.FileSelectBtn = Instance.new("TextButton")
    self.FileSelectBtn.Size = UDim2.new(1, 0, 0, 24)
    self.FileSelectBtn.BackgroundColor3 = Theme.CardBg
    self.FileSelectBtn.Font = Enum.Font.Gotham
    self.FileSelectBtn.Text = "  Select file...                                                     v"
    self.FileSelectBtn.TextColor3 = Theme.Text
    self.FileSelectBtn.TextSize = 10
    self.FileSelectBtn.TextXAlignment = Enum.TextXAlignment.Left
    self.FileSelectBtn.Parent = BuildScroll
    createCorner(self.FileSelectBtn, 4)
    createStroke(self.FileSelectBtn, Theme.Border, 1)

    local RefreshFilesBtn = Instance.new("TextButton")
    RefreshFilesBtn.Size = UDim2.new(1, 0, 0, 24)
    RefreshFilesBtn.BackgroundColor3 = Theme.CardBg
    RefreshFilesBtn.Font = Enum.Font.Gotham
    RefreshFilesBtn.Text = "Refresh File List"
    RefreshFilesBtn.TextColor3 = Theme.Text
    RefreshFilesBtn.TextSize = 10
    RefreshFilesBtn.Parent = BuildScroll
    createCorner(RefreshFilesBtn, 4)
    createStroke(RefreshFilesBtn, Theme.Border, 1)

    makeLabel("ACTIONS", BuildScroll)

    local ActionBuildBtn = Instance.new("TextButton")
    ActionBuildBtn.Size = UDim2.new(1, 0, 0, 24)
    ActionBuildBtn.BackgroundColor3 = Theme.CardBg
    ActionBuildBtn.Font = Enum.Font.GothamBold
    ActionBuildBtn.Text = "Build"
    ActionBuildBtn.TextColor3 = Theme.Text
    ActionBuildBtn.TextSize = 11
    ActionBuildBtn.Parent = BuildScroll
    createCorner(ActionBuildBtn, 4)
    createStroke(ActionBuildBtn, Theme.Border, 1)

    local StopBuildBtn = Instance.new("TextButton")
    StopBuildBtn.Size = UDim2.new(1, 0, 0, 24)
    StopBuildBtn.BackgroundColor3 = Theme.CardBg
    StopBuildBtn.Font = Enum.Font.GothamBold
    StopBuildBtn.Text = "Stop Build"
    StopBuildBtn.TextColor3 = Theme.Danger
    StopBuildBtn.TextSize = 11
    StopBuildBtn.Parent = BuildScroll
    createCorner(StopBuildBtn, 4)
    createStroke(StopBuildBtn, Theme.Border, 1)

    local PreviewBtn = Instance.new("TextButton")
    PreviewBtn.Size = UDim2.new(1, 0, 0, 24)
    PreviewBtn.BackgroundColor3 = Theme.CardBg
    PreviewBtn.Font = Enum.Font.Gotham
    PreviewBtn.Text = "Clear Preview / Preview"
    PreviewBtn.TextColor3 = Theme.Text
    PreviewBtn.TextSize = 10
    PreviewBtn.Parent = BuildScroll
    createCorner(PreviewBtn, 4)
    createStroke(PreviewBtn, Theme.Border, 1)

    makeLabel("BUILD SCALE / OFFSET", BuildScroll)

    local OffsetRow = Instance.new("Frame")
    OffsetRow.Size = UDim2.new(1, 0, 0, 24)
    OffsetRow.BackgroundTransparency = 1
    OffsetRow.Parent = BuildScroll

    local offLayout = Instance.new("UIListLayout")
    offLayout.FillDirection = Enum.FillDirection.Horizontal
    offLayout.Padding = UDim.new(0, 4)
    offLayout.Parent = OffsetRow

    local function makeBox(text, placeholder)
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.25, -3, 1, 0)
        box.BackgroundColor3 = Theme.InputBg
        box.Font = Enum.Font.Gotham
        box.Text = text
        box.PlaceholderText = placeholder
        box.TextColor3 = Theme.Text
        box.TextSize = 10
        box.ClearTextOnFocus = false
        box.Parent = OffsetRow
        createCorner(box, 4)
        createStroke(box, Theme.Border, 1)
        return box
    end

    self.InputScale = makeBox("1", "Scale")
    self.InputOffsetX = makeBox("0", "X")
    self.InputOffsetY = makeBox("3", "Y")
    self.InputOffsetZ = makeBox("0", "Z")

    makeLabel("BUILD SPEED (DELAY SEC)", BuildScroll)

    self.InputSpeed = Instance.new("TextBox")
    self.InputSpeed.Size = UDim2.new(1, 0, 0, 24)
    self.InputSpeed.BackgroundColor3 = Theme.InputBg
    self.InputSpeed.Font = Enum.Font.Gotham
    self.InputSpeed.Text = "0.03"
    self.InputSpeed.TextColor3 = Theme.Text
    self.InputSpeed.TextSize = 10
    self.InputSpeed.ClearTextOnFocus = false
    self.InputSpeed.Parent = BuildScroll
    createCorner(self.InputSpeed, 4)
    createStroke(self.InputSpeed, Theme.Border, 1)

    -- Контейнер SAVER
    local SaverScroll = Instance.new("ScrollingFrame")
    SaverScroll.Size = UDim2.new(1, 0, 1, -84)
    SaverScroll.Position = UDim2.new(0, 0, 0, 82)
    SaverScroll.BackgroundTransparency = 1
    SaverScroll.BorderSizePixel = 0
    SaverScroll.ScrollBarThickness = 3
    SaverScroll.ScrollBarImageColor3 = Theme.Accent
    SaverScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
    SaverScroll.Visible = false
    SaverScroll.Parent = page

    local sLayout = Instance.new("UIListLayout")
    sLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sLayout.Padding = UDim.new(0, 6)
    sLayout.Parent = SaverScroll

    makeLabel("TARGET PLAYER", SaverScroll)

    self.PlayerSelectBtn = Instance.new("TextButton")
    self.PlayerSelectBtn.Size = UDim2.new(1, 0, 0, 24)
    self.PlayerSelectBtn.BackgroundColor3 = Theme.CardBg
    self.PlayerSelectBtn.Font = Enum.Font.Gotham
    self.PlayerSelectBtn.Text = "  " .. LocalPlayer.Name .. " [ME]                                 v"
    self.PlayerSelectBtn.TextColor3 = Theme.Text
    self.PlayerSelectBtn.TextSize = 10
    self.PlayerSelectBtn.TextXAlignment = Enum.TextXAlignment.Left
    self.PlayerSelectBtn.Parent = SaverScroll
    createCorner(self.PlayerSelectBtn, 4)
    createStroke(self.PlayerSelectBtn, Theme.Border, 1)

    makeLabel("FILE NAME", SaverScroll)

    self.InputSaveFileName = Instance.new("TextBox")
    self.InputSaveFileName.Size = UDim2.new(1, 0, 0, 24)
    self.InputSaveFileName.BackgroundColor3 = Theme.InputBg
    self.InputSaveFileName.Font = Enum.Font.Gotham
    self.InputSaveFileName.PlaceholderText = "Enter file name..."
    self.InputSaveFileName.Text = ""
    self.InputSaveFileName.TextColor3 = Theme.Text
    self.InputSaveFileName.TextSize = 10
    self.InputSaveFileName.ClearTextOnFocus = false
    self.InputSaveFileName.Parent = SaverScroll
    createCorner(self.InputSaveFileName, 4)
    createStroke(self.InputSaveFileName, Theme.Border, 1)

    local SaveBuildBtn = Instance.new("TextButton")
    SaveBuildBtn.Size = UDim2.new(1, 0, 0, 26)
    SaveBuildBtn.BackgroundColor3 = Theme.TabActive
    SaveBuildBtn.Font = Enum.Font.GothamBold
    SaveBuildBtn.Text = "Save Build"
    SaveBuildBtn.TextColor3 = Theme.Text
    SaveBuildBtn.TextSize = 11
    SaveBuildBtn.Parent = SaverScroll
    createCorner(SaveBuildBtn, 4)
    createStroke(SaveBuildBtn, Theme.AccentGlow, 1)

    -- Переключение режимов
    BuildModeBtn.MouseButton1Click:Connect(function()
        BuildModeBtn.BackgroundColor3 = Theme.TabActive
        BuildModeBtn.BackgroundTransparency = 0
        BuildModeBtn.TextColor3 = Theme.Text
        SaverModeBtn.BackgroundTransparency = 1
        SaverModeBtn.TextColor3 = Theme.TextMuted
        BuildScroll.Visible = true
        SaverScroll.Visible = false
    end)

    SaverModeBtn.MouseButton1Click:Connect(function()
        SaverModeBtn.BackgroundColor3 = Theme.TabActive
        SaverModeBtn.BackgroundTransparency = 0
        SaverModeBtn.TextColor3 = Theme.Text
        BuildModeBtn.BackgroundTransparency = 1
        BuildModeBtn.TextColor3 = Theme.TextMuted
        BuildScroll.Visible = false
        SaverScroll.Visible = true
    end)

    -- Колбэки
    ActionBuildBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnBuild then
            self.Callbacks.OnBuild({
                Scale = tonumber(self.InputScale.Text) or 1,
                Offset = Vector3.new(
                    tonumber(self.InputOffsetX.Text) or 0,
                    tonumber(self.InputOffsetY.Text) or 0,
                    tonumber(self.InputOffsetZ.Text) or 0
                ),
                Delay = tonumber(self.InputSpeed.Text) or 0.03
            })
        end
    end)

    StopBuildBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnStop then self.Callbacks.OnStop() end
    end)

    SaveBuildBtn.MouseButton1Click:Connect(function()
        if self.Callbacks.OnSave then
            self.Callbacks.OnSave(self.InputSaveFileName.Text)
        end
    end)
end

-- 4. Страница: BLOCKS (Требуемые блоки)
function AutoBuildUI:BuildBlocksPage()
    local page = Instance.new("Frame")
    page.Name = "Page_BLOCKS"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = self.ContentFrame
    self.Pages["BLOCKS"] = page

    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 24)
    Header.BackgroundTransparency = 1
    Header.Parent = page

    local lblReq = Instance.new("TextLabel")
    lblReq.Size = UDim2.new(0.5, 0, 1, 0)
    lblReq.BackgroundTransparency = 1
    lblReq.Font = Enum.Font.GothamBold
    lblReq.Text = "REQUIRED BLOCKS"
    lblReq.TextColor3 = Theme.Text
    lblReq.TextSize = 11
    lblReq.TextXAlignment = Enum.TextXAlignment.Left
    lblReq.Parent = Header

    local RefreshBlocksBtn = Instance.new("TextButton")
    RefreshBlocksBtn.Size = UDim2.new(0, 60, 1, 0)
    RefreshBlocksBtn.Position = UDim2.new(1, -60, 0, 0)
    RefreshBlocksBtn.BackgroundColor3 = Theme.CardBg
    RefreshBlocksBtn.Font = Enum.Font.Gotham
    RefreshBlocksBtn.Text = "Refresh"
    RefreshBlocksBtn.TextColor3 = Theme.Text
    RefreshBlocksBtn.TextSize = 10
    RefreshBlocksBtn.Parent = Header
    createCorner(RefreshBlocksBtn, 4)
    createStroke(RefreshBlocksBtn, Theme.Border, 1)

    self.BlocksInfoLabel = Instance.new("TextLabel")
    self.BlocksInfoLabel.Size = UDim2.new(1, 0, 0, 16)
    self.BlocksInfoLabel.Position = UDim2.new(0, 0, 0, 26)
    self.BlocksInfoLabel.BackgroundTransparency = 1
    self.BlocksInfoLabel.Font = Enum.Font.Gotham
    self.BlocksInfoLabel.Text = "INF: -0 parts | Total blocks: 0"
    self.BlocksInfoLabel.TextColor3 = Theme.TextMuted
    self.BlocksInfoLabel.TextSize = 10
    self.BlocksInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    self.BlocksInfoLabel.Parent = page

    self.BlocksGridScroll = Instance.new("ScrollingFrame")
    self.BlocksGridScroll.Size = UDim2.new(1, 0, 1, -46)
    self.BlocksGridScroll.Position = UDim2.new(0, 0, 0, 44)
    self.BlocksGridScroll.BackgroundTransparency = 1
    self.BlocksGridScroll.BorderSizePixel = 0
    self.BlocksGridScroll.ScrollBarThickness = 3
    self.BlocksGridScroll.ScrollBarImageColor3 = Theme.Accent
    self.BlocksGridScroll.Parent = page

    local grid = Instance.new("UIGridLayout")
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.CellSize = UDim2.new(0, 94, 0, 96)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = self.BlocksGridScroll
end

-- Добавление карточки блока в BLOCKS
function AutoBuildUI:AddBlockCard(blockName, needCount, haveCount, partsCount, iconAssetId)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. blockName
    card.BackgroundColor3 = Theme.CardBg
    card.Parent = self.BlocksGridScroll
    createCorner(card, 5)

    local isSufficient = (haveCount >= needCount)
    createStroke(card, isSufficient and Theme.Border or Theme.Danger, 1)

    local btnM = Instance.new("TextButton")
    btnM.Size = UDim2.new(0, 14, 0, 14)
    btnM.Position = UDim2.new(1, -32, 0, 2)
    btnM.BackgroundColor3 = Theme.InputBg
    btnM.Font = Enum.Font.GothamBold
    btnM.Text = "M"
    btnM.TextColor3 = Theme.TextMuted
    btnM.TextSize = 8
    btnM.Parent = card
    createCorner(btnM, 2)

    local btnX = Instance.new("TextButton")
    btnX.Size = UDim2.new(0, 14, 0, 14)
    btnX.Position = UDim2.new(1, -16, 0, 2)
    btnX.BackgroundColor3 = Theme.InputBg
    btnX.Font = Enum.Font.GothamBold
    btnX.Text = "X"
    btnX.TextColor3 = Theme.Danger
    btnX.TextSize = 8
    btnX.Parent = card
    createCorner(btnX, 2)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 32, 0, 32)
    icon.Position = UDim2.new(0.5, -16, 0, 14)
    icon.BackgroundTransparency = 1
    icon.Image = iconAssetId or "rbxassetid://10849911875"
    icon.Parent = card

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -4, 0, 14)
    nameLabel.Position = UDim2.new(0, 2, 0, 48)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = blockName
    nameLabel.TextColor3 = Theme.Text
    nameLabel.TextSize = 9
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(1, -4, 0, 12)
    countLabel.Position = UDim2.new(0, 2, 0, 62)
    countLabel.BackgroundTransparency = 1
    countLabel.Font = Enum.Font.Gotham
    countLabel.Text = string.format("%d need / %d have", needCount, haveCount)
    countLabel.TextColor3 = isSufficient and Theme.Success or Theme.Danger
    countLabel.TextSize = 8
    countLabel.Parent = card

    local partsLabel = Instance.new("TextLabel")
    partsLabel.Size = UDim2.new(1, -4, 0, 12)
    partsLabel.Position = UDim2.new(0, 2, 0, 76)
    partsLabel.BackgroundTransparency = 1
    partsLabel.Font = Enum.Font.Gotham
    partsLabel.Text = string.format("%d part(s)", partsCount or needCount)
    partsLabel.TextColor3 = Theme.TextMuted
    partsLabel.TextSize = 8
    partsLabel.Parent = card
end

-- 5. Страница: EXPLOIT (Shape Builder)
function AutoBuildUI:BuildExploitPage()
    local page = Instance.new("Frame")
    page.Name = "Page_EXPLOIT"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = self.ContentFrame
    self.Pages["EXPLOIT"] = page

    local SubNav = Instance.new("Frame")
    SubNav.Size = UDim2.new(1, 0, 0, 22)
    SubNav.BackgroundTransparency = 1
    SubNav.Parent = page

    local sLayout = Instance.new("UIListLayout")
    sLayout.FillDirection = Enum.FillDirection.Horizontal
    sLayout.Padding = UDim.new(0, 4)
    sLayout.Parent = SubNav

    for _, name in ipairs({ "INP", "MISC", "MOVE", "CONV", "SHAPE" }) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.2, -4, 1, 0)
        btn.BackgroundColor3 = (name == "SHAPE") and Theme.TabActive or Theme.TabInactive
        btn.Font = Enum.Font.GothamBold
        btn.Text = name
        btn.TextColor3 = (name == "SHAPE") and Theme.Text or Theme.TextMuted
        btn.TextSize = 9
        btn.Parent = SubNav
        createCorner(btn, 3)
    end

    local ShapeScroll = Instance.new("ScrollingFrame")
    ShapeScroll.Size = UDim2.new(1, 0, 1, -26)
    ShapeScroll.Position = UDim2.new(0, 0, 0, 26)
    ShapeScroll.BackgroundTransparency = 1
    ShapeScroll.BorderSizePixel = 0
    ShapeScroll.ScrollBarThickness = 3
    ShapeScroll.ScrollBarImageColor3 = Theme.Accent
    ShapeScroll.CanvasSize = UDim2.new(0, 0, 0, 310)
    ShapeScroll.Parent = page

    local shLayout = Instance.new("UIListLayout")
    shLayout.SortOrder = Enum.SortOrder.LayoutOrder
    shLayout.Padding = UDim.new(0, 4)
    shLayout.Parent = ShapeScroll

    local function makeDrop(text)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = Theme.CardBg
        btn.Font = Enum.Font.Gotham
        btn.Text = "  " .. text .. "                                                         v"
        btn.TextColor3 = Theme.Text
        btn.TextSize = 10
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = ShapeScroll
        createCorner(btn, 4)
        createStroke(btn, Theme.Border, 1)
        return btn
    end

    makeDrop("WoodBlock")
    makeDrop("cylinder")

    local function makeStepper(labelName, defVal)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Parent = ShapeScroll

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.Text = labelName .. ":"
        lbl.TextColor3 = Theme.TextMuted
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local minus = Instance.new("TextButton")
        minus.Size = UDim2.new(0, 22, 1, 0)
        minus.Position = UDim2.new(0.55, 0, 0, 0)
        minus.BackgroundColor3 = Theme.InputBg
        minus.Font = Enum.Font.GothamBold
        minus.Text = "-"
        minus.TextColor3 = Theme.Text
        minus.TextSize = 12
        minus.Parent = row
        createCorner(minus, 3)

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.3, -48, 1, 0)
        box.Position = UDim2.new(0.55, 24, 0, 0)
        box.BackgroundColor3 = Theme.InputBg
        box.Font = Enum.Font.Gotham
        box.Text = tostring(defVal)
        box.TextColor3 = Theme.Text
        box.TextSize = 10
        box.ClearTextOnFocus = false
        box.Parent = row
        createCorner(box, 3)

        local plus = Instance.new("TextButton")
        plus.Size = UDim2.new(0, 22, 1, 0)
        plus.Position = UDim2.new(0.85, -20, 0, 0)
        plus.BackgroundColor3 = Theme.InputBg
        plus.Font = Enum.Font.GothamBold
        plus.Text = "+"
        plus.TextColor3 = Theme.Text
        plus.TextSize = 12
        plus.Parent = row
        createCorner(plus, 3)
    end

    makeStepper("Radius", 6)
    makeStepper("Height", 10)
    makeStepper("Segments", 12)
    makeStepper("Thickness", 0.2)
    makeStepper("Height Offset", 15)

    local PreviewBtn = Instance.new("TextButton")
    PreviewBtn.Size = UDim2.new(1, 0, 0, 24)
    PreviewBtn.BackgroundColor3 = Theme.CardBg
    PreviewBtn.Font = Enum.Font.Gotham
    PreviewBtn.Text = "Preview"
    PreviewBtn.TextColor3 = Theme.Text
    PreviewBtn.TextSize = 10
    PreviewBtn.Parent = ShapeScroll
    createCorner(PreviewBtn, 4)
    createStroke(PreviewBtn, Theme.Border, 1)

    local SaveShapeBtn = Instance.new("TextButton")
    SaveShapeBtn.Size = UDim2.new(1, 0, 0, 24)
    SaveShapeBtn.BackgroundColor3 = Theme.TabActive
    SaveShapeBtn.Font = Enum.Font.GothamBold
    SaveShapeBtn.Text = "SAVE File"
    SaveShapeBtn.TextColor3 = Theme.Text
    SaveShapeBtn.TextSize = 10
    SaveShapeBtn.Parent = ShapeScroll
    createCorner(SaveShapeBtn, 4)
    createStroke(SaveShapeBtn, Theme.AccentGlow, 1)
end

-- 6. Страница: SETTINGS
function AutoBuildUI:BuildSettingsPage()
    local page = Instance.new("Frame")
    page.Name = "Page_SETTINGS"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = self.ContentFrame
    self.Pages["SETTINGS"] = page

    local SubNav = Instance.new("Frame")
    SubNav.Size = UDim2.new(1, 0, 0, 22)
    SubNav.BackgroundTransparency = 1
    SubNav.Parent = page

    local sLayout = Instance.new("UIListLayout")
    sLayout.FillDirection = Enum.FillDirection.Horizontal
    sLayout.Padding = UDim.new(0, 4)
    sLayout.Parent = SubNav

    for _, name in ipairs({ "BUILD", "FARM", "GUI" }) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.333, -3, 1, 0)
        btn.BackgroundColor3 = (name == "GUI") and Theme.TabActive or Theme.TabInactive
        btn.Font = Enum.Font.GothamBold
        btn.Text = name
        btn.TextColor3 = (name == "GUI") and Theme.Text or Theme.TextMuted
        btn.TextSize = 10
        btn.Parent = SubNav
        createCorner(btn, 3)
    end

    local SetScroll = Instance.new("ScrollingFrame")
    SetScroll.Size = UDim2.new(1, 0, 1, -26)
    SetScroll.Position = UDim2.new(0, 0, 0, 26)
    SetScroll.BackgroundTransparency = 1
    SetScroll.BorderSizePixel = 0
    SetScroll.ScrollBarThickness = 3
    SetScroll.ScrollBarImageColor3 = Theme.Accent
    SetScroll.CanvasSize = UDim2.new(0, 0, 0, 250)
    SetScroll.Parent = page

    local setList = Instance.new("UIListLayout")
    setList.SortOrder = Enum.SortOrder.LayoutOrder
    setList.Padding = UDim.new(0, 6)
    setList.Parent = SetScroll

    local function makeSettingStepper(title, val)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Parent = SetScroll

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.Text = title
        lbl.TextColor3 = Theme.TextMuted
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local minus = Instance.new("TextButton")
        minus.Size = UDim2.new(0, 22, 1, 0)
        minus.Position = UDim2.new(0.7, -26, 0, 0)
        minus.BackgroundColor3 = Theme.InputBg
        minus.Font = Enum.Font.GothamBold
        minus.Text = "-"
        minus.TextColor3 = Theme.Text
        minus.TextSize = 12
        minus.Parent = row
        createCorner(minus, 3)

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0, 44, 1, 0)
        valLbl.Position = UDim2.new(0.7, 0, 0, 0)
        valLbl.BackgroundColor3 = Theme.InputBg
        valLbl.Font = Enum.Font.Gotham
        valLbl.Text = val
        valLbl.TextColor3 = Theme.Text
        valLbl.TextSize = 10
        valLbl.Parent = row
        createCorner(valLbl, 3)

        local plus = Instance.new("TextButton")
        plus.Size = UDim2.new(0, 22, 1, 0)
        plus.Position = UDim2.new(0.7, 48, 0, 0)
        plus.BackgroundColor3 = Theme.InputBg
        plus.Font = Enum.Font.GothamBold
        plus.Text = "+"
        plus.TextColor3 = Theme.Text
        plus.TextSize = 12
        plus.Parent = row
        createCorner(plus, 3)
    end

    makeSettingStepper("UI Scale", "100%")
    makeSettingStepper("GUI Transparency", "15%")
    makeSettingStepper("Preview Transparency", "50%")

    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Size = UDim2.new(1, 0, 0, 26)
    SaveBtn.BackgroundColor3 = Theme.TabActive
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.Text = "Save All Settings"
    SaveBtn.TextColor3 = Theme.Text
    SaveBtn.TextSize = 10
    SaveBtn.Parent = SetScroll
    createCorner(SaveBtn, 4)
    createStroke(SaveBtn, Theme.AccentGlow, 1)
end

-- Публичный API модуля для взаимодействия с Loader
function AutoBuildUI:SetStatus(title, subtitle)
    if self.StatusTitle then self.StatusTitle.Text = title or "" end
    if self.StatusSubtitle then self.StatusSubtitle.Text = subtitle or "" end
end

function AutoBuildUI:SetProgress(percent)
    percent = math.clamp(percent or 0, 0, 100)
    if self.PercentLabel then
        self.PercentLabel.Text = string.format("%d%%", percent)
    end
    if self.ProgressBar then
        tween(self.ProgressBar, { Size = UDim2.new(percent / 100, 0, 1, 0) })
    end
end

function AutoBuildUI:SetBlocksInfo(totalBlocks, missingParts)
    if self.BlocksInfoLabel then
        self.BlocksInfoLabel.Text = string.format("INF: -%d parts | Total blocks: %d", missingParts or 0, totalBlocks or 0)
    end
end

function AutoBuildUI:ClearBlocks()
    for _, child in ipairs(self.BlocksGridScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name:sub(1, 5) == "Card_" then
            child:Destroy()
        end
    end
end

function AutoBuildUI:Toggle(visible)
    if visible == nil then
        self.MainFrame.Visible = not self.MainFrame.Visible
    else
        self.MainFrame.Visible = visible
    end
end

function AutoBuildUI:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
end

return AutoBuildUI

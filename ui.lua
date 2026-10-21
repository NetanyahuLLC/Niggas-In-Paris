local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UI = {}

function UI.new(options)
    options = options or {}
    local self = {
        alive = true,
        connections = {},
        rows = {},
        crateRows = {},
        queue = {},
        tweens = {},
    }

    local colors = {
        background = Color3.fromRGB(10, 10, 10),
        panel = Color3.fromRGB(17, 17, 17),
        card = Color3.fromRGB(23, 23, 23),
        border = Color3.fromRGB(49, 49, 49),
        white = Color3.fromRGB(245, 245, 245),
        secondary = Color3.fromRGB(165, 165, 165),
        muted = Color3.fromRGB(115, 115, 115),
    }

    local function make(class, parent, props)
        local obj = Instance.new(class)
        for key, value in pairs(props or {}) do obj[key] = value end
        obj.Parent = parent
        return obj
    end

    local function corner(obj, radius)
        make("UICorner", obj, {CornerRadius = UDim.new(0, radius or 6)})
    end

    local function card(parent, props)
        props.BackgroundColor3 = props.BackgroundColor3 or colors.card
        props.BorderSizePixel = 0
        local obj = make("Frame", parent, props)
        corner(obj)
        make("UIStroke", obj, {
            Color = colors.border,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
        return obj
    end

    local function label(parent, props)
        local defaults = {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = colors.secondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }
        for key, value in pairs(props) do defaults[key] = value end
        return make("TextLabel", parent, defaults)
    end

    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(self.connections, connection)
        return connection
    end

    local function tween(obj, duration, props)
        local animation = TweenService:Create(
            obj,
            TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            props
        )
        self.tweens[animation] = true
        animation.Completed:Once(function() self.tweens[animation] = nil end)
        animation:Play()
        return animation
    end

    local parent = options.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
    local guiName = options.Name or "Lezor"
    local old = parent:FindFirstChild(guiName)
    if old then old:Destroy() end

    local gui = make("ScreenGui", parent, {
        Name = guiName,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 50,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    local destroyed = Instance.new("BindableEvent")
    local toggled = Instance.new("BindableEvent")
    local shown = Instance.new("BindableEvent")
    local soundToggled = Instance.new("BindableEvent")
    local crateBuy = Instance.new("BindableEvent")
    self.Destroyed = destroyed.Event
    self.AlertToggled = toggled.Event
    self.NotificationShown = shown.Event
    self.SoundToggled = soundToggled.Event
    self.CrateBuy = crateBuy.Event

    local autobuyRowToggled = Instance.new("BindableEvent")
    local autobuyCountChanged = Instance.new("BindableEvent")
    local autobuyMasterToggled = Instance.new("BindableEvent")
    self.AutobuyRowToggled = autobuyRowToggled.Event
    self.AutobuyCountChanged = autobuyCountChanged.Event
    self.AutobuyMasterToggled = autobuyMasterToggled.Event

    local autosellToggled = Instance.new("BindableEvent")
    local autosellBalance = Instance.new("BindableEvent")
    local autosellPrice = Instance.new("BindableEvent")
    local autocollectToggled = Instance.new("BindableEvent")
    local autocollectInterval = Instance.new("BindableEvent")
    self.AutosellToggled = autosellToggled.Event
    self.AutosellBalance = autosellBalance.Event
    self.AutosellPrice = autosellPrice.Event
    self.AutocollectToggled = autocollectToggled.Event
    self.AutocollectInterval = autocollectInterval.Event

    local window = card(gui, {
        Name = "MainWindow",
        Size = UDim2.fromOffset(540, 390),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = colors.background,
        Active = true,
    })

    label(window, {
        Text = options.Title or "Lezor",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.fromOffset(290, 22),
    })
    label(window, {
        Text = "RSHIFT / HIDE",
        TextSize = 9,
        Position = UDim2.new(1, -110, 0, 32),
        Size = UDim2.fromOffset(95, 14),
    })

    -- Tab pages keep a caller-assigned "home" position; switching tabs
    -- tweens relative to home instead of clobbering the layout.
    local function tabs(parentObj, names, position, size)
        local bar = card(parentObj, {
            Position = position,
            Size = size,
            BackgroundColor3 = colors.panel,
        })
        local buttons, pages = {}, {}
        local home = {}
        local activeName

        local function select(name)
            if activeName == name then return end
            activeName = name
            for key, button in pairs(buttons) do
                local selected = key == name
                tween(button, 0.16, {
                    BackgroundColor3 = selected and colors.white or colors.panel,
                    TextColor3 = selected and colors.background or colors.secondary,
                })
                local page = pages[key]
                if selected then
                    if not home[page] then
                        home[page] = page.Position
                    end
                    page.Visible = true
                    page.Position = home[page] + UDim2.fromOffset(0, 5)
                    tween(page, 0.20, {Position = home[page]})
                else
                    page.Visible = false
                end
            end
        end

        for index, name in ipairs(names) do
            local button = make("TextButton", bar, {
                Text = name,
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                BackgroundColor3 = colors.panel,
                TextColor3 = colors.secondary,
                Position = UDim2.new((index - 1) / #names, 3, 0, 3),
                Size = UDim2.new(1 / #names, -6, 1, -6),
            })
            corner(button, 4)
            buttons[name] = button
            pages[name] = make("Frame", parentObj, {
                BackgroundTransparency = 1,
                Visible = false,
            })
            connect(button.Activated, function() select(name) end)
        end

        return pages, select
    end

    -- Layout first, then select, so "home" is captured correctly.
    local pages, selectMainTab = tabs(
        window,
        {"Exchange", "Markets", "Crates", "Autos", "Settings"},
        UDim2.new(1, -306, 0, 6),
        UDim2.fromOffset(290, 26)
    )
    for _, page in pairs(pages) do
        page.Position = UDim2.fromOffset(12, 52)
        page.Size = UDim2.new(1, -24, 1, -64)
    end
    selectMainTab("Exchange")

    local function info(parentObj, name, y)
        local box = card(parentObj, {
            Size = UDim2.new(1, 0, 0, 48),
            Position = UDim2.fromOffset(0, y),
        })
        label(box, {
            Text = name,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0.6, -12, 1, 0),
        })
        return label(box, {
            Text = "--",
            Font = Enum.Font.GothamBold,
            TextColor3 = colors.white,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right,
            Position = UDim2.new(0.6, 0, 0, 0),
            Size = UDim2.new(0.4, -12, 1, 0),
        })
    end

    local priceLabel = info(pages.Exchange, "Current Token Price", 0)
    local epochLabel = info(pages.Exchange, "Next Price Switch", 56)
    local restockLabel = info(pages.Markets, "Shop Restock", 0)

    local shopPages, selectShopTab = tabs(
        pages.Markets,
        {"Hardware", "Data Sources", "Data Packs"},
        UDim2.fromOffset(0, 56),
        UDim2.new(1, 0, 0, 30)
    )

    local lists = {}
    for name, page in pairs(shopPages) do
        page.Position = UDim2.fromOffset(0, 94)
        page.Size = UDim2.new(1, 0, 1, -94)
        local list = make("ScrollingFrame", page, {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        make("UIListLayout", list, {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        lists[name] = list
    end
    selectShopTab("Hardware")

    -- Crates page (black market stock + buy buttons)
    local crateList = make("ScrollingFrame", pages.Crates, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", crateList, {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    label(pages.Crates, {
        Text = "DEALER STOCK / SMUGGLED CRATES",
        TextSize = 9,
        Position = UDim2.fromOffset(0, -16),
        Size = UDim2.new(1, 0, 0, 14),
    })

    function self:AddCrate(item)
        local row = card(crateList, {
            Size = UDim2.new(1, -5, 0, 50),
            LayoutOrder = item.order,
        })
        label(row, {
            Text = item.name,
            TextColor3 = colors.white,
            TextSize = 11,
            Position = UDim2.fromOffset(12, 5),
            Size = UDim2.new(0.5, -20, 0, 18),
        })
        label(row, {
            Text = item.priceText,
            TextSize = 10,
            Position = UDim2.fromOffset(12, 27),
            Size = UDim2.new(0.5, -20, 0, 15),
        })
        local stock = label(row, {
            Text = "Stock: 0",
            TextSize = 10,
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.new(0.2, -6, 1, 0),
        })
        local buy = make("TextButton", row, {
            Text = "BUY",
            TextSize = 9,
            Font = Enum.Font.GothamMedium,
            BackgroundColor3 = colors.white,
            TextColor3 = colors.background,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -84, 0.5, -12),
            Size = UDim2.fromOffset(76, 25),
        })
        corner(buy, 5)
        self.crateRows[item.id] = {stock = stock, buy = buy}
        connect(buy.Activated, function() crateBuy:Fire(item.id) end)
    end

    function self:SetCrateStock(id, text, available)
        local row = self.crateRows[id]
        if not row then return end
        row.stock.Text = text
        row.stock.TextColor3 = available and colors.white or colors.muted
    end

    function self:SetCrateBuy(id, text, canBuy)
        local row = self.crateRows[id]
        if not row then return end
        row.buy.Text = text
        row.buy.BackgroundColor3 = canBuy and colors.white or colors.panel
        row.buy.TextColor3 = canBuy and colors.background or colors.muted
        row.buy.AutoButtonColor = canBuy
        row.buy.Active = canBuy
    end

    -- AutoBuy page: master toggle + per-crate config rows
    local autobuyMaster = make("TextButton", pages.Autos, {
        Text = "AUTO BUY: OFF",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BackgroundColor3 = colors.panel,
        TextColor3 = colors.secondary,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 30),
    })
    corner(autobuyMaster, 5)
    connect(autobuyMaster.Activated, function()
        local enabled = autobuyMaster.Text == "AUTO BUY: OFF"
        autobuyMaster.Text = enabled and "AUTO BUY: ON" or "AUTO BUY: OFF"
        autobuyMaster.BackgroundColor3 = enabled and colors.white or colors.panel
        autobuyMaster.TextColor3 = enabled and colors.background or colors.secondary
        autobuyMasterToggled:Fire(enabled)
    end)

    local autobuyList = make("ScrollingFrame", pages.Autos, {
        Size = UDim2.new(1, 0, 0, 108),
        Position = UDim2.fromOffset(0, 38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    make("UIListLayout", autobuyList, {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    self.autobuyRows = {}

    function self:AddAutobuyRow(item)
        local row = card(autobuyList, {
            Size = UDim2.new(1, -5, 0, 46),
            LayoutOrder = item.order,
        })
        label(row, {
            Text = item.name,
            TextColor3 = colors.white,
            TextSize = 11,
            Position = UDim2.fromOffset(12, 5),
            Size = UDim2.new(0.4, -20, 0, 16),
        })
        local progress = label(row, {
            Text = "0/" .. tostring(item.count or 1) .. " bought",
            TextSize = 9,
            Position = UDim2.fromOffset(12, 26),
            Size = UDim2.new(0.4, -20, 0, 14),
        })
        local toggle = make("TextButton", row, {
            Text = "OFF",
            TextSize = 9,
            Font = Enum.Font.GothamMedium,
            BackgroundColor3 = colors.panel,
            TextColor3 = colors.secondary,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Position = UDim2.new(0.44, 0, 0.5, -12),
            Size = UDim2.fromOffset(54, 24),
        })
        corner(toggle, 5)
        local minus = make("TextButton", row, {
            Text = "-",
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            BackgroundColor3 = colors.panel,
            TextColor3 = colors.white,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -156, 0.5, -12),
            Size = UDim2.fromOffset(24, 24),
        })
        corner(minus, 5)
        local countLbl = label(row, {
            Text = tostring(item.count or 1),
            TextColor3 = colors.white,
            TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.new(1, -126, 0.5, -12),
            Size = UDim2.fromOffset(32, 24),
        })
        local plus = make("TextButton", row, {
            Text = "+",
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            BackgroundColor3 = colors.panel,
            TextColor3 = colors.white,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -92, 0.5, -12),
            Size = UDim2.fromOffset(24, 24),
        })
        corner(plus, 5)

        local count = math.max(1, math.floor(item.count or 1))
        connect(minus.Activated, function()
            count = math.max(1, count - 1)
            countLbl.Text = tostring(count)
            autobuyCountChanged:Fire(item.id, count)
        end)
        connect(plus.Activated, function()
            count = math.min(99, count + 1)
            countLbl.Text = tostring(count)
            autobuyCountChanged:Fire(item.id, count)
        end)
        connect(toggle.Activated, function()
            local enabled = toggle.Text == "OFF"
            toggle.Text = enabled and "ON" or "OFF"
            toggle.BackgroundColor3 = enabled and colors.white or colors.panel
            toggle.TextColor3 = enabled and colors.background or colors.secondary
            autobuyRowToggled:Fire(item.id, enabled)
        end)

        self.autobuyRows[item.id] = {
            progress = progress,
            count = countLbl,
            toggle = toggle,
        }
    end

    function self:SetAutobuyProgress(id, text)
        local row = self.autobuyRows[id]
        if row then row.progress.Text = text end
    end

    -- Preset button row helper (used by AutoSell / AutoCollect cards)
    local function presetButtons(parentObj, y, options, onPick)
        local buttons = {}
        local function highlight(opt)
            for _, data in ipairs(buttons) do
                local active = data.opt == opt
                tween(data.button, 0.12, {
                    BackgroundColor3 = active and colors.white or colors.panel,
                    TextColor3 = active and colors.background or colors.secondary,
                })
            end
        end
        for index, opt in ipairs(options) do
            local button = make("TextButton", parentObj, {
                Text = opt.label,
                Font = Enum.Font.GothamMedium,
                TextSize = 9,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                BackgroundColor3 = colors.panel,
                TextColor3 = colors.secondary,
                Position = UDim2.fromOffset(12 + (index - 1) * 68, y),
                Size = UDim2.fromOffset(62, 22),
            })
            corner(button, 4)
            table.insert(buttons, {button = button, opt = opt})
            connect(button.Activated, function()
                highlight(opt)
                onPick(opt.value)
            end)
        end
    end

    local function sectionToggle(parentObj, onChange)
        local toggle = make("TextButton", parentObj, {
            Text = "OFF",
            TextSize = 9,
            Font = Enum.Font.GothamMedium,
            BackgroundColor3 = colors.panel,
            TextColor3 = colors.secondary,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -66, 0, 3),
            Size = UDim2.fromOffset(54, 20),
        })
        corner(toggle, 5)
        connect(toggle.Activated, function()
            local enabled = toggle.Text == "OFF"
            toggle.Text = enabled and "ON" or "OFF"
            toggle.BackgroundColor3 = enabled and colors.white or colors.panel
            toggle.TextColor3 = enabled and colors.background or colors.secondary
            onChange(enabled)
        end)
    end

    --========== AUTO SELL ==========
    local sellCard = card(pages.Autos, {
        Position = UDim2.fromOffset(0, 148),
        Size = UDim2.new(1, 0, 0, 94),
    })
    label(sellCard, {
        Text = "AUTO SELL",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.fromOffset(120, 16),
    })
    local sellStatus = label(sellCard, {
        Text = "Tokens: -- | Exchange: --",
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -252, 0, 5),
        Size = UDim2.fromOffset(240, 16),
    })
    label(sellCard, {
        Text = "SELL WHEN BALANCE IS AT LEAST",
        TextSize = 8,
        Position = UDim2.fromOffset(12, 20),
        Size = UDim2.new(1, -24, 0, 12),
    })
    presetButtons(sellCard, 32, {
        {label = "OFF", value = nil},
        {label = "5B", value = 5e9},
        {label = "10B", value = 10e9},
        {label = "20B", value = 20e9},
        {label = "30B", value = 30e9},
        {label = "40B", value = 40e9},
        {label = "50B", value = 50e9},
    }, function(value) autosellBalance:Fire(value) end)
    label(sellCard, {
        Text = "AND TOKEN EXCHANGE IS AT LEAST",
        TextSize = 8,
        Position = UDim2.fromOffset(12, 56),
        Size = UDim2.new(1, -24, 0, 12),
    })
    presetButtons(sellCard, 68, {
        {label = "OFF", value = nil},
        {label = "$5", value = 5},
        {label = "$10", value = 10},
        {label = "$13", value = 13},
        {label = "$15", value = 15},
        {label = "$20", value = 20},
        {label = "$25", value = 25},
    }, function(value) autosellPrice:Fire(value) end)
    sectionToggle(sellCard, function(enabled) autosellToggled:Fire(enabled) end)

    --========== AUTO COLLECT ==========
    local collectCard = card(pages.Autos, {
        Position = UDim2.fromOffset(0, 248),
        Size = UDim2.new(1, 0, 0, 64),
    })
    label(collectCard, {
        Text = "AUTO COLLECT",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(12, 5),
        Size = UDim2.fromOffset(120, 16),
    })
    label(collectCard, {
        Text = "DROP EVERY",
        TextSize = 8,
        Position = UDim2.fromOffset(12, 22),
        Size = UDim2.new(1, -24, 0, 12),
    })
    presetButtons(collectCard, 36, {
        {label = "1 min", value = 60},
        {label = "5 min", value = 300},
        {label = "10 min", value = 600},
        {label = "15 min", value = 900},
    }, function(value) autocollectInterval:Fire(value) end)
    sectionToggle(collectCard, function(enabled) autocollectToggled:Fire(enabled) end)

    function self:SetAutosellStatus(text)
        sellStatus.Text = tostring(text)
    end

    function self:AddItem(category, item)
        assert(lists[category], "Unknown UI category: " .. tostring(category))
        local row = card(lists[category], {
            Size = UDim2.new(1, -5, 0, 50),
            LayoutOrder = item.order,
        })
        label(row, {
            Text = item.name,
            TextColor3 = colors.white,
            TextSize = 11,
            Position = UDim2.fromOffset(12, 5),
            Size = UDim2.new(0.55, -20, 0, 18),
        })
        label(row, {
            Text = item.priceText,
            TextSize = 10,
            Position = UDim2.fromOffset(12, 27),
            Size = UDim2.new(0.55, -20, 0, 15),
        })
        local stock = label(row, {
            Text = "Stock: 0",
            TextSize = 10,
            Position = UDim2.new(0.55, 0, 0, 0),
            Size = UDim2.new(0.23, -8, 1, 0),
        })
        local button = make("TextButton", row, {
            Text = "ALERT OFF",
            TextSize = 9,
            Font = Enum.Font.GothamMedium,
            BackgroundColor3 = colors.panel,
            TextColor3 = colors.secondary,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -84, 0.5, -12),
            Size = UDim2.fromOffset(76, 25),
        })
        corner(button, 5)
        self.rows[item.id] = self.rows[item.id] or {}
        table.insert(self.rows[item.id], {stock = stock, button = button})
        connect(button.Activated, function() toggled:Fire(item.id) end)
    end

    function self:SetStock(id, text, available)
        for _, row in ipairs(self.rows[id] or {}) do
            row.stock.Text = text
            row.stock.TextColor3 = available and colors.white or colors.muted
        end
    end

    function self:SetAlertEnabled(id, enabled)
        for _, row in ipairs(self.rows[id] or {}) do
            row.button.Text = enabled and "ALERT ON" or "ALERT OFF"
            row.button.BackgroundColor3 = enabled and colors.white or colors.panel
            row.button.TextColor3 = enabled and colors.background or colors.secondary
        end
    end

    function self:SetTokenPrice(text) priceLabel.Text = text end
    function self:SetEpochTimer(text) epochLabel.Text = text end
    function self:SetRestockTimer(text) restockLabel.Text = text end

    -- Settings page
    label(pages.Settings, {
        Text = "SETTINGS",
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 24),
    })
    local soundCard = card(pages.Settings, {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 54),
    })
    label(soundCard, {
        Text = "Price-change sound",
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0.6, -12, 1, 0),
    })
    local soundButton = make("TextButton", soundCard, {
        Text = "SOUND ON",
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        BackgroundColor3 = colors.white,
        TextColor3 = colors.background,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -100, 0.5, -13),
        Size = UDim2.fromOffset(88, 26),
    })
    corner(soundButton, 5)
    connect(soundButton.Activated, function()
        local soundEnabled = soundButton.Text == "SOUND OFF"
        soundButton.Text = soundEnabled and "SOUND ON" or "SOUND OFF"
        soundButton.BackgroundColor3 = soundEnabled and colors.white or colors.panel
        soundButton.TextColor3 = soundEnabled and colors.background or colors.secondary
        soundToggled:Fire(soundEnabled)
    end)

    local unloadCard = card(pages.Settings, {
        Position = UDim2.fromOffset(0, 100),
        Size = UDim2.new(1, 0, 0, 72),
    })
    label(unloadCard, {
        Text = "Unload Token Market Hub",
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -24, 0, 22),
    })
    label(unloadCard, {
        Text = "Closes the UI and stops this hub's tracked tasks.",
        TextSize = 10,
        Position = UDim2.fromOffset(12, 26),
        Size = UDim2.new(1, -130, 0, 30),
        TextWrapped = true,
    })
    local unloadButton = make("TextButton", unloadCard, {
        Text = "UNLOAD",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        BackgroundColor3 = colors.panel,
        TextColor3 = colors.white,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -96, 0.5, -13),
        Size = UDim2.fromOffset(84, 26),
    })
    corner(unloadButton, 5)

    -- Bottom-right notification; queued so each stays visible for two seconds.
    local banner = card(gui, {
        AnchorPoint = Vector2.new(1, 1),
        Size = UDim2.fromOffset(400, 76),
        Position = UDim2.new(1, -18, 1, -18),
        Visible = false,
        BackgroundColor3 = colors.panel,
        ZIndex = 50,
    })
    local indicator = make("Frame", banner, {
        BackgroundColor3 = colors.white,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(0, 4, 1, -20),
        ZIndex = 51,
    })
    corner(indicator, 2)
    label(banner, {
        Text = "MARKET ALERT",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(24, 10),
        Size = UDim2.new(1, -44, 0, 20),
        ZIndex = 51,
    })
    local message = label(banner, {
        Text = "",
        TextSize = 13,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        Position = UDim2.fromOffset(24, 33),
        Size = UDim2.new(1, -44, 0, 34),
        ZIndex = 51,
    })

    local processing = false
    function self:Notify(text)
        if not self.alive then return end
        table.insert(self.queue, tostring(text))
        if processing then return end
        processing = true

        task.spawn(function()
            while self.alive and #self.queue > 0 do
                message.Text = table.remove(self.queue, 1)
                banner.Position = UDim2.new(1, 430, 1, -18)
                banner.Visible = true
                shown:Fire()

                local enter = tween(banner, 0.38, {
                    Position = UDim2.new(1, -18, 1, -18),
                })
                enter.Completed:Wait()
                if not self.alive then break end
                task.wait(2)
                if not self.alive then break end

                local exit = tween(banner, 0.32, {
                    Position = UDim2.new(1, 430, 1, -18),
                })
                exit.Completed:Wait()
                if not self.alive then break end
                banner.Visible = false
            end
            processing = false
        end)
    end

    connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.RightShift
            and not UserInputService:GetFocusedTextBox() then
            window.Visible = not window.Visible
        end
    end)

    -- Smooth drag: input updates a target position, RenderStepped eases the
    -- window toward it. This kills the jitter from event-driven repositioning.
    local dragging = false
    local dragStart = Vector2.zero
    local startPosition = UDim2.new()
    local targetPosition = UDim2.new()

    connect(window.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = window.Position
            targetPosition = window.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging
            and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            targetPosition = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    connect(RunService.RenderStepped, function(dt)
        if dragging then
            local alpha = math.clamp(dt * 24, 0, 1)
            window.Position = window.Position:Lerp(targetPosition, alpha)
        end
    end)

    function self:Destroy()
        if self.alive then gui:Destroy() end
    end
    connect(unloadButton.Activated, function() self:Destroy() end)

    gui.Destroying:Connect(function()
        if not self.alive then return end
        self.alive = false
        destroyed:Fire()
        for _, connection in ipairs(self.connections) do
            pcall(function() connection:Disconnect() end)
        end
        for animation in pairs(self.tweens) do
            pcall(function() animation:Cancel() end)
        end
        table.clear(self.queue)
        task.defer(function()
            destroyed:Destroy()
            toggled:Destroy()
            shown:Destroy()
            soundToggled:Destroy()
            crateBuy:Destroy()
            autobuyRowToggled:Destroy()
            autobuyCountChanged:Destroy()
            autobuyMasterToggled:Destroy()
            autosellToggled:Destroy()
            autosellBalance:Destroy()
            autosellPrice:Destroy()
            autocollectToggled:Destroy()
            autocollectInterval:Destroy()
        end)
    end)

    return self
end

return UI

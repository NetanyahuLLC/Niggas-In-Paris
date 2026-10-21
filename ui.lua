local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UI = {}

function UI.new(options)
    options = options or {}
    local self = {alive = true, connections = {}, rows = {}, queue = {}, tweens = {}}
    local colors = {
        background = Color3.fromRGB(10,10,10), panel = Color3.fromRGB(17,17,17),
        card = Color3.fromRGB(23,23,23), border = Color3.fromRGB(49,49,49),
        white = Color3.fromRGB(245,245,245), secondary = Color3.fromRGB(165,165,165),
        muted = Color3.fromRGB(115,115,115),
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
        make("UIStroke", obj, {Color = colors.border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
        return obj
    end
    local function label(parent, props)
        local defaults = {
            BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.Gotham,
            TextSize = 12, TextColor3 = colors.secondary,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
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
        local animation = TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quint), props)
        self.tweens[animation] = true
        animation.Completed:Once(function() self.tweens[animation] = nil end)
        animation:Play()
        return animation
    end
    local parent = options.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
    local guiName = options.Name or "TokenMarketHub"
    local old = parent:FindFirstChild(guiName)
    if old then old:Destroy() end
    local gui = make("ScreenGui", parent, {
        Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local destroyed = Instance.new("BindableEvent")
    local toggled = Instance.new("BindableEvent")
    local shown = Instance.new("BindableEvent")
    self.Destroyed = destroyed.Event
    self.AlertToggled = toggled.Event
    self.NotificationShown = shown.Event

    local window = card(gui, {
        Name = "MainWindow", Size = UDim2.fromOffset(540,390),
        AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
        BackgroundColor3 = colors.background, Active = true,
    })
    label(window, {Text = options.Title or "Token Market", Font = Enum.Font.GothamBold,
        TextSize = 14, TextColor3 = colors.white, Position = UDim2.fromOffset(16,8), Size = UDim2.fromOffset(290,22)})
    label(window, {Text = "TOKEN MARKET / LIVE MONITOR", TextSize = 9,
        Position = UDim2.fromOffset(16,30), Size = UDim2.fromOffset(280,15)})
    label(window, {Text = "RSHIFT / HIDE", TextSize = 9,
        Position = UDim2.new(1,-110,0,32), Size = UDim2.fromOffset(95,14)})

    local function tabs(parentObj, names, position, size)
        local bar = card(parentObj, {Position = position, Size = size, BackgroundColor3 = colors.panel})
        local buttons, pages, selected = {}, {}, nil
        local function select(name)
            selected = name
            for key, button in pairs(buttons) do
                button.BackgroundColor3 = key == name and colors.white or colors.panel
                button.TextColor3 = key == name and colors.background or colors.secondary
                pages[key].Visible = key == name
            end
        end
        for index, name in ipairs(names) do
            local button = make("TextButton", bar, {
                Text = name, Font = Enum.Font.GothamMedium, TextSize = 11,
                AutoButtonColor = false, BorderSizePixel = 0,
                Position = UDim2.new((index-1)/#names,3,0,3),
                Size = UDim2.new(1/#names,-6,1,-6),
            })
            corner(button,4)
            buttons[name] = button
            pages[name] = make("Frame", parentObj, {BackgroundTransparency = 1, Visible = false})
            connect(button.Activated, function() select(name) end)
        end
        select(names[1])
        return pages
    end
    local pages = tabs(window, {"Token Data","Shops"}, UDim2.new(1,-216,0,6), UDim2.fromOffset(200,26))
    for _, page in pairs(pages) do
        page.Position = UDim2.fromOffset(12,52)
        page.Size = UDim2.new(1,-24,1,-64)
    end
    local function info(parentObj, name, y)
        local box = card(parentObj, {Size = UDim2.new(1,0,0,48), Position = UDim2.fromOffset(0,y)})
        label(box, {Text = name, Position = UDim2.fromOffset(12,0), Size = UDim2.new(0.6,-12,1,0)})
        return label(box, {Text = "--", Font = Enum.Font.GothamBold, TextColor3 = colors.white,
            TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right,
            Position = UDim2.new(0.6,0,0,0), Size = UDim2.new(0.4,-12,1,0)})
    end
    local priceLabel = info(pages["Token Data"], "Current Token Price", 0)
    local epochLabel = info(pages["Token Data"], "Next Price Switch", 56)
    local restockLabel = info(pages.Shops, "Shop Restock", 0)
    local shops = tabs(pages.Shops, {"Hardware","Data Sources","Data Packs"}, UDim2.fromOffset(0,56), UDim2.new(1,0,0,30))
    local lists = {}
    for name, page in pairs(shops) do
        page.Position = UDim2.fromOffset(0,94)
        page.Size = UDim2.new(1,0,1,-94)
        local list = make("ScrollingFrame", page, {
            Size = UDim2.fromScale(1,1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        make("UIListLayout", list, {Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder})
        lists[name] = list
    end
    function self:AddItem(category, item)
        assert(lists[category], "Unknown UI category: " .. tostring(category))
        local row = card(lists[category], {Size = UDim2.new(1,-5,0,50), LayoutOrder = item.order})
        label(row, {Text = item.name, TextColor3 = colors.white, TextSize = 11,
            Position = UDim2.fromOffset(12,5), Size = UDim2.new(0.55,-20,0,18)})
        label(row, {Text = item.priceText, TextSize = 10,
            Position = UDim2.fromOffset(12,27), Size = UDim2.new(0.55,-20,0,15)})
        local stock = label(row, {Text = "Stock: 0", TextSize = 10,
            Position = UDim2.new(0.55,0,0,0), Size = UDim2.new(0.23,-8,1,0)})
        local button = make("TextButton", row, {
            Text = "ALERT OFF", TextSize = 9, Font = Enum.Font.GothamMedium,
            BackgroundColor3 = colors.panel, TextColor3 = colors.secondary, AutoButtonColor = false,
            BorderSizePixel = 0, Position = UDim2.new(1,-84,0.5,-12), Size = UDim2.fromOffset(76,25),
        })
        corner(button,5)
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

    local banner = card(gui, {
        AnchorPoint = Vector2.new(0,1), Size = UDim2.new(1,-36,0,76),
        Position = UDim2.new(0,-430,1,-18), Visible = false,
        BackgroundColor3 = colors.panel, ZIndex = 50,
    })
    make("UISizeConstraint", banner, {MaxSize = Vector2.new(400,76)})
    local indicator = make("Frame", banner, {BackgroundColor3 = colors.white,
        BorderSizePixel = 0, Position = UDim2.fromOffset(10,10), Size = UDim2.new(0,4,1,-20), ZIndex = 51})
    corner(indicator,2)
    label(banner, {Text = "STOCK ALERT", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = colors.white, Position = UDim2.fromOffset(24,10), Size = UDim2.new(1,-44,0,20), ZIndex = 51})
    local message = label(banner, {Text = "", TextSize = 13, TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None, Position = UDim2.fromOffset(24,33),
        Size = UDim2.new(1,-44,0,34), ZIndex = 51})
    local processing = false
    function self:Notify(text)
        if not self.alive then return end
        table.insert(self.queue, tostring(text))
        if processing then return end
        processing = true
        task.spawn(function()
            while self.alive and #self.queue > 0 do
                message.Text = table.remove(self.queue,1)
                banner.Position = UDim2.new(0,-430,1,-18)
                banner.Visible = true
                shown:Fire()
                tween(banner,0.38,{Position = UDim2.new(0,18,1,-18)}).Completed:Wait()
                if not self.alive then break end
                task.wait(3.5)
                if not self.alive then break end
                tween(banner,0.32,{Position = UDim2.new(0,-430,1,-18)}).Completed:Wait()
                if not self.alive then break end
                banner.Visible = false
            end
            processing = false
        end)
    end
    connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.RightShift and not UserInputService:GetFocusedTextBox() then
            window.Visible = not window.Visible
        end
    end)
    local dragging, dragStart, startPosition, dragInput
    connect(window.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPosition = true, input.Position, window.Position
        end
    end)
    connect(window.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            window.Position = UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    function self:Destroy() if self.alive then gui:Destroy() end end
    gui.Destroying:Connect(function()
        if not self.alive then return end
        self.alive = false
        destroyed:Fire()
        for _, connection in ipairs(self.connections) do connection:Disconnect() end
        for animation in pairs(self.tweens) do animation:Cancel() end
        table.clear(self.queue)
        task.defer(function()
            destroyed:Destroy()
            toggled:Destroy()
            shown:Destroy()
        end)
    end)
    return self
end

return UI

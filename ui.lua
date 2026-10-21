local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = {}

function UI.new(options)
    options = options or {}
    local self = {
        alive = true,
        connections = {},
        rows = {},
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
    local guiName = options.Name or "TokenMarketHub"
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
    self.Destroyed = destroyed.Event
    self.AlertToggled = toggled.Event
    self.NotificationShown = shown.Event
    self.SoundToggled = soundToggled.Event

    local window = card(gui, {
        Name = "MainWindow",
        Size = UDim2.fromOffset(540, 390),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = colors.background,
        Active = true,
    })

    label(window, {
        Text = options.Title or "Token Market",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = colors.white,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.fromOffset(290, 22),
    })
    label(window, {
        Text = "TOKEN MARKET / LIVE MONITOR",
        TextSize = 9,
        Position = UDim2.fromOffset(16, 30),
        Size = UDim2.fromOffset(280, 15),
    })
    label(window, {
        Text = "RSHIFT / HIDE",
        TextSize = 9,
        Position = UDim2.new(1, -110, 0, 32),
        Size = UDim2.fromOffset(95, 14),
    })

    local function tabs(parentObj, names, position, size)
        local bar = card(parentObj, {
            Position = position,
            Size = size,
            BackgroundColor3 = colors.panel,
        })
        local buttons, pages = {}, {}
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
                    page.Visible = true
                    page.Position = UDim2.fromOffset(0, 5)
                    page.BackgroundTransparency = 1
                    tween(page, 0.20, {
                        Position = UDim2.fromOffset(0, 0),
                        BackgroundTransparency = 1,
                    })
                else
                    page.Visible = false
                end
            end
        end

        for index, name in ipairs(names) do
            local button = make("TextButton", bar, {
                Text = name,
                Font = Enum.Font.GothamMedium,
                TextSize = 11,
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

        activeName = nil
        select(names[1])
        return pages
    end

    local pages = tabs(
        window,
        {"Token Data", "Shops", "Settings"},
        UDim2.new(1, -306, 0, 6),
        UDim2.fromOffset(290, 26)
    )
    for _, page in pairs(pages) do
        page.Position = UDim2.fromOffset(12, 52)
        page.Size = U

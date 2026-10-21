
    
  
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


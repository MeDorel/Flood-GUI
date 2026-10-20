local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local FloodUI = {}
FloodUI.__index = FloodUI

local THEME = {
	Backdrop = Color3.fromRGB(10, 13, 20),
	Sidebar = Color3.fromRGB(14, 18, 27),
	Card = Color3.fromRGB(21, 27, 39),
	CardHover = Color3.fromRGB(27, 34, 49),
	Stroke = Color3.fromRGB(38, 48, 68),
	Text = Color3.fromRGB(232, 238, 248),
	Muted = Color3.fromRGB(140, 152, 175),
	Accent = Color3.fromRGB(56, 160, 255),
	Good = Color3.fromRGB(70, 214, 140),
	Bad = Color3.fromRGB(255, 92, 100),
	Warn = Color3.fromRGB(255, 184, 77),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local function tween(obj, props, time, style)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function new(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then obj[k] = v end
	end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	if props and props.Parent then obj.Parent = props.Parent end
	return obj
end

local function corner(radius) return new("UICorner", { CornerRadius = UDim.new(0, radius) }) end
local function stroke(color, thickness, transparency)
	return new("UIStroke", { Color = color or THEME.Stroke, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function padding(l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t) })
end

local function label(props)
	local base = { BackgroundTransparency = 1, Font = FONT, TextSize = 14, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, RichText = true }
	for k, v in pairs(props) do base[k] = v end
	return new("TextLabel", base)
end

local function guiParent()
	local ok, hui = pcall(function() return gethui() end)
	if ok and hui then return hui end
	return game:GetService("CoreGui")
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local Section = {}
Section.__index = Section

local function rowBase(section, height)
	local row = new("Frame", {
		BackgroundColor3 = THEME.Card, Size = UDim2.new(1, 0, 0, height or 44), BorderSizePixel = 0,
		Parent = section.Body,
	}, { corner(8), stroke(THEME.Stroke, 1, 0.5) })
	return row
end

function Section:Label(text, color)
	local lbl = label({
		Text = text, TextWrapped = true, TextColor3 = color or THEME.Muted, TextSize = 13,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Body,
	})
	local api = {}
	function api:Set(newText, newColor)
		lbl.Text = newText
		if newColor then lbl.TextColor3 = newColor end
	end
	return api
end

function Section:Toggle(opts)
	local hasDesc = opts.Description ~= nil
	local row = rowBase(self, hasDesc and 54 or 44)
	label({ Text = opts.Name, Font = FONT_BOLD, Position = UDim2.new(0, 14, 0, hasDesc and 8 or 0), Size = UDim2.new(1, -84, 0, hasDesc and 18 or 44), Parent = row })
	if hasDesc then
		label({ Text = opts.Description, TextSize = 12, TextColor3 = THEME.Muted, Position = UDim2.new(0, 14, 0, 27), Size = UDim2.new(1, -84, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	end
	local track = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(42, 22), BackgroundColor3 = THEME.Stroke, BorderSizePixel = 0, Parent = row }, { corner(11) })
	local knob = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track }, { corner(8) })
	local button = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row })

	local api = { Value = opts.Default == true }
	local function render(animate)
		local goalPos = api.Value and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
		local goalColor = api.Value and (opts.Color or THEME.Accent) or THEME.Stroke
		if animate then
			tween(knob, { Position = goalPos }, 0.15)
			tween(track, { BackgroundColor3 = goalColor }, 0.15)
		else
			knob.Position, track.BackgroundColor3 = goalPos, goalColor
		end
	end
	render(false)
	function api:Set(value, silent)
		api.Value = value == true
		render(true)
		if not silent and opts.Callback then task.spawn(opts.Callback, api.Value) end
	end
	button.Activated:Connect(function() api:Set(not api.Value) end)
	button.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = THEME.CardHover }, 0.1) end)
	button.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = THEME.Card }, 0.1) end)
	return api
end

function Section:Slider(opts)
	local row = rowBase(self, 58)
	label({ Text = opts.Name, Font = FONT_BOLD, Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -100, 0, 18), Parent = row })
	local valueLabel = label({ Text = "", Font = FONT_BOLD, TextColor3 = THEME.Accent, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -94, 0, 8), Size = UDim2.new(0, 80, 0, 18), Parent = row })
	local track = new("Frame", { Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = THEME.Stroke, BorderSizePixel = 0, Parent = row }, { corner(3) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Parent = track }, { corner(3) })
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track }, { corner(7) })
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 26), Parent = row })

	local min, max, step = opts.Min or 0, opts.Max or 100, opts.Step or 1
	local api = { Value = math.clamp(opts.Default or min, min, max) }
	local function render()
		local frac = (api.Value - min) / math.max(max - min, 1e-9)
		fill.Size = UDim2.fromScale(frac, 1)
		knob.Position = UDim2.fromScale(frac, 0.5)
		valueLabel.Text = tostring(api.Value) .. (opts.Suffix or "")
	end
	render()
	function api:Set(value, silent)
		value = math.clamp(math.round(value / step) * step, min, max)
		if value == api.Value and not silent then return end
		api.Value = value
		render()
		if not silent and opts.Callback then task.spawn(opts.Callback, value) end
	end
	local dragging = false
	local function fromInput(input)
		local frac = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		api:Set(min + (max - min) * frac)
	end
	hit.InputBegan:Connect(function(input)
		if isPress(input) then dragging = true fromInput(input) end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end)
	return api
end

function Section:Button(opts)
	local button = new("TextButton", {
		Text = opts.Name, Font = FONT_BOLD, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = opts.Color or THEME.Accent, Size = UDim2.new(1, 0, 0, 36), BorderSizePixel = 0, AutoButtonColor = false,
		Parent = self.Body,
	}, { corner(8) })
	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function() tween(button, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) }, 0.1) end)
	button.MouseLeave:Connect(function() tween(button, { BackgroundColor3 = base }, 0.1) end)
	button.Activated:Connect(function() if opts.Callback then task.spawn(opts.Callback) end end)
	return button
end

function Section:Input(opts)
	local row = rowBase(self, 44)
	label({ Text = opts.Name, Font = FONT_BOLD, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), Parent = row })
	local box = new("TextBox", {
		Text = "", PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = THEME.Muted, ClearTextOnFocus = false,
		Font = FONT, TextSize = 13, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundColor3 = THEME.Backdrop, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.58, 0, 0, 28), BorderSizePixel = 0, Parent = row,
	}, { corner(6), stroke(THEME.Stroke, 1, 0.3), padding(8, 0) })
	local api = { Value = opts.Default or "" }
	local function mask()
		if opts.Password and api.Value ~= "" then box.Text = string.rep("•", math.min(#api.Value, 28)) else box.Text = api.Value end
	end
	mask()
	function api:Set(value, silent)
		api.Value = tostring(value or "")
		mask()
		if not silent and opts.Callback then task.spawn(opts.Callback, api.Value) end
	end
	box.Focused:Connect(function() box.Text = api.Value end)
	box.FocusLost:Connect(function()
		api.Value = box.Text
		mask()
		if opts.Callback then task.spawn(opts.Callback, api.Value) end
	end)
	return api
end

function Section:Chips(opts)
	local row = new("Frame", { BackgroundColor3 = THEME.Card, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = self.Body }, {
		corner(8), stroke(THEME.Stroke, 1, 0.5), padding(12, 10),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if opts.Name then label({ Text = opts.Name, Font = FONT_BOLD, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = row }) end
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = row }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local api = { Values = {} }
	local chips = {}
	for i, item in ipairs(opts.Items) do
		local color = item.Color or THEME.Accent
		local chip = new("TextButton", {
			Text = item.Label, Font = FONT_BOLD, TextSize = 13, TextColor3 = color, AutoButtonColor = false,
			BackgroundColor3 = color, BackgroundTransparency = 0.88, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, BorderSizePixel = 0, Parent = holder,
		}, { corner(15), stroke(color, 1.5, 0.35), padding(14, 0) })
		chips[item.Value] = { button = chip, color = color }
		api.Values[item.Value] = false
	end
	local function render(value)
		local chip = chips[value]
		if not chip then return end
		local on = api.Values[value]
		tween(chip.button, { BackgroundTransparency = on and 0.1 or 0.88 }, 0.12)
		chip.button.TextColor3 = on and Color3.new(1, 1, 1) or chip.color
	end
	function api:Set(value, state, silent)
		api.Values[value] = state == true
		render(value)
		if not silent and opts.Callback then task.spawn(opts.Callback, api.Values, value) end
	end
	for value, chip in pairs(chips) do
		chip.button.Activated:Connect(function() api:Set(value, not api.Values[value]) end)
	end
	for _, value in ipairs(opts.Default or {}) do api:Set(value, true, true) end
	return api
end

function Section:Keybind(opts)
	local row = rowBase(self, 44)
	label({ Text = opts.Name, Font = FONT_BOLD, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -120, 1, 0), Parent = row })
	local button = new("TextButton", {
		Text = opts.Default and opts.Default.Name or "None", Font = FONT_BOLD, TextSize = 13, TextColor3 = THEME.Text, AutoButtonColor = false,
		BackgroundColor3 = THEME.Backdrop, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(86, 28), BorderSizePixel = 0, Parent = row,
	}, { corner(6), stroke(THEME.Stroke, 1, 0.3) })
	local api = { Value = opts.Default, Listening = false }
	function api:Set(key)
		api.Value = key
		button.Text = key and key.Name or "None"
	end
	button.Activated:Connect(function()
		api.Listening = true
		button.Text = "..."
		button.TextColor3 = THEME.Accent
	end)
	table.insert(self.Window.Keybinds, api)
	api.Callback = opts.Callback
	api.Button = button
	return api
end

local Tab = {}
Tab.__index = Tab

function Tab:Section(title)
	local card = new("Frame", { BackgroundColor3 = THEME.Sidebar, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = self.Page }, {
		corner(12), stroke(THEME.Stroke, 1, 0.4), padding(14, 12),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Text = string.upper(title), Font = FONT_BOLD, TextSize = 12, TextColor3 = THEME.Accent, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 0, Parent = card })
	local body = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card }, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return setmetatable({ Body = body, Window = self.Window }, Section)
end

function FloodUI.new(opts)
	opts = opts or {}
	if opts.Accent then THEME.Accent = opts.Accent end
	local self = setmetatable({ Tabs = {}, Keybinds = {}, Connections = {}, ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift }, FloodUI)

	local gui = new("ScreenGui", { Name = "FloodUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	gui.Parent = guiParent()
	self.Gui = gui

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(math.min(viewport.X / 760, viewport.Y / 520), 0.6, 1.1)
	new("UIScale", { Scale = scale, Parent = gui })

	local main = new("Frame", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(660, 440),
		BackgroundColor3 = THEME.Backdrop, BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
	}, { corner(14), stroke(THEME.Stroke, 1.5, 0.15) })
	self.Main = main

	new("UIGradient", {
		Color = ColorSequence.new(THEME.Backdrop, Color3.fromRGB(13, 19, 33)), Rotation = 90, Parent = main,
	})

	local sidebar = new("Frame", { Size = UDim2.new(0, 168, 1, 0), BackgroundColor3 = THEME.Sidebar, BorderSizePixel = 0, Parent = main })
	local brand = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74), Parent = sidebar })
	local logo = new("Frame", { Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Parent = brand }, {
		corner(10),
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(86, 204, 255), Color3.fromRGB(46, 108, 255)), Rotation = 45 }),
	})
	label({ Text = "≋", Font = FONT_BOLD, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = logo })
	label({ Text = opts.Title or "Flood GUI", Font = FONT_BOLD, TextSize = 16, Position = UDim2.fromOffset(64, 18), Size = UDim2.new(1, -70, 0, 20), Parent = brand })
	label({ Text = opts.Subtitle or "", TextSize = 12, TextColor3 = THEME.Muted, Position = UDim2.fromOffset(64, 38), Size = UDim2.new(1, -70, 0, 16), Parent = brand })

	local tabList = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -150), BorderSizePixel = 0,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), padding(10, 0) })
	self.TabList = tabList

	local status = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 56), BackgroundColor3 = THEME.Card, BorderSizePixel = 0, Parent = sidebar }, { corner(10), stroke(THEME.Stroke, 1, 0.5), padding(10, 6) })
	self.StatusLabel = label({ Text = "Ready", TextSize = 12, TextColor3 = THEME.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = status })

	local titleBar = new("Frame", { Position = UDim2.fromOffset(168, 0), Size = UDim2.new(1, -168, 0, 52), BackgroundTransparency = 1, Parent = main })
	self.PageTitle = label({ Text = "", Font = FONT_BOLD, TextSize = 20, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -120, 1, 0), Parent = titleBar })
	local function windowButton(text, offset, color)
		local b = new("TextButton", { Text = text, Font = FONT_BOLD, TextSize = 16, TextColor3 = THEME.Muted, AutoButtonColor = false, BackgroundColor3 = THEME.Card, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, offset, 0.5, 0), Size = UDim2.fromOffset(30, 30), BorderSizePixel = 0, Parent = titleBar }, { corner(8) })
		b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = color }, 0.1) b.TextColor3 = Color3.new(1, 1, 1) end)
		b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = THEME.Card }, 0.1) b.TextColor3 = THEME.Muted end)
		return b
	end
	local closeBtn = windowButton("✕", -14, THEME.Bad)
	local hideBtn = windowButton("–", -50, THEME.CardHover)
	hideBtn.Activated:Connect(function() self:SetVisible(false) end)
	closeBtn.Activated:Connect(function() self:Destroy() end)

	local dragging, dragStart, startPos
	local function beginDrag(input)
		if isPress(input) then
			dragging, dragStart, startPos = true, input.Position, main.Position
		end
	end
	titleBar.InputBegan:Connect(beginDrag)
	brand.InputBegan:Connect(beginDrag)
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local ui = gui:FindFirstChildOfClass("UIScale")
			local s = ui and ui.Scale or 1
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X / s, startPos.Y.Scale, startPos.Y.Offset + delta.Y / s)
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end))

	local pages = new("Frame", { Position = UDim2.fromOffset(168, 52), Size = UDim2.new(1, -168, 1, -52), BackgroundTransparency = 1, Parent = main })
	self.Pages = pages

	self.ToastHolder = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(300, 400), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		for _, kb in ipairs(self.Keybinds) do
			if kb.Listening then
				kb.Listening = false
				kb.Button.TextColor3 = THEME.Text
				kb:Set(input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil)
				if kb.OnChanged then task.spawn(kb.OnChanged, kb.Value) end
				return
			end
		end
		if processed then return end
		if input.KeyCode == self.ToggleKey then self:SetVisible(not main.Visible) return end
		for _, kb in ipairs(self.Keybinds) do
			if kb.Value and input.KeyCode == kb.Value and kb.Callback then task.spawn(kb.Callback) end
		end
	end))

	main.Size = UDim2.fromOffset(640, 420)
	main.BackgroundTransparency = 1
	tween(main, { Size = UDim2.fromOffset(660, 440), BackgroundTransparency = 0 }, 0.25, Enum.EasingStyle.Back)
	return self
end

function FloodUI:Tab(name, icon)
	local button = new("TextButton", {
		Text = "", AutoButtonColor = false, BackgroundColor3 = THEME.Card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), BorderSizePixel = 0,
		LayoutOrder = #self.Tabs + 1, Parent = self.TabList,
	}, { corner(9) })
	local bar = new("Frame", { Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(3, 20), BackgroundColor3 = THEME.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = button }, { corner(2) })
	local iconLabel = label({ Text = icon or "•", Font = FONT_BOLD, TextSize = 16, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(26, 38), Parent = button })
	local nameLabel = label({ Text = name, Font = FONT_BOLD, TextSize = 14, TextColor3 = THEME.Muted, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -44, 1, 0), Parent = button })

	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.Stroke,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = self.Pages,
	}, { new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }), padding(18, 4, 18, 18) })

	local tab = setmetatable({ Name = name, Page = page, Window = self, Button = button }, Tab)
	local function setActive(active)
		tween(button, { BackgroundTransparency = active and 0.35 or 1 }, 0.12)
		tween(bar, { BackgroundTransparency = active and 0 or 1 }, 0.12)
		nameLabel.TextColor3 = active and THEME.Text or THEME.Muted
		iconLabel.TextColor3 = active and THEME.Accent or THEME.Muted
	end
	tab.SetActive = setActive
	button.Activated:Connect(function() self:Select(tab) end)
	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:Select(tab) end
	return tab
end

function FloodUI:Select(tab)
	for _, t in ipairs(self.Tabs) do
		t.Page.Visible = t == tab
		t.SetActive(t == tab)
	end
	self.PageTitle.Text = tab.Name
end

function FloodUI:SetStatus(text, color)
	if self.StatusLabel then
		self.StatusLabel.Text = text
		self.StatusLabel.TextColor3 = color or THEME.Muted
	end
end

function FloodUI:SetVisible(visible)
	self.Main.Visible = visible
end

function FloodUI:Notify(title, text, color, duration)
	local toast = new("Frame", { BackgroundColor3 = THEME.Card, Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = self.ToastHolder }, {
		corner(10), stroke(color or THEME.Accent, 1.5, 0.2), padding(14, 10),
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Text = title, Font = FONT_BOLD, TextSize = 14, TextColor3 = color or THEME.Accent, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = toast })
	label({ Text = text or "", TextSize = 13, TextColor3 = THEME.Text, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = toast })
	toast.BackgroundTransparency = 1
	tween(toast, { BackgroundTransparency = 0 }, 0.2)
	task.delay(duration or 4, function()
		if toast.Parent then
			tween(toast, { BackgroundTransparency = 1 }, 0.25)
			task.wait(0.25)
			toast:Destroy()
		end
	end)
end

function FloodUI:Destroy()
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	if self.Gui then self.Gui:Destroy() end
	if self.OnDestroy then pcall(self.OnDestroy) end
end

FloodUI.Theme = THEME
return FloodUI

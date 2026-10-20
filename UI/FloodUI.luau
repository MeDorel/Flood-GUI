local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FloodUI = {}
FloodUI.__index = FloodUI

local THEME = {
	Backdrop = Color3.fromRGB(12, 12, 12),
	Panel = Color3.fromRGB(18, 18, 18),
	Card = Color3.fromRGB(26, 26, 26),
	CardHover = Color3.fromRGB(36, 36, 36),
	Stroke = Color3.fromRGB(66, 66, 66),
	Text = Color3.fromRGB(235, 235, 235),
	Muted = Color3.fromRGB(150, 150, 150),
	Accent = Color3.fromRGB(235, 235, 235),
	Good = Color3.fromRGB(110, 220, 130),
	Bad = Color3.fromRGB(235, 90, 90),
	Warn = Color3.fromRGB(240, 190, 90),
}

local FONT = Enum.Font.Code
local TEXT_SIZE = 13

local function tween(obj, props, time)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
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

local function stroke(color, thickness)
	return new("UIStroke", { Color = color or THEME.Stroke, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t) })
end

local function label(props)
	local base = { BackgroundTransparency = 1, Font = FONT, TextSize = TEXT_SIZE, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, RichText = true }
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

local function row(section, height)
	return new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, Parent = section.Body })
end

function Section:Label(text, color)
	local lbl = label({
		Text = text, TextWrapped = true, TextColor3 = color or THEME.Muted, TextSize = 12,
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
	local r = row(self, hasDesc and 32 or 20)
	local box = new("Frame", { Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = THEME.Backdrop, BorderSizePixel = 0, Parent = r }, { stroke(THEME.Stroke, 1) })
	local fill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = opts.Color or THEME.Accent, BorderSizePixel = 0, Visible = false, Parent = box })
	label({ Text = opts.Name, Position = UDim2.fromOffset(21, 0), Size = UDim2.new(1, -21, 0, 19), Parent = r })
	if hasDesc then
		label({ Text = opts.Description, TextSize = 11, TextColor3 = THEME.Muted, Position = UDim2.fromOffset(21, 17), Size = UDim2.new(1, -21, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, Parent = r })
	end
	local button = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = r })

	local api = { Value = opts.Default == true }
	local function render()
		fill.Visible = api.Value
		box.UIStroke.Color = api.Value and (opts.Color or THEME.Accent) or THEME.Stroke
	end
	render()
	function api:Set(value, silent)
		api.Value = value == true
		render()
		if not silent and opts.Callback then task.spawn(opts.Callback, api.Value) end
	end
	button.Activated:Connect(function() api:Set(not api.Value) end)
	return api
end

function Section:Slider(opts)
	local r = row(self, 36)
	label({ Text = opts.Name, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 16), Parent = r })
	local track = new("Frame", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 15), BackgroundColor3 = THEME.Backdrop, BorderSizePixel = 0, Parent = r }, { stroke(THEME.Stroke, 1) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Parent = track })
	local valueLabel = label({ Text = "", TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = track })
	valueLabel.TextStrokeTransparency = 0.3
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = track })

	local min, max, step = opts.Min or 0, opts.Max or 100, opts.Step or 1
	local api = { Value = math.clamp(opts.Default or min, min, max) }
	local function render()
		fill.Size = UDim2.fromScale((api.Value - min) / math.max(max - min, 1e-9), 1)
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
	table.insert(self.Window.Connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end
	end))
	table.insert(self.Window.Connections, UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then dragging = false end
	end))
	return api
end

function Section:Button(opts)
	local button = new("TextButton", {
		Text = opts.Name, Font = FONT, TextSize = TEXT_SIZE, TextColor3 = THEME.Text, AutoButtonColor = false,
		BackgroundColor3 = opts.Color or THEME.Card, Size = UDim2.new(1, 0, 0, 22), BorderSizePixel = 0, Parent = self.Body,
	}, { stroke(THEME.Stroke, 1) })
	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function() tween(button, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.1) }) end)
	button.MouseLeave:Connect(function() tween(button, { BackgroundColor3 = base }) end)
	button.Activated:Connect(function() if opts.Callback then task.spawn(opts.Callback) end end)
	return button
end

function Section:Input(opts)
	local r = row(self, 38)
	label({ Text = opts.Name, Size = UDim2.new(1, 0, 0, 16), Parent = r })
	local box = new("TextBox", {
		Text = "", PlaceholderText = opts.Placeholder or "", PlaceholderColor3 = THEME.Muted, ClearTextOnFocus = false,
		Font = FONT, TextSize = 12, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundColor3 = THEME.Backdrop, Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 20), BorderSizePixel = 0, Parent = r,
	}, { stroke(THEME.Stroke, 1), padding(6, 0) })
	local api = { Value = opts.Default or "" }
	local function mask()
		if opts.Password and api.Value ~= "" then box.Text = string.rep("*", math.min(#api.Value, 40)) else box.Text = api.Value end
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
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Body }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local api = { Values = {} }
	local chips = {}
	for i, item in ipairs(opts.Items) do
		local color = item.Color or THEME.Accent
		local chip = new("TextButton", {
			Text = item.Label, Font = FONT, TextSize = 12, TextColor3 = color, AutoButtonColor = false,
			BackgroundColor3 = color, BackgroundTransparency = 0.9, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, BorderSizePixel = 0, Parent = holder,
		}, { stroke(color, 1), padding(9, 0) })
		chips[item.Value] = { button = chip, color = color }
		api.Values[item.Value] = false
	end
	local function render(value)
		local chip = chips[value]
		if not chip then return end
		local on = api.Values[value]
		chip.button.BackgroundTransparency = on and 0.15 or 0.9
		chip.button.TextColor3 = on and Color3.new(0, 0, 0) or chip.color
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
	local r = row(self, 20)
	label({ Text = opts.Name, Size = UDim2.new(1, -70, 1, 0), Parent = r })
	local button = new("TextButton", {
		Text = "[" .. (opts.Default and opts.Default.Name or "None") .. "]", Font = FONT, TextSize = 12, TextColor3 = THEME.Muted, AutoButtonColor = false,
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 70, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
	})
	local api = { Value = opts.Default, Listening = false }
	function api:Set(key)
		api.Value = key
		button.Text = "[" .. (key and key.Name or "None") .. "]"
	end
	button.Activated:Connect(function()
		api.Listening = true
		button.Text = "[...]"
		button.TextColor3 = THEME.Text
	end)
	table.insert(self.Window.Keybinds, api)
	api.Callback = opts.Callback
	api.OnChanged = opts.OnChanged
	api.Button = button
	return api
end

local Tab = {}
Tab.__index = Tab

function Tab:Section(title)
	self.SectionCount += 1
	local column = self.Columns[(self.SectionCount - 1) % 2 + 1]
	local group = new("Frame", { BackgroundColor3 = THEME.Panel, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = column }, {
		stroke(THEME.Stroke, 1), padding(8, 18, 8, 8),
	})
	label({ Text = title, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = THEME.Text, Position = UDim2.fromOffset(0, -15), Size = UDim2.new(1, 0, 0, 14), Parent = group })
	local body = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = group }, {
		new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
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
	new("UIScale", { Scale = math.clamp(math.min(viewport.X / 760, viewport.Y / 500), 0.6, 1.1), Parent = gui })

	local DEFAULT_SIZE = Vector2.new(700, 440)
	local main = new("Frame", {
		Name = "Main", Position = UDim2.new(0.5, -DEFAULT_SIZE.X / 2, 0.5, -DEFAULT_SIZE.Y / 2), Size = UDim2.fromOffset(DEFAULT_SIZE.X, DEFAULT_SIZE.Y),
		BackgroundColor3 = THEME.Backdrop, BorderSizePixel = 0, Parent = gui,
	}, { stroke(Color3.fromRGB(95, 95, 95), 1) })
	self.Main = main
	self.DefaultSize = DEFAULT_SIZE

	function self:SetSize(width, height)
		local ui = gui:FindFirstChildOfClass("UIScale")
		local s = ui and ui.Scale or 1
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		width = math.clamp(width, 480, math.max(vp.X / s - 20, 480))
		height = math.clamp(height, 320, math.max(vp.Y / s - 20, 320))
		main.Size = UDim2.fromOffset(width, height)
	end

	local titleBar = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Parent = main }, {
		new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Stroke, BorderSizePixel = 0 }),
	})
	label({
		Text = (opts.Title or "Flood GUI") .. (opts.Subtitle and ("  " .. opts.Subtitle) or ""),
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(30, 0), Parent = titleBar,
	})
	local closeBtn = new("TextButton", { Text = "x", Font = FONT, TextSize = 14, TextColor3 = THEME.Muted, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(26, 24), Parent = titleBar })
	closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = THEME.Bad end)
	closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = THEME.Muted end)
	closeBtn.Activated:Connect(function() self:Destroy() end)

	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if isPress(input) then dragging, dragStart, startPos = true, input.Position, main.Position end
	end)
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

	self.TabBar = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = THEME.Backdrop, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, Parent = main,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		padding(6, 0),
	})

	self.Pages = new("Frame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, ClipsDescendants = true, Parent = main })

	local statusBar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Parent = main }, {
		new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = THEME.Stroke, BorderSizePixel = 0 }),
	})
	self.StatusLabel = label({ Text = "Ready", TextSize = 12, TextColor3 = THEME.Muted, Position = UDim2.fromOffset(8, 1), Size = UDim2.new(1, -34, 1, -1), TextTruncate = Enum.TextTruncate.AtEnd, Parent = statusBar })

	local grip = new("TextButton", {
		Text = "=", Rotation = -45, Font = FONT, TextSize = 16, TextColor3 = THEME.Muted, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(20, 20), ZIndex = 5, Parent = main,
	})
	local resizing, resizeStart, startSize
	grip.InputBegan:Connect(function(input)
		if isPress(input) then
			resizing, resizeStart, startSize = true, input.Position, main.AbsoluteSize
		end
	end)
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local ui = gui:FindFirstChildOfClass("UIScale")
			local s = ui and ui.Scale or 1
			local delta = input.Position - resizeStart
			self:SetSize(startSize.X / s + delta.X / s, startSize.Y / s + delta.Y / s)
		end
	end))
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then resizing = false end
	end))

	self.ToastHolder = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(280, 400), BackgroundTransparency = 1, Parent = gui }, {
		new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		for _, kb in ipairs(self.Keybinds) do
			if kb.Listening then
				kb.Listening = false
				kb.Button.TextColor3 = THEME.Muted
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

	return self
end

function FloodUI:Tab(name)
	local button = new("TextButton", {
		Text = name, Font = FONT, TextSize = TEXT_SIZE, TextColor3 = THEME.Muted, AutoButtonColor = false,
		BackgroundColor3 = THEME.Panel, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0, LayoutOrder = #self.Tabs + 1, Parent = self.TabBar,
	}, { padding(9, 0) })

	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.Stroke,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = self.Pages,
	}, { padding(10, 14, 10, 10) })
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function column(order)
		return new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = holder }, {
			new("UIListLayout", { Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end

	local tab = setmetatable({ Name = name, Page = page, Window = self, Button = button, Columns = { column(1), column(2) }, SectionCount = 0 }, Tab)
	local stroke = new("UIStroke", { Color = THEME.Stroke, Thickness = 1, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	tab.SetActive = function(active)
		button.BackgroundTransparency = active and 0 or 1
		button.TextColor3 = active and THEME.Text or THEME.Muted
		stroke.Enabled = active
	end
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
end

function FloodUI:SetStatus(text, color)
	if self.StatusLabel then
		self.StatusLabel.Text = (text:gsub("\n", "  |  "))
		self.StatusLabel.TextColor3 = color or THEME.Muted
	end
end

function FloodUI:SetVisible(visible)
	self.Main.Visible = visible
end

function FloodUI:Notify(title, text, color, duration)
	local toast = new("Frame", { BackgroundColor3 = THEME.Panel, Size = UDim2.fromOffset(260, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = self.ToastHolder }, {
		stroke(color or THEME.Accent, 1), padding(10, 7),
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Text = title, TextColor3 = color or THEME.Accent, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = toast })
	label({ Text = text or "", TextSize = 12, TextColor3 = THEME.Text, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = toast })
	task.delay(duration or 4, function()
		if toast.Parent then toast:Destroy() end
	end)
end

function FloodUI:Destroy()
	for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
	if self.Gui then self.Gui:Destroy() end
	if self.OnDestroy then pcall(self.OnDestroy) end
end

FloodUI.Theme = THEME
return FloodUI

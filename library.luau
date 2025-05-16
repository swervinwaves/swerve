local Library = {
	Tabs = {},

	GUIPallete = {
		Font = Font.new("rbxasset://fonts/families/Inconsolata.json"),
		MainBG =     Color3.fromRGB(17, 17, 17),
		Outline =    Color3.fromRGB(48, 48, 48),
		Border =     Color3.fromRGB(0, 0, 0),
		SelectedBG = Color3.fromRGB(26, 26, 26), -- also used for button background
		Text =       Color3.fromRGB(175, 175, 175),
		Image =      Color3.fromRGB(150, 150, 150),
		Selected =   Color3.fromRGB(255, 255, 255),
		Theme =      Color3.fromRGB(150, 0, 255) -- primarily used for the sliders to stand out from the text
	},

	Keybind =      Enum.KeyCode.RightShift,

	Loaded =       false,

	Instances = {},
	Connections = {},

	Utils = {}
}

local windowFrame

-- helper funcs
function Library:IsLoaded(): boolean
	return Library.Loaded
end

-- clone
function Library.Utils.Clone<orig>(obj: any & orig): orig
	local Type = typeof(obj)

	if Type == "Instance" then
		local clone = cloneref or clonereference
		if clone then
			return clone(obj)
		end
	elseif Type == "function" then
		local clone = clonefunc or clonefunction
		if clone then
			return clone(obj)
		end
	elseif Type == "table" then
		return table.clone(obj)
	end

	return obj
end

-- new instance
function Library.Utils.New(class: string, props: {[any]: any}?): Instance
	local instance = Instance.new(class)

	if props then
		for key, value in pairs(props) do
			pcall(function()
				instance[key] = value
			end)
		end
	end

	table.insert(Library.Instances, instance)

	return instance
end

-- new connection
function Library.Utils.Connect(event: RBXScriptSignal, func: (...any) -> ...any): RBXScriptConnection
	local connection = event:Connect(func)

	table.insert(Library.Connections, connection)

	return connection
end

-- uninject
function Library:Uninject()
	for _, instance in pairs(self.Instances) do
		instance:Destroy()
	end; table.clear(self.Instances)

	for _, connection in pairs(self.Connections) do
		connection:Disconnect()
	end; table.clear(self.Connections)

	table.clear(self); self = nil
end

local New = Library.Utils.New
local Connect = Library.Utils.Connect

local fontSize = New("GetTextBoundsParams")
local textService = game:GetService("TextService")

local getTextSize = function(text)
	fontSize.Text = text
	fontSize.Size = 14
	fontSize.Font = Library.GUIPallete.Font
	return textService:GetTextBoundsAsync(fontSize)
end

local tweenService = game:GetService("TweenService")

local tween = function(object, info, properties)
	local tween = tweenService:Create(object, info, properties)
	tween:Play()
	return tween
end

-- main container
local Container = New("ScreenGui", {
	Name = "Athos",
	IgnoreGuiInset = true,
	Parent = (gethui or get_hidden_gui) and (gethui or get_hidden_gui)() or Library.Utils.Clone(game:GetService("CoreGui"))
})

local notificationsFolder = New("Folder", {Parent = Container})

local function addCorner(parent: Instance, guiElement: boolean?): UICorner
	local corner = New("UICorner", {
		CornerRadius = guiElement and UDim.new(0, 3) or UDim.new(0, 5),
		Parent = parent
	})

	return corner
end

local function addStroke(parent: Instance, blackOutline: boolean?): (UIStroke, UIStroke?)
	local stroke = New("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = blackOutline and 2 or 1,
		Color = blackOutline and Library.GUIPallete.Border or Library.GUIPallete.Outline,
		Parent = parent
	})

	local outline; if blackOutline then
		local strokeContainer = New("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = parent
		}) addCorner(strokeContainer)

		outline = New("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
			Color = Library.GUIPallete.Outline,
			Parent = strokeContainer
		})
	end

	if outline then return stroke, outline else return stroke end
end

local inputService = game:GetService("UserInputService")

local function makeDraggable(object: Instance, isIndicator: boolean?)
	Connect(object.InputBegan, function(inputObj)
		if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch) and (inputObj.Position.Y - object.AbsolutePosition.Y < 40) then
			if isIndicator and not windowFrame.Visible then return end

			local dragPosition = Vector2.new(object.AbsolutePosition.X - inputObj.Position.X, object.AbsolutePosition.Y - inputObj.Position.Y + game:GetService("GuiService"):GetGuiInset().Y)

			local changed = Connect(inputService.InputChanged, function(input)
				if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
					object.Position = UDim2.fromOffset(input.Position.X + dragPosition.X, input.Position.Y + dragPosition.Y)
				end
			end)

			local ended; ended = Connect(inputObj.Changed, function()
				if inputObj.UserInputState == Enum.UserInputState.End then
					if changed then changed:Disconnect() end; if ended then ended:Disconnect() end
				end
			end)
		end
	end)
end

local tooltip = New("TextLabel", {
	Visible = false,
	BackgroundColor3 = Library.GUIPallete.MainBG,
	TextColor3 = Library.GUIPallete.Selected, -- gotta use the selected text for it to stand out more
	TextSize = 14,
	FontFace = Library.GUIPallete.Font,
	Parent = Container
}) addCorner(tooltip); addStroke(tooltip)

local function addToolTip(object: Instance, text: string)
	local function tooltipMoved(x, y)
		local right = x + 16 + tooltip.Size.X.Offset
		tooltip.Position = UDim2.fromOffset(
			(right and x - tooltip.Size.X.Offset - 16 or x + 16),
			((y + 11) - (tooltip.Size.Y.Offset / 2))
		)
		tooltip.Visible = true
	end
	Connect(object.MouseEnter, function(x, y)
		local tooltipSize = getTextSize(text)
		tooltip.Size = UDim2.fromOffset(tooltipSize.X + 10, tooltipSize.Y + 10)
		tooltip.Text = text
		tooltipMoved(x, y)
	end)
	Connect(object.MouseMoved, tooltipMoved)
	Connect(object.MouseLeave, function() tooltip.Visible = false end)
end

-- window
function Library:Window()
	-- the main window frame
	windowFrame = New("Frame", {
		Position = UDim2.fromOffset(Container.AbsoluteSize.X / 2, Container.AbsoluteSize.Y / 2),
		Size = UDim2.fromOffset(550, 450),
		BackgroundColor3 = Library.GUIPallete.MainBG,
		Parent = Container
	}) addCorner(windowFrame); addStroke(windowFrame, true); makeDraggable(windowFrame)

	-- keybind functionality
	local keybindConnection = Connect(inputService.InputBegan, function(input, isTyping)
		if isTyping then return end

		if input.KeyCode == Library.Keybind then
			windowFrame.Visible = not windowFrame.Visible
		end
	end)

	-- the holder for the tabs frame
	local tabsFrame = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 100, 1, 0),
		Parent = windowFrame
	})

	-- the tabs frame
	local tabsHolder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 1, -12),
		Parent = tabsFrame
	}) addCorner(tabsHolder); addStroke(tabsHolder)

	-- list layout inside of tab's frame
	local tabListLayout = New("UIListLayout", {
		Padding = UDim.new(0, 10),
		VerticalFlex = Enum.UIFlexAlignment.Fill,
		Parent = tabsHolder
	})

	-- the holder for the tab component holder
	local tabFrame = New("Frame", {
		Position = UDim2.fromOffset(105, 6),
		Size = UDim2.new(1, -112, 1, -12),
		BackgroundTransparency = 1,
		Parent = windowFrame
	})

	-- the holder for the actual tab components
	local tabComponentHolder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundTransparency = 1,
		Parent = tabFrame
	}) addCorner(tabComponentHolder); addStroke(tabComponentHolder)

	local windowFunctions = {}

	function windowFunctions:ToggleVisibility()
		windowFrame.Visible = not windowFrame.Visible
	end

	function windowFunctions:Show()
		windowFrame.Visible = true
	end

	function windowFunctions:Hide()
		windowFrame.Visible = false
	end

	function windowFunctions:Remove()
		keybindConnection:Disconnect()
		windowFrame:Destroy()
		table.clear(self); self = nil
	end

	-- make tab function
	function windowFunctions:Tab(Icon: string)
		-- the holder for the tab's icon and also acts as the button
		local tabHolder = New("TextButton", {
			Name = Icon:gsub("rbxassetid://",''),
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundTransparency = 1,
			Text = "",
			Parent = tabsHolder
		})

		-- the icon for the tab itself
		local tabIcon = New("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(48, 48),
			BackgroundTransparency = 1,
			Image = Icon,
			ImageColor3 = Library.GUIPallete.Image,
			Parent = tabHolder
		})

		-- the tab's components
		local tabComponents = New("ScrollingFrame", {
			Name = Icon:gsub("rbxassetid://",''),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -5, 1, -5),
			CanvasSize = UDim2.new(),
			BackgroundTransparency = 1,
			AutomaticCanvasSize = "Y",
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			Visible = #Library.Tabs == 0,
			Parent = tabComponentHolder
		})

		table.insert(Library.Tabs, Icon)
	end

	return windowFunctions
end

-- watermark
function Library:Watermark(text: string?)
	local waterMark = New("Frame", {
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.fromOffset(getTextSize(text).X + 10, 30),
		BackgroundColor3 = Library.GUIPallete.MainBG,
		Parent = Container
	}) addCorner(waterMark); addStroke(waterMark, true); makeDraggable(waterMark, true)

	local waterMarkText = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = Library.GUIPallete.Selected, -- gotta use the selected text for it to stand out more
		TextSize = 14,
		FontFace = Library.GUIPallete.Font,
		RichText = true,
		Text = text,
		Parent = waterMark
	})

	local watermarkFunctions = {}

	function watermarkFunctions:ToggleVisibility()
		windowFrame.Visible = not windowFrame.Visible
	end

	function watermarkFunctions:Show()
		windowFrame.Visible = true
	end

	function watermarkFunctions:Hide()
		windowFrame.Visible = false
	end

	function watermarkFunctions:Remove()
		waterMark:Destroy()
		table.clear(self); self = nil
	end

	function watermarkFunctions:Set(text: string)
		waterMarkText.Text = text
	end

	return watermarkFunctions
end

-- notify
function Library:Notify(text: string, duration: number?)
	local notificationAmount = #notificationsFolder:GetChildren() + 1

	-- the notification frame
	local notification = New("Frame", {
		Position = UDim2.new(1, -10, 1, -(40 * notificationAmount)),
		Size = UDim2.fromOffset(getTextSize(text).X + 10, 30),
		BackgroundColor3 = Library.GUIPallete.MainBG,
		Parent = notificationsFolder
	}) addCorner(notification); addStroke(notification, true)

	-- the notification text
	local notificationText = New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -10, 0, 20),
		BackgroundTransparency = 1,
		TextColor3 = Library.GUIPallete.Selected, -- gotta use the selected text for it to stand out more
		TextSize = 14,
		FontFace = Library.GUIPallete.Font,
		RichText = true,
		Text = text,
		Parent = notification
	})

	local notificationFunctions = {}

	function notificationFunctions:Remove()
		notification:Destroy()
		table.clear(self); self = nil
	end

	function notificationFunctions:Set(text: string)
		notificationText.Text = text
	end

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Exponential)

	tween(notification, tweenInfo, {AnchorPoint = Vector2.new(1)})

	task.delay(duration or 3, function()
		tween(notification, tweenInfo, {AnchorPoint = Vector2.new()})

		task.wait(0.25)

		notification:Destroy()
	end)

	return notificationFunctions
end

-- init library
Library.Loaded = true

return Library

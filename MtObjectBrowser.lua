local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local function DecID2ImgID(id:number): string
	return string.format("rbxthumb://type=Asset&id=%s&w=420&h=420",tostring(id))
end

local function InvertToggledAttribute(button:PluginToolbarButton): boolean
	local oldstate = button:GetAttribute("Show")
	local newstate

	if oldstate~=nil then
		newstate = not oldstate
	else
		newstate = false
	end
	button:SetAttribute("Show",newstate)

	return newstate
end

local OBJECT_ICON = DecID2ImgID(9814496235)
local FUNCTION_ICON = DecID2ImgID(9817022493)
local PROPERTY_ICON = DecID2ImgID(9855837573)
local CONST_ICON = DecID2ImgID(9872210636)

local toolbar = plugin:CreateToolbar("Mt Object Browser")
local objectsButton = toolbar:CreateButton("objectsButton", "Browse through all objects in the Mt module.", OBJECT_ICON,"Objects")
objectsButton.ClickableWhenViewportHidden = false
InvertToggledAttribute(objectsButton)

local THEME = settings().Studio.Theme

local function InitScreenGui(enabled:boolean, name:string): ScreenGui
	enabled = enabled or false
	name = name or "MtObjectBrowser"

	local screen = CoreGui:FindFirstChild(name)
	if not screen then
		screen = Instance.new("ScreenGui")
		screen.Name = name
		screen.IgnoreGuiInset = true
		screen.DisplayOrder = 999
		screen.Enabled = enabled
		screen.Parent = game:GetService("CoreGui")
	end

	return screen
end

local mainscreen = InitScreenGui()

type Parameter = {
	["Name"]: string,
	["Type"]: string,
	["Default"]: string
}

type Tag = {
	["Name"]: string,
	["Color"]: Color3,
	["Strikethrough"]: boolean
}

local function ShouldStriketrhough(tags:{Tag}): boolean
	if tags then
		for _,tag in ipairs(tags) do
			if tag.Strikethrough then
				return true
			end
		end
	end
	return false
end

local DEPRECATED_TAG: Tag = {
	Name = "deprecated",
	Color = Color3.new(1,0,0),
	Strikethrough = true
}

type Member = {
	["Name"]: string,
	["Type"]: string,
	["MemberType"]: "method"|"property"|"constant",
	["Icon"]: string,
	["Description"]: string,
	["Parameters"]: {Parameter},
	["Tags"]: {Tag}
}

type Object = {
	["Name"]: string,
	["Icon"]: string,
	["Description"]: string,
	["Parent"]: string,
	["Children"]: {string},
	["Members"]: {Member},
	["Tags"]: {Tag}
}

local function _StringFloor(n: number): string
	return tostring(math.floor(n))
end

local function _Color3ToRichText(c: Color3): string
	return 'rgb('.._StringFloor(c.R*255)..','.._StringFloor(c.G*255)..','.._StringFloor(c.B*255)..')'
end

local function GetFullDesc(info:Object|Member): string
	if not info then error("MtObjectBrowser error: GetFullDesc must have info.") end

	local strikethrough: boolean = ShouldStriketrhough(info.Tags)

	local desc = '<b><font size="30">'..(strikethrough and "<s>" or "")..(info.Name or "") -- name
	if info.MemberType == "method" then
		desc = desc.."(" -- add parentheses if function
		if info.Parameters then -- parameters
			for i,param in ipairs(info.Parameters) do
				desc = desc..param.Name..": "..param.Type..(info.Default~=nil and "="..info.Default or "")..(i==#info.Parameters and "" or ", ")
			end
		end
		desc = desc..")" -- close parentheses
	end
	if strikethrough then desc = desc.."</s>" end
	desc = desc..'</font>'
	
	if info.Type then -- member type
		desc = desc..'<font size="24">: '..info.Type..'</font>'
	end
	desc = desc..'<br/>'
	if info.Tags then -- add tags
		for _,tag in ipairs(info.Tags) do
			desc = desc..'<font color="'.._Color3ToRichText(tag.Color)..'">['..tag.Name..']</font> '
		end
	end
	if info.Parent then -- super class
		desc = desc..'Inherits: '..info.Parent.."<br/>"
	end
	if info.Children then -- child classes
		desc = desc.."Inherited by: "
		for i,class in ipairs(info.Children) do
			desc = desc..class..(i==#info.Children and "" or ", ")
		end
		desc = desc.."<br/>"
	end

	desc = desc.."</b><br/>"

	desc = desc..(info.Description or "<i>This class/member seems to be undocumented.</i>")

	return desc
end

local function GetDictKeys(d:{[string]: any?}): {string}
	local keyset={}
	local n=0

	for k,v in pairs(d) do
		n=n+1
		keyset[n]=k
	end

	return keyset
end
local function DoesKeyExist(d:{[string]: any?},k:string): boolean
	k = k or ""
	return table.find(GetDictKeys(d),k) ~= nil
end

local function _MemberLexicalSort(a:Member,b:Member): boolean
	return a.Name:lower() < b.Name:lower()
end

local function SortMembers(members:{Member}): {Member}
	local orgMembers = { -- organized members
		["property"] = {},
		["method"]   = {},
		["constant"] = {}
	}

	-- organize members by member type
	for _, member in pairs(members) do
		if DoesKeyExist(orgMembers,member.MemberType) then
			table.insert(orgMembers[member.MemberType],member)
		end
	end

	for _, list in pairs(orgMembers) do
		table.sort(list,_MemberLexicalSort)
	end

	local sorted = {}
	for i,v in ipairs(orgMembers.property) do sorted[i]                                           = v end
	for i,v in ipairs(orgMembers.method)   do sorted[i+#orgMembers.property]                      = v end
	for i,v in ipairs(orgMembers.constant) do sorted[i+#orgMembers.property+#orgMembers.method] = v end

	return sorted
end

type ObjectList = {Object}

local OBJECTS = {
	{
		Name = "MObject",
		Icon = OBJECT_ICON,
		Description = "Base class for all Mt objects.",
		Parent = nil,
		Children = {"MWidget","MScreen","MWindowResizeRegion","MRobloxInstance"},
		Members = {
			{
				Name = "Name",
				Type = "string",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Name of the object.",
			},
			{
				Name = "Init",
				Type = "nil",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Creates a new MObject."
			},
			{
				Name = "Parent",
				Type = "MObject",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Object's parent. Not to be confused with the parent class.",
			},
			{
				Name = "Destroy",
				Type = "nil",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Deletes the object."
			},
			{
				Name = "ClassName",
				Type = "string",
				MemberType = "constant",
				Icon = CONST_ICON,
				Description = "Object class name."
			},
			{
				Name = "BlockEvents",
				Type = "boolean",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "If this value is true then all events in the object won't be fired.",
				Tags = {DEPRECATED_TAG}
			},
		}
	},
	{
		Name = "MWidget",
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Children = {"MWindow", "MProgressBar"},
		Description = "A place where you can put GUI objects like progress bars, spinboxes, etc.<br />This class is also the base for all Mt GUI objects!",
		Members = {
			{
				Name = "SetSize",
				Type = "boolean",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Resizes widget to given point.",
				Parameters = {
					{
						Name = "newsize",
						Type = "Vector2"
					},
					{
						Name = "anchor",
						Type = "boolean",
						Default = "false"
					}
				}
			},
			{
				Name = "SetPosition",
				Type = "nil",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Teleports widget to given location."
			},
			{
				Name = "IsCoordinateBelowMax",
				Type = "boolean",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Returns true if given Vector2 value is below the maximum widget size."
			},
			{
				Name = "IsCoordinateAboveMin",
				Type = "boolean",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Returns true if given Vector2 value is above the minimum widget size."
			},
			{
				Name = "CalcLimitedSize",
				Type = "(Vector2, boolean)",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "Returns the given Vector2 value below maximum and above minimum widget size.<br/>Also returns true if given value wasn't in between limited size."
			},
			{
				Name = "SetSizeFromScale",
				Type = "nil",
				MemberType = "method",
				Icon = FUNCTION_ICON,
				Description = "<u>Converts scale to offset</u> and resizes widget."
			},
		}
	},
	{
		Name = "MWindow",
		Icon = OBJECT_ICON,
		Parent = "MWidget",
		Description = "A window, controlled by an MWindowManager objects",
		Members = {
			{
				Name = "Handle",
				Type = "MWidget",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Widget representing the window caption/handle."
			},
			{
				Name = "Stroke",
				Type = "UIStroke",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "UIStroke object representing the blue borders around the window."
			},
			{
				Name = "Content",
				Type = "Frame",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Frame representing the area where it's possible to add widgets in the window."
			},
			{
				Name = "ResizeRegions",
				Type = "{MWindowResizeRegions}",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "List containing all four window resize regions."
			},
			{
				Name = "WindowInteractionState",
				Type = "MtEnum.WindowInteractionState",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Value indicating if the window is being moved, resized, etc."
			},
		}
	},
	{
		Name = "MScreen",
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Description = "An object representing a ScreenGui, where you can put MWidgets."
	},
	{
		Name = "MWindowManager",
		Icon = OBJECT_ICON,
		Parent = "MScreen",
		Description = "A screen that controls MWindows. It can move, resize, close and maximize them."
	},
	{
		Name = "MWindowResizeRegion",
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Description = "Frame that attaches to a border of an MWindow to detect resizing events."
	},
	{
		Name = "MProgressBar",
		Icon = OBJECT_ICON,
		Parent = "MWidget",
		Description = "A widget displaying a bar that fills to a desired spot from 0 to 100%."
	},
	{
		Name = "MRobloxInstance",
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Description = nil
	},
}

local function FindFirstObjectByProp(list:{},property:string,value:any): Object|Member
	for i,obj in ipairs(list) do
		if obj[property] == value then
			return obj
		end
	end
	return nil
end

local STROKE = Instance.new("UIStroke")
STROKE.Name = "Stroke"
STROKE.Thickness = 3
STROKE.LineJoinMode = Enum.LineJoinMode.Miter
STROKE.Color = THEME:GetColor(Enum.StudioStyleGuideColor.Border)

local function AddStroke(frame:Frame, useUIStroke:boolean)
	useUIStroke = useUIStroke or false

	if useUIStroke then
		STROKE:Clone().Parent = frame
	else
		frame.BorderSizePixel = STROKE.Thickness
		frame.BorderColor3 = STROKE.Color
		frame.BorderMode = Enum.BorderMode.Inset
	end
end

local function LoadClassInfoGui(scrollarea:ScrollingFrame, desclabel:TextLabel, order:number, info:Object|Member): TextButton
	local button = Instance.new("TextButton")
	button.Name = info.Name
	button.Text = ""
	button.Size = UDim2.new(1,0,0,25)
	button.BackgroundColor3 = scrollarea.BackgroundColor3
	button.BorderSizePixel = 0

	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1,1)
	label.BackgroundTransparency = 1
	label.TextColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainText)
	label.Font = Enum.Font.SourceSans
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextSize = 17.5
	label.Text = info.Name
	if ShouldStriketrhough(info.Tags) then
		label.RichText = true
		label.Text = "<s>"..label.Text.."</s>"
	end
	label.LayoutOrder = 2
	label.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0,25,1,0)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = info.Icon
	icon.LayoutOrder = 1
	icon.Parent = button

	button.LayoutOrder = order
	button.Parent = scrollarea

	button.MouseButton1Down:Connect(function()
		for _, button in ipairs(scrollarea:GetChildren()) do
			if button:IsA("GuiButton") then
				button.BackgroundColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainBackground)
				button.TextColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainText)
			end
		end
		button.BackgroundColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.Item, Enum.StudioStyleGuideModifier.Selected)
		button.TextColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Selected)

		desclabel.Text = GetFullDesc(info)
	end)

	return button
end

local SCROLLBAR = DecID2ImgID(5234388158)

local function CreateScrollArea(name: string, pos:UDim2, size:UDim2, screen): ScrollingFrame
	screen = screen or mainscreen

	local area = Instance.new("ScrollingFrame")
	area.Name = name
	area.Position = pos
	area.Size = size
	area.BackgroundColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	area.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	AddStroke(area)

	area.ScrollBarImageColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainText)
	area.MidImage = SCROLLBAR
	area.TopImage = SCROLLBAR
	area.BottomImage = SCROLLBAR
	area.ScrollBarImageTransparency = 0

	area.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.Name = "ListLayout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0,0)
	layout.Parent = area

	return area
end

local function TableAppend(a:{},b:{},overwrite:boolean):{}
	a = a or {}
	b = b or {}
	overwrite = overwrite or false

	if not overwrite then a = table.clone(a) end
	for _,v in pairs(b) do table.insert(a,v) end

	return a
end

local function GetInheritedMembers(parentName:string): {Member}
	local parent = FindFirstObjectByProp(OBJECTS,"Name",parentName)

	if parent then
		local parentMembers = {}
		if parent.Parent then
			parentMembers = GetInheritedMembers(parent.Parent)
		end

		local members = TableAppend(parent.Members,parentMembers)
		return members
	end

	return {}
end

local function InitGui(objects:ObjectList, screen:ScreenGui)
	screen = screen or mainscreen

	local objectsarea = CreateScrollArea("ObjectsArea",UDim2.fromScale(0,0),UDim2.fromScale(0.225,1), screen)
	local membersarea = CreateScrollArea("MembersArea",UDim2.fromScale(0.225,0),UDim2.fromScale(0.775,0.6), screen)

	local descarea    = CreateScrollArea("DescArea",UDim2.fromScale(0.225,0.6),UDim2.fromScale(0.775,0.4), screen)

	local descpadding = Instance.new("UIPadding")
	descpadding.Name = "Padding"
	local padding = UDim.new(0,5)
	descpadding.PaddingTop = padding
	descpadding.PaddingBottom = padding
	descpadding.PaddingLeft = padding
	descpadding.PaddingRight = padding
	descpadding.Parent = descarea

	local desclabel = Instance.new("TextLabel")
	desclabel.Name = "DescLabel"
	desclabel.Size = UDim2.fromScale(1,1)
	desclabel.BackgroundTransparency = 1
	desclabel.TextColor3 = THEME:GetColor(Enum.StudioStyleGuideColor.MainText)
	desclabel.TextXAlignment = Enum.TextXAlignment.Left
	desclabel.TextYAlignment = Enum.TextYAlignment.Top
	desclabel.TextSize = 15
	desclabel.TextWrapped = true
	desclabel.Font = Enum.Font.SourceSans
	desclabel.RichText = true
	desclabel.Text = "<i>Press an object in the panel on the left to look at its description!</i>"
	desclabel.Parent = descarea

	for i, info in ipairs(objects) do
		local button = LoadClassInfoGui(objectsarea,desclabel,i,info)

		function info:Show()
			-- destroy all buttons inside membersarea
			for _,v in ipairs(membersarea:GetChildren()) do if v:IsA("GuiButton") then v:Destroy() end end
			
			local inherited = {}
			if self.Parent then inherited=GetInheritedMembers(self.Parent) end

			local members = SortMembers(TableAppend(self.Members,inherited))

			for i, member in ipairs(members) do
				LoadClassInfoGui(membersarea,desclabel,i,member)
			end
		end

		button.MouseButton1Down:Connect(function() info:Show() end)
	end
end

InitGui(OBJECTS)

RunService.Heartbeat:Connect(function()
	objectsButton:SetActive(objectsButton:GetAttribute("Show"))
end)

local function OnClick()
	local active = InvertToggledAttribute(objectsButton)
	mainscreen.Enabled = active
end

objectsButton.Click:Connect(OnClick)

local function AboutToQuit()
	toolbar:Destroy()
	mainscreen.Enabled = false
	mainscreen:Destroy()
end

plugin.Unloading:Connect(AboutToQuit)
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

local toolbar = plugin:CreateToolbar("Mt Object Browser")
local objectsButton = toolbar:CreateButton("objectsButton", "Browse through all objects in the Mt module.", OBJECT_ICON,"Objects")
objectsButton.ClickableWhenViewportHidden = false
InvertToggledAttribute(objectsButton)

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

type Member = {
	["Type"]: string,
	["MemberType"]: "function"|"property"|"constant",
	["Icon"]: string,
	["Description"]: string,
}

type Object = {
	["Icon"]: string,
	["Description"]: string,
	["Parent"]: string,
	["Children"]: {string},
	["Members"]: {[string]: Member}
}

local function GetFullDesc(name:string,info:Object|Member): string
	if not name or not info then error("MtObjectBrowser error: GetFullDesc must have name and info.") end

	local desc = '<b><font size="30">'..name -- name
	if info.MemberType == "function" then -- add parentheses if function
		desc = desc.."()"
	end
	desc = desc..'</font>'
	if info.Type then -- member type
		desc = desc..'<font size="24">: '..info.Type..'</font>'
	end
	desc = desc..'<br/>'
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

type ObjectList = {[string]: Object}

local OBJECTS = {
	MObject = {
		Icon = OBJECT_ICON,
		Description = "Base class for all Mt objects.",
		Parent = nil,
		Children = {"MWidget","MScreen","MWindowResizeRegion","MRobloxInstance"},
		Members = {
			Name = {
				Type = "string",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Name of the object.",
			},
			Init = {
				Type = "nil",
				MemberType = "function",
				Icon = FUNCTION_ICON,
				Description = "Creates a new MObject."
			},
			Parent = {
				Type = "MObject",
				MemberType = "property",
				Icon = PROPERTY_ICON,
				Description = "Object's parent. Not to be confused with the parent class (which in this case doesn't even exist).",
			},
			Destroy = {
				Type = "nil",
				MemberType = "function",
				Icon = FUNCTION_ICON,
				Description = "Deletes the object."
			},
		}
	},
	MWidget = {
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Children = {"MWindow", "MProgressBar"},
		Description = "A place where you can put GUI objects like progress bars, spinboxes, etc.<br />This class is also the base for all Mt GUI objects!"
	},
	MWindow = {
		Icon = OBJECT_ICON,
		Parent = "MWidget",
		Description = "A window, controlled by an MWindowManager objects"
	},
	MScreen = {
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Description = "An object representing a ScreenGui, where you can put MWidgets."
	},
	MWindowManager = {
		Icon = OBJECT_ICON,
		Parent = "MScreen",
		Description = "A screen that controls MWindows. It can move, resize, close and maximize them."
	},
	MWindowResizeRegion = {
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Description = "Frame that attaches to a border of an MWindow to detect resizing events."
	},
	MProgressBar = {
		Icon = OBJECT_ICON,
		Parent = "MWidget",
		Description = "A widget displaying a bar that fills to a desired spot from 0 to 100%."
	},
	MRobloxInstance = {
		Icon = OBJECT_ICON,
		Parent = "MObject",
		Description = nil
	},
}

local STROKE = Instance.new("UIStroke")
STROKE.Name = "Stroke"
STROKE.Thickness = 3
STROKE.LineJoinMode = Enum.LineJoinMode.Miter
STROKE.Color = Color3.fromRGB(130, 130, 130)

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

local function LoadClassInfoGui(scrollarea:ScrollingFrame, desclabel:TextLabel, order:number, name:string, info:Object|Member, use_fontsize:boolean): TextButton
	use_fontsize = use_fontsize or true

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1,0,0,25)
	button.BackgroundColor3 = scrollarea.BackgroundColor3
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSans
	if use_fontsize then
		button.TextSize = 15
	else
		button.TextScaled = true
	end

	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = "         "..name -- TODO: find a way to not do this
	button.LayoutOrder = order
	button.Parent = scrollarea


	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0,25,1,0)
	icon.BackgroundTransparency = 1

	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = info.Icon
	icon.Parent = button

	button.MouseButton1Down:Connect(function()
		for _, button in ipairs(scrollarea:GetChildren()) do
			if button:IsA("GuiButton") then
				button.BackgroundColor3 = Color3.fromRGB(46,46,46)
			end
		end
		button.BackgroundColor3 = Color3.fromRGB(0, 92, 179)

		desclabel.Text = GetFullDesc(name,info)
	end)

	return button
end

local function CreateScrollArea(name: string, pos:UDim2, size:UDim2, screen): ScrollingFrame
	screen = screen or mainscreen

	local area = Instance.new("ScrollingFrame")
	area.Name = name
	area.Position = pos
	area.Size = size
	area.BackgroundColor3 = Color3.fromRGB(46,46,46)
	area.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	AddStroke(area)
	area.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.Name = "ListLayout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0,0)
	layout.Parent = area

	return area
end

local function TableMerge(a:{},b:{},overwrite:boolean):{}
	a = a or {}
	b = b or {}
	overwrite = overwrite or false

	if not overwrite then a = table.clone(a) end
	for i,v in pairs(b) do a[i] = v end

	return a
end

local function GetInheritedMembers(parentName:string): {Member}
	--print("getting members of "..parentName)

	local parent = OBJECTS[parentName]

	if parent then
		local parentMembers = {}
		
		--print(parentName, parent)
		if parent.Parent then
			parentMembers = GetInheritedMembers(parent.Parent)
		end

		local members = TableMerge(parent.Members,parentMembers)
		--print(members)
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
	desclabel.TextColor3 = Color3.new(1,1,1)
	desclabel.TextXAlignment = Enum.TextXAlignment.Left
	desclabel.TextYAlignment = Enum.TextYAlignment.Top
	desclabel.TextSize = 15
	desclabel.TextWrapped = true
	desclabel.Font = Enum.Font.SourceSans
	desclabel.RichText = true
	desclabel.Text = "<i>Press an object in the panel on the left to look at its description!</i>"
	desclabel.Parent = descarea

	local order = 0
	for name, info in pairs(objects) do
		order += 1

		local button = LoadClassInfoGui(objectsarea,desclabel,order,name,info)
		button.MouseButton1Down:Connect(function()
			print("show members for "..name)
			-- destroy all buttons inside membersarea
			for _,v in ipairs(membersarea:GetChildren()) do if v:IsA("GuiButton") then v:Destroy() end end
			
			local inherited = {}
			if info.Parent then inherited=GetInheritedMembers(info.Parent) end

			local members = TableMerge(info.Members,inherited)
			print(info.Members, inherited, members)

			do
				local order = 0
				for name, info in pairs(members) do
					order += 1
					print(name,info)

					LoadClassInfoGui(membersarea,desclabel,order,name,info)
				end
			end
		end)
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
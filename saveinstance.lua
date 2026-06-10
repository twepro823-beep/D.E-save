--[[
	Basic SaveInstance for Luau.

	Usage:
		local SaveInstance = require(path.to.saveinstance)
		local rbxlx = SaveInstance(workspace)

	This module returns a minimal RBXLX-like XML string. It does not write files,
	download assets, serialize Terrain voxels, or read Script.Source.
]]

local SaveInstance = {}

local DEFAULT_OPTIONS = {
	IncludeScripts = false,
	IgnoreServices = {
		CoreGui = true,
		CorePackages = true,
		Chat = true,
		Players = true,
		StarterPlayer = true,
		StarterGui = true,
		StarterPack = true,
		Lighting = false,
		ReplicatedFirst = false,
		ReplicatedStorage = false,
		ServerScriptService = true,
		ServerStorage = false,
		SoundService = false,
		Teams = false,
		TextChatService = true,
	},
}

local BASE_PROPERTIES = {
	"Name",
	"Archivable",
}

local CLASS_PROPERTIES = {
	Workspace = {
		"Gravity",
		"FallenPartsDestroyHeight",
	},

	Model = {
		"PrimaryPart",
		"WorldPivot",
	},

	Folder = {},

	Part = {
		"Shape",
	},

	MeshPart = {
		"MeshId",
		"TextureID",
		"RenderFidelity",
		"CollisionFidelity",
	},

	UnionOperation = {
		"UsePartColor",
	},

	TrussPart = {
		"Style",
	},

	WedgePart = {},
	CornerWedgePart = {},
	SpawnLocation = {
		"AllowTeamChangeOnTouch",
		"Duration",
		"Enabled",
		"Neutral",
		"TeamColor",
	},

	Attachment = {
		"CFrame",
		"Axis",
		"SecondaryAxis",
		"Position",
		"Orientation",
		"Visible",
	},

	WeldConstraint = {
		"Part0",
		"Part1",
		"Enabled",
	},

	Weld = {
		"Part0",
		"Part1",
		"C0",
		"C1",
		"Enabled",
	},

	Motor6D = {
		"Part0",
		"Part1",
		"C0",
		"C1",
		"Transform",
		"Enabled",
	},

	SpecialMesh = {
		"MeshId",
		"TextureId",
		"MeshType",
		"Scale",
		"Offset",
		"VertexColor",
	},

	BlockMesh = {
		"Scale",
		"Offset",
		"VertexColor",
	},

	CylinderMesh = {
		"Scale",
		"Offset",
		"VertexColor",
	},

	Decal = {
		"Texture",
		"Color3",
		"Transparency",
		"Face",
	},

	Texture = {
		"Texture",
		"Color3",
		"Transparency",
		"Face",
		"OffsetStudsU",
		"OffsetStudsV",
		"StudsPerTileU",
		"StudsPerTileV",
	},

	Sound = {
		"SoundId",
		"Volume",
		"PlaybackSpeed",
		"Looped",
		"RollOffMaxDistance",
		"RollOffMinDistance",
		"RollOffMode",
		"EmitterSize",
		"Playing",
		"TimePosition",
	},

	Animation = {
		"AnimationId",
	},

	Shirt = {
		"ShirtTemplate",
		"Color3",
	},

	Pants = {
		"PantsTemplate",
		"Color3",
	},

	ShirtGraphic = {
		"Graphic",
		"Color3",
	},

	ParticleEmitter = {
		"Texture",
		"Color",
		"LightEmission",
		"LightInfluence",
		"Orientation",
		"Size",
		"Squash",
		"Transparency",
		"ZOffset",
		"EmissionDirection",
		"Enabled",
		"Lifetime",
		"Rate",
		"Rotation",
		"RotSpeed",
		"Speed",
		"SpreadAngle",
		"Shape",
		"ShapeInOut",
		"ShapeStyle",
		"Acceleration",
		"Drag",
		"LockedToPart",
		"TimeScale",
	},

	Trail = {
		"Texture",
		"TextureLength",
		"TextureMode",
		"Color",
		"Transparency",
		"Lifetime",
		"MinLength",
		"MaxLength",
		"WidthScale",
		"LightEmission",
		"LightInfluence",
		"FaceCamera",
		"Enabled",
		"Attachment0",
		"Attachment1",
	},

	Beam = {
		"Texture",
		"TextureLength",
		"TextureMode",
		"TextureSpeed",
		"Color",
		"Transparency",
		"Width0",
		"Width1",
		"CurveSize0",
		"CurveSize1",
		"Segments",
		"LightEmission",
		"LightInfluence",
		"FaceCamera",
		"Enabled",
		"Attachment0",
		"Attachment1",
	},

	Humanoid = {
		"DisplayName",
		"Health",
		"MaxHealth",
		"WalkSpeed",
		"JumpPower",
		"JumpHeight",
		"UseJumpPower",
		"AutoRotate",
		"RigType",
		"RequiresNeck",
		"BreakJointsOnDeath",
		"HipHeight",
	},

	PointLight = {
		"Brightness",
		"Color",
		"Enabled",
		"Range",
		"Shadows",
	},

	SpotLight = {
		"Angle",
		"Brightness",
		"Color",
		"Enabled",
		"Face",
		"Range",
		"Shadows",
	},

	SurfaceLight = {
		"Angle",
		"Brightness",
		"Color",
		"Enabled",
		"Face",
		"Range",
		"Shadows",
	},

	Fire = {
		"Color",
		"Enabled",
		"Heat",
		"SecondaryColor",
		"Size",
	},

	Smoke = {
		"Color",
		"Enabled",
		"Opacity",
		"RiseVelocity",
		"Size",
	},

	Sparkles = {
		"Enabled",
		"SparkleColor",
	},
}

local BASEPART_PROPERTIES = {
	"CFrame",
	"Size",
	"Color",
	"BrickColor",
	"Material",
	"Transparency",
	"Reflectance",
	"Anchored",
	"CanCollide",
	"CanTouch",
	"CanQuery",
	"CastShadow",
	"Massless",
	"Locked",
	"RootPriority",
	"CustomPhysicalProperties",
}

local SKIPPED_SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local function copyDefaults()
	local options = {
		IncludeScripts = DEFAULT_OPTIONS.IncludeScripts,
		IgnoreServices = {},
	}

	for name, ignored in pairs(DEFAULT_OPTIONS.IgnoreServices) do
		options.IgnoreServices[name] = ignored
	end

	return options
end

local function mergeOptions(userOptions)
	local options = copyDefaults()

	if type(userOptions) ~= "table" then
		return options
	end

	if userOptions.IncludeScripts ~= nil then
		options.IncludeScripts = userOptions.IncludeScripts == true
	end

	if type(userOptions.IgnoreServices) == "table" then
		for name, ignored in pairs(userOptions.IgnoreServices) do
			options.IgnoreServices[name] = ignored == true
		end
	end

	return options
end

local function xmlEscape(value)
	value = tostring(value)
	value = value:gsub("&", "&amp;")
	value = value:gsub("<", "&lt;")
	value = value:gsub(">", "&gt;")
	value = value:gsub("\"", "&quot;")
	value = value:gsub("'", "&apos;")
	return value
end

local function indent(level)
	return string.rep("\t", level)
end

local function getTypeName(value)
	local valueType = typeof(value)

	if valueType == "EnumItem" then
		return "token"
	end

	if valueType == "Instance" then
		return "Ref"
	end

	if valueType == "number" then
		return "float"
	end

	if valueType == "boolean" then
		return "bool"
	end

	return valueType
end

local function formatNumber(value)
	if value ~= value then
		return "0"
	end

	if value == math.huge then
		return "INF"
	end

	if value == -math.huge then
		return "-INF"
	end

	return string.format("%.9g", value)
end

local function appendSimpleXml(lines, level, tagName, name, value)
	table.insert(lines, string.format(
		"%s<%s name=\"%s\">%s</%s>",
		indent(level),
		tagName,
		xmlEscape(name),
		xmlEscape(value),
		tagName
	))
end

local function appendVector2(lines, level, tagName, name, value)
	table.insert(lines, string.format("%s<%s name=\"%s\">", indent(level), tagName, xmlEscape(name)))
	table.insert(lines, string.format("%s<X>%s</X>", indent(level + 1), formatNumber(value.X)))
	table.insert(lines, string.format("%s<Y>%s</Y>", indent(level + 1), formatNumber(value.Y)))
	table.insert(lines, string.format("%s</%s>", indent(level), tagName))
end

local function appendVector3(lines, level, tagName, name, value)
	table.insert(lines, string.format("%s<%s name=\"%s\">", indent(level), tagName, xmlEscape(name)))
	table.insert(lines, string.format("%s<X>%s</X>", indent(level + 1), formatNumber(value.X)))
	table.insert(lines, string.format("%s<Y>%s</Y>", indent(level + 1), formatNumber(value.Y)))
	table.insert(lines, string.format("%s<Z>%s</Z>", indent(level + 1), formatNumber(value.Z)))
	table.insert(lines, string.format("%s</%s>", indent(level), tagName))
end

local function appendColor3(lines, level, name, value)
	table.insert(lines, string.format("%s<Color3 name=\"%s\">", indent(level), xmlEscape(name)))
	table.insert(lines, string.format("%s<R>%s</R>", indent(level + 1), formatNumber(value.R)))
	table.insert(lines, string.format("%s<G>%s</G>", indent(level + 1), formatNumber(value.G)))
	table.insert(lines, string.format("%s<B>%s</B>", indent(level + 1), formatNumber(value.B)))
	table.insert(lines, string.format("%s</Color3>", indent(level)))
end

local function appendCFrame(lines, level, name, value)
	local components = { value:GetComponents() }
	local labels = {
		"X",
		"Y",
		"Z",
		"R00",
		"R01",
		"R02",
		"R10",
		"R11",
		"R12",
		"R20",
		"R21",
		"R22",
	}

	table.insert(lines, string.format("%s<CoordinateFrame name=\"%s\">", indent(level), xmlEscape(name)))

	for index, label in ipairs(labels) do
		table.insert(lines, string.format("%s<%s>%s</%s>", indent(level + 1), label, formatNumber(components[index]), label))
	end

	table.insert(lines, string.format("%s</CoordinateFrame>", indent(level)))
end

local function appendUDim(lines, level, name, value)
	table.insert(lines, string.format("%s<UDim name=\"%s\">", indent(level), xmlEscape(name)))
	table.insert(lines, string.format("%s<S>%s</S>", indent(level + 1), formatNumber(value.Scale)))
	table.insert(lines, string.format("%s<O>%s</O>", indent(level + 1), formatNumber(value.Offset)))
	table.insert(lines, string.format("%s</UDim>", indent(level)))
end

local function appendUDim2(lines, level, name, value)
	table.insert(lines, string.format("%s<UDim2 name=\"%s\">", indent(level), xmlEscape(name)))
	table.insert(lines, string.format("%s<XS>%s</XS>", indent(level + 1), formatNumber(value.X.Scale)))
	table.insert(lines, string.format("%s<XO>%s</XO>", indent(level + 1), formatNumber(value.X.Offset)))
	table.insert(lines, string.format("%s<YS>%s</YS>", indent(level + 1), formatNumber(value.Y.Scale)))
	table.insert(lines, string.format("%s<YO>%s</YO>", indent(level + 1), formatNumber(value.Y.Offset)))
	table.insert(lines, string.format("%s</UDim2>", indent(level)))
end

local function appendNumberRange(lines, level, name, value)
	table.insert(lines, string.format("%s<NumberRange name=\"%s\">%s %s</NumberRange>", indent(level), xmlEscape(name), formatNumber(value.Min), formatNumber(value.Max)))
end

local function formatNumberSequenceKeypoint(keypoint)
	return table.concat({
		formatNumber(keypoint.Time),
		formatNumber(keypoint.Value),
		formatNumber(keypoint.Envelope),
	}, " ")
end

local function appendNumberSequence(lines, level, name, value)
	local parts = {}

	for _, keypoint in ipairs(value.Keypoints) do
		table.insert(parts, formatNumberSequenceKeypoint(keypoint))
	end

	table.insert(lines, string.format("%s<NumberSequence name=\"%s\">%s</NumberSequence>", indent(level), xmlEscape(name), xmlEscape(table.concat(parts, " "))))
end

local function formatColorSequenceKeypoint(keypoint)
	return table.concat({
		formatNumber(keypoint.Time),
		formatNumber(keypoint.Value.R),
		formatNumber(keypoint.Value.G),
		formatNumber(keypoint.Value.B),
		"0",
	}, " ")
end

local function appendColorSequence(lines, level, name, value)
	local parts = {}

	for _, keypoint in ipairs(value.Keypoints) do
		table.insert(parts, formatColorSequenceKeypoint(keypoint))
	end

	table.insert(lines, string.format("%s<ColorSequence name=\"%s\">%s</ColorSequence>", indent(level), xmlEscape(name), xmlEscape(table.concat(parts, " "))))
end

local function appendPhysicalProperties(lines, level, name, value)
	if value == nil then
		appendSimpleXml(lines, level, "OptionalPhysicalProperties", name, "nil")
		return
	end

	table.insert(lines, string.format("%s<PhysicalProperties name=\"%s\">", indent(level), xmlEscape(name)))
	table.insert(lines, string.format("%s<CustomPhysics>true</CustomPhysics>", indent(level + 1)))
	table.insert(lines, string.format("%s<Density>%s</Density>", indent(level + 1), formatNumber(value.Density)))
	table.insert(lines, string.format("%s<Friction>%s</Friction>", indent(level + 1), formatNumber(value.Friction)))
	table.insert(lines, string.format("%s<Elasticity>%s</Elasticity>", indent(level + 1), formatNumber(value.Elasticity)))
	table.insert(lines, string.format("%s<FrictionWeight>%s</FrictionWeight>", indent(level + 1), formatNumber(value.FrictionWeight)))
	table.insert(lines, string.format("%s<ElasticityWeight>%s</ElasticityWeight>", indent(level + 1), formatNumber(value.ElasticityWeight)))
	table.insert(lines, string.format("%s</PhysicalProperties>", indent(level)))
end

local function appendBrickColor(lines, level, name, value)
	appendSimpleXml(lines, level, "BrickColor", name, value.Number)
end

local function appendEnum(lines, level, name, value)
	appendSimpleXml(lines, level, "token", name, value.Value)
end

local function appendRef(lines, level, name, value, references)
	local referent = references[value]

	if not referent then
		return false
	end

	appendSimpleXml(lines, level, "Ref", name, referent)
	return true
end

local function appendProperty(lines, level, name, value, references)
	local valueType = typeof(value)

	if valueType == "nil" then
		return false
	elseif valueType == "string" then
		appendSimpleXml(lines, level, "string", name, value)
	elseif valueType == "number" then
		appendSimpleXml(lines, level, "float", name, formatNumber(value))
	elseif valueType == "boolean" then
		appendSimpleXml(lines, level, "bool", name, value and "true" or "false")
	elseif valueType == "Vector2" then
		appendVector2(lines, level, "Vector2", name, value)
	elseif valueType == "Vector3" then
		appendVector3(lines, level, "Vector3", name, value)
	elseif valueType == "Color3" then
		appendColor3(lines, level, name, value)
	elseif valueType == "BrickColor" then
		appendBrickColor(lines, level, name, value)
	elseif valueType == "CFrame" then
		appendCFrame(lines, level, name, value)
	elseif valueType == "UDim" then
		appendUDim(lines, level, name, value)
	elseif valueType == "UDim2" then
		appendUDim2(lines, level, name, value)
	elseif valueType == "EnumItem" then
		appendEnum(lines, level, name, value)
	elseif valueType == "NumberRange" then
		appendNumberRange(lines, level, name, value)
	elseif valueType == "NumberSequence" then
		appendNumberSequence(lines, level, name, value)
	elseif valueType == "ColorSequence" then
		appendColorSequence(lines, level, name, value)
	elseif valueType == "PhysicalProperties" then
		appendPhysicalProperties(lines, level, name, value)
	elseif valueType == "Instance" then
		return appendRef(lines, level, name, value, references)
	else
		return false, getTypeName(value)
	end

	return true
end

local function appendPropertyName(list, seen, propertyName)
	if not seen[propertyName] then
		seen[propertyName] = true
		table.insert(list, propertyName)
	end
end

local function getPropertiesFor(instance)
	local properties = {}
	local seen = {}

	for _, propertyName in ipairs(BASE_PROPERTIES) do
		appendPropertyName(properties, seen, propertyName)
	end

	local okIsBasePart, isBasePart = pcall(function()
		return instance:IsA("BasePart")
	end)

	if okIsBasePart and isBasePart then
		for _, propertyName in ipairs(BASEPART_PROPERTIES) do
			appendPropertyName(properties, seen, propertyName)
		end
	end

	local classProperties = CLASS_PROPERTIES[instance.ClassName]

	if classProperties then
		for _, propertyName in ipairs(classProperties) do
			appendPropertyName(properties, seen, propertyName)
		end
	end

	return properties
end

local function shouldInclude(instance, options)
	if not options.IncludeScripts and SKIPPED_SCRIPT_CLASSES[instance.ClassName] then
		return false
	end

	local okIsService, isService = pcall(function()
		return instance.Parent == game and game:GetService(instance.ClassName) == instance
	end)

	if okIsService and isService and options.IgnoreServices[instance.ClassName] then
		return false
	end

	return true
end

local function collectInstances(root, options, list, forceInclude)
	if not forceInclude and not shouldInclude(root, options) then
		return
	end

	table.insert(list, root)

	for _, child in ipairs(root:GetChildren()) do
		collectInstances(child, options, list, false)
	end
end

local function buildReferences(instances)
	local references = {}

	for index, instance in ipairs(instances) do
		references[instance] = "RBX" .. tostring(index)
	end

	return references
end

local function appendProperties(lines, level, instance, references)
	table.insert(lines, string.format("%s<Properties>", indent(level)))

	for _, propertyName in ipairs(getPropertiesFor(instance)) do
		local ok, value = pcall(function()
			return instance[propertyName]
		end)

		if ok then
			appendProperty(lines, level + 1, propertyName, value, references)
		end
	end

	table.insert(lines, string.format("%s</Properties>", indent(level)))
end

local function appendItem(lines, level, instance, options, references)
	local referent = references[instance]

	if not referent then
		return
	end

	table.insert(lines, string.format(
		"%s<Item class=\"%s\" referent=\"%s\">",
		indent(level),
		xmlEscape(instance.ClassName),
		xmlEscape(referent)
	))

	appendProperties(lines, level + 1, instance, references)

	for _, child in ipairs(instance:GetChildren()) do
		if references[child] and shouldInclude(child, options) then
			appendItem(lines, level + 1, child, options, references)
		end
	end

	table.insert(lines, string.format("%s</Item>", indent(level)))
end

local function buildDocument(root, options)
	local instances = {}
	collectInstances(root, options, instances, true)

	local references = buildReferences(instances)
	local lines = {
		"<?xml version=\"1.0\" encoding=\"utf-8\"?>",
		"<roblox version=\"4\">",
		"\t<Meta name=\"ExplicitAutoJoints\">true</Meta>",
	}

	appendItem(lines, 1, root, options, references)

	table.insert(lines, "</roblox>")

	return table.concat(lines, "\n")
end

function SaveInstance.SaveInstance(root, userOptions)
	assert(typeof(root) == "Instance", "SaveInstance(root, options) expects root to be an Instance")

	local options = mergeOptions(userOptions)
	return buildDocument(root, options)
end

setmetatable(SaveInstance, {
	__call = function(_, root, userOptions)
		return SaveInstance.SaveInstance(root, userOptions)
	end,
})

return SaveInstance

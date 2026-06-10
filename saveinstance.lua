--[[
	Basic SaveInstance for Luau/executors.

	Usage:
		local SaveInstance = require(path.to.saveinstance)
		local rbxlx = SaveInstance(workspace)
		local result = SaveInstance.SaveToFile(workspace, "dumps/place.rbxlx", {
			SaveAssets = true,
			ShowReadMe = true,
			Callback = function(message, progress)
				print(message, progress)
			end,
		})

	SaveInstance(root, options) returns a minimal RBXLX-like XML string.
	SaveToFile(root, path, options) uses executor APIs such as writefile,
	appendfile, makefolder/isfolder, and request/http_request.

	This does not decompile scripts, read bytecode, or use nil-instance tricks.
	Terrain can be embedded with executor gethiddenproperty grids encoded as
	base64 BinaryString properties.
]]

local SaveInstance = {}

local DEFAULT_OPTIONS = {
	IncludeScripts = true,
	SaveAssets = false,
	SaveTerrain = false,
	ShowReadMe = false,
	IgnoreDefaultProperties = false,
	AlternativeWritefile = true,
	WriteSegmentSize = 4 * 1024 * 1024,
	AssetsFolder = "saveinstance_assets",
	RequestTimeout = 20,
	Callback = nil,
	IgnoreClasses = {},
	IgnoreInstances = {},
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
		"DoubleSided",
		"HasJointOffset",
		"JointOffset",
	},

	UnionOperation = {
		"UsePartColor",
		"RenderFidelity",
		"CollisionFidelity",
		"SmoothingAngle",
	},

	NegateOperation = {
		"UsePartColor",
		"RenderFidelity",
		"CollisionFidelity",
		"SmoothingAngle",
	},

	PartOperation = {
		"UsePartColor",
		"RenderFidelity",
		"CollisionFidelity",
		"SmoothingAngle",
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

	FileMesh = {
		"MeshId",
		"TextureId",
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

	Script = {
		"Disabled",
		"Source",
	},

	LocalScript = {
		"Disabled",
		"Source",
	},

	ModuleScript = {
		"Source",
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

local ASSET_PROPERTY_NAMES = {
	AnimationId = true,
	Graphic = true,
	MeshId = true,
	PantsTemplate = true,
	ShirtTemplate = true,
	SoundId = true,
	Texture = true,
	TextureID = true,
	TextureId = true,
}

local DEFAULT_INSTANCE_CACHE = {}

local function copyDefaults()
	local options = {
		IncludeScripts = DEFAULT_OPTIONS.IncludeScripts,
		SaveAssets = DEFAULT_OPTIONS.SaveAssets,
		SaveTerrain = DEFAULT_OPTIONS.SaveTerrain,
		ShowReadMe = DEFAULT_OPTIONS.ShowReadMe,
		IgnoreDefaultProperties = DEFAULT_OPTIONS.IgnoreDefaultProperties,
		AlternativeWritefile = DEFAULT_OPTIONS.AlternativeWritefile,
		WriteSegmentSize = DEFAULT_OPTIONS.WriteSegmentSize,
		AssetsFolder = DEFAULT_OPTIONS.AssetsFolder,
		RequestTimeout = DEFAULT_OPTIONS.RequestTimeout,
		Callback = DEFAULT_OPTIONS.Callback,
		IgnoreClasses = {},
		IgnoreInstances = {},
		IgnoreServices = {},
	}

	for className, ignored in pairs(DEFAULT_OPTIONS.IgnoreClasses) do
		options.IgnoreClasses[className] = ignored
	end

	for instance, ignored in pairs(DEFAULT_OPTIONS.IgnoreInstances) do
		options.IgnoreInstances[instance] = ignored
	end

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

	if userOptions.SaveAssets ~= nil then
		options.SaveAssets = userOptions.SaveAssets == true
	end

	if userOptions.SaveTerrain ~= nil then
		options.SaveTerrain = userOptions.SaveTerrain == true
	end

	if userOptions.ShowReadMe ~= nil then
		options.ShowReadMe = userOptions.ShowReadMe == true
	end

	if userOptions.IgnoreDefaultProperties ~= nil then
		options.IgnoreDefaultProperties = userOptions.IgnoreDefaultProperties == true
	end

	if userOptions.AlternativeWritefile ~= nil then
		options.AlternativeWritefile = userOptions.AlternativeWritefile == true
	end

	if type(userOptions.WriteSegmentSize) == "number" and userOptions.WriteSegmentSize > 0 then
		options.WriteSegmentSize = math.floor(userOptions.WriteSegmentSize)
	end

	if type(userOptions.AssetsFolder) == "string" and userOptions.AssetsFolder ~= "" then
		options.AssetsFolder = userOptions.AssetsFolder
	end

	if type(userOptions.RequestTimeout) == "number" and userOptions.RequestTimeout > 0 then
		options.RequestTimeout = userOptions.RequestTimeout
	end

	if type(userOptions.Callback) == "function" then
		options.Callback = userOptions.Callback
	end

	if type(userOptions.IgnoreClasses) == "table" then
		for className, ignored in pairs(userOptions.IgnoreClasses) do
			if type(className) == "string" then
				options.IgnoreClasses[className] = ignored ~= false
			elseif type(ignored) == "string" then
				options.IgnoreClasses[ignored] = true
			end
		end
	end

	if type(userOptions.IgnoreInstances) == "table" then
		for instance, ignored in pairs(userOptions.IgnoreInstances) do
			if typeof(instance) == "Instance" then
				options.IgnoreInstances[instance] = ignored ~= false
			elseif typeof(ignored) == "Instance" then
				options.IgnoreInstances[ignored] = true
			end
		end
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

local function getCallableGlobal(name)
	local okEnv, env = pcall(function()
		if getgenv then
			return getgenv()
		end

		if getfenv then
			return getfenv(0)
		end

		return _G
	end)

	if okEnv and type(env) == "table" and type(env[name]) == "function" then
		return env[name]
	end

	local value = rawget(_G, name)

	if type(value) == "function" then
		return value
	end

	return nil
end

local function base64EncodeFallback(data)
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}

	for index = 1, #data, 3 do
		local byte1 = string.byte(data, index) or 0
		local byte2 = string.byte(data, index + 1) or 0
		local byte3 = string.byte(data, index + 2) or 0
		local combined = byte1 * 65536 + byte2 * 256 + byte3
		local char1 = math.floor(combined / 262144) % 64
		local char2 = math.floor(combined / 4096) % 64
		local char3 = math.floor(combined / 64) % 64
		local char4 = combined % 64
		local remaining = #data - index + 1

		table.insert(output, string.sub(alphabet, char1 + 1, char1 + 1))
		table.insert(output, string.sub(alphabet, char2 + 1, char2 + 1))
		table.insert(output, remaining > 1 and string.sub(alphabet, char3 + 1, char3 + 1) or "=")
		table.insert(output, remaining > 2 and string.sub(alphabet, char4 + 1, char4 + 1) or "=")
	end

	return table.concat(output)
end

local function encodeBase64(data)
	if type(data) ~= "string" then
		return nil, "expected binary string"
	end

	local base64encode = getCallableGlobal("base64encode")

	if base64encode then
		local ok, encoded = pcall(base64encode, data)

		if ok and type(encoded) == "string" then
			return encoded
		end
	end

	local okCrypt, cryptTable = pcall(function()
		return crypt
	end)

	if okCrypt and type(cryptTable) == "table" then
		local encoder = cryptTable.base64encode

		if type(encoder) ~= "function" and type(cryptTable.base64) == "table" then
			encoder = cryptTable.base64.encode
		end

		if type(encoder) == "function" then
			local ok, encoded = pcall(encoder, data)

			if ok and type(encoded) == "string" then
				return encoded
			end
		end
	end

	local okEncoding, encodingService = pcall(function()
		return game:GetService("EncodingService")
	end)

	if okEncoding and encodingService then
		local ok, encoded = pcall(function()
			local source = buffer and buffer.fromstring and buffer.fromstring(data) or data
			local result = encodingService:Base64Encode(source)

			if typeof(result) == "buffer" and buffer and buffer.tostring then
				return buffer.tostring(result)
			end

			return result
		end)

		if ok and type(encoded) == "string" then
			return encoded
		end
	end

	return base64EncodeFallback(data)
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

local function appendBinaryString(lines, level, name, value)
	local encoded, err = encodeBase64(value)

	if not encoded then
		return false, err
	end

	appendSimpleXml(lines, level, "BinaryString", name, encoded)
	return true
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

local function report(options, message, progress)
	if type(options.Callback) == "function" then
		pcall(options.Callback, message, progress)
	end
end

local function canCreateDefault(className)
	local ok, instance = pcall(Instance.new, className)

	if ok and instance then
		DEFAULT_INSTANCE_CACHE[className] = instance
		return instance
	end

	DEFAULT_INSTANCE_CACHE[className] = false
	return nil
end

local function getDefaultInstance(className)
	local cached = DEFAULT_INSTANCE_CACHE[className]

	if cached == nil then
		return canCreateDefault(className)
	end

	if cached == false then
		return nil
	end

	return cached
end

local function valuesEqual(left, right)
	if typeof(left) ~= typeof(right) then
		return false
	end

	local valueType = typeof(left)

	if valueType == "number" then
		return math.abs(left - right) < 0.000001
	end

	if valueType == "CFrame" then
		return select(1, left:GetComponents()) == select(1, right:GetComponents()) and tostring(left) == tostring(right)
	end

	return left == right
end

local function isDefaultProperty(instance, propertyName, value)
	local defaultInstance = getDefaultInstance(instance.ClassName)

	if not defaultInstance then
		return false
	end

	local ok, defaultValue = pcall(function()
		return defaultInstance[propertyName]
	end)

	return ok and valuesEqual(value, defaultValue)
end

local function isScriptClass(className)
	return SKIPPED_SCRIPT_CLASSES[className] == true
end

local function getHiddenPropertyReader()
	local direct = getCallableGlobal("gethiddenproperty") or getCallableGlobal("get_hidden_property")

	if direct then
		return direct
	end

	local okDebug, debugTable = pcall(function()
		return debug
	end)

	if okDebug and type(debugTable) == "table" and type(debugTable.gethiddenproperty) == "function" then
		return debugTable.gethiddenproperty
	end

	return nil
end

local function appendHiddenBinaryProperty(lines, level, instance, propertyName, errors)
	local gethiddenproperty = getHiddenPropertyReader()

	if not gethiddenproperty then
		if errors then
			table.insert(errors, propertyName .. ": executor does not provide gethiddenproperty")
		end

		return false
	end

	local okRead, value = pcall(gethiddenproperty, instance, propertyName)

	if not okRead then
		if errors then
			table.insert(errors, propertyName .. ": " .. tostring(value))
		end

		return false
	end

	if type(value) ~= "string" then
		if errors and value ~= nil then
			table.insert(errors, propertyName .. ": expected string, got " .. typeof(value))
		end

		return false
	end

	local okWrite, writeErr = appendBinaryString(lines, level, propertyName, value)

	if not okWrite and errors then
		table.insert(errors, propertyName .. ": " .. tostring(writeErr))
	end

	return okWrite
end

local HIDDEN_MESH_BINARY_PROPERTIES = {
	MeshPart = {
		"MeshData",
		"PhysicsData",
	},

	UnionOperation = {
		"AssetId",
		"ChildData",
		"FormFactor",
		"InitialSize",
		"MeshData",
		"PhysicsData",
	},

	NegateOperation = {
		"AssetId",
		"ChildData",
		"FormFactor",
		"InitialSize",
		"MeshData",
		"PhysicsData",
	},

	PartOperation = {
		"AssetId",
		"ChildData",
		"FormFactor",
		"InitialSize",
		"MeshData",
		"PhysicsData",
	},
}

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
	if options.IgnoreInstances[instance] then
		return false
	end

	if options.IgnoreClasses[instance.ClassName] then
		return false
	end

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

local function appendProperties(lines, level, instance, references, options)
	table.insert(lines, string.format("%s<Properties>", indent(level)))

	for _, propertyName in ipairs(getPropertiesFor(instance)) do
		if isScriptClass(instance.ClassName) and propertyName == "Source" then
			appendSimpleXml(lines, level + 1, "ProtectedString", "Source", "")
		else
			local ok, value = pcall(function()
				return instance[propertyName]
			end)

			if ok and (not options.IgnoreDefaultProperties or not isDefaultProperty(instance, propertyName, value)) then
				appendProperty(lines, level + 1, propertyName, value, references)
			end
		end
	end

	if options.SaveTerrain and instance:IsA("Terrain") then
		local terrainErrors = options._TerrainErrors

		appendHiddenBinaryProperty(lines, level + 1, instance, "SmoothGrid", terrainErrors)
		appendHiddenBinaryProperty(lines, level + 1, instance, "PhysicsGrid", terrainErrors)
	end

	local hiddenMeshProperties = HIDDEN_MESH_BINARY_PROPERTIES[instance.ClassName]

	if hiddenMeshProperties then
		for _, propertyName in ipairs(hiddenMeshProperties) do
			appendHiddenBinaryProperty(lines, level + 1, instance, propertyName)
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

	appendProperties(lines, level + 1, instance, references, options)

	for _, child in ipairs(instance:GetChildren()) do
		if references[child] and shouldInclude(child, options) then
			appendItem(lines, level + 1, child, options, references)
		end
	end

	table.insert(lines, string.format("%s</Item>", indent(level)))
end

local function getRobloxVersion()
	local ok, result = pcall(function()
		return version()
	end)

	if ok and result then
		return result
	end

	ok, result = pcall(function()
		return game:GetService("RunService"):GetRobloxVersion()
	end)

	if ok and result then
		return result
	end

	return "UNKNOWN"
end

local function appendMetadata(lines, root, options, instanceCount)
	table.insert(lines, string.format("\t<Meta name=\"D.E save Root\">%s</Meta>", xmlEscape(root:GetFullName())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save InstanceCount\">%s</Meta>", tostring(instanceCount)))
	table.insert(lines, string.format("\t<Meta name=\"D.E save GeneratedAtUnix\">%s</Meta>", tostring(os.time())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save RobloxVersion\">%s</Meta>", xmlEscape(getRobloxVersion())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save IgnoreDefaultProperties\">%s</Meta>", options.IgnoreDefaultProperties and "true" or "false"))
end

local function appendReadMe(lines, level, options, references)
	if not options.ShowReadMe then
		return
	end

	local referent = "RBX_README"
	local body = table.concat({
		"D.E save export",
		"",
		"This file was generated by a basic Luau RBXLX exporter.",
		"Scripts are saved with empty Source placeholders for future decompiler support.",
		"Terrain SmoothGrid and PhysicsGrid can be embedded as base64 BinaryString properties.",
		"Asset properties are preserved by reference; optional asset downloads are stored beside the file.",
	}, "\n")

	table.insert(lines, string.format("%s<Item class=\"Script\" referent=\"%s\">", indent(level), referent))
	table.insert(lines, string.format("%s<Properties>", indent(level + 1)))
	appendSimpleXml(lines, level + 2, "string", "Name", "D.E save README")
	appendSimpleXml(lines, level + 2, "bool", "Archivable", "true")
	appendSimpleXml(lines, level + 2, "ProtectedString", "Source", body)
	table.insert(lines, string.format("%s</Properties>", indent(level + 1)))
	table.insert(lines, string.format("%s</Item>", indent(level)))
end

local function buildDocument(root, options)
	local instances = {}
	options._TerrainErrors = {}
	report(options, "Collecting instances", 0)
	collectInstances(root, options, instances, true)
	local sawTerrain = false

	for _, instance in ipairs(instances) do
		if instance:IsA("Terrain") then
			sawTerrain = true
			break
		end
	end

	local references = buildReferences(instances)
	local lines = {
		"<?xml version=\"1.0\" encoding=\"utf-8\"?>",
		"<roblox version=\"4\">",
		"\t<Meta name=\"ExplicitAutoJoints\">true</Meta>",
	}

	appendMetadata(lines, root, options, #instances)
	report(options, "Serializing instances", 0.25)
	appendItem(lines, 1, root, options, references)
	appendReadMe(lines, 1, options, references)

	if options.SaveTerrain and not sawTerrain then
		table.insert(options._TerrainErrors, "terrain was not found under the selected root")
	end

	table.insert(lines, "</roblox>")
	report(options, "XML ready", 0.75)

	local terrainResult = {
		Embedded = options.SaveTerrain == true,
		Files = {},
		Errors = options._TerrainErrors,
	}
	options._TerrainErrors = nil

	return table.concat(lines, "\n"), terrainResult
end

local function getExecutorEnvironment()
	local ok, env = pcall(function()
		if getgenv then
			return getgenv()
		end

		if getfenv then
			return getfenv(0)
		end

		return _G
	end)

	if ok and type(env) == "table" then
		return env
	end

	return _G
end

local function getExecutorFunction(name)
	local env = getExecutorEnvironment()
	local value = env and env[name]

	if type(value) == "function" then
		return value
	end

	value = rawget(_G, name)

	if type(value) == "function" then
		return value
	end

	return nil
end

local function getRequestFunction()
	local directRequest = getExecutorFunction("request")
		or getExecutorFunction("http_request")
		or getExecutorFunction("httpRequest")

	if directRequest then
		return directRequest
	end

	local okSyn, synTable = pcall(function()
		return syn
	end)

	if okSyn and type(synTable) == "table" and type(synTable.request) == "function" then
		return synTable.request
	end

	local okHttp, httpTable = pcall(function()
		return http
	end)

	if okHttp and type(httpTable) == "table" and type(httpTable.request) == "function" then
		return httpTable.request
	end

	return nil
end

local function normalizePath(path)
	path = tostring(path)
	path = path:gsub("\\", "/")
	path = path:gsub("/+", "/")
	return path
end

local function parentFolderOf(path)
	path = normalizePath(path)
	return path:match("^(.*)/[^/]+$")
end

local function ensureFolder(path)
	path = normalizePath(path or "")

	if path == "" or path == "." then
		return true
	end

	local makefolder = getExecutorFunction("makefolder")
	local isfolder = getExecutorFunction("isfolder")

	if not makefolder then
		return false, "executor does not provide makefolder"
	end

	local current = ""

	for part in string.gmatch(path, "[^/]+") do
		current = current == "" and part or (current .. "/" .. part)

		local exists = false

		if isfolder then
			local ok, result = pcall(isfolder, current)
			exists = ok and result == true
		end

		if not exists then
			local ok, err = pcall(makefolder, current)

			if not ok then
				return false, err
			end
		end
	end

	return true
end

local function writeFileSegmented(path, content, options)
	local writefile = getExecutorFunction("writefile")
	local appendfile = getExecutorFunction("appendfile")

	if not writefile then
		return false, "executor does not provide writefile"
	end

	if not options.AlternativeWritefile or not appendfile or #content <= options.WriteSegmentSize then
		local ok, err = pcall(writefile, path, content)
		return ok, err
	end

	local ok, err = pcall(writefile, path, "")

	if not ok then
		return false, err
	end

	local total = math.ceil(#content / options.WriteSegmentSize)
	local index = 0

	for offset = 1, #content, options.WriteSegmentSize do
		index += 1
		local chunk = string.sub(content, offset, offset + options.WriteSegmentSize - 1)
		ok, err = pcall(appendfile, path, chunk)

		if not ok then
			return false, err
		end

		report(options, string.format("Writing file %d/%d", index, total), 0.75 + (index / total) * 0.2)

		if task and task.wait then
			task.wait()
		end
	end

	return true
end

local function getBodyFromResponse(response)
	if type(response) == "string" then
		return response
	end

	if type(response) ~= "table" then
		return nil
	end

	return response.Body or response.body or response.Data or response.data
end

local function getStatusFromResponse(response)
	if type(response) ~= "table" then
		return 200
	end

	return response.StatusCode or response.Status or response.status_code or response.status
end

local function extractAssetId(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	return value:match("rbxassetid://(%d+)")
		or value:match("[?&]id=(%d+)")
		or value:match("/asset/%?id=(%d+)")
		or value:match("(%d+)")
end

local function sanitizeFilePart(value)
	value = tostring(value):gsub("[^%w%._%-]", "_"):gsub("_+", "_")
	return value ~= "" and value or "asset"
end

local function collectAssetReferences(root, options)
	local instances = {}
	local assetsById = {}
	local orderedAssets = {}

	collectInstances(root, options, instances, true)

	for _, instance in ipairs(instances) do
		for _, propertyName in ipairs(getPropertiesFor(instance)) do
			if ASSET_PROPERTY_NAMES[propertyName] then
				local ok, value = pcall(function()
					return instance[propertyName]
				end)

				local assetId = ok and extractAssetId(value) or nil

				if assetId and not assetsById[assetId] then
					local asset = {
						Id = assetId,
						Property = propertyName,
						ClassName = instance.ClassName,
						InstanceName = instance.Name,
						Original = value,
					}

					assetsById[assetId] = asset
					table.insert(orderedAssets, asset)
				end
			end
		end
	end

	return orderedAssets
end

local function requestAsset(assetId, options)
	local request = getRequestFunction()

	if not request then
		return nil, "executor does not provide request/http_request"
	end

	local ok, response = pcall(request, {
		Url = "https://assetdelivery.roblox.com/v1/asset/?id=" .. tostring(assetId),
		Method = "GET",
		Timeout = options.RequestTimeout,
	})

	if not ok then
		return nil, response
	end

	local status = getStatusFromResponse(response)
	local body = getBodyFromResponse(response)

	if type(status) == "number" and (status < 200 or status >= 300) then
		return nil, "HTTP " .. tostring(status)
	end

	if type(body) ~= "string" or body == "" then
		return nil, "empty response body"
	end

	return body
end

local function appendManifestLine(lines, asset, path, status, message)
	table.insert(lines, table.concat({
		tostring(asset.Id),
		status,
		path or "",
		asset.ClassName or "",
		asset.InstanceName or "",
		asset.Property or "",
		asset.Original or "",
		message or "",
	}, "\t"))
end

local function saveAssets(root, options)
	local writefile = getExecutorFunction("writefile")
	local result = {
		Assets = {},
		Errors = {},
	}

	if not writefile then
		table.insert(result.Errors, "executor does not provide writefile")
		return result
	end

	local okFolder, folderErr = ensureFolder(options.AssetsFolder)

	if not okFolder then
		table.insert(result.Errors, "could not create assets folder: " .. tostring(folderErr))
		return result
	end

	local assets = collectAssetReferences(root, options)
	local manifestLines = {
		"Id\tStatus\tPath\tClassName\tInstanceName\tProperty\tOriginal\tMessage",
	}

	for index, asset in ipairs(assets) do
		report(options, string.format("Saving asset %d/%d", index, #assets), 0.95)

		local assetPath = normalizePath(options.AssetsFolder .. "/" .. sanitizeFilePart(asset.Id) .. ".asset")
		local body, requestErr = requestAsset(asset.Id, options)

		if body then
			local okWrite, writeErr = pcall(writefile, assetPath, body)

			if okWrite then
				asset.Path = assetPath
				asset.Status = "saved"
				table.insert(result.Assets, asset)
				appendManifestLine(manifestLines, asset, assetPath, "saved")
			else
				local message = tostring(writeErr)
				asset.Status = "write_failed"
				asset.Error = message
				table.insert(result.Assets, asset)
				table.insert(result.Errors, "asset " .. asset.Id .. ": " .. message)
				appendManifestLine(manifestLines, asset, assetPath, "write_failed", message)
			end
		else
			local message = tostring(requestErr)
			asset.Status = "download_failed"
			asset.Error = message
			table.insert(result.Assets, asset)
			table.insert(result.Errors, "asset " .. asset.Id .. ": " .. message)
			appendManifestLine(manifestLines, asset, assetPath, "download_failed", message)
		end
	end

	pcall(writefile, normalizePath(options.AssetsFolder .. "/manifest.tsv"), table.concat(manifestLines, "\n"))

	return result
end

function SaveInstance.SaveInstance(root, userOptions)
	assert(typeof(root) == "Instance", "SaveInstance(root, options) expects root to be an Instance")

	local options = mergeOptions(userOptions)
	return buildDocument(root, options)
end

function SaveInstance.SaveToFile(root, filePath, userOptions)
	assert(typeof(root) == "Instance", "SaveToFile(root, filePath, options) expects root to be an Instance")
	assert(type(filePath) == "string" and filePath ~= "", "SaveToFile(root, filePath, options) expects a non-empty filePath")

	local options = mergeOptions(userOptions)
	local normalizedPath = normalizePath(filePath)
	local folder = parentFolderOf(normalizedPath)

	if folder then
		local okFolder, folderErr = ensureFolder(folder)

		if not okFolder then
			error("could not create output folder: " .. tostring(folderErr), 2)
		end
	end

	if options.SaveAssets and (type(userOptions) ~= "table" or userOptions.AssetsFolder == nil) and folder then
		options.AssetsFolder = normalizePath(folder .. "/" .. DEFAULT_OPTIONS.AssetsFolder)
	end

	local xml, terrainResult = buildDocument(root, options)
	local okWrite, writeErr = writeFileSegmented(normalizedPath, xml, options)

	if not okWrite then
		error("could not write RBXLX file: " .. tostring(writeErr), 2)
	end

	local assetResult = {
		Assets = {},
		Errors = {},
	}

	if options.SaveAssets then
		assetResult = saveAssets(root, options)
	end

	local errors = {}

	for _, err in ipairs(assetResult.Errors) do
		table.insert(errors, err)
	end

	for _, err in ipairs(terrainResult.Errors) do
		table.insert(errors, err)
	end

	report(options, "Done", 1)

	return {
		Ok = #errors == 0,
		Path = normalizedPath,
		Content = xml,
		Assets = assetResult.Assets,
		Terrain = terrainResult,
		Errors = errors,
	}
end

setmetatable(SaveInstance, {
	__call = function(_, root, userOptions)
		return SaveInstance.SaveInstance(root, userOptions)
	end,
})

return SaveInstance

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

	This can decompile scripts through ByteFall or a system decompiler when
	enabled. It does not use nil-instance tricks. Terrain can be embedded with
	executor gethiddenproperty grids encoded as base64 BinaryString properties.
	It can also use the public Roblox API dump for extra properties and optional
	SharedStrings for large binary blobs.
]]

local SaveInstance = {}

local DEFAULT_OPTIONS = {
	IncludeScripts = true,
	SaveAssets = false,
	SaveTerrain = false,
	SaveAttributes = true,
	SaveTags = true,
	SaveHiddenProperties = true,
	DecompileScripts = true,
	UseByteFallDecompiler = true,
	ByteFallEndpoint = "https://decompiler.bytefall.dev/decompile",
	FallbackToSystemDecompiler = true,
	DecompilerTimeout = 30,
	RobloxLikeReferents = true,
	UseApiDump = true,
	ApiDumpUrl = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json",
	SaveInternalIds = false,
	UseSharedStrings = false,
	SharedStringMinBytes = 4096,
	Diagnostics = true,
	ShowStatus = false,
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
		StarterGui = false,
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

	StarterGui = {
		"ProcessUserInput",
		"ResetPlayerGuiOnSpawn",
		"ScreenOrientation",
		"ShowDevelopmentGui",
	},

	ReplicatedStorage = {},

	ReplicatedFirst = {},

	StarterPack = {},

	Lighting = {
		"Ambient",
		"Brightness",
		"ClockTime",
		"ColorShift_Bottom",
		"ColorShift_Top",
		"EnvironmentDiffuseScale",
		"EnvironmentSpecularScale",
		"ExposureCompensation",
		"FogColor",
		"FogEnd",
		"FogStart",
		"GeographicLatitude",
		"GlobalShadows",
		"OutdoorAmbient",
		"ShadowSoftness",
		"Technology",
		"TimeOfDay",
	},

	SoundService = {
		"AmbientReverb",
		"DistanceFactor",
		"DopplerScale",
		"RespectFilteringEnabled",
		"RolloffScale",
		"VolumetricAudio",
	},

	Teams = {},

	TextChatService = {
		"ChatTranslationEnabled",
		"CreateDefaultCommands",
		"CreateDefaultTextChannels",
	},

	Camera = {
		"CFrame",
		"CameraType",
		"FieldOfView",
		"FieldOfViewMode",
		"Focus",
		"HeadLocked",
		"HeadScale",
		"MaxAxisFieldOfView",
	},

	Model = {
		"PrimaryPart",
		"WorldPivot",
		"LevelOfDetail",
		"ModelStreamingMode",
	},

	Folder = {},

	Part = {
		"Shape",
	},

	MeshPart = {
		"MeshId",
		"TextureID",
		"TextureId",
		"MeshContent",
		"TextureContent",
		"RenderFidelity",
		"CollisionFidelity",
		"DoubleSided",
		"HasJointOffset",
		"JointOffset",
		"FluidFidelity",
		"UsePartColor",
		"HasSkinnedMesh",
	},

	UnionOperation = {
		"UsePartColor",
		"RenderFidelity",
		"CollisionFidelity",
		"SmoothingAngle",
		"AssetId",
		"ChildData",
		"InitialSize",
	},

	NegateOperation = {
		"UsePartColor",
		"RenderFidelity",
		"CollisionFidelity",
		"SmoothingAngle",
		"AssetId",
		"ChildData",
		"InitialSize",
	},

	PartOperation = {
		"UsePartColor",
		"RenderFidelity",
		"CollisionFidelity",
		"SmoothingAngle",
		"AssetId",
		"ChildData",
		"InitialSize",
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

	AlignPosition = {
		"Attachment0",
		"Attachment1",
		"Enabled",
		"MaxForce",
		"MaxVelocity",
		"Mode",
		"Position",
		"Responsiveness",
		"RigidityEnabled",
	},

	AlignOrientation = {
		"Attachment0",
		"Attachment1",
		"CFrame",
		"Enabled",
		"MaxAngularVelocity",
		"MaxTorque",
		"Mode",
		"Responsiveness",
		"RigidityEnabled",
	},

	BallSocketConstraint = {
		"Attachment0",
		"Attachment1",
		"Enabled",
		"LimitsEnabled",
		"Radius",
		"Restitution",
		"TwistLimitsEnabled",
		"TwistLowerAngle",
		"TwistUpperAngle",
		"UpperAngle",
	},

	HingeConstraint = {
		"Attachment0",
		"Attachment1",
		"ActuatorType",
		"AngularResponsiveness",
		"AngularSpeed",
		"Enabled",
		"LimitsEnabled",
		"LowerAngle",
		"MotorMaxAcceleration",
		"MotorMaxTorque",
		"Restitution",
		"ServoMaxTorque",
		"TargetAngle",
		"UpperAngle",
	},

	RodConstraint = {
		"Attachment0",
		"Attachment1",
		"Enabled",
		"Length",
		"LimitAngle0",
		"LimitAngle1",
		"LimitsEnabled",
		"Thickness",
	},

	RopeConstraint = {
		"Attachment0",
		"Attachment1",
		"Enabled",
		"Length",
		"Restitution",
		"Thickness",
		"Visible",
	},

	SpringConstraint = {
		"Attachment0",
		"Attachment1",
		"Coils",
		"Damping",
		"Enabled",
		"FreeLength",
		"LimitsEnabled",
		"MaxForce",
		"MaxLength",
		"MinLength",
		"Radius",
		"Stiffness",
		"Thickness",
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
		"MeshID",
		"TextureID",
		"MeshType",
		"Scale",
		"Offset",
		"VertexColor",
		"LODX",
		"LODY",
	},

	FileMesh = {
		"MeshId",
		"TextureId",
		"MeshID",
		"TextureID",
		"Scale",
		"Offset",
		"VertexColor",
		"LODX",
		"LODY",
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

	SurfaceAppearance = {
		"AlphaMode",
		"ColorMap",
		"MetalnessMap",
		"NormalMap",
		"RoughnessMap",
	},

	Sky = {
		"CelestialBodiesShown",
		"MoonAngularSize",
		"MoonTextureId",
		"SkyboxBk",
		"SkyboxDn",
		"SkyboxFt",
		"SkyboxLf",
		"SkyboxRt",
		"SkyboxUp",
		"StarCount",
		"SunAngularSize",
		"SunTextureId",
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

	ProximityPrompt = {
		"ActionText",
		"AutoLocalize",
		"ClickablePrompt",
		"Enabled",
		"Exclusivity",
		"GamepadKeyCode",
		"HoldDuration",
		"KeyboardKeyCode",
		"MaxActivationDistance",
		"ObjectText",
		"RequiresLineOfSight",
		"RootLocalizationTable",
		"Style",
		"UIOffset",
	},

	ClickDetector = {
		"CursorIcon",
		"MaxActivationDistance",
	},

	ScreenGui = {
		"DisplayOrder",
		"Enabled",
		"IgnoreGuiInset",
		"ResetOnSpawn",
		"ScreenInsets",
		"ZIndexBehavior",
	},

	SurfaceGui = {
		"Active",
		"Adornee",
		"AlwaysOnTop",
		"Brightness",
		"CanvasSize",
		"ClipsDescendants",
		"Enabled",
		"Face",
		"LightInfluence",
		"MaxDistance",
		"PixelsPerStud",
		"SizingMode",
		"ToolPunchThroughDistance",
		"ZIndexBehavior",
	},

	BillboardGui = {
		"Active",
		"Adornee",
		"AlwaysOnTop",
		"Brightness",
		"ClipsDescendants",
		"Enabled",
		"ExtentsOffset",
		"ExtentsOffsetWorldSpace",
		"LightInfluence",
		"MaxDistance",
		"PlayerToHideFrom",
		"Size",
		"SizeOffset",
		"StudsOffset",
		"StudsOffsetWorldSpace",
		"ZIndexBehavior",
	},

	Frame = {
		"Active",
		"AnchorPoint",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"ClipsDescendants",
		"LayoutOrder",
		"Position",
		"Rotation",
		"Selectable",
		"Size",
		"SizeConstraint",
		"Visible",
		"ZIndex",
	},

	TextLabel = {
		"Active",
		"AnchorPoint",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"ClipsDescendants",
		"Font",
		"LayoutOrder",
		"LineHeight",
		"Position",
		"RichText",
		"Rotation",
		"Selectable",
		"Size",
		"SizeConstraint",
		"Text",
		"TextColor3",
		"TextScaled",
		"TextSize",
		"TextStrokeColor3",
		"TextStrokeTransparency",
		"TextTransparency",
		"TextTruncate",
		"TextWrapped",
		"TextXAlignment",
		"TextYAlignment",
		"Visible",
		"ZIndex",
	},

	TextButton = {
		"Active",
		"AnchorPoint",
		"AutoButtonColor",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"ClipsDescendants",
		"Font",
		"LayoutOrder",
		"LineHeight",
		"Modal",
		"Position",
		"RichText",
		"Rotation",
		"Selectable",
		"Selected",
		"Size",
		"SizeConstraint",
		"Style",
		"Text",
		"TextColor3",
		"TextScaled",
		"TextSize",
		"TextStrokeColor3",
		"TextStrokeTransparency",
		"TextTransparency",
		"TextTruncate",
		"TextWrapped",
		"TextXAlignment",
		"TextYAlignment",
		"Visible",
		"ZIndex",
	},

	ImageLabel = {
		"Active",
		"AnchorPoint",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"ClipsDescendants",
		"Image",
		"ImageColor3",
		"ImageRectOffset",
		"ImageRectSize",
		"ImageTransparency",
		"LayoutOrder",
		"Position",
		"ResampleMode",
		"Rotation",
		"ScaleType",
		"Selectable",
		"Size",
		"SizeConstraint",
		"SliceCenter",
		"SliceScale",
		"TileSize",
		"Visible",
		"ZIndex",
	},

	ImageButton = {
		"Active",
		"AnchorPoint",
		"AutoButtonColor",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"ClipsDescendants",
		"Image",
		"ImageColor3",
		"ImageRectOffset",
		"ImageRectSize",
		"ImageTransparency",
		"LayoutOrder",
		"Modal",
		"Position",
		"ResampleMode",
		"Rotation",
		"ScaleType",
		"Selectable",
		"Selected",
		"Size",
		"SizeConstraint",
		"SliceCenter",
		"SliceScale",
		"Style",
		"TileSize",
		"Visible",
		"ZIndex",
	},

	ScrollingFrame = {
		"Active",
		"AnchorPoint",
		"AutomaticCanvasSize",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"BottomImage",
		"CanvasPosition",
		"CanvasSize",
		"ClipsDescendants",
		"ElasticBehavior",
		"HorizontalScrollBarInset",
		"LayoutOrder",
		"MidImage",
		"Position",
		"Rotation",
		"ScrollBarImageColor3",
		"ScrollBarImageTransparency",
		"ScrollBarThickness",
		"ScrollingDirection",
		"ScrollingEnabled",
		"Selectable",
		"Size",
		"SizeConstraint",
		"TopImage",
		"VerticalScrollBarInset",
		"VerticalScrollBarPosition",
		"Visible",
		"ZIndex",
	},

	CanvasGroup = {
		"Active",
		"AnchorPoint",
		"AutomaticSize",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"GroupColor3",
		"GroupTransparency",
		"LayoutOrder",
		"Position",
		"Rotation",
		"Selectable",
		"Size",
		"SizeConstraint",
		"Visible",
		"ZIndex",
	},

	VideoFrame = {
		"Active",
		"AnchorPoint",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"LayoutOrder",
		"Looped",
		"Playing",
		"Position",
		"Resolution",
		"Rotation",
		"Size",
		"SizeConstraint",
		"TimePosition",
		"Video",
		"Visible",
		"Volume",
		"ZIndex",
	},

	ViewportFrame = {
		"Active",
		"Ambient",
		"AnchorPoint",
		"BackgroundColor3",
		"BackgroundTransparency",
		"BorderColor3",
		"BorderMode",
		"BorderSizePixel",
		"CurrentCamera",
		"ImageColor3",
		"ImageTransparency",
		"LightColor",
		"LightDirection",
		"Position",
		"Rotation",
		"Size",
		"Visible",
		"ZIndex",
	},

	UICorner = {
		"CornerRadius",
	},

	UIStroke = {
		"ApplyStrokeMode",
		"Color",
		"Enabled",
		"LineJoinMode",
		"Thickness",
		"Transparency",
	},

	UIGradient = {
		"Color",
		"Enabled",
		"Offset",
		"Rotation",
		"Transparency",
	},

	UIListLayout = {
		"FillDirection",
		"HorizontalAlignment",
		"Padding",
		"SortOrder",
		"VerticalAlignment",
	},

	UIGridLayout = {
		"CellPadding",
		"CellSize",
		"FillDirection",
		"HorizontalAlignment",
		"SortOrder",
		"StartCorner",
		"VerticalAlignment",
	},

	UIAspectRatioConstraint = {
		"AspectRatio",
		"AspectType",
		"DominantAxis",
	},

	UIScale = {
		"Scale",
	},

	UITextSizeConstraint = {
		"MaxTextSize",
		"MinTextSize",
	},

	UIPadding = {
		"PaddingBottom",
		"PaddingLeft",
		"PaddingRight",
		"PaddingTop",
	},

	Script = {
		"Disabled",
		"Enabled",
		"LinkedSource",
		"RunContext",
		"Source",
	},

	LocalScript = {
		"Disabled",
		"Enabled",
		"LinkedSource",
		"RunContext",
		"Source",
	},

	ModuleScript = {
		"LinkedSource",
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
	"CollisionGroup",
	"Massless",
	"Locked",
	"MaterialVariant",
	"PivotOffset",
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
	ColorMap = true,
	CursorIcon = true,
	Graphic = true,
	MeshId = true,
	MeshID = true,
	MeshContent = true,
	MetalnessMap = true,
	MoonTextureId = true,
	NormalMap = true,
	PantsTemplate = true,
	RoughnessMap = true,
	ShirtTemplate = true,
	SkyboxBk = true,
	SkyboxDn = true,
	SkyboxFt = true,
	SkyboxLf = true,
	SkyboxRt = true,
	SkyboxUp = true,
	SoundId = true,
	SunTextureId = true,
	Texture = true,
	TextureID = true,
	TextureId = true,
	TextureContent = true,
	LinkedSource = true,
	Video = true,
	Image = true,
}

local CONTENT_PROPERTY_NAMES = {
	AnimationId = true,
	ColorMap = true,
	CursorIcon = true,
	Graphic = true,
	Image = true,
	LinkedSource = true,
	MeshId = true,
	MeshID = true,
	MeshContent = true,
	MetalnessMap = true,
	MoonTextureId = true,
	NormalMap = true,
	PantsTemplate = true,
	RoughnessMap = true,
	ShirtTemplate = true,
	SkyboxBk = true,
	SkyboxDn = true,
	SkyboxFt = true,
	SkyboxLf = true,
	SkyboxRt = true,
	SkyboxUp = true,
	SoundId = true,
	SunTextureId = true,
	Texture = true,
	TextureID = true,
	TextureId = true,
	TextureContent = true,
	Video = true,
}

local PROPERTY_ALIASES = {
	MeshId = { "MeshID", "MeshContent" },
	MeshID = { "MeshId", "MeshContent" },
	MeshContent = { "MeshId", "MeshID" },
	TextureID = { "TextureId", "TextureContent" },
	TextureId = { "TextureID", "TextureContent" },
	TextureContent = { "TextureID", "TextureId" },
}

local DEFAULT_INSTANCE_CACHE = {}
local HIDDEN_PROPERTY_READER
local HIDDEN_PROPERTY_READER_CHECKED = false

local function copyDefaults()
	local options = {
		IncludeScripts = DEFAULT_OPTIONS.IncludeScripts,
		SaveAssets = DEFAULT_OPTIONS.SaveAssets,
		SaveTerrain = DEFAULT_OPTIONS.SaveTerrain,
		SaveAttributes = DEFAULT_OPTIONS.SaveAttributes,
		SaveTags = DEFAULT_OPTIONS.SaveTags,
		SaveHiddenProperties = DEFAULT_OPTIONS.SaveHiddenProperties,
		DecompileScripts = DEFAULT_OPTIONS.DecompileScripts,
		UseByteFallDecompiler = DEFAULT_OPTIONS.UseByteFallDecompiler,
		ByteFallEndpoint = DEFAULT_OPTIONS.ByteFallEndpoint,
		FallbackToSystemDecompiler = DEFAULT_OPTIONS.FallbackToSystemDecompiler,
		DecompilerTimeout = DEFAULT_OPTIONS.DecompilerTimeout,
		RobloxLikeReferents = DEFAULT_OPTIONS.RobloxLikeReferents,
		UseApiDump = DEFAULT_OPTIONS.UseApiDump,
		ApiDumpUrl = DEFAULT_OPTIONS.ApiDumpUrl,
		SaveInternalIds = DEFAULT_OPTIONS.SaveInternalIds,
		UseSharedStrings = DEFAULT_OPTIONS.UseSharedStrings,
		SharedStringMinBytes = DEFAULT_OPTIONS.SharedStringMinBytes,
		Diagnostics = DEFAULT_OPTIONS.Diagnostics,
		ShowStatus = DEFAULT_OPTIONS.ShowStatus,
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

	if userOptions.SaveAttributes ~= nil then
		options.SaveAttributes = userOptions.SaveAttributes == true
	end

	if userOptions.SaveTags ~= nil then
		options.SaveTags = userOptions.SaveTags == true
	end

	if userOptions.SaveHiddenProperties ~= nil then
		options.SaveHiddenProperties = userOptions.SaveHiddenProperties == true
	end

	if userOptions.DecompileScripts ~= nil then
		options.DecompileScripts = userOptions.DecompileScripts == true
	end

	if userOptions.UseByteFallDecompiler ~= nil then
		options.UseByteFallDecompiler = userOptions.UseByteFallDecompiler == true
	end

	if type(userOptions.ByteFallEndpoint) == "string" and userOptions.ByteFallEndpoint ~= "" then
		options.ByteFallEndpoint = userOptions.ByteFallEndpoint
	end

	if userOptions.FallbackToSystemDecompiler ~= nil then
		options.FallbackToSystemDecompiler = userOptions.FallbackToSystemDecompiler == true
	end

	if type(userOptions.DecompilerTimeout) == "number" and userOptions.DecompilerTimeout > 0 then
		options.DecompilerTimeout = userOptions.DecompilerTimeout
	end

	if userOptions.RobloxLikeReferents ~= nil then
		options.RobloxLikeReferents = userOptions.RobloxLikeReferents == true
	end

	if userOptions.UseApiDump ~= nil then
		options.UseApiDump = userOptions.UseApiDump == true
	end

	if type(userOptions.ApiDumpUrl) == "string" and userOptions.ApiDumpUrl ~= "" then
		options.ApiDumpUrl = userOptions.ApiDumpUrl
	end

	if userOptions.SaveInternalIds ~= nil then
		options.SaveInternalIds = userOptions.SaveInternalIds == true
	end

	if userOptions.UseSharedStrings ~= nil then
		options.UseSharedStrings = userOptions.UseSharedStrings == true
	end

	if type(userOptions.SharedStringMinBytes) == "number" and userOptions.SharedStringMinBytes > 0 then
		options.SharedStringMinBytes = math.floor(userOptions.SharedStringMinBytes)
	end

	if userOptions.Diagnostics ~= nil then
		options.Diagnostics = userOptions.Diagnostics == true
	end

	if userOptions.ShowStatus ~= nil then
		options.ShowStatus = userOptions.ShowStatus == true
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

local recordDiagnostic
local API_DUMP_CACHE = nil

local INTERNAL_PROPERTY_NAMES = {
	HistoryId = true,
	UniqueId = true,
	SourceAssetId = true,
	RobloxLocked = true,
}

local function isUnsafeApiProperty(member)
	if type(member) ~= "table" or member.MemberType ~= "Property" then
		return true
	end

	if type(member.Name) ~= "string" or member.Name == "Source" then
		return true
	end

	local tags = member.Tags

	if type(tags) == "table" then
		for _, tag in ipairs(tags) do
			if tag == "Hidden" or tag == "Deprecated" or tag == "NotScriptable" or tag == "ReadOnly" then
				return true
			end
		end
	end

	return false
end

local function getHttpService()
	local ok, service = pcall(function()
		return game:GetService("HttpService")
	end)

	if ok then
		return service
	end

	return nil
end

local function fetchUrl(url)
	local request = getCallableGlobal("request") or getCallableGlobal("http_request") or getCallableGlobal("httpRequest")

	if not request then
		local okSyn, synTable = pcall(function()
			return syn
		end)

		if okSyn and type(synTable) == "table" and type(synTable.request) == "function" then
			request = synTable.request
		end
	end

	if not request then
		local okFluxus, fluxusTable = pcall(function()
			return fluxus
		end)

		if okFluxus and type(fluxusTable) == "table" and type(fluxusTable.request) == "function" then
			request = fluxusTable.request
		end
	end

	if not request then
		local okHttp, httpTable = pcall(function()
			return http
		end)

		if okHttp and type(httpTable) == "table" and type(httpTable.request) == "function" then
			request = httpTable.request
		end
	end

	if request then
		local ok, response = pcall(request, {
			Url = url,
			Method = "GET",
		})

		if ok then
			if type(response) == "string" then
				return response
			end

			if type(response) == "table" then
				local status = response.StatusCode or response.Status or response.status_code or response.status

				if type(status) == "number" and (status < 200 or status >= 300) then
					return nil, "HTTP " .. tostring(status)
				end

				return response.Body or response.body or response.Data or response.data
			end
		end

		return nil, tostring(response)
	end

	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)

	if ok and type(body) == "string" then
		return body
	end

	return nil, tostring(body)
end

local function loadApiDump(options)
	if not options.UseApiDump then
		return nil
	end

	if API_DUMP_CACHE then
		if options.Diagnostics and options._Diagnostics then
			local classCount = 0
			local propertyCount = 0

			for _, classInfo in pairs(API_DUMP_CACHE) do
				classCount += 1
				propertyCount += #(classInfo.Properties or {})
			end

			options._Diagnostics.ApiDump.Enabled = true
			options._Diagnostics.ApiDump.Loaded = true
			options._Diagnostics.ApiDump.Error = nil
			options._Diagnostics.ApiDump.ClassCount = classCount
			options._Diagnostics.ApiDump.PropertyCount = propertyCount
		end

		return API_DUMP_CACHE
	end

	local body, fetchErr = fetchUrl(options.ApiDumpUrl)

	if not body then
		recordDiagnostic(options, "api_error", fetchErr)
		return nil
	end

	local httpService = getHttpService()

	if not httpService then
		recordDiagnostic(options, "api_error", "HttpService is unavailable")
		return nil
	end

	local okDecode, decoded = pcall(function()
		return httpService:JSONDecode(body)
	end)

	if not okDecode or type(decoded) ~= "table" or type(decoded.Classes) ~= "table" then
		recordDiagnostic(options, "api_error", okDecode and "invalid API dump shape" or decoded)
		return nil
	end

	local classCache = {}
	local classCount = 0
	local propertyCount = 0

	for _, class in ipairs(decoded.Classes) do
		if type(class) == "table" and type(class.Name) == "string" then
			classCount += 1
			local properties = {}

			for _, member in ipairs(class.Members or {}) do
				if not isUnsafeApiProperty(member) then
					table.insert(properties, member.Name)
					propertyCount += 1
				end
			end

			classCache[class.Name] = {
				Superclass = class.Superclass,
				Properties = properties,
			}
		end
	end

	API_DUMP_CACHE = classCache

	if options.Diagnostics then
		options._Diagnostics = options._Diagnostics or {
			ApiDump = {},
			PropertiesWritten = 0,
			PropertiesIgnored = 0,
			Errors = {},
		}
		options._Diagnostics.ApiDump.Enabled = true
		options._Diagnostics.ApiDump.Loaded = true
		options._Diagnostics.ApiDump.Error = nil
		options._Diagnostics.ApiDump.ClassCount = classCount
		options._Diagnostics.ApiDump.PropertyCount = propertyCount
	end

	return classCache
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

local function appendContent(lines, level, name, value)
	local text = tostring(value or "")

	if text == "" then
		return false
	end

	table.insert(lines, string.format("%s<Content name=\"%s\">", indent(level), xmlEscape(name)))
	table.insert(lines, string.format("%s<url>%s</url>", indent(level + 1), xmlEscape(text)))
	table.insert(lines, string.format("%s</Content>", indent(level)))
	return true
end

local function getSharedStringId(options, encodedValue)
	options._SharedStrings = options._SharedStrings or {}
	options._SharedStringOrder = options._SharedStringOrder or {}

	local existing = options._SharedStrings[encodedValue]

	if existing then
		return existing
	end

	local id = encodeBase64("DE_SHARED_" .. tostring(#options._SharedStringOrder + 1))
	options._SharedStrings[encodedValue] = id
	table.insert(options._SharedStringOrder, {
		Id = id,
		Value = encodedValue,
	})

	return id
end

local function appendBinaryString(lines, level, name, value, options)
	local encoded, err = encodeBase64(value)

	if not encoded then
		return false, err
	end

	if options and options.UseSharedStrings and #value >= options.SharedStringMinBytes then
		appendSimpleXml(lines, level, "SharedString", name, getSharedStringId(options, encoded))
		return true
	end

	appendSimpleXml(lines, level, "BinaryString", name, encoded)
	return true
end

local function packAttributeValue(value)
	local valueType = typeof(value)

	if valueType == "string" then
		return "string", value
	elseif valueType == "boolean" then
		return "boolean", value and "true" or "false"
	elseif valueType == "number" then
		return "number", formatNumber(value)
	elseif valueType == "UDim" then
		return "UDim", table.concat({ formatNumber(value.Scale), tostring(value.Offset) }, ",")
	elseif valueType == "UDim2" then
		return "UDim2", table.concat({
			formatNumber(value.X.Scale),
			tostring(value.X.Offset),
			formatNumber(value.Y.Scale),
			tostring(value.Y.Offset),
		}, ",")
	elseif valueType == "BrickColor" then
		return "BrickColor", tostring(value.Number)
	elseif valueType == "Color3" then
		return "Color3", table.concat({
			formatNumber(value.R),
			formatNumber(value.G),
			formatNumber(value.B),
		}, ",")
	elseif valueType == "Vector2" then
		return "Vector2", table.concat({ formatNumber(value.X), formatNumber(value.Y) }, ",")
	elseif valueType == "Vector3" then
		return "Vector3", table.concat({ formatNumber(value.X), formatNumber(value.Y), formatNumber(value.Z) }, ",")
	elseif valueType == "CFrame" then
		local components = { value:GetComponents() }

		for index, component in ipairs(components) do
			components[index] = formatNumber(component)
		end

		return "CFrame", table.concat(components, ",")
	elseif valueType == "EnumItem" then
		return "EnumItem", tostring(value.EnumType) .. ":" .. value.Name .. ":" .. tostring(value.Value)
	elseif valueType == "NumberRange" then
		return "NumberRange", table.concat({ formatNumber(value.Min), formatNumber(value.Max) }, ",")
	elseif valueType == "NumberSequence" then
		local keypoints = {}

		for _, keypoint in ipairs(value.Keypoints) do
			table.insert(keypoints, table.concat({
				formatNumber(keypoint.Time),
				formatNumber(keypoint.Value),
				formatNumber(keypoint.Envelope),
			}, ","))
		end

		return "NumberSequence", table.concat(keypoints, ";")
	elseif valueType == "ColorSequence" then
		local keypoints = {}

		for _, keypoint in ipairs(value.Keypoints) do
			table.insert(keypoints, table.concat({
				formatNumber(keypoint.Time),
				formatNumber(keypoint.Value.R),
				formatNumber(keypoint.Value.G),
				formatNumber(keypoint.Value.B),
			}, ","))
		end

		return "ColorSequence", table.concat(keypoints, ";")
	end

	return nil
end

local function packKeyValueBinary(header, values)
	local lines = { header }
	local keys = {}

	for key in pairs(values) do
		table.insert(keys, key)
	end

	table.sort(keys)

	for _, key in ipairs(keys) do
		local valueType, packed = packAttributeValue(values[key])

		if valueType then
			table.insert(lines, table.concat({
				tostring(#key),
				key,
				valueType,
				tostring(#packed),
				packed,
			}, "\t"))
		end
	end

	return table.concat(lines, "\n")
end

local function appendAttributes(lines, level, instance, options)
	if not options.SaveAttributes then
		return
	end

	local ok, attributes = pcall(function()
		return instance:GetAttributes()
	end)

	if not ok or type(attributes) ~= "table" or next(attributes) == nil then
		return
	end

	appendBinaryString(lines, level, "AttributesSerialize", packKeyValueBinary("DE_ATTRIBUTES_V1", attributes))
end

local function appendTags(lines, level, instance, options)
	if not options.SaveTags then
		return
	end

	local okService, collectionService = pcall(function()
		return game:GetService("CollectionService")
	end)

	if not okService or not collectionService then
		return
	end

	local okTags, tags = pcall(function()
		return collectionService:GetTags(instance)
	end)

	if not okTags or type(tags) ~= "table" or #tags == 0 then
		return
	end

	table.sort(tags)
	appendBinaryString(lines, level, "Tags", "DE_TAGS_V1\n" .. table.concat(tags, "\n"))
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

local function appendRect(lines, level, name, value)
	table.insert(lines, string.format("%s<Rect name=\"%s\">", indent(level), xmlEscape(name)))
	appendVector2(lines, level + 1, "min", "Min", value.Min)
	appendVector2(lines, level + 1, "max", "Max", value.Max)
	table.insert(lines, string.format("%s</Rect>", indent(level)))
end

local function appendRay(lines, level, name, value)
	table.insert(lines, string.format("%s<Ray name=\"%s\">", indent(level), xmlEscape(name)))
	appendVector3(lines, level + 1, "origin", "Origin", value.Origin)
	appendVector3(lines, level + 1, "direction", "Direction", value.Direction)
	table.insert(lines, string.format("%s</Ray>", indent(level)))
end

local function appendFaces(lines, level, name, value)
	table.insert(lines, string.format("%s<Faces name=\"%s\">", indent(level), xmlEscape(name)))
	for _, face in ipairs({ "Top", "Bottom", "Left", "Right", "Front", "Back" }) do
		local ok, enabled = pcall(function()
			return value[face]
		end)
		table.insert(lines, string.format("%s<%s>%s</%s>", indent(level + 1), face, ok and enabled and "true" or "false", face))
	end
	table.insert(lines, string.format("%s</Faces>", indent(level)))
end

local function appendAxes(lines, level, name, value)
	table.insert(lines, string.format("%s<Axes name=\"%s\">", indent(level), xmlEscape(name)))
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local ok, enabled = pcall(function()
			return value[axis]
		end)
		table.insert(lines, string.format("%s<%s>%s</%s>", indent(level + 1), axis, ok and enabled and "true" or "false", axis))
	end
	table.insert(lines, string.format("%s</Axes>", indent(level)))
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
		if CONTENT_PROPERTY_NAMES[name] then
			return appendContent(lines, level, name, value)
		else
			appendSimpleXml(lines, level, "string", name, value)
		end
	elseif valueType == "number" then
		appendSimpleXml(lines, level, "float", name, formatNumber(value))
	elseif valueType == "boolean" then
		appendSimpleXml(lines, level, "bool", name, value and "true" or "false")
	elseif valueType == "Vector2" then
		appendVector2(lines, level, "Vector2", name, value)
	elseif valueType == "Vector3" then
		appendVector3(lines, level, "Vector3", name, value)
	elseif valueType == "Vector2int16" then
		appendVector2(lines, level, "Vector2int16", name, value)
	elseif valueType == "Vector3int16" then
		appendVector3(lines, level, "Vector3int16", name, value)
	elseif valueType == "Color3" then
		appendColor3(lines, level, name, value)
	elseif valueType == "BrickColor" then
		appendBrickColor(lines, level, name, value)
	elseif valueType == "CFrame" then
		appendCFrame(lines, level, name, value)
	elseif valueType == "Rect" then
		appendRect(lines, level, name, value)
	elseif valueType == "Ray" then
		appendRay(lines, level, name, value)
	elseif valueType == "Faces" then
		appendFaces(lines, level, name, value)
	elseif valueType == "Axes" then
		appendAxes(lines, level, name, value)
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
	elseif valueType == "Font" then
		appendSimpleXml(lines, level, "Font", name, tostring(value))
	elseif valueType == "Content" then
		return appendContent(lines, level, name, value)
	elseif valueType == "SecurityCapabilities" then
		appendSimpleXml(lines, level, "SecurityCapabilities", name, tostring(value))
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

local function markWrittenProperty(writtenProperties, propertyName)
	writtenProperties[propertyName] = true

	for _, alias in ipairs(PROPERTY_ALIASES[propertyName] or {}) do
		writtenProperties[alias] = true
	end
end

local function report(options, message, progress)
	if type(options.Callback) == "function" then
		pcall(options.Callback, message, progress)
	end

	if options.ShowStatus then
		local suffix = type(progress) == "number" and (" " .. tostring(math.floor(progress * 100)) .. "%") or ""
		warn("[D.E save] " .. tostring(message) .. suffix)
	end
end

recordDiagnostic = function(options, bucket, message)
	if not options.Diagnostics then
		return
	end

	options._Diagnostics = options._Diagnostics or {
		ApiDump = {
			Enabled = options.UseApiDump == true,
			Loaded = false,
			Error = nil,
			ClassCount = 0,
			PropertyCount = 0,
		},
		PropertiesWritten = 0,
		PropertiesIgnored = 0,
		Errors = {},
	}

	if bucket == "error" then
		local text = tostring(message)

		for _, existing in ipairs(options._Diagnostics.Errors) do
			if existing == text then
				return
			end
		end

		table.insert(options._Diagnostics.Errors, text)
	elseif bucket == "written" then
		options._Diagnostics.PropertiesWritten += 1
	elseif bucket == "ignored" then
		options._Diagnostics.PropertiesIgnored += 1
	elseif bucket == "api_error" then
		options._Diagnostics.ApiDump.Error = tostring(message)
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
	if HIDDEN_PROPERTY_READER_CHECKED then
		return HIDDEN_PROPERTY_READER
	end

	HIDDEN_PROPERTY_READER_CHECKED = true

	local direct = getCallableGlobal("gethiddenproperty") or getCallableGlobal("get_hidden_property")

	local okDebug, debugTable = pcall(function()
		return debug
	end)

	if not direct and okDebug and type(debugTable) == "table" and type(debugTable.gethiddenproperty) == "function" then
		direct = debugTable.gethiddenproperty
	end

	if not direct then
		return nil
	end

	local okWorkspace = pcall(direct, workspace, "Gravity")
	local okTerrain = false

	pcall(function()
		okTerrain = pcall(direct, workspace.Terrain, "SmoothGrid")
	end)

	if okWorkspace or okTerrain then
		HIDDEN_PROPERTY_READER = direct
	end

	return HIDDEN_PROPERTY_READER
end

local function appendUniqueError(errors, message)
	if not errors then
		return
	end

	for _, existing in ipairs(errors) do
		if existing == message then
			return
		end
	end

	table.insert(errors, message)
end

local function getExecutorRequestFunction()
	local directRequest = getCallableGlobal("request")
		or getCallableGlobal("http_request")
		or getCallableGlobal("httpRequest")

	if directRequest then
		return directRequest
	end

	local okSyn, synTable = pcall(function()
		return syn
	end)

	if okSyn and type(synTable) == "table" and type(synTable.request) == "function" then
		return synTable.request
	end

	local okFluxus, fluxusTable = pcall(function()
		return fluxus
	end)

	if okFluxus and type(fluxusTable) == "table" and type(fluxusTable.request) == "function" then
		return fluxusTable.request
	end

	local okHttp, httpTable = pcall(function()
		return http
	end)

	if okHttp and type(httpTable) == "table" and type(httpTable.request) == "function" then
		return httpTable.request
	end

	return nil
end

local function getResponseBody(response)
	if type(response) == "string" then
		return response
	end

	if type(response) ~= "table" then
		return nil
	end

	return response.Body or response.body or response.Data or response.data
end

local function getResponseStatus(response)
	if type(response) ~= "table" then
		return 200
	end

	return response.StatusCode or response.Status or response.status_code or response.status or 0
end

local function jsonEscape(value)
	value = tostring(value)
	value = value:gsub("\\", "\\\\")
	value = value:gsub("\"", "\\\"")
	value = value:gsub(string.char(8), "\\b")
	value = value:gsub(string.char(12), "\\f")
	value = value:gsub("\n", "\\n")
	value = value:gsub("\r", "\\r")
	value = value:gsub("\t", "\\t")
	return value
end

local function getScriptBytecodeFunction()
	return getCallableGlobal("getscriptbytecode")
end

local function getSystemDecompilerFunction()
	return getCallableGlobal("decompile")
end

local function decompileWithSystem(scriptInstance)
	local systemDecompiler = getSystemDecompilerFunction()

	if not systemDecompiler then
		return nil, "system decompiler is not available"
	end

	local ok, source = pcall(systemDecompiler, scriptInstance)

	if ok and type(source) == "string" and source ~= "" then
		return source
	end

	return nil, ok and "system decompiler returned empty source" or tostring(source)
end

local function decompileWithByteFall(scriptInstance, options)
	local getscriptbytecode = getScriptBytecodeFunction()

	if not getscriptbytecode then
		return nil, "getscriptbytecode is not available"
	end

	local okBytecode, bytecode = pcall(getscriptbytecode, scriptInstance)

	if not okBytecode then
		return nil, "getscriptbytecode failed: " .. tostring(bytecode)
	end

	if type(bytecode) ~= "string" or bytecode == "" then
		return nil, "getscriptbytecode returned empty"
	end

	local request = getExecutorRequestFunction()

	if not request then
		return nil, "no http request function available"
	end

	local encoded = encodeBase64(bytecode)
	local body = "{\"script\":\"" .. jsonEscape(encoded) .. "\"}"
	local okRequest, response = pcall(request, {
		Url = options.ByteFallEndpoint,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
		},
		Body = body,
		Timeout = options.DecompilerTimeout,
	})

	if not okRequest then
		return nil, "ByteFall request failed: " .. tostring(response)
	end

	local status = getResponseStatus(response)
	local responseBody = getResponseBody(response) or ""

	if status == 200 and responseBody ~= "" then
		return responseBody
	end

	if status == 400 then
		return nil, "ByteFall 400 bad request: " .. tostring(responseBody)
	elseif status == 404 then
		return nil, "ByteFall 404 not found"
	elseif status == 500 then
		return nil, "ByteFall 500 decompilation failed: " .. tostring(responseBody)
	end

	return nil, "ByteFall HTTP " .. tostring(status) .. ": " .. tostring(responseBody)
end

local function decompileScriptSource(scriptInstance, options)
	if not options.DecompileScripts then
		return ""
	end

	local errors = options._DecompilerErrors

	if options.UseByteFallDecompiler then
		local source, err = decompileWithByteFall(scriptInstance, options)

		if source then
			return source
		end

		appendUniqueError(errors, scriptInstance:GetFullName() .. ": " .. tostring(err))

		if not options.FallbackToSystemDecompiler then
			return "-- ByteFall: " .. tostring(err)
		end
	end

	if options.FallbackToSystemDecompiler then
		local source, err = decompileWithSystem(scriptInstance)

		if source then
			return source
		end

		appendUniqueError(errors, scriptInstance:GetFullName() .. ": " .. tostring(err))
		return "-- D.E save decompiler failed: " .. tostring(err)
	end

	return "-- D.E save decompiler disabled or unavailable"
end

local function appendHiddenBinaryProperty(lines, level, instance, propertyName, errors, options)
	local gethiddenproperty = getHiddenPropertyReader()

	if not gethiddenproperty then
		appendUniqueError(errors, "executor does not provide gethiddenproperty")
		return false
	end

	local okRead, value = pcall(gethiddenproperty, instance, propertyName)

	if not okRead then
		appendUniqueError(errors, propertyName .. ": " .. tostring(value))
		return false
	end

	if type(value) ~= "string" then
		if value ~= nil then
			appendUniqueError(errors, propertyName .. ": expected string, got " .. typeof(value))
		end

		return false
	end

	local okWrite, writeErr = appendBinaryString(lines, level, propertyName, value, options)

	if not okWrite then
		appendUniqueError(errors, propertyName .. ": " .. tostring(writeErr))
	end

	return okWrite
end

local function appendHiddenContentProperty(lines, level, instance, propertyName, errors)
	local gethiddenproperty = getHiddenPropertyReader()

	if not gethiddenproperty then
		appendUniqueError(errors, "executor does not provide gethiddenproperty")
		return false
	end

	local okRead, value = pcall(gethiddenproperty, instance, propertyName)

	if not okRead then
		return false
	end

	if typeof(value) == "Content" or type(value) == "string" then
		return appendContent(lines, level, propertyName, value)
	end

	return false
end

local HIDDEN_MESH_BINARY_PROPERTIES = {
	MeshPart = {
		"MeshData",
		"PhysicsData",
		"SerializedMeshData",
		"TriangleMeshData",
	},

	UnionOperation = {
		"ChildData",
		"MeshData",
		"PhysicsData",
		"SerializedMeshData",
		"TriangleMeshData",
	},

	NegateOperation = {
		"ChildData",
		"MeshData",
		"PhysicsData",
		"SerializedMeshData",
		"TriangleMeshData",
	},

	PartOperation = {
		"ChildData",
		"MeshData",
		"PhysicsData",
		"SerializedMeshData",
		"TriangleMeshData",
	},
}

local HIDDEN_MESH_CONTENT_PROPERTIES = {
	MeshPart = {
		"MeshId",
		"MeshID",
		"MeshContent",
		"TextureID",
		"TextureId",
		"TextureContent",
	},

	SpecialMesh = {
		"MeshId",
		"MeshID",
		"TextureId",
		"TextureID",
	},

	FileMesh = {
		"MeshId",
		"MeshID",
		"TextureId",
		"TextureID",
	},
}

local function appendApiDumpProperties(list, seen, className, classCache, options)
	local visited = {}
	local current = className

	while current and not visited[current] do
		visited[current] = true
		local classInfo = classCache[current]

		if not classInfo then
			break
		end

		for _, propertyName in ipairs(classInfo.Properties or {}) do
			if options.SaveInternalIds or not INTERNAL_PROPERTY_NAMES[propertyName] then
				appendPropertyName(list, seen, propertyName)
			end
		end

		current = classInfo.Superclass
	end
end

local function getPropertiesFor(instance, options)
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

	if options and options._ApiDumpClassCache then
		appendApiDumpProperties(properties, seen, instance.ClassName, options._ApiDumpClassCache, options)
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

local function makeRobloxLikeReferent(index)
	local seed = (index * 1103515245 + 12345) % 0x100000000
	local parts = {}

	for offset = 1, 32 do
		seed = (seed * 1664525 + 1013904223 + offset) % 0x100000000
		local nibble = seed % 16
		parts[offset] = string.format("%X", nibble)
	end

	return "RBX" .. table.concat(parts)
end

local function buildReferences(instances, options)
	local references = {}

	for index, instance in ipairs(instances) do
		if options.RobloxLikeReferents then
			references[instance] = makeRobloxLikeReferent(index)
		else
			references[instance] = "RBX" .. tostring(index)
		end
	end

	return references
end

local function appendProperties(lines, level, instance, references, options)
	table.insert(lines, string.format("%s<Properties>", indent(level)))
	local writtenProperties = {}

	for _, propertyName in ipairs(getPropertiesFor(instance, options)) do
		if isScriptClass(instance.ClassName) and propertyName == "Source" then
			appendSimpleXml(lines, level + 1, "ProtectedString", "Source", decompileScriptSource(instance, options))
			markWrittenProperty(writtenProperties, propertyName)
			recordDiagnostic(options, "written")
		else
			local ok, value = pcall(function()
				return instance[propertyName]
			end)

			if ok and (not options.IgnoreDefaultProperties or not isDefaultProperty(instance, propertyName, value)) then
				local wrote = appendProperty(lines, level + 1, propertyName, value, references)

				if wrote then
					markWrittenProperty(writtenProperties, propertyName)
					recordDiagnostic(options, "written")
				else
					recordDiagnostic(options, "ignored")
				end
			elseif not ok then
				recordDiagnostic(options, "ignored")
			else
				recordDiagnostic(options, "ignored")
			end
		end
	end

	appendAttributes(lines, level + 1, instance, options)
	appendTags(lines, level + 1, instance, options)

	if options.SaveTerrain and options.SaveHiddenProperties and instance:IsA("Terrain") then
		local terrainErrors = options._TerrainErrors

		appendHiddenBinaryProperty(lines, level + 1, instance, "SmoothGrid", terrainErrors, options)
		appendHiddenBinaryProperty(lines, level + 1, instance, "PhysicsGrid", terrainErrors, options)
	end

	local hiddenMeshProperties = HIDDEN_MESH_BINARY_PROPERTIES[instance.ClassName]

	if options.SaveHiddenProperties and hiddenMeshProperties then
		for _, propertyName in ipairs(hiddenMeshProperties) do
			appendHiddenBinaryProperty(lines, level + 1, instance, propertyName, options._HiddenErrors, options)
		end
	end

	local hiddenMeshContentProperties = HIDDEN_MESH_CONTENT_PROPERTIES[instance.ClassName]

	if options.SaveHiddenProperties and hiddenMeshContentProperties then
		for _, propertyName in ipairs(hiddenMeshContentProperties) do
			if not writtenProperties[propertyName] and appendHiddenContentProperty(lines, level + 1, instance, propertyName, options._HiddenErrors) then
				markWrittenProperty(writtenProperties, propertyName)
				recordDiagnostic(options, "written")
			end
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

local function getExecutorName()
	local identify = getCallableGlobal("identifyexecutor")
		or getCallableGlobal("getexecutorname")
		or getCallableGlobal("whatexecutor")

	if identify then
		local ok, name, versionText = pcall(identify)

		if ok and name then
			if versionText then
				return tostring(name) .. " " .. tostring(versionText)
			end

			return tostring(name)
		end
	end

	return "UNKNOWN"
end

local function getGameField(name)
	local ok, value = pcall(function()
		return game[name]
	end)

	if ok and value ~= nil then
		return tostring(value)
	end

	return "UNKNOWN"
end

local function appendMetadata(lines, root, options, instanceCount)
	table.insert(lines, string.format("\t<Meta name=\"D.E save Root\">%s</Meta>", xmlEscape(root:GetFullName())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save InstanceCount\">%s</Meta>", tostring(instanceCount)))
	table.insert(lines, string.format("\t<Meta name=\"D.E save GeneratedAtUnix\">%s</Meta>", tostring(os.time())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save RobloxVersion\">%s</Meta>", xmlEscape(getRobloxVersion())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save Executor\">%s</Meta>", xmlEscape(getExecutorName())))
	table.insert(lines, string.format("\t<Meta name=\"D.E save PlaceId\">%s</Meta>", xmlEscape(getGameField("PlaceId"))))
	table.insert(lines, string.format("\t<Meta name=\"D.E save PlaceVersion\">%s</Meta>", xmlEscape(getGameField("PlaceVersion"))))
	table.insert(lines, string.format("\t<Meta name=\"D.E save IgnoreDefaultProperties\">%s</Meta>", options.IgnoreDefaultProperties and "true" or "false"))
	table.insert(lines, string.format("\t<Meta name=\"D.E save UseApiDump\">%s</Meta>", options.UseApiDump and "true" or "false"))
	table.insert(lines, string.format("\t<Meta name=\"D.E save UseSharedStrings\">%s</Meta>", options.UseSharedStrings and "true" or "false"))
	table.insert(lines, string.format("\t<Meta name=\"D.E save DecompileScripts\">%s</Meta>", options.DecompileScripts and "true" or "false"))
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

local function appendSharedStrings(lines, options)
	if not options.UseSharedStrings or not options._SharedStringOrder or #options._SharedStringOrder == 0 then
		return
	end

	table.insert(lines, "\t<SharedStrings>")

	for _, sharedString in ipairs(options._SharedStringOrder) do
		table.insert(lines, string.format(
			"\t\t<SharedString md5=\"%s\">%s</SharedString>",
			xmlEscape(sharedString.Id),
			xmlEscape(sharedString.Value)
		))
	end

	table.insert(lines, "\t</SharedStrings>")
end

local function buildDocument(root, options)
	local instances = {}
	options._Diagnostics = options.Diagnostics and {
		ApiDump = {
			Enabled = options.UseApiDump == true,
			Loaded = false,
			Error = nil,
			ClassCount = 0,
			PropertyCount = 0,
		},
		PropertiesWritten = 0,
		PropertiesIgnored = 0,
		Errors = {},
	} or nil
	options._ApiDumpClassCache = loadApiDump(options)
	options._SharedStrings = nil
	options._SharedStringOrder = nil
	options._TerrainErrors = {}
	options._HiddenErrors = {}
	options._DecompilerErrors = {}
	report(options, "Collecting instances", 0)
	collectInstances(root, options, instances, true)
	local sawTerrain = false

	for _, instance in ipairs(instances) do
		if instance:IsA("Terrain") then
			sawTerrain = true
			break
		end
	end

	local references = buildReferences(instances, options)
	local lines = {
		"<?xml version=\"1.0\" encoding=\"utf-8\"?>",
		"<roblox version=\"4\">",
		"\t<External>null</External>",
		"\t<External>nil</External>",
		"\t<Meta name=\"ExplicitAutoJoints\">true</Meta>",
	}

	appendMetadata(lines, root, options, #instances)
	report(options, "Serializing instances", 0.25)
	appendItem(lines, 1, root, options, references)
	appendReadMe(lines, 1, options, references)

	if options.SaveTerrain and not sawTerrain then
		table.insert(options._TerrainErrors, "terrain was not found under the selected root")
	end

	if options.SaveTerrain and not options.SaveHiddenProperties then
		table.insert(options._TerrainErrors, "SaveHiddenProperties must be enabled to embed SmoothGrid and PhysicsGrid")
	end

	appendSharedStrings(lines, options)
	if options._Diagnostics then
		options._Diagnostics.SharedStrings = options._SharedStringOrder and #options._SharedStringOrder or 0
	end
	table.insert(lines, "</roblox><!-- Saved by D.E save -->")
	report(options, "XML ready", 0.75)

	local terrainResult = {
		Embedded = options.SaveTerrain == true,
		Files = {},
		Errors = options._TerrainErrors,
	}
	local hiddenResult = {
		Enabled = options.SaveHiddenProperties == true,
		Errors = options._HiddenErrors,
	}
	local decompilerResult = {
		Enabled = options.DecompileScripts == true,
		UseByteFall = options.UseByteFallDecompiler == true,
		Errors = options._DecompilerErrors,
	}
	local diagnostics = options._Diagnostics
	options._TerrainErrors = nil
	options._HiddenErrors = nil
	options._DecompilerErrors = nil
	options._ApiDumpClassCache = nil
	options._SharedStrings = nil
	options._SharedStringOrder = nil
	options._Diagnostics = nil

	return table.concat(lines, "\n"), terrainResult, hiddenResult, decompilerResult, diagnostics
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
	if value == nil then
		return nil
	end

	value = tostring(value)

	if value == "" then
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
		for _, propertyName in ipairs(getPropertiesFor(instance, options)) do
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
	local xml = buildDocument(root, options)
	return xml
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

	local xml, terrainResult, hiddenResult, decompilerResult, diagnostics = buildDocument(root, options)
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

	for _, err in ipairs(hiddenResult.Errors) do
		table.insert(errors, err)
	end

	for _, err in ipairs(decompilerResult.Errors) do
		table.insert(errors, err)
	end

	report(options, "Done", 1)

	return {
		Ok = #errors == 0,
		Path = normalizedPath,
		Content = xml,
		Assets = assetResult.Assets,
		Terrain = terrainResult,
		HiddenProperties = hiddenResult,
		Decompiler = decompilerResult,
		Diagnostics = diagnostics,
		Errors = errors,
	}
end

setmetatable(SaveInstance, {
	__call = function(_, root, userOptions)
		return SaveInstance.SaveInstance(root, userOptions)
	end,
})

return SaveInstance

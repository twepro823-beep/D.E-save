# D.E save

Basic Roblox SaveInstance implementation written in Luau for executor environments.

## What it does

- Serializes a Roblox instance tree into a simple RBXLX-style XML string.
- Can save the generated `.rbxlx` file with executor APIs like `writefile`.
- Can optionally try to download referenced assets with `request`/`http_request`.
- Can embed Terrain `SmoothGrid` and `PhysicsGrid` data into the generated `.rbxlx` when the executor supports `gethiddenproperty`.
- Can preserve attributes and CollectionService tags in best-effort binary properties.
- Preserves asset references such as `MeshId`, `TextureID`, `SoundId`, `AnimationId`, `ShirtTemplate`, `PantsTemplate`, `Graphic`, and `Texture`.
- Can decompile `Script`, `LocalScript`, and `ModuleScript` sources through ByteFall by default, with optional fallback to the executor's `decompile`.
- Includes client-visible containers like `StarterGui`, `ReplicatedStorage`, and `ReplicatedFirst` by default.
- Supports progress callbacks, segmented writing with `appendfile`, simple metadata, filters, and optional default-property skipping.

## Usage

```lua
local SaveInstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/D.E-save/main/saveinstance.lua"))()

local result = SaveInstance.SaveToFile(workspace, "dumps/place.rbxlx", {
	SaveAssets = true,
	SaveTerrain = true,
	SaveAttributes = true,
	SaveTags = true,
	DecompileScripts = true,
	UseByteFallDecompiler = true,
	ShowReadMe = true,
	IgnoreDefaultProperties = false,
	Callback = function(message, progress)
		print(message, progress)
	end,
})

print(result.Path)
print(result.Ok)
```

To only generate the XML string:

```lua
local xml = SaveInstance(workspace)
print(xml)
```

## Options

```lua
{
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
	ShowStatus = false,
	ShowReadMe = false,
	IgnoreDefaultProperties = false,
	AlternativeWritefile = true,
	WriteSegmentSize = 4194304,
	AssetsFolder = "saveinstance_assets",
	RequestTimeout = 20,
	Callback = nil,
	IgnoreClasses = {
		CoreGui = true,
	},
	IgnoreInstances = {
		[workspace.Camera] = true,
	},
	IgnoreServices = {
		Players = true,
		ServerScriptService = true,
	}
}
```

To disable ByteFall and use the executor's decompiler instead:

```lua
local result = SaveInstance.SaveToFile(workspace, "dumps/place.rbxlx", {
	UseByteFallDecompiler = false,
	FallbackToSystemDecompiler = true,
})
```

## Current limitations

- Terrain embedding requires `gethiddenproperty` support for `SmoothGrid` and `PhysicsGrid`.
- Attribute and tag export uses D.E save's own best-effort binary payloads inside `AttributesSerialize` and `Tags`.
- ByteFall decompilation sends script bytecode through HTTP to `ByteFallEndpoint`; disable `UseByteFallDecompiler` to use the executor's `decompile` fallback instead.
- Script decompilation depends on executor support for `getscriptbytecode`, HTTP request APIs, or a global `decompile` function.
- RBXLX output is intentionally basic and is not a perfect 1:1 copy of Roblox Studio's exporter.
- Asset downloading depends on executor HTTP support and Roblox asset permissions.
- Hidden properties are used for Terrain grids and optional mesh/union binary data; nil instances and script-killing behavior are intentionally not used.

## License

MIT

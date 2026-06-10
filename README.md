# D.E save

Basic Roblox SaveInstance implementation written in Luau for executor environments.

## What it does

- Serializes a Roblox instance tree into a simple RBXLX-style XML string.
- Can save the generated `.rbxlx` file with executor APIs like `writefile`.
- Can optionally try to download referenced assets with `request`/`http_request`.
- Can embed Terrain `SmoothGrid` and `PhysicsGrid` data into the generated `.rbxlx` when the executor supports `gethiddenproperty`.
- Preserves asset references such as `MeshId`, `TextureID`, `SoundId`, `AnimationId`, `ShirtTemplate`, `PantsTemplate`, `Graphic`, and `Texture`.
- Includes `Script`, `LocalScript`, and `ModuleScript` instances with empty `Source` placeholders.
- Supports progress callbacks, segmented writing with `appendfile`, simple metadata, filters, and optional default-property skipping.

## Usage

```lua
local SaveInstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/D.E-save/main/saveinstance.lua"))()

local result = SaveInstance.SaveToFile(workspace, "dumps/place.rbxlx", {
	SaveAssets = true,
	SaveTerrain = true,
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

## Current limitations

- Terrain embedding requires `gethiddenproperty` support for `SmoothGrid` and `PhysicsGrid`.
- Script source is not decompiled or recovered; scripts are saved with empty `Source` placeholders.
- RBXLX output is intentionally basic and is not a perfect 1:1 copy of Roblox Studio's exporter.
- Asset downloading depends on executor HTTP support and Roblox asset permissions.
- Hidden properties are used for Terrain grids and optional mesh/union binary data; nil instances, bytecode/decompiler APIs, and script-killing behavior are intentionally not used.

## License

MIT

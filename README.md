# D.E save

Basic Roblox SaveInstance implementation written in Luau for executor environments.

## What it does

- Serializes a Roblox instance tree into a simple RBXLX-style XML string.
- Can save the generated `.rbxlx` file with executor APIs like `writefile`.
- Can optionally try to download referenced assets with `request`/`http_request`.
- Preserves asset references such as `MeshId`, `TextureID`, `SoundId`, `AnimationId`, `ShirtTemplate`, `PantsTemplate`, `Graphic`, and `Texture`.
- Supports progress callbacks, segmented writing with `appendfile`, simple metadata, filters, and optional default-property skipping.

## Usage

```lua
local SaveInstance = loadstring(game:HttpGet("RAW_URL_HERE"))()

local result = SaveInstance.SaveToFile(workspace, "dumps/place.rbxlx", {
	SaveAssets = true,
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
	IncludeScripts = false,
	SaveAssets = false,
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

- Terrain voxel data is not serialized yet.
- Script source is not decompiled or recovered.
- RBXLX output is intentionally basic and is not a perfect 1:1 copy of Roblox Studio's exporter.
- Asset downloading depends on executor HTTP support and Roblox asset permissions.
- Hidden properties, nil instances, bytecode/decompiler APIs, and script-killing behavior are intentionally not used.

## License

MIT

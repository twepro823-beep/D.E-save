# D.E save

Basic Roblox SaveInstance implementation written in Luau for executor environments.

## What it does

- Serializes a Roblox instance tree into a simple RBXLX-style XML string.
- Can save the generated `.rbxlx` file with executor APIs like `writefile`.
- Can optionally try to download referenced assets with `request`/`http_request`.
- Can export Terrain voxels into chunked JSON files with materials and occupancy.
- Preserves asset references such as `MeshId`, `TextureID`, `SoundId`, `AnimationId`, `ShirtTemplate`, `PantsTemplate`, `Graphic`, and `Texture`.
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

To export only Terrain chunks:

```lua
local terrain = SaveInstance.SaveTerrain(workspace, "dumps/terrain", {
	TerrainResolution = 4,
	TerrainChunkSize = 64,
})

print(#terrain.Chunks)
```

## Options

```lua
{
	IncludeScripts = false,
	SaveAssets = false,
	SaveTerrain = false,
	ShowReadMe = false,
	IgnoreDefaultProperties = false,
	AlternativeWritefile = true,
	WriteSegmentSize = 4194304,
	AssetsFolder = "saveinstance_assets",
	TerrainFolder = "saveinstance_terrain",
	TerrainResolution = 4,
	TerrainChunkSize = 64,
	TerrainRegion = nil,
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

- Terrain is exported as separate JSON chunks, not embedded into the `.rbxlx` TerrainRegion format yet.
- Script source is not decompiled or recovered.
- RBXLX output is intentionally basic and is not a perfect 1:1 copy of Roblox Studio's exporter.
- Asset downloading depends on executor HTTP support and Roblox asset permissions.
- Hidden properties, nil instances, bytecode/decompiler APIs, and script-killing behavior are intentionally not used.

## License

MIT

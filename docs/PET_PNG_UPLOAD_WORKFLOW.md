# Pet PNG Upload Workflow

This workflow uploads all pet PNGs and keeps runtime pet rendering stable.

## Scope

- Pet sprite source folder: `assets/pets/`
- Runtime asset map: `src/shared/Pets/PetAssetManifest.luau`
- Runtime renderer: `src/shared/Pets/BillboardPetRenderer.luau`
- Canonical pet registry: `src/shared/Pets/PetDefinitions.luau`

## Upload Steps

1. Verify pet PNG files in `assets/pets/`.
2. Upload images using the existing project uploader flow:
   - Open Cloud API (recommended in this repo via tools scripts)
   - Roblox Creator Dashboard / Asset Manager (manual fallback)
3. Confirm each uploaded file has a numeric asset ID.
4. Store IDs in `rbxassetid://<ASSET_ID>` format.
5. Update `src/shared/Pets/PetAssetManifest.luau` with the new IDs.
6. Run config sync/validation scripts if needed:
   - `python tools/update_configs.py`
   - `python tools/validate_visual_assets.py`
7. Test in Studio Play mode with Rojo connected.

## Runtime Rules

- Use direct `rbxassetid://` for pet image rendering.
- Do not use `rbxthumb://` for runtime pet display.
- Keep golden/rainbow variants generated in code unless dedicated variant PNGs already exist.

## Recommended Test Flow

1. Upload and map one pet first.
2. Verify it in:
   - inventory icon
   - pokedex icon
   - hatch result
   - equipped/follower billboard
3. Batch upload and map remaining pets.
4. Enable studio-only dev spawner in `src/server/Dev/SpawnAllBillboardPets.server.luau`.
5. Confirm all pets render with transparent edges and no placeholders.

## Warning

Roblox thumbnails may show Pending or cached placeholders for newly uploaded decals. The game should use rbxassetid:// directly for pet art rendering.

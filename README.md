# Refreshed mods

The catalog for the in-game mod browser. Each folder in `packages/` is one mod. The game reads `catalog.json` and downloads each mod's ZIP from its author, not this repo.

Listing a mod here doesn't give it a license. Only add mods you're allowed to share.

Making a mod? Start with [docs/MODDING.md](docs/MODDING.md) and the [examples](examples).

## Add a mod

1. Fork this repo.
2. Pick your release URL now, like `https://github.com/yourname/my-mod/releases/download/1.0.0/my-mod.zip`. The ZIP has to end up at exactly this link.
3. Create `packages/yourname.mod/package.json`. The folder name must match your mod ID:

```json
{
  "source": "https://github.com/yourname/my-mod",
  "license": "MIT",
  "license_url": "https://github.com/yourname/my-mod/blob/main/LICENSE",
  "license_files": ["LICENSE"],
  "asset_licenses": [],
  "icon": "https://raw.githubusercontent.com/yourname/my-mod/main/icon.png",
  "readme": "# My mod\nInstructions and credits.",
  "download": { "url": "https://github.com/yourname/my-mod/releases/download/1.0.0/my-mod.zip" }
}
```

4. Build:

```sh
python build.py --package ../my-mod --metadata packages/yourname.mod/package.json --archive ../my-mod.zip
```

This makes the ZIP, copies ID, name, version, author, description and dependencies from your `manifest.json`, fills in the checksum and size, and updates `catalog.json`.

5. Upload the ZIP as a release asset at your release URL.
6. Test it: push your fork, add it in **Refreshed > Source > Mod Sources** and install your mod from **Mods > Browse**.
7. Open a PR with your `package.json` and `catalog.json`.

Use your real license. `license_files` must be in your mod folder so they ship in the ZIP. If assets have a different license, add `{"license": "CC-BY-4.0, Artist", "url": "..."}` to `asset_licenses`. Don't include game files.

## Update a mod

Bump `version` in `manifest.json`, point `download.url` at the new release, run the build again, upload, PR. Never replace a released ZIP, the browser checks the hash.

## Limits

- ZIP: 128 MiB, 4,096 files, 256 MiB unpacked.
- Icon: HTTPS PNG, 512x512, 1 MiB. Leave it out to show initials.
- `readme`: basic Markdown, 16,384 characters.

## Contributing

Please don't send vibecoded PRs. Only send changes you understand and tested yourself, If you use AI read and understand why and how the changes work before sending them in. PRs that look generated without that will be closed, However I'm only gonna moderate changes to the core, i will not moderate individual mods.

#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath

MAX_ZIP = 128 * 1024 * 1024
MAX_UNPACKED = 256 * 1024 * 1024


def relative_path(value):
    if not isinstance(value, str) or not value or len(value) > 240 or "\\" in value or ":" in value:
        return False
    for part in value.rstrip("/").split("/"):
        stem = part.split(".")[0].upper()
        if not part or part in (".", "..") or part.endswith((".", " ")):
            return False
        if stem in {"CON", "PRN", "AUX", "NUL"} or re.fullmatch(r"(?:COM|LPT)[1-9]", stem):
            return False
        if any(ord(c) < 32 or c in '<>"|?*' for c in part):
            return False
    return not PurePosixPath(value).is_absolute()


def https(value):
    if not isinstance(value, str) or len(value) > 2048 or any(c.isspace() or ord(c) < 32 for c in value):
        return False
    return bool(re.fullmatch(r"https://[A-Za-z0-9.-]+(?::[0-9]+)?/[^\s\x00-\x1f]*", value))


def valid_id(value):
    return isinstance(value, str) and re.fullmatch(r"[a-z0-9._-]{1,128}", value) and relative_path(value)


def version(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value)


def validate(record):
    if not isinstance(record, dict) or not valid_id(record.get("id")) or not version(record.get("version")):
        raise ValueError("Invalid mod ID or version")
    for key in ("name", "author", "description", "license"):
        value = record.get(key)
        if not isinstance(value, str) or not value.strip() or len(value) > (1024 if key == "description" else 160):
            raise ValueError(f"Missing or invalid {key}")
    if record.get("api_version") != 1 or record.get("network_scope") not in ("client", "content"):
        raise ValueError("Unsupported API version or network scope")
    if not https(record.get("source")) or not https(record.get("license_url")):
        raise ValueError("Source and license links must use HTTPS")
    download = record.get("download")
    if not isinstance(download, dict) or not https(download.get("url")):
        raise ValueError("Missing HTTPS package URL")
    if not isinstance(download.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", download["sha256"]):
        raise ValueError("Missing SHA-256 checksum")
    if type(download.get("size")) is not int or not 0 < download["size"] <= MAX_ZIP:
        raise ValueError("Invalid package size")
    dependencies = record.get("dependencies", {})
    if not isinstance(dependencies, dict) or len(dependencies) > 64 or any(not valid_id(k) or not version(v) for k, v in dependencies.items()):
        raise ValueError("Invalid dependencies")
    licenses = record.get("license_files")
    if not isinstance(licenses, list) or not 0 < len(licenses) <= 32 or any(not relative_path(p) or p.endswith("/") for p in licenses):
        raise ValueError("List the license files included in the ZIP")
    assets = record.get("asset_licenses", [])
    if not isinstance(assets, list) or len(assets) > 32:
        raise ValueError("Invalid asset licenses")
    for credit in assets:
        if not isinstance(credit, dict) or not isinstance(credit.get("license"), str) or not 0 < len(credit["license"]) <= 160 or not https(credit.get("url")):
            raise ValueError("Invalid asset license")
    if not isinstance(record.get("icon", ""), str) or record.get("icon") and not https(record["icon"]):
        raise ValueError("Icons need an HTTPS PNG URL")
    if not isinstance(record.get("readme", ""), str) or len(record.get("readme", "")) > 16384:
        raise ValueError("README exceeds 16,384 characters")


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def build(root):
    records = []
    for path in sorted((root / "packages").glob("*/package.json")):
        record = json.loads(path.read_text(encoding="utf-8"))
        validate(record)
        if record["id"] != path.parent.name:
            raise ValueError(f"{path}: folder must match the mod ID")
        records.append(record)
    if len(records) > 1000:
        raise ValueError("Catalog exceeds 1,000 mods")
    encoded = json.dumps({"format": 1, "mods": records}, indent=2, ensure_ascii=False) + "\n"
    if len(encoded.encode("utf-8")) > 2 * 1024 * 1024:
        raise ValueError("Catalog exceeds 2 MiB")
    return encoded


def package(mod, metadata, archive):
    mod, archive = mod.resolve(), archive.resolve()
    if archive.is_relative_to(mod):
        raise ValueError("Write the ZIP outside the mod folder")
    record = json.loads(metadata.read_text(encoding="utf-8"))
    manifest = json.loads((mod / "manifest.json").read_text(encoding="utf-8"))
    for key in ("id", "version", "api_version", "network_scope", "name", "author", "description"):
        record[key] = manifest[key]
    record["dependencies"] = manifest.get("dependencies", {})
    files = []
    folded = set()
    total = 0
    for path in sorted(mod.rglob("*")):
        name = path.relative_to(mod).as_posix()
        if any(part in (".git", ".godot", "__pycache__") for part in path.relative_to(mod).parts) or path.name.endswith("~"):
            continue
        if path.is_symlink():
            raise ValueError(f"Symlinks cannot be packaged: {name}")
        if not path.is_file():
            continue
        if not relative_path(name) or name.lower() in folded:
            raise ValueError(f"Unsafe or repeated file path: {name}")
        size = path.stat().st_size
        total += size
        if size > 64 * 1024 * 1024 or total > MAX_UNPACKED or len(files) >= 4096:
            raise ValueError("Mod exceeds the file count or unpacked size limit")
        folded.add(name.lower())
        files.append(path)
    names = {path.relative_to(mod).as_posix(): path for path in files}
    script = manifest.get("entry", "main.gd")
    if not isinstance(script, str) or not script.endswith(".gd") or script not in names:
        raise ValueError("Missing entry script")
    if (mod / "manifest.json").stat().st_size > 262144:
        raise ValueError("Manifest exceeds 256 KiB")
    for name in record.get("license_files", []):
        if name not in names or names[name].stat().st_size == 0:
            raise ValueError(f"Missing license file: {name}")
    temporary = archive.with_name(archive.name + ".tmp")
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as output:
            for path in files:
                output.write(path, path.relative_to(mod).as_posix())
        record["download"]["size"] = temporary.stat().st_size
        record["download"]["sha256"] = hashlib.sha256(temporary.read_bytes()).hexdigest()
        validate(record)
        temporary.replace(archive)
        write_json(metadata, record)
    finally:
        temporary.unlink(missing_ok=True)
    return record


def main():
    parser = argparse.ArgumentParser(description="Build the Refreshed mod catalog or one mod ZIP")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--package", type=Path, metavar="MOD_FOLDER")
    parser.add_argument("--metadata", type=Path, metavar="PACKAGE_JSON")
    parser.add_argument("--archive", type=Path, metavar="ZIP")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    try:
        if args.package:
            if not args.metadata or not args.archive:
                parser.error("--package needs --metadata and --archive")
            record = package(args.package, args.metadata, args.archive)
            print(f"Packaged {record['id']} {record['version']}")
        encoded = build(root)
        catalog = root / "catalog.json"
        if args.check:
            if not catalog.exists() or catalog.read_text(encoding="utf-8") != encoded:
                raise ValueError("catalog.json is stale. Run python build.py and commit it with the package entries.")
        else:
            catalog.write_text(encoded, encoding="utf-8")
        print("Catalog is valid")
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

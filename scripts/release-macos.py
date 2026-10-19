#!/usr/bin/env python3
"""Build a signed, notarized universal macOS release candidate for Dispatch."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ACCOUNT = "com.robzilla1738.dispatch"
REPO = "robzilla1738/dispatch"
FEED = f"https://raw.githubusercontent.com/{REPO}/main/updates/appcast.xml"
PUBLIC_KEY = "cK/lI4rfOoT6pOy7xIusZYyvNT3hJAKrO0OaTxS0EaU="


def run(*args, capture=False):
    return subprocess.run(
        [str(a) for a in args],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=capture,
    )


def sign_app(app: Path, identity: str):
    framework = app / "Contents/Frameworks/Sparkle.framework"
    base = framework / "Versions/B"
    for path in [
        base / "Autoupdate",
        base / "Updater.app",
        base / "XPCServices/Downloader.xpc",
        base / "XPCServices/Installer.xpc",
        framework,
        app,
    ]:
        if not path.exists():
            raise SystemExit(f"Missing required signing target: {path}")
        run(
            "codesign",
            "--force",
            "--options",
            "runtime",
            "--timestamp",
            "--sign",
            identity,
            path,
        )


def validate_app(app: Path, version: str, team: str):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected = {
        "CFBundleIdentifier": ACCOUNT,
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "SUFeedURL": FEED,
        "SUPublicEDKey": PUBLIC_KEY,
        "SURequireSignedFeed": True,
        "SUVerifyUpdateBeforeExtraction": True,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise SystemExit(f"Unexpected {key}: {info.get(key)!r} (expected {value!r})")
    binary = app / "Contents/MacOS/Dispatch"
    archs = set(run("lipo", "-archs", binary, capture=True).stdout.split())
    if archs != {"arm64", "x86_64"}:
        raise SystemExit(f"Release must include arm64 and x86_64 (found {archs}).")
    signature = run("codesign", "-dvv", app, capture=True).stderr
    if f"TeamIdentifier={team}" not in signature or "runtime" not in signature or "Timestamp=" not in signature:
        raise SystemExit("Release requires the expected Developer ID, hardened runtime, and timestamp.")
    if not (app / "Contents/Frameworks/Sparkle.framework").exists():
        raise SystemExit("Missing Sparkle framework.")
    run("codesign", "--verify", "--deep", "--strict", app)


def notarize(path: Path, profile: str):
    result = run(
        "xcrun",
        "notarytool",
        "submit",
        path,
        "--keychain-profile",
        profile,
        "--wait",
        "--output-format",
        "json",
        capture=True,
    )
    receipt = json.loads(result.stdout)
    print(f"Notarization: {receipt.get('status')} ({receipt.get('id')})", flush=True)
    if receipt.get("status") != "Accepted":
        raise SystemExit("Apple rejected this artifact; inspect its notarization log before continuing.")
    return receipt


def build_universal_app(out_app: Path):
    print("==> Building universal (arm64 + x86_64) release binary", flush=True)
    run("swift", "build", "-c", "release", "--arch", "arm64", "--arch", "x86_64", "--product", "Dispatch")

    bin_dir = Path(
        run("swift", "build", "-c", "release", "--arch", "arm64", "--arch", "x86_64", "--show-bin-path", capture=True).stdout.strip()
    )

    if out_app.exists():
        shutil.rmtree(out_app)
    contents = out_app / "Contents"
    macos = contents / "MacOS"
    resources = contents / "Resources"
    frameworks = contents / "Frameworks"
    macos.mkdir(parents=True)
    resources.mkdir(parents=True)
    frameworks.mkdir(parents=True)

    shutil.copyfile(bin_dir / "Dispatch", macos / "Dispatch")
    (macos / "Dispatch").chmod(0o755)

    for bundle in bin_dir.glob("*.bundle"):
        run("ditto", bundle, resources / bundle.name)

    shutil.copyfile(ROOT / "Info.plist", contents / "Info.plist")
    shutil.copyfile(
        ROOT / "Sources/DispatchApp/Resources/AppIcon-Release.icns",
        resources / "AppIcon.icns",
    )
    (contents / "PkgInfo").write_text("APPL????")

    sparkle_fw = ROOT / ".cache/sparkle/2.10.0/Sparkle.framework"
    run("ditto", sparkle_fw, frameworks / "Sparkle.framework")

    licenses_dir = resources / "licenses"
    licenses_dir.mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "LICENSE", licenses_dir / "Dispatch.txt")
    if (ROOT / "licenses/Sparkle.txt").exists():
        shutil.copyfile(ROOT / "licenses/Sparkle.txt", licenses_dir / "Sparkle.txt")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", required=True, help="Developer ID Application signing identity")
    parser.add_argument("--keychain-profile", required=True, help="Existing notarytool profile name")
    args = parser.parse_args()

    if not args.identity.startswith("Developer ID Application:"):
        parser.error("Use a Developer ID Application identity.")
    team_match = re.search(r"\(([A-Z0-9]{10})\)$", args.identity)
    if not team_match:
        parser.error("Identity must include its 10-character Apple team ID.")
    team_id = team_match[1]

    info = plistlib.loads((ROOT / "Info.plist").read_bytes())
    version = info["CFBundleShortVersionString"]

    run("xcrun", "notarytool", "history", "--keychain-profile", args.keychain_profile, "--output-format", "json", capture=True)
    run("python3", ROOT / "scripts/setup-sparkle.py")

    tools = ROOT / ".cache/sparkle/2.10.0/bin"
    key_out = run(tools / "generate_keys", "--account", ACCOUNT, "-p", capture=True).stdout.strip()
    if key_out != PUBLIC_KEY:
        raise SystemExit(f"Sparkle Keychain key ({key_out}) does not match SUPublicEDKey ({PUBLIC_KEY}).")

    out = ROOT / "release-artifacts" / version
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    app = ROOT / "dist/Dispatch.app"
    build_universal_app(app)

    print("==> Signing Dispatch.app inside-out with Developer ID + Hardened Runtime", flush=True)
    sign_app(app, args.identity)
    validate_app(app, version, team_id)

    print("==> Submitting Dispatch.app for Apple Notarization", flush=True)
    with tempfile.TemporaryDirectory(prefix="dispatch-notarize-") as temp:
        upload = Path(temp) / "Dispatch.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, upload)
        receipt = notarize(upload, args.keychain_profile)
    (out / "app-notarization.json").write_text(json.dumps(receipt, indent=2) + "\n")
    run("xcrun", "stapler", "staple", app)
    run("xcrun", "stapler", "validate", app)
    run("spctl", "--assess", "--type", "execute", "--verbose", app)

    archive_dir = out / "sparkle"
    archive_dir.mkdir()
    archive = archive_dir / f"Dispatch-{version}-universal.zip"
    run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive)

    with tempfile.TemporaryDirectory(prefix="dispatch-verify-") as temp:
        run("ditto", "-x", "-k", archive, temp)
        extracted = Path(temp) / "Dispatch.app"
        validate_app(extracted, version, team_id)
        run("xcrun", "stapler", "validate", extracted)
        run("spctl", "--assess", "--type", "execute", extracted)

    print("==> Building, signing, and notarizing Dispatch DMG", flush=True)
    dmg = out / f"Dispatch-{version}-universal.dmg"
    with tempfile.TemporaryDirectory(prefix="dispatch-dmg-") as temp:
        run("ditto", app, Path(temp) / "Dispatch.app")
        (Path(temp) / "Applications").symlink_to("/Applications")
        run("hdiutil", "create", "-volname", "Dispatch", "-srcfolder", temp, "-format", "UDZO", dmg)
    run("codesign", "--force", "--timestamp", "--sign", args.identity, dmg)
    dmg_receipt = notarize(dmg, args.keychain_profile)
    (out / "dmg-notarization.json").write_text(json.dumps(dmg_receipt, indent=2) + "\n")
    run("xcrun", "stapler", "staple", dmg)
    run("codesign", "--verify", "--strict", dmg)
    run("xcrun", "stapler", "validate", dmg)
    run("spctl", "--assess", "--type", "open", "--context", "context:primary-signature", dmg)

    release_notes = ROOT / "docs/releases" / f"{version}.md"
    if release_notes.is_file():
        shutil.copyfile(release_notes, archive.with_suffix(".md"))

    print("==> Generating and verifying signed Sparkle appcast.xml", flush=True)
    run(
        tools / "generate_appcast",
        "--account",
        ACCOUNT,
        "--maximum-deltas",
        "0",
        "--embed-release-notes",
        "--download-url-prefix",
        f"https://github.com/{REPO}/releases/download/v{version}/",
        archive_dir,
    )
    feed = archive_dir / "appcast.xml"
    run(tools / "sign_update", "--account", ACCOUNT, "--verify", feed)
    enclosure = next((e for e in ET.parse(feed).iter("enclosure") if e.attrib["url"].endswith(archive.name)), None)
    if enclosure is None or int(enclosure.attrib["length"]) != archive.stat().st_size:
        raise SystemExit("Generated feed does not match final archive.")
    signature = enclosure.attrib["{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"]
    run(tools / "sign_update", "--account", ACCOUNT, "--verify", archive, signature)

    source_sha = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()
    manifest = {
        "version": version,
        "sourceCommit": source_sha,
        "repository": REPO,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "artifacts": {
            str(p.relative_to(out)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (archive, dmg, feed)
        },
    }
    (out / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (out / "SHA256SUMS.txt").write_text(
        "".join(
            f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n"
            for p in [archive, dmg, out / "release-manifest.json"]
        )
    )
    print(f"Verified signed & notarized release candidate: {out}", flush=True)


if __name__ == "__main__":
    main()

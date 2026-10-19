#!/usr/bin/env python3
"""Fetch the pinned official Sparkle framework and tools; verify before extracting."""
import hashlib
import pathlib
import platform
import subprocess
import tempfile

VERSION = "2.10.0"
SHA256 = "c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"
ROOT = pathlib.Path(__file__).resolve().parents[1]
CACHE = ROOT / ".cache" / "sparkle" / VERSION
LICENSES = ROOT / "licenses"


def main():
    if platform.system() != "Darwin":
        raise SystemExit("Sparkle builds require macOS.")
    marker = CACHE / ".verified-sha256"
    if not (marker.exists() and marker.read_text().strip() == SHA256 and (CACHE / "bin/generate_appcast").exists()):
        CACHE.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="dispatch-sparkle-") as folder:
            archive = pathlib.Path(folder) / "Sparkle.tar.xz"
            subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--output", str(archive),
                            f"https://github.com/sparkle-project/Sparkle/releases/download/{VERSION}/Sparkle-{VERSION}.tar.xz"], check=True)
            if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
                raise SystemExit("Sparkle archive checksum mismatch; nothing was extracted.")
            subprocess.run(["tar", "-xf", str(archive), "-C", str(CACHE)], check=True)
            marker.write_text(SHA256 + "\n")
    LICENSES.mkdir(parents=True, exist_ok=True)
    license_src = CACHE / "LICENSE"
    if license_src.exists():
        (LICENSES / "Sparkle.txt").write_bytes(license_src.read_bytes())
    print(f"Sparkle {VERSION} ready ({SHA256[:12]}…).")


if __name__ == "__main__":
    main()

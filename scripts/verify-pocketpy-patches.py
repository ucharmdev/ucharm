#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _download_pocketpy_c(version: str) -> str:
    url = (
        f"https://github.com/pocketpy/pocketpy/releases/download/v{version}/pocketpy.c"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "ucharm/patch-verify"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    return data.decode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify μcharm PocketPy vendor patchset."
    )
    parser.add_argument(
        "--check-upstream",
        action="store_true",
        help="Also verify the anchors are absent from pristine upstream PocketPy for this version.",
    )
    parser.add_argument(
        "--upstream-path",
        type=Path,
        default=None,
        help="Use a local pristine upstream pocketpy.c instead of downloading.",
    )
    parser.add_argument(
        "--pocketpy-version",
        default=None,
        help="PocketPy version to check upstream against (defaults to pocketpy/POCKETPY_VERSION).",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    manifest_path = repo_root / "pocketpy" / "patches" / "manifest.json"
    if not manifest_path.exists():
        print(f"error: missing manifest: {manifest_path}")
        return 2

    manifest = json.loads(_read_text(manifest_path))
    failures: list[str] = []

    tracked = manifest.get("tracked_files", [])
    for entry in tracked:
        rel_path = entry.get("path")
        if not rel_path:
            continue
        file_path = repo_root / rel_path
        if not file_path.exists():
            failures.append(f"missing file: {rel_path}")
            continue

        text = _read_text(file_path)
        for anchor in entry.get("anchors", []):
            if anchor not in text:
                failures.append(f"missing anchor in {rel_path}: {anchor}")

    if args.check_upstream:
        vendor_anchors: list[str] = []
        for entry in tracked:
            vendor_anchors.extend(entry.get("anchors", []))

        upstream_text: str
        if args.upstream_path is not None:
            upstream_text = _read_text(args.upstream_path)
        else:
            version = args.pocketpy_version
            if version is None:
                version_file = repo_root / "pocketpy" / "POCKETPY_VERSION"
                if not version_file.exists():
                    failures.append(
                        "missing pocketpy/POCKETPY_VERSION (needed for --check-upstream)"
                    )
                    upstream_text = ""
                else:
                    version = version_file.read_text(encoding="utf-8").strip()
            if version:
                try:
                    upstream_text = _download_pocketpy_c(version)
                except (urllib.error.URLError, TimeoutError) as e:
                    failures.append(
                        f"failed to download upstream pocketpy.c for v{version}: {e}"
                    )
                    upstream_text = ""

        if upstream_text:
            for anchor in vendor_anchors:
                if anchor in upstream_text:
                    failures.append(
                        f"upstream contains vendor anchor unexpectedly: {anchor}"
                    )

            if "ucharm patch:" in upstream_text:
                failures.append(
                    "upstream contains 'ucharm patch:' markers unexpectedly"
                )

    if failures:
        print("PocketPy vendor patch verification failed:")
        for item in failures:
            print(f"  - {item}")
        return 1

    patchset_id = manifest.get("patchset_id", "<unknown>")
    patchset_version = manifest.get("patchset_version", "<unknown>")
    print(f"PocketPy vendor patches OK: {patchset_id} v{patchset_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

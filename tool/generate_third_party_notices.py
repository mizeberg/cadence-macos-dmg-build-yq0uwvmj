#!/usr/bin/env python3
"""Regenerate THIRD_PARTY_NOTICES.md from Flutter's resolved package graph."""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / ".dart_tool" / "package_config.json"
OUTPUT = ROOT / "THIRD_PARTY_NOTICES.md"


def package_root(uri: str) -> Path:
    parsed = urlparse(uri)
    if parsed.scheme == "file":
        return Path(unquote(parsed.path)).resolve()
    return (ROOT / uri).resolve()


def license_files(root: Path) -> list[Path]:
    for candidate_root in (root, *root.parents[:3]):
        exact = [candidate_root / name for name in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING")]
        existing = [path for path in exact if path.is_file()]
        if existing:
            return existing
        found = sorted(
            path
            for path in candidate_root.glob("LICENSE*")
            if path.is_file() and path.name not in {"LICENSES.chromium.html"}
        )
        if found:
            return found
    return []


def fence_for(content: str) -> str:
    longest = max((len(run) for run in content.split() if run and set(run) == {"`"}), default=0)
    return "`" * max(3, longest + 1)


def main() -> None:
    if not CONFIG.is_file():
        raise SystemExit("Run `flutter pub get` first to create .dart_tool/package_config.json.")

    packages = json.loads(CONFIG.read_text(encoding="utf-8"))["packages"]
    sections = [
        "# Third-party notices",
        "",
        "This file is generated from the resolved Flutter package graph. Regenerate it after changing dependencies with `python3 tool/generate_third_party_notices.py`. Exact package versions are recorded in `pubspec.lock`.",
        "",
        "## Reference-project acknowledgement",
        "",
        "Cadence is an independent Flutter desktop implementation informed by the user-provided brief and the public BitChord project. BitChord is authored by Kushagra Singh (`kushagrasinghx`) and licensed under GNU General Public License version 3.0 (GPL-3.0): <https://github.com/kushagrasinghx/BitChord>.",
        "",
        "The requested BitChord tracked file set (543 files, upstream commit `fe198ac0bde052f8b84cfd84b1d271f8f1fcc7b2`) is included separately under `third_party/BitChord/`, with its upstream `LICENSE` and project notices intact. In this public build copy only, the upstream `GOOGLE_API_KEY` value in `PoTokenWebView.kt` is replaced with `REDACTED_FOR_PUBLIC_REPOSITORY`; no tracked files are omitted. BitChord is an Android/Kotlin source project and is not compiled, linked, or loaded by Cadence. Cadence's Flutter online-source adapter is an independent implementation using Jamendo's documented API. This acknowledgement does not imply affiliation with or endorsement by the BitChord author.",
        "",
        "Anyone redistributing the separate BitChord snapshot must preserve and comply with its GPL-3.0 terms. All tracked files and the upstream license are included in this repository; one credential value is intentionally replaced by a placeholder. The applicable licensing terms for a combined distribution should be reviewed before release.",
        "",
        "## Resolved package licenses",
        "",
    ]

    for entry in sorted(packages, key=lambda item: item["name"].casefold()):
        name = entry["name"]
        if name == "cadence_music":
            continue
        root = package_root(entry["rootUri"])
        files = license_files(root)
        version = root.name
        sections.extend([f"### {name} ({version})", ""])
        if not files:
            sections.extend(["No license file was found in the resolved package directory; verify upstream terms before redistribution.", ""])
            continue
        for license_path in files:
            content = license_path.read_text(encoding="utf-8", errors="replace").strip()
            fence = fence_for(content)
            sections.extend([f"License text from `{license_path.name}`:", "", fence + "text", content, fence, ""])

    OUTPUT.write_text("\n".join(sections).rstrip() + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT} for {len(packages) - 1} resolved packages.")


if __name__ == "__main__":
    main()

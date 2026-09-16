"""Download an SHL archive from an official, user-authorised URL only.

SHL access can require registration/acceptance of its terms.  This script
intentionally does not know an unofficial mirror or attempt to bypass a login.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import requests


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.getenv("SHL_OFFICIAL_DOWNLOAD_URL"))
    parser.add_argument("--output", default="data/raw/shl_preview.zip")
    args = parser.parse_args()
    if not args.url:
        parser.error(
            "Provide --url (or SHL_OFFICIAL_DOWNLOAD_URL) copied from the official "
            "SHL portal after accepting its access terms. No unofficial source is used."
        )
    destination = Path(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(args.url, stream=True, timeout=60) as response:
        response.raise_for_status()
        with destination.open("wb") as out:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    out.write(chunk)
    print(f"Downloaded official SHL archive to {destination}")


if __name__ == "__main__":
    main()

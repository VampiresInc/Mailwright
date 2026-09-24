"""Upload the validated client artifact to CurseForge; never log credentials."""
import argparse
import json
import os
from pathlib import Path
import re
import urllib.request
import urllib.error
import uuid

ROOT = Path(__file__).resolve().parents[1]

def prepare(tag, release):
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+(?:-(?:alpha|beta)\.[0-9]+)?", tag):
        raise ValueError("Unsupported release tag")
    folder = ROOT / "dist" / "release" / tag
    filename = release["filename"]
    if Path(filename).name != filename:
        raise ValueError("Invalid artifact filename")
    client = release["metadata"][0]
    interface = client["interface"]
    patch = f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"
    channel = "alpha" if "-alpha." in tag else "beta" if "-beta." in tag else "release"
    if client["flavor"] == "forever" and channel == "release":
        raise ValueError("Forever must remain a prerelease pending persistence validation")
    metadata = {"changelog": (ROOT / "RELEASE_NOTES.md").read_text(),
                "changelogType": "markdown", "displayName": f"Mailwright {tag[1:]} ({client['flavor']})",
                "gameVersionNames": [patch], "releaseType": channel,
                "isMarkedForManualRelease": False}
    return folder / filename, metadata

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    releases = json.loads((ROOT / "dist" / "release" / args.tag / "release.json").read_text())["releases"]
    prepared = [prepare(args.tag, release) for release in releases]
    for archive, metadata in prepared:
        if args.dry_run:
            print(archive.name, metadata["releaseType"], metadata["gameVersionNames"])
        else:
            upload(archive, metadata)

def upload(archive, metadata):
    data = archive.read_bytes()
    token = os.environ.get("CF_API_KEY")
    if not token:
        raise SystemExit("Missing CF_API_KEY repository secret")
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'.encode()
            + json.dumps(metadata).encode()
            + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n'.encode()
            + data + f'\r\n--{boundary}--\r\n'.encode())
    request = urllib.request.Request("https://wow.curseforge.com/api/projects/1706898/upload-file",
        data=body, headers={"X-Api-Token": token, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    # Do not retry an ambiguous upload: it may already have created a file.
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit(f"CurseForge upload failed: HTTP {error.code}; inspect project before retrying") from None
    if not result.get("id"):
        raise SystemExit("No file ID returned; inspect project before retrying")
    print(f"CurseForge file submitted: {result['id']}")

if __name__ == "__main__":
    main()

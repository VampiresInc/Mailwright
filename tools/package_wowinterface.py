"""Build a single WoWInterface archive for the five tested clients."""
import re
import zipfile
from package import ROOT, FILES

version = "0.2.3"
interfaces = "120100, 11509, 50504, 20506, 16001"
entries = {"Mailwright/" + name: (ROOT / name).read_bytes() for name in FILES}
core = entries["Mailwright/Core.lua"].decode()
core = re.sub(r'(M.addon, M.version = addon, ")[^"]+', lambda m: m.group(1) + version, core, count=1)
entries["Mailwright/Core.lua"] = core.encode()
# Forever can select Mainline: use the actual interface rather than TOC selection.
entries["Mailwright/FlavorForever.lua"] = b"local _, ns = ...\nlocal _, _, _, interface = GetBuildInfo()\nns.forever = tonumber(interface) == 16001\n"
# Existing FlavorForever sets ns.forever; Core consumes this flag.
for suffix in ["", "_Mainline", "_Vanilla", "_Mists", "_TBC", "_Camelot"]:
    source = ROOT / ("Mailwright" + suffix + ".toc")
    toc = source.read_text(encoding="utf-8")
    toc = re.sub(r"## Interface: .*", "## Interface: " + interfaces, toc)
    toc = re.sub(r"## Version: .*", "## Version: " + version, toc)
    toc = toc.replace("FlavorForever.lua\n", "")
    toc = toc.replace("Core.lua\n", "FlavorForever.lua\nCore.lua\n")
    entries["Mailwright/" + source.name] = toc.encode()
output = ROOT / "dist" / "wowinterface" / f"Mailwright-{version}-all-clients.zip"
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for name, data in entries.items():
        archive.writestr(name, data)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == set(entries)
    for name, data in entries.items():
        assert archive.read(name) == data
        if name.endswith(".toc"):
            for line in data.decode().splitlines():
                if line.strip() and not line.startswith("#"):
                    assert "Mailwright/" + line.strip() in entries
print(output)

"""Checks source/config wiring only. NOT a Swift compiler or device test."""
from pathlib import Path
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
app = root / "ios/LightMeal"
project = root / "ios/LightMeal.xcodeproj/project.pbxproj"
def check():
    text = project.read_text(encoding="utf-8")
    swift = list(app.rglob("*.swift"))
    assert len(swift) >= 14, "Missing native source files"
    for file in swift:
        relative = file.relative_to(root / "ios").as_posix()
        assert relative in text, f"Unreferenced source: {relative}"
    paths = re.findall(r'path = "(LightMeal/[^";]+\.swift)"', text)
    if "--negative" in sys.argv: paths.append("LightMeal/App/Missing.swift")
    for path in paths: assert (root / "ios" / path).is_file(), f"Missing referenced source: {path}"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    for key in ["NSCameraUsageDescription", "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"]:
        assert info.get(key), f"Missing permission: {key}"
    assert not info.get("NSAppTransportSecurity"), "Must not disable HTTPS protection"
    entitlements = plistlib.loads((app / "LightMeal.entitlements").read_bytes())
    assert entitlements.get("com.apple.developer.healthkit") is True
    assert not any("icloud" in key for key in entitlements), "Unapproved health history cloud storage"
    ET.parse(root / "ios/LightMeal.xcodeproj/xcshareddata/xcschemes/LightMeal.xcscheme")
    assert "RootView()" in (app / "App/LightMealApp.swift").read_text(encoding="utf-8")
    assert "VisionRecognitionService().recognize" in (app / "Views/CaptureView.swift").read_text(encoding="utf-8")
    assert "health.sync" in (app / "Views/CaptureView.swift").read_text(encoding="utf-8")
    assert "HKMetadataKeySyncVersion" in (app / "Services/HealthService.swift").read_text(encoding="utf-8")
    print(f"PASS project wiring/config: {len(swift)} sources. Swift compilation NOT RUN.")
try: check()
except (AssertionError, OSError, ValueError) as error:
    print(f"FAIL: {error}"); sys.exit(1)

"""Deterministic, dependency-free native Xcode project generator. Run at repo root."""
from pathlib import Path
import hashlib
import plistlib
import json

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"
APP = IOS / "LightMeal"
PROJECT = IOS / "LightMeal.xcodeproj"
def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()
def quoted(value):
    return json.dumps(str(value), ensure_ascii=False)
def main():
    PROJECT.mkdir(parents=True, exist_ok=True)
    sources = sorted(APP.rglob("*.swift"))
    if not sources:
        raise SystemExit("No Swift source files")
    info = {
        "CFBundleDisplayName": "轻食记", "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1",
        "LSRequiresIPhoneOS": True, "UILaunchScreen": {},
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
        "NSCameraUsageDescription": "拍摄你选择的餐食照片以估算热量。",
        "NSHealthShareUsageDescription": "读取你授权的运动能量、步数、体重、心率和训练，结合餐食记录展示摄入与消耗。",
        "NSHealthUpdateUsageDescription": "将你确认的餐食摄入热量写入 Apple 健康，并维护本应用创建的记录。",
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "ITSAppUsesNonExemptEncryption": False,
    }
    (APP / "Info.plist").write_bytes(plistlib.dumps(info, sort_keys=True))
    (APP / "LightMeal.entitlements").write_bytes(plistlib.dumps({"com.apple.developer.healthkit": True}))
    asset = APP / "Assets.xcassets"; asset.mkdir(exist_ok=True)
    (asset / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}), encoding="utf-8")
    project, target, main_group, products, sources_phase, resources, frameworks = [uid(x) for x in ["project", "target", "main", "products", "sources", "resources", "frameworks"]]
    app_ref = uid("product")
    objects = []
    def add(key, content): objects.append(f"\t\t{key} = {{ {content} }};")
    refs, builds = [], []
    for file in sources:
        path = file.relative_to(IOS).as_posix(); ref, build = uid(path), uid("build:" + path)
        refs.append(ref); builds.append(build)
        add(ref, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(path)}; sourceTree = "<group>";')
        add(build, f"isa = PBXBuildFile; fileRef = {ref};")
    asset_ref, asset_build = uid("asset-ref"), uid("asset-build")
    add(asset_ref, 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = LightMeal/Assets.xcassets; sourceTree = "<group>";')
    add(asset_build, f"isa = PBXBuildFile; fileRef = {asset_ref};")
    add(app_ref, 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LightMeal.app; sourceTree = BUILT_PRODUCTS_DIR;')
    add(sources_phase, f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(builds)}); runOnlyForDeploymentPostprocessing = 0;")
    add(resources, f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({asset_build}); runOnlyForDeploymentPostprocessing = 0;")
    add(frameworks, "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    add(products, f'isa = PBXGroup; children = ({app_ref}); name = Products; sourceTree = "<group>";')
    add(main_group, f'isa = PBXGroup; children = ({",".join(refs + [asset_ref, products])}); sourceTree = "<group>";')
    configs = {}
    for owner in ["project", "target"]:
        config_ids = []
        for name in ["Debug", "Release"]:
            key = uid(owner + name); config_ids.append(key)
            settings = {"SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES"}
            if owner == "target":
                settings.update({"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.LightMeal",
                    "INFOPLIST_FILE": "LightMeal/Info.plist", "CODE_SIGN_ENTITLEMENTS": "LightMeal/LightMeal.entitlements",
                    "CODE_SIGN_STYLE": "Automatic", "TARGETED_DEVICE_FAMILY": "1,2", "GENERATE_INFOPLIST_FILE": "NO",
                    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks", "SWIFT_EMIT_LOC_STRINGS": "YES"})
            if name == "Debug": settings.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"})
            body = " ".join(f"{k} = {quoted(v)};" for k, v in settings.items())
            add(key, f"isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {name};")
        list_id = uid(owner + "configs"); configs[owner] = list_id
        add(list_id, f"isa = XCConfigurationList; buildConfigurations = ({','.join(config_ids)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
    add(target, f'isa = PBXNativeTarget; buildConfigurationList = {configs["target"]}; buildPhases = ({sources_phase},{frameworks},{resources}); buildRules = (); dependencies = (); name = LightMeal; productName = LightMeal; productReference = {app_ref}; productType = "com.apple.product-type.application";')
    add(project, f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {configs["project"]}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en,"zh-Hans",Base); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target});')
    text = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {project};\n}}\n"
    (PROJECT / "project.pbxproj").write_text(text, encoding="utf-8")
    scheme = PROJECT / "xcshareddata/xcschemes"; scheme.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="LightMeal.app" BlueprintName="LightMeal" ReferencedContainer="container:LightMeal.xcodeproj"/>'
    (scheme / "LightMeal.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''', encoding="utf-8")
    print(f"Generated Xcode project: {len(sources)} Swift files")
if __name__ == "__main__": main()

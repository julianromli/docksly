#!/usr/bin/env python3
"""Emit a checked-in Docksly.xcodeproj that Xcode 14+ can open without XcodeGen."""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Docksly.xcodeproj"

SWIFT_FILES = [
    ("DockslyApp.swift", "app"),
    ("AppDelegate.swift", "app"),
    ("DockslyCommands.swift", "app"),
    ("Models/DockItem.swift", "models"),
    ("Models/DockProfile.swift", "models"),
    ("Models/DockLibrary.swift", "models"),
    ("Models/ProfileColor.swift", "models"),
    ("Models/LicenseRecord.swift", "models"),
    ("Persistence/DockStore.swift", "persistence"),
    ("Persistence/LicenseStore.swift", "persistence"),
    ("Services/DockApplicator.swift", "services"),
    ("Services/AppIconService.swift", "services"),
    ("Services/LaunchAtLoginService.swift", "services"),
    ("Services/LicenseClient.swift", "services"),
    ("Views/VisualEffectBackground.swift", "views"),
    ("Views/ColorDot.swift", "views"),
    ("Views/DockTileView.swift", "views"),
    ("Views/DockStripView.swift", "views"),
    ("Views/AddAppSheet.swift", "views"),
    ("Views/ProfilePickerButton.swift", "views"),
    ("Views/EditorWindowView.swift", "views"),
    ("Views/SettingsView.swift", "views"),
    ("Views/LicenseLockSheet.swift", "views"),
    ("Views/MenuBarContentView.swift", "views"),
]


def hid(name: str) -> str:
    """Stable 24-char hex id from a label."""
    import hashlib

    digest = hashlib.sha1(name.encode()).hexdigest().upper()
    return digest[:24]


def pbx_file(path: str, group: str) -> dict[str, str]:
    stem = Path(path).name
    return {
        "path": path,
        "name": stem,
        "group": group,
        "ref": hid(f"file:{path}"),
        "build": hid(f"build:{path}"),
    }


def main() -> None:
    files = [pbx_file(path, group) for path, group in SWIFT_FILES]
    assets_ref = hid("file:Assets.xcassets")
    assets_build = hid("build:Assets.xcassets")
    info_ref = hid("file:Info.plist")
    entitlements_ref = hid("file:Docksly.entitlements")

    group_app = hid("group:app")
    group_models = hid("group:models")
    group_persistence = hid("group:persistence")
    group_services = hid("group:services")
    group_views = hid("group:views")
    group_products = hid("group:products")
    group_main = hid("group:main")
    target_ref = hid("target:Docksly")
    project_ref = hid("project:Docksly")
    sources_phase = hid("phase:sources")
    resources_phase = hid("phase:resources")
    frameworks_phase = hid("phase:frameworks")
    config_list_project = hid("xcconfiglist:project")
    config_list_target = hid("xcconfiglist:target")
    debug_project = hid("xcbuild:project:debug")
    release_project = hid("xcbuild:project:release")
    debug_target = hid("xcbuild:target:debug")
    release_target = hid("xcbuild:target:release")
    product_ref = hid("product:Docksly.app")

    file_entries = []
    build_entries = []
    for item in files:
        file_entries.append(
            f"\t\t{item['ref']} /* {item['name']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {Path(item['path']).name}; sourceTree = \"<group>\"; }};"
        )
        build_entries.append(
            f"\t\t{item['build']} /* {item['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {item['ref']} /* {item['name']} */; }};"
        )

    file_entries.append(
        f"\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
    )
    file_entries.append(
        f"\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};"
    )
    file_entries.append(
        f"\t\t{entitlements_ref} /* Docksly.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Docksly.entitlements; sourceTree = \"<group>\"; }};"
    )
    file_entries.append(
        f"\t\t{product_ref} /* Docksly.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Docksly.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    build_entries.append(
        f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};"
    )

    def children(group_name: str) -> str:
        refs = [item for item in files if item["group"] == group_name]
        lines = [f"\t\t\t\t{item['ref']} /* {item['name']} */," for item in refs]
        return "\n".join(lines)

    sources_list = "\n".join(
        f"\t\t\t\t{item['build']} /* {item['name']} in Sources */," for item in files
    )

    pbxproj = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_entries)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_entries)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{group_main} = {{
			isa = PBXGroup;
			children = (
				{group_app} /* Docksly */,
				{group_products} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{group_products} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_ref} /* Docksly.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{group_app} /* Docksly */ = {{
			isa = PBXGroup;
			children = (
{children("app")}
				{group_models} /* Models */,
				{group_persistence} /* Persistence */,
				{group_services} /* Services */,
				{group_views} /* Views */,
				{assets_ref} /* Assets.xcassets */,
				{info_ref} /* Info.plist */,
				{entitlements_ref} /* Docksly.entitlements */,
			);
			path = Docksly;
			sourceTree = "<group>";
		}};
		{group_models} /* Models */ = {{
			isa = PBXGroup;
			children = (
{children("models")}
			);
			path = Models;
			sourceTree = "<group>";
		}};
		{group_persistence} /* Persistence */ = {{
			isa = PBXGroup;
			children = (
{children("persistence")}
			);
			path = Persistence;
			sourceTree = "<group>";
		}};
		{group_services} /* Services */ = {{
			isa = PBXGroup;
			children = (
{children("services")}
			);
			path = Services;
			sourceTree = "<group>";
		}};
		{group_views} /* Views */ = {{
			isa = PBXGroup;
			children = (
{children("views")}
			);
			path = Views;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_ref} /* Docksly */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_target} /* Build configuration list for PBXNativeTarget "Docksly" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Docksly;
			productName = Docksly;
			productReference = {product_ref} /* Docksly.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_ref} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{target_ref} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {config_list_project} /* Build configuration list for PBXProject "Docksly" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {group_main};
			productRefGroup = {group_products} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_ref} /* Docksly */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_build} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_project} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{release_project} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{debug_target} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Docksly/Docksly.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Docksly/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = app.docksly.Docksly;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = macosx;
				SUPPORTED_PLATFORMS = macosx;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{release_target} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Docksly/Docksly.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Docksly/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = app.docksly.Docksly;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = macosx;
				SUPPORTED_PLATFORMS = macosx;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{config_list_project} /* Build configuration list for PBXProject "Docksly" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_project} /* Debug */,
				{release_project} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_target} /* Build configuration list for PBXNativeTarget "Docksly" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_target} /* Debug */,
				{release_target} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project_ref} /* Project object */;
}}
"""

    PROJECT.mkdir(parents=True, exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(pbxproj)

    scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    scheme = dedent(
        f"""\
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme
           LastUpgradeVersion = "1500"
           version = "1.7">
           <BuildAction
              parallelizeBuildables = "YES"
              buildImplicitDependencies = "YES">
              <BuildActionEntries>
                 <BuildActionEntry
                    buildForTesting = "YES"
                    buildForRunning = "YES"
                    buildForProfiling = "YES"
                    buildForArchiving = "YES"
                    buildForAnalyzing = "YES">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "{target_ref}"
                       BuildableName = "Docksly.app"
                       BlueprintName = "Docksly"
                       ReferencedContainer = "container:Docksly.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES"
              shouldAutocreateTestPlan = "YES">
           </TestAction>
           <LaunchAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              launchStyle = "0"
              useCustomWorkingDirectory = "NO"
              ignoresPersistentStateOnLaunch = "NO"
              debugDocumentVersioning = "YES"
              debugServiceExtension = "internal"
              allowLocationSimulation = "YES">
              <BuildableProductRunnable
                 runnableDebuggingMode = "0">
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "{target_ref}"
                    BuildableName = "Docksly.app"
                    BlueprintName = "Docksly"
                    ReferencedContainer = "container:Docksly.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </LaunchAction>
           <ProfileAction
              buildConfiguration = "Release"
              shouldUseLaunchSchemeArgsEnv = "YES"
              savedToolIdentifier = ""
              useCustomWorkingDirectory = "NO"
              debugDocumentVersioning = "YES">
              <BuildableProductRunnable
                 runnableDebuggingMode = "0">
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "{target_ref}"
                    BuildableName = "Docksly.app"
                    BlueprintName = "Docksly"
                    ReferencedContainer = "container:Docksly.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </ProfileAction>
           <AnalyzeAction
              buildConfiguration = "Debug">
           </AnalyzeAction>
           <ArchiveAction
              buildConfiguration = "Release"
              revealArchiveInOrganizer = "YES">
           </ArchiveAction>
        </Scheme>
        """
    )
    (scheme_dir / "Docksly.xcscheme").write_text(scheme)
    print(f"Wrote {PROJECT}")


if __name__ == "__main__":
    main()

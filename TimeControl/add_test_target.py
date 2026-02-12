#!/usr/bin/env python3
"""
Script to add a test target to TimeControl.xcodeproj
This adds the TimeControlTests target and all test files to the Xcode project.
"""

import os
import sys

# Test files to add
TEST_FILES = [
    "CompilationTest.swift",
    "TodoItemTests.swift",
    "SubtaskTests.swift",
    "TodoStorageTests.swift",
    "TodoOperationsTests.swift",
    "TimeFormattingTests.swift",
]

def generate_uuid(base_id):
    """Generate a unique ID for Xcode project objects"""
    return f"A1{base_id:021d}"

# Start with ID 100 for test-related objects
current_id = 100

# Generate UUIDs for all objects we need to create
uuid_test_target = generate_uuid(current_id); current_id += 1
uuid_test_product_ref = generate_uuid(current_id); current_id += 1
uuid_test_group = generate_uuid(current_id); current_id += 1
uuid_test_sources_phase = generate_uuid(current_id); current_id += 1
uuid_test_frameworks_phase = generate_uuid(current_id); current_id += 1
uuid_test_resources_phase = generate_uuid(current_id); current_id += 1
uuid_test_dependency = generate_uuid(current_id); current_id += 1
uuid_test_target_dependency = generate_uuid(current_id); current_id += 1
uuid_test_container_proxy = generate_uuid(current_id); current_id += 1
uuid_test_build_config_list = generate_uuid(current_id); current_id += 1
uuid_test_debug_config = generate_uuid(current_id); current_id += 1
uuid_test_release_config = generate_uuid(current_id); current_id += 1

# Generate UUIDs for test files
test_file_uuids = {}
test_buildfile_uuids = {}
for test_file in TEST_FILES:
    test_file_uuids[test_file] = generate_uuid(current_id); current_id += 1
    test_buildfile_uuids[test_file] = generate_uuid(current_id); current_id += 1

def read_project():
    """Read the project.pbxproj file"""
    path = "TimeControl.xcodeproj/project.pbxproj"
    if not os.path.exists(path):
        print(f"Error: {path} not found")
        print("Please run this script from the TimeControl directory")
        sys.exit(1)
    
    with open(path, 'r') as f:
        return f.read()

def write_project(content):
    """Write the modified project.pbxproj file"""
    path = "TimeControl.xcodeproj/project.pbxproj"
    
    # Backup original
    backup_path = path + ".backup"
    with open(path, 'r') as f:
        with open(backup_path, 'w') as backup:
            backup.write(f.read())
    print(f"✅ Created backup: {backup_path}")
    
    # Write new content
    with open(path, 'w') as f:
        f.write(content)
    print(f"✅ Updated: {path}")

def add_test_target(content):
    """Add the test target to the project"""
    
    # 1. Add PBXBuildFile entries for test files
    build_files_section = "/* Begin PBXBuildFile section */"
    build_files_additions = []
    for test_file in TEST_FILES:
        build_files_additions.append(
            f"\t\t{test_buildfile_uuids[test_file]} /* {test_file} in Sources */ = {{isa = PBXBuildFile; fileRef = {test_file_uuids[test_file]} /* {test_file} */; }};"
        )
    
    # Find the end of PBXBuildFile section and add our entries
    insert_pos = content.find("/* End PBXBuildFile section */")
    content = content[:insert_pos] + "\n".join(build_files_additions) + "\n" + content[insert_pos:]
    
    # 2. Add PBXContainerItemProxy
    container_proxy_section = "/* End PBXBuildFile section */"
    container_proxy = f"""

/* Begin PBXContainerItemProxy section */
\t\t{uuid_test_container_proxy} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = A1000020000000000000001 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = A1000016000000000000001;
\t\t\tremoteInfo = TimeControl;
\t\t}};
/* End PBXContainerItemProxy section */
"""
    insert_pos = content.find(container_proxy_section) + len(container_proxy_section)
    content = content[:insert_pos] + container_proxy + content[insert_pos:]
    
    # 3. Add PBXFileReference entries for test files and test product
    file_ref_section = "/* End PBXFileReference section */"
    file_refs = [
        f"\t\t{uuid_test_product_ref} /* TimeControlTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TimeControlTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
    ]
    for test_file in TEST_FILES:
        file_refs.append(
            f"\t\t{test_file_uuids[test_file]} /* {test_file} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {test_file}; sourceTree = \"<group>\"; }};"
        )
    
    insert_pos = content.find(file_ref_section)
    content = content[:insert_pos] + "\n".join(file_refs) + "\n" + content[insert_pos:]
    
    # 4. Add PBXFrameworksBuildPhase for tests
    frameworks_section = "/* End PBXFrameworksBuildPhase section */"
    frameworks_phase = f"""\t\t{uuid_test_frameworks_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    insert_pos = content.find(frameworks_section)
    content = content[:insert_pos] + frameworks_phase + content[insert_pos:]
    
    # 5. Add PBXGroup for test files and update Products group
    # First, add TimeControlTests group
    group_section = "/* End PBXGroup section */"
    test_files_list = ",\n".join([f"\t\t\t\t{test_file_uuids[test_file]} /* {test_file} */" for test_file in TEST_FILES])
    test_group = f"""\t\t{uuid_test_group} /* TimeControlTests */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{test_files_list},
\t\t\t);
\t\t\tpath = TimeControlTests;
\t\t\tsourceTree = \"<group>\";
\t\t}};
"""
    insert_pos = content.find(group_section)
    content = content[:insert_pos] + test_group + content[insert_pos:]
    
    # Update root group to include TimeControlTests
    root_group_pattern = "A1000013000000000000001 /* TimeControl */,"
    content = content.replace(
        root_group_pattern,
        f"{root_group_pattern}\n\t\t\t\t{uuid_test_group} /* TimeControlTests */,"
    )
    
    # Update Products group
    products_pattern = "A1000009000000000000001 /* TimeControl.app */,"
    content = content.replace(
        products_pattern,
        f"{products_pattern}\n\t\t\t\t{uuid_test_product_ref} /* TimeControlTests.xctest */,"
    )
    
    # 6. Add PBXNativeTarget for tests
    native_target_section = "/* End PBXNativeTarget section */"
    test_target = f"""\t\t{uuid_test_target} /* TimeControlTests */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {uuid_test_build_config_list} /* Build configuration list for PBXNativeTarget "TimeControlTests" */;
\t\t\tbuildPhases = (
\t\t\t\t{uuid_test_sources_phase} /* Sources */,
\t\t\t\t{uuid_test_frameworks_phase} /* Frameworks */,
\t\t\t\t{uuid_test_resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t{uuid_test_dependency} /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = TimeControlTests;
\t\t\tproductName = TimeControlTests;
\t\t\tproductReference = {uuid_test_product_ref} /* TimeControlTests.xctest */;
\t\t\tproductType = "com.apple.product-type.bundle.unit-test";
\t\t}};
"""
    insert_pos = content.find(native_target_section)
    content = content[:insert_pos] + test_target + content[insert_pos:]
    
    # 7. Update PBXProject to include test target
    project_targets = "A1000016000000000000001 /* TimeControl */,"
    content = content.replace(
        project_targets,
        f"{project_targets}\n\t\t\t\t{uuid_test_target} /* TimeControlTests */,"
    )
    
    # Update TargetAttributes
    target_attrs_pattern = "A1000016000000000000001 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t};"
    content = content.replace(
        target_attrs_pattern,
        f"""A1000016000000000000001 = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t}};
\t\t\t\t\t{uuid_test_target} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t\tTestTargetID = A1000016000000000000001;
\t\t\t\t\t}};"""
    )
    
    # 8. Add PBXResourcesBuildPhase for tests
    resources_section = "/* End PBXResourcesBuildPhase section */"
    resources_phase = f"""\t\t{uuid_test_resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    insert_pos = content.find(resources_section)
    content = content[:insert_pos] + resources_phase + content[insert_pos:]
    
    # 9. Add PBXSourcesBuildPhase for tests
    sources_section = "/* End PBXSourcesBuildPhase section */"
    source_files_list = ",\n".join([f"\t\t\t\t{test_buildfile_uuids[test_file]} /* {test_file} in Sources */" for test_file in TEST_FILES])
    sources_phase = f"""\t\t{uuid_test_sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{source_files_list},
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
    insert_pos = content.find(sources_section)
    content = content[:insert_pos] + sources_phase + content[insert_pos:]
    
    # 10. Add PBXTargetDependency
    target_dep_section = "/* End PBXSourcesBuildPhase section */"
    target_dep = f"""

/* Begin PBXTargetDependency section */
\t\t{uuid_test_dependency} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = A1000016000000000000001 /* TimeControl */;
\t\t\ttargetProxy = {uuid_test_container_proxy} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */
"""
    insert_pos = content.find(target_dep_section) + len(target_dep_section)
    content = content[:insert_pos] + target_dep + content[insert_pos:]
    
    # 11. Add XCBuildConfiguration for tests
    build_config_section = "/* End XCBuildConfiguration section */"
    test_debug_config = f"""\t\t{uuid_test_debug_config} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.TimeControlTests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/TimeControl.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TimeControl";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uuid_test_release_config} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.TimeControlTests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/TimeControl.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TimeControl";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
    insert_pos = content.find(build_config_section)
    content = content[:insert_pos] + test_debug_config + content[insert_pos:]
    
    # 12. Add XCConfigurationList for tests
    config_list_section = "/* End XCConfigurationList section */"
    test_config_list = f"""\t\t{uuid_test_build_config_list} /* Build configuration list for PBXNativeTarget "TimeControlTests" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uuid_test_debug_config} /* Debug */,
\t\t\t\t{uuid_test_release_config} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""
    insert_pos = content.find(config_list_section)
    content = content[:insert_pos] + test_config_list + content[insert_pos:]
    
    return content

def main():
    """Main function"""
    print("=" * 50)
    print("Adding Test Target to TimeControl")
    print("=" * 50)
    print()
    
    # Check if we're in the right directory
    if not os.path.exists("TimeControl.xcodeproj"):
        print("❌ Error: TimeControl.xcodeproj not found")
        print("Please run this script from the TimeControl directory")
        sys.exit(1)
    
    # Check if test files exist
    print("Checking test files...")
    missing = []
    for test_file in TEST_FILES:
        path = f"TimeControlTests/{test_file}"
        if os.path.exists(path):
            print(f"✅ {path}")
        else:
            print(f"❌ {path} (missing)")
            missing.append(test_file)
    
    if missing:
        print()
        print(f"❌ Missing {len(missing)} test file(s)")
        sys.exit(1)
    
    print()
    print("Reading project file...")
    content = read_project()
    
    # Check if test target already exists
    if "TimeControlTests" in content:
        print("⚠️  Test target already exists in project")
        print("No changes made")
        sys.exit(0)
    
    print("Adding test target...")
    modified_content = add_test_target(content)
    
    print("Writing updated project...")
    write_project(modified_content)
    
    print()
    print("=" * 50)
    print("✅ Test target added successfully!")
    print("=" * 50)
    print()
    print("Next steps:")
    print("1. Open the project: open TimeControl.xcodeproj")
    print("2. Build the project: Cmd+B")
    print("3. Run tests: Cmd+U")
    print()
    print("Or run tests from command line:")
    print("  xcodebuild test -scheme TimeControl -destination 'platform=macOS'")
    print()

if __name__ == "__main__":
    main()

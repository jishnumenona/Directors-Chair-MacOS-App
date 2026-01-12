# Test Fixtures Setup - CRITICAL STEP

## Current Status

✅ DirectorsChairCore package added to project
✅ Test files (JSONCompatibilityTests.swift, PerformanceTests.swift) added to project
❌ Test fixtures added to WRONG TARGET (DirectorsChair-Desktop instead of DirectorsChair-DesktopTests)
⚠️ **MUST FIX:** Remove from main app target, add to TEST target

## Problem

The tests are running but failing immediately (in 0.001-0.041 seconds) because they can't find the JSON fixture files:
- `minimal_project.json`
- `comprehensive_project.json`

**Root Cause (2026-01-08 12:23):**
The fixtures were accidentally added to the **WRONG TARGET**:
- ❌ Currently in: `DirectorsChair-Desktop` (main app target)
- ✅ Should be in: `DirectorsChair-DesktopTests` (test target)

The tests look for fixtures in the **test bundle**, not the main app bundle!

## Solution: Move Fixtures to Correct Target

### CRITICAL: Two-Step Process

**First, REMOVE from wrong target:**
1. Select **DirectorsChair-Desktop** target (main app)
2. Build Phases → Copy Bundle Resources
3. Find and REMOVE both JSON files (click "-" button)

**Then, ADD to correct target:**
1. Select **DirectorsChair-DesktopTests** target (TEST target)
2. Build Phases → Copy Bundle Resources
3. Add both JSON files (click "+" button)

---

## Original Instructions (For Reference)

### Step-by-Step Instructions

1. **In Xcode, select the DirectorsChair-DesktopTests target**
   - In the left sidebar (Project Navigator), click on the blue "DirectorsChair-Desktop" project icon at the very top
   - In the TARGETS section (middle panel), select **DirectorsChair-DesktopTests**

2. **Go to the Build Phases tab**
   - At the top, you'll see tabs: General, Signing & Capabilities, Resource Tags, Info, **Build Phases**, Build Settings, Build Rules
   - Click on **Build Phases**

3. **Expand "Copy Bundle Resources" section**
   - You'll see several collapsed sections
   - Find and click on **"Copy Bundle Resources"** to expand it

4. **Add the Fixtures folder**
   - Click the **"+"** button under "Copy Bundle Resources"
   - A file browser dialog will appear
   - Navigate to and select the **Fixtures** folder:
     ```
     DirectorsChair-DesktopTests/Fixtures
     ```
   - Make sure BOTH files inside are visible:
     - `minimal_project.json`
     - `comprehensive_project.json`
   - Click **"Add"**

5. **Verify the files were added**
   - You should now see in the "Copy Bundle Resources" section:
     ```
     Fixtures/minimal_project.json
     Fixtures/comprehensive_project.json
     ```
   - OR you might see just:
     ```
     Fixtures
     ```
   - Either way is fine!

### Alternative Method (If the above doesn't work)

If you don't see the Fixtures folder or it doesn't add properly:

1. In "Copy Bundle Resources", click the "+" button
2. Click "Add Other..." at the bottom of the dialog
3. Navigate to:
   ```
   /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop/DirectorsChair-DesktopTests/Fixtures
   ```
4. Select BOTH JSON files:
   - Hold Command (⌘) and click both files
   - `minimal_project.json`
   - `comprehensive_project.json`
5. Make sure "Copy items if needed" is **UNCHECKED** (we want references, not copies)
6. Click "Add"

### After Adding the Fixtures

Run the tests again:

**In Xcode:**
- Press ⌘U (Product → Test)

**Or in Terminal:**
```bash
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop
xcodebuild test -scheme DirectorsChair-Desktop -destination 'platform=macOS'
```

## Expected Results After Fix

Once the fixtures are properly added, you should see:

```
✅ Test Case 'testLoadMinimalPythonProject' passed (0.XXX seconds)
    ✅ Minimal project loaded successfully!

✅ Test Case 'testLoadComprehensivePythonProject' passed (0.XXX seconds)
    ✅ Comprehensive project loaded successfully!
    - Validated project metadata
    - Validated 2 characters with 70+ fields
    - Validated scene with 3 dialogues

✅ Test Case 'testCharacterWith70PlusFields' passed (0.XXX seconds)
    ✅ Character validation complete: All 70+ fields validated!
    - Basic info: ✓
    - Physical appearance (12 fields): ✓
    - Personality traits (25 traits): ✓
    - Biography: ✓
    - Images (12-angle system): ✓
    - Costumes: ✓

✅ Test Case 'testJSONFieldNaming' passed (0.XXX seconds)
    ✅ CodingKeys validation complete!
    - snake_case (Python JSON) → camelCase (Swift) mapping: ✓
    - All fields decoded correctly: ✓

❌ Test Case 'testSwiftPythonRoundTrip' failed (0.XXX seconds)
    ⚠️ Expected failure - waiting on Agent 1's ProjectPersistence

✅ Test Case 'testLoadPerformance' passed (0.XXX seconds)
```

**Expected Pass Rate:** 5 out of 6 tests (83%)

## How to Verify Fixtures are in Bundle

After adding the fixtures, you can verify they're being copied:

```bash
# Build the tests
xcodebuild build-for-testing -scheme DirectorsChair-Desktop -destination 'platform=macOS'

# Find the test bundle
find ~/Library/Developer/Xcode/DerivedData/DirectorsChair-Desktop-*/Build/Products/Debug -name "DirectorsChair-DesktopTests.xctest" -type d

# List contents of test bundle (replace path with output from above)
ls -la [PATH_TO_TEST_BUNDLE]/Contents/Resources/
```

You should see the Fixtures folder with both JSON files inside.

## Still Having Issues?

If the tests still fail after adding fixtures:

1. **Clean Build Folder**
   - Product → Clean Build Folder (⇧⌘K)
   - Try building again

2. **Check File References**
   - In Project Navigator, click on `Fixtures` folder
   - In the File Inspector (right sidebar), check:
     - Location should be "Relative to Group"
     - Target Membership should include "DirectorsChair-DesktopTests"

3. **Verify JSON Files**
   - Make sure the JSON files aren't corrupted:
   ```bash
   cat DirectorsChair-DesktopTests/Fixtures/minimal_project.json | python3 -m json.tool > /dev/null && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
   cat DirectorsChair-DesktopTests/Fixtures/comprehensive_project.json | python3 -m json.tool > /dev/null && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
   ```

---

**Created:** 2026-01-08
**Status:** ⚠️ CRITICAL - This step must be completed for tests to pass
**Impact:** Blocks Phase 1 gate validation

# Agent 5: QA & Testing - Next Steps

## Current Status

✅ **Phase 1 Infrastructure: 100% Complete**

All test infrastructure has been created and is ready for validation. However, the test files need to be manually added to the Xcode project to run.

---

## Test Files Created

All files are located in `DirectorsChair-DesktopTests/`:

### Test Suites
1. **JSONCompatibilityTests.swift** (295 lines, 8 test methods)
   - ✅ Imports DirectorsChairCore
   - ✅ Tests loading Python JSON → Swift models
   - ✅ Validates 70+ Character fields
   - ✅ Tests CodingKeys mapping (snake_case ↔ camelCase)
   - ⏸️ Round-trip tests (waiting on ProjectPersistence)

2. **PerformanceTests.swift** (292 lines, 12 benchmarks)
   - Timeline rendering performance (60fps target)
   - Save/Load performance (<500ms target)
   - AI latency tests
   - Memory usage tests

### Test Fixtures
3. **Fixtures/minimal_project.json** (1,640 bytes)
   - Basic project structure for round-trip testing

4. **Fixtures/comprehensive_project.json** (10,929 bytes)
   - Full project with 2 characters (70+ fields)
   - 3 dialogues with tags, costumes, effects
   - All production data

---

## Manual Steps Required

### Step 1: Add Test Files to Xcode Project

**You MUST manually add the following files to the Xcode project:**

1. Open `DirectorsChair-Desktop.xcodeproj` in Xcode
2. Select the `DirectorsChair-DesktopTests` target in Project Navigator
3. Right-click and select "Add Files to DirectorsChair-Desktop..."
4. Add these files:
   - `DirectorsChair-DesktopTests/JSONCompatibilityTests.swift`
   - `DirectorsChair-DesktopTests/PerformanceTests.swift`
5. **IMPORTANT**: Ensure "Target Membership" checkbox for `DirectorsChair-DesktopTests` is checked

### Step 2: Add Test Fixtures as Resources

1. Select `DirectorsChair-DesktopTests` target
2. Go to "Build Phases" tab
3. Expand "Copy Bundle Resources"
4. Click "+" and add:
   - `DirectorsChair-DesktopTests/Fixtures/minimal_project.json`
   - `DirectorsChair-DesktopTests/Fixtures/comprehensive_project.json`

### Step 3: Link DirectorsChairCore Module

1. Select `DirectorsChair-DesktopTests` target
2. Go to "Build Phases" tab
3. Expand "Link Binary With Libraries"
4. Click "+" and add:
   - `DirectorsChairCore` (the Swift package)

### Step 4: Update Test Scheme

1. Select Product → Scheme → Edit Scheme...
2. Select "Test" in left sidebar
3. Ensure `DirectorsChair-DesktopTests` is checked
4. Click "Close"

---

## Running the Tests

Once the files are added to Xcode:

### Command Line
```bash
xcodebuild test -scheme DirectorsChair-Desktop -destination 'platform=macOS'
```

### In Xcode
1. Select Product → Test (⌘U)
2. Or click the diamond icon next to each test method
3. Or use the Test Navigator (⌘6) to run specific tests

---

## Expected Test Results

### JSON Compatibility Tests

**testLoadMinimalPythonProject():**
- Should PASS ✅
- Validates basic project loading
- Checks sequences, scenes, empty collections

**testLoadComprehensivePythonProject():**
- Should PASS ✅
- Validates full project with all metadata
- Checks 2 characters with 70+ fields
- Validates 3 dialogues with tags

**testCharacterWith70PlusFields():**
- Should PASS ✅
- Validates all Character fields:
  - Basic info (name, role, color)
  - Physical appearance (12 fields)
  - Personality traits (25 traits in dictionary)
  - Biography (backstory, occupation)
  - Images (12-angle system)
  - Costumes

**testJSONFieldNaming():**
- Should PASS ✅
- Validates CodingKeys mapping:
  - `project_type` → `projectType`
  - `target_duration` → `targetDuration`
  - `production_company` → `productionCompany`
  - `text_color` → `textColor`
  - `height_cm` → `heightCm`

**testSwiftPythonRoundTrip():**
- Will FAIL currently (expected) ⏸️
- Waiting on Agent 1's ProjectPersistence implementation
- Needs encode capability, not just decode

**testLoadPerformance():**
- Should PASS ✅
- Measures JSON load time
- Target: <500ms for typical project

### Performance Tests

Most performance tests will FAIL initially (expected) ⏸️:
- Timeline tests: Waiting on Agent 4
- Save tests: Waiting on Agent 1 persistence layer
- AI tests: Waiting on Agent 3

---

## Troubleshooting

### Build Errors

**"No such module 'DirectorsChairCore'"**
- Ensure DirectorsChairCore is built
- Check Framework Search Paths
- Verify target membership

**"Cannot find 'Project' in scope"**
- Import statement might be missing
- Check that DirectorsChairCore module exports Project type publicly

**"Bundle resource not found"**
- Fixtures not added to Copy Bundle Resources
- Check Build Phases → Copy Bundle Resources

### Test Failures

**"Fixture not found"**
- Fixtures not copied to test bundle
- Add to Copy Bundle Resources in Build Phases

**"Decoding error"**
- CodingKeys mismatch
- Check Agent 1's model implementation
- Verify snake_case ↔ camelCase mapping

**"Type mismatch"**
- Field types don't match JSON
- Check fixture JSON structure
- Verify model field types

---

## Reporting Issues to Agent 1

If tests fail, post in `docs/shared/messages.md`:

```markdown
## [ISO Timestamp] - Agent 5 → Agent 1
**Subject**: Test Failure - [Test Name]

**Test Failed**: testXXX()
**Error**: [Error message]
**Expected**: [What should happen]
**Actual**: [What happened]

**Model Affected**: [Model name]
**Field**: [Field name if applicable]

**Fixture**: [Which JSON file]

**Suggested Fix**: [What needs to change]

**Response Required**: Yes
**Urgency**: 🔴 High (blocks Phase 1 gate)
```

---

## Phase 1 Gate Criteria

Before Agent 1 can proceed to Phase 2:

- ✅ All 27 data models compile (DONE)
- ⏸️ JSON decode test passes (ready to test - needs manual Xcode setup)
- ⏸️ JSON encode test passes (waiting on persistence)
- ⏸️ Round-trip test passes (waiting on persistence)
- ⏸️ EventBus functional (Agent 1 working on it)

**Current Status**: 1/5 criteria met

**Blocker**: Test files need to be added to Xcode project manually

---

## Communication

### Message Posted to Agent 1

Check `docs/shared/messages.md` for coordination message.

**Awaiting Response**: Yes

**Topics**:
- Confirmation of CodingKeys implementation ✅
- Status of JSON persistence layer ⏸️
- Permission to run tests once Xcode setup complete

---

## Next Session Tasks

1. Add test files to Xcode project (manual)
2. Add fixtures as bundle resources (manual)
3. Run tests and verify results
4. Report any failures to Agent 1
5. Document test results in status.md
6. Update feature_parity_checklist.md with validated items

---

**Created**: 2026-01-08T18:30:00Z
**Status**: Ready for manual Xcode configuration
**Urgency**: 🟡 Medium (blocks Phase 1 gate validation)

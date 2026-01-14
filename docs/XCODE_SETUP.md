# Xcode Project Setup Guide

This guide walks through configuring the DirectorsChair-Desktop Xcode project to build successfully.

## Prerequisites

- Xcode 15.0 or later
- macOS 14.0 (Sonoma) or later
- All Swift packages in the workspace

## Current Status

✅ **Already Configured:**
- DirectorsChairCore package (added and resolved)

❌ **Missing Package Dependencies:**
- DirectorsChairViews (contains BubbleView, TimelineView, StoryDesignView, VisionBoardView, CinematographyView)
- DirectorsChairProduction (contains ScheduleView, CastCrewView, BudgetView)

## Step-by-Step Configuration

### 1. Open the Xcode Project

```bash
cd /Users/jishnumenonasokakumar/Workspaces/Technical/DirectorsChair/DirectorsChair-Desktop
open DirectorsChair-Desktop.xcodeproj
```

### 2. Add DirectorsChairViews Package

1. In Xcode, select the **DirectorsChair-Desktop** project in the navigator (blue icon at top)
2. Select the **DirectorsChair-Desktop** target (not the project)
3. Go to the **"General"** tab
4. Scroll down to **"Frameworks, Libraries, and Embedded Content"** section
5. Click the **"+"** button
6. Click **"Add Other..." → "Add Local..."**
7. Navigate to: `DirectorsChairViews`
8. Select the `DirectorsChairViews` folder and click **"Add"**
9. In the dialog, select **"DirectorsChairViews"** library
10. Click **"Add"**

### 3. Add DirectorsChairProduction Package

Repeat the same steps for DirectorsChairProduction:

1. Click the **"+"** button again in "Frameworks, Libraries, and Embedded Content"
2. Click **"Add Other..." → "Add Local..."**
3. Navigate to: `DirectorsChairProduction`
4. Select the `DirectorsChairProduction` folder and click **"Add"**
5. In the dialog, select **"DirectorsChairProduction"** library
6. Click **"Add"**

### Alternative Method: Using Package Dependencies Tab

1. Select the **DirectorsChair-Desktop** project (blue icon)
2. Go to **"Package Dependencies"** tab
3. Click the **"+"** button
4. Select **"Add Local..."**
5. Navigate to `DirectorsChairViews` and click **"Add Package"**
6. Repeat for `DirectorsChairProduction`

### 4. Verify Package Resolution

After adding the packages:

1. Go to **File → Packages → Resolve Package Versions**
2. Wait for Xcode to resolve dependencies
3. Check for any errors in the Issue Navigator (⌘+5)

You should see:
- ✅ DirectorsChairCore
- ✅ DirectorsChairViews
- ✅ DirectorsChairProduction

### 5. Build the Project

1. Select **Product → Clean Build Folder** (⌘+Shift+K)
2. Select **Product → Build** (⌘+B)

**Expected Result:** Build should succeed with 0 errors

## Package Dependencies Overview

```
DirectorsChair-Desktop (Main App)
├── DirectorsChairCore (Models, Persistence, Event Bus)
├── DirectorsChairViews (UI Components from Agents 2 & 3)
│   ├── BubbleView (Dialogue editor)
│   ├── TimelineView (Timeline visualization)
│   ├── StoryDesignView (Story structure)
│   ├── VisionBoardView (Visual references)
│   └── CinematographyView (Shot list)
└── DirectorsChairProduction (Production Planning from Agent 4)
    ├── ScheduleView (Production schedule)
    ├── CastCrewView (Cast & crew management)
    └── BudgetView (Budget tracking)
```

## Troubleshooting

### Error: "No such module 'DirectorsChairViews'"

**Cause:** Package not added to project dependencies

**Solution:**
1. Follow steps 2-3 above to add the package
2. Clean build folder (⌘+Shift+K)
3. Rebuild (⌘+B)

### Error: "No such module 'DirectorsChairProduction'"

**Cause:** Package not added to project dependencies

**Solution:**
1. Follow step 3 above to add the package
2. Clean build folder
3. Rebuild

### Error: Package resolution fails

**Cause:** Package.swift file misconfigured or circular dependencies

**Solution:**
1. Check Package.swift in each package folder
2. Verify dependency paths are correct (relative `../` paths)
3. Try **File → Packages → Reset Package Caches**

### Error: "Type 'BubbleView' is ambiguous"

**Cause:** Multiple definitions or import conflicts

**Solution:**
1. Check imports at top of ContentView.swift
2. Ensure only one import per package
3. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/DirectorsChair*`

## Verification Checklist

After setup, verify:

- [ ] Project builds without errors (⌘+B)
- [ ] All 3 packages show in Project Navigator under "Package Dependencies"
- [ ] No red errors in any Swift files
- [ ] App runs (⌘+R) and shows window

## Post-Setup Testing

Once the build succeeds:

1. **Run the app** (⌘+R)
2. **Test basic navigation:**
   - Overview tab shows project stats
   - Scenes tab lists scenes
   - Settings tab shows project metadata
3. **Test New Project dialog:**
   - File → New Project (⌘+N)
   - Fill in project details
   - Choose save location
   - Verify project creates

## Next Steps

After successful configuration:

1. **Create sample project** for testing
2. **Test all 11 views** for functionality
3. **Verify file I/O** (save/load project files)
4. **Test auto-save** mechanism
5. **Validate error handling** (try invalid operations)

## Package Locations

All packages are in the same workspace:

```
DirectorsChair-Desktop/
├── DirectorsChair-Desktop/       # Main app source
├── DirectorsChairCore/           # Core models & persistence
├── DirectorsChairViews/          # UI views (Agents 2 & 3)
├── DirectorsChairProduction/     # Production views (Agent 4)
├── DirectorsChairServices/       # AI & services
└── DirectorsChairExports/        # Export formats
```

## Support

If you encounter issues not covered here:

1. Check `docs/shared/integration_log.md` for recent changes
2. Review commit history for package updates
3. Verify all packages build independently: `swift build` in each package directory

## Build Status Reference

Last successful build configuration:
- **Date:** 2026-01-14
- **Xcode:** 15.0+
- **macOS:** 14.0+ (Sonoma)
- **Swift:** 5.10
- **Packages:** Core, Views, Production

---

**Note:** This is a one-time setup. Once configured, the packages will remain linked to the project.

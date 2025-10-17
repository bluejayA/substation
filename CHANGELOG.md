# Changelog

All notable changes to Substation will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-16

### Breaking Changes

**Command-based navigation is now the ONLY supported interface.** Single-key navigation handlers have been completely removed from the codebase.

This is a major version bump due to the complete removal of legacy navigation patterns. All navigation must now use command-based syntax (`:servers`, `:create`, etc.).

### Removed

**Complete Single-Key Navigation Removal**:
- All lowercase single-key navigation handlers removed (d, k, s, g, r, n, u, e, l, p, v, i, f, h, b, o, j, t, m, z)
- Legacy single-key action handlers removed (a, c, r for auto-refresh, cache, refresh)
- Duplicate case statements cleaned up (removed duplicate Int32(82) for 'R' key)
- NavigationPreferences mode logic retained for future compatibility but single-key handlers gone
- Approximately 400+ lines of legacy code removed from InputHandler.swift

**Help Text Cleanup**:
- All single-key references removed from UIUtils.swift help text
- Mode-aware formatHelp() method simplified to command-only
- Help text now shows only command syntax (`:create` instead of `C/:create`)

### Added

#### Phase 3: Command-Only Mode as Default

- **Default Navigation Mode**: Changed from hybrid to command-only mode
  - New users start with command-based navigation
  - Existing users maintain their configured mode (backward compatible)
  - Migration notice displayed to users upgrading from hybrid mode

- **Welcome System**: First-run tutorial and onboarding
  - Interactive welcome screen for new users
  - Tutorial system with step-by-step guidance (`:tutorial`)
  - Quick start guide and command examples
  - Automatic first-run detection

- **Command Discovery Features**:
  - `:tutorial` - Interactive walkthrough of command-based navigation
  - `:shortcuts` - Quick reference of frequently used commands
  - `:examples` - Real-world workflow examples
  - `:welcome` - Display welcome message again

- **Enhanced User Experience**:
  - Helpful hints when pressing unmapped letter keys in command-only mode
  - Mode-aware help text (command-focused in command-only mode)
  - Improved tab completion includes discovery commands
  - Better first-time user experience

#### Configuration & Migration

- **Migration Detection**: Automatically detects users upgrading from v1.x
  - Shows migration notice explaining command-only mode
  - Preserves existing user preferences
  - Optional acknowledgment system to prevent repeated notices

- **WelcomeScreen Utility**: New utility for managing onboarding
  - First-run detection via marker file
  - Multiple tutorial formats (welcome, quick start, full tutorial)
  - Command examples and workflow documentation

### Changed

- **NavigationPreferences**: Default mode changed from `.hybrid` to `.commandOnly`
- **UIUtils Help System**: Now command-focused by default
  - Continues to support legacy/hybrid modes for backwards compatibility
  - Mode indicator in help footer
  - Dynamic help text based on current mode

- **InputHandler**: Enhanced fallback handling
  - Unmapped keys show helpful command suggestions
  - Better user guidance when single-key navigation is disabled

- **ResourceRegistry**: Extended command registry
  - Added discovery commands (tutorial, shortcuts, examples, welcome)
  - Improved command categorization
  - Enhanced tab completion coverage

### Migration Guide

#### For New Users

Welcome to Substation 2.0! You'll be using command-based navigation:

1. Press `:` (colon) to enter command mode
2. Press `Tab` to see available commands
3. Type `:tutorial` for an interactive walkthrough
4. Type `:help` for comprehensive documentation

#### For Existing Users

If you were using hybrid mode (default in v1.x):

**Your settings are preserved** - You'll continue using hybrid mode with no changes required.

However, we recommend trying command-only mode for a cleaner, more intuitive experience:

```bash
# Try command-only mode
:command-mode commandOnly

# Revert to hybrid if needed
:command-mode hybrid

# Or use legacy mode (single-key only)
:command-mode legacy
```

**Benefits of command-only mode:**
- Cleaner help text
- No accidental single-key triggers
- More discoverable actions
- Consistent with modern CLI tools

**Command equivalents for single-keys:**
- `d` -> `:dashboard` or `:dash`
- `s` -> `:servers` or `:srv`
- `n` -> `:networks` or `:net`
- `v` -> `:volumes` or `:vol`
- `C` -> `:create`
- `R` -> `:restart`
- `S` -> `:start`
- `T` -> `:stop`

See full mapping with `:shortcuts` or `:examples`

### Technical Notes

#### Files Added
- `Sources/Substation/Utilities/WelcomeScreen.swift` - Onboarding system
- `CHANGELOG.md` - Project changelog (this file)
- `ModelMemory/phase3-migration-guide.md` - Detailed migration documentation

#### Files Modified
- `Sources/Substation/Navigation/NavigationPreferences.swift` - Default mode change, migration logic
- `Sources/Substation/Navigation/CommandMode.swift` - Discovery command results
- `Sources/Substation/Navigation/ResourceRegistry.swift` - Discovery commands added
- `Sources/Substation/Utilities/UIUtils.swift` - Help system updates
- `Sources/Substation/Managers/InputHandler.swift` - Fallback handler improvements

#### Configuration

**Preference File**: `~/.config/substation/preferences.json`
**Welcome Marker**: `~/.config/substation/.welcome_shown`

Preferences persist across restarts. Delete preference file to reset to defaults.

### Backward Compatibility

Full backward compatibility maintained:
- Legacy mode: single-key navigation only (like v1.x)
- Hybrid mode: both single-key and commands (former default)
- Command-only mode: commands only (new default)

All existing features work in all modes. No functionality removed.

### Testing

Tested configurations:
- Fresh install (first-run experience)
- Upgrade from v1.x with preferences (migration path)
- All three navigation modes (legacy, hybrid, command-only)
- Command discovery features
- Tab completion with new commands

### Known Issues

None at release.

### Future Enhancements

Planned for v2.1:
- User-defined command aliases (`:alias` command)
- Enhanced command history with persistence
- Command usage statistics
- Command recommendation system

---

## [1.x] - Previous Versions

See git history for changes in v1.x series. Version 2.0 represents the first major version with changelog documentation.


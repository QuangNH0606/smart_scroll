# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.4]

### Fixed
- **Static Analysis**: Fixed missing type annotations in `ClassicHeader` and `ClassicFooter` to satisfy `flutter analyze`.

### Improved
- **Package Metadata**: Updated description and topics for better clarity.

## [1.0.3]

### Improved
- **Core Performance**: Completely eliminated `O(N)` widget tree traversal during `applyBoundaryConditions` scroll loops by utilizing an `O(1)` cached `renderSliver` lookup. 
- **Core Performance**: Removed excessive `InheritedWidget` listener dependency inside the rendering pipeline (`updateRenderObject`).
- **Core Performance**: Optimized `math.pow` calculations in scroll physics friction, swapping it out for direct mathematical multiplication for extreme 120Hz consistency.

## [1.0.2]

### Added
- **PlatformHeader** — native-adaptive refresh indicator (iOS Cupertino / Android Material)
- **PlatformFooter** — native-adaptive load-more footer
- **BuilderHeader** / **BuilderFooter** — custom indicator API with `dragProgress`, `offset`, `triggered` data
- `RefreshIndicatorData` / `LoadIndicatorData` — rich state classes for custom animation builders
- `RefreshController` convenience methods: `refreshCompleted()`, `loadComplete()`, `loadFailed()`, `loadNoData()`, `resetNoData()`
- GitHub Actions CI workflow (analyze, format, test)
- PR template, issue templates, CONTRIBUTING.md

### Improved
- Scroll physics: cached configuration values to avoid per-frame InheritedWidget lookups
- Platform-aware overscroll behavior (iOS bouncing vs Android clamping)
- Reduced unnecessary rebuilds in indicator state management

### Fixed
- Removed stale TODO comments and unnecessary overrides
- Fixed lint warnings across all source files
- Cleaned up code formatting

## [1.0.1] 

### Fixed
- Resolved lint warnings
- Fixed override annotation issues
- Improved constructor parameter handling

### Added
- Added country code support for internationalization
- Enhanced error handling and edge cases
- Improved documentation and code comments


## [1.0.0] 

### Added
- Initial release of smart_scroll package
- Comprehensive list scrolling, pull refresh, and load more functionality
- Multiple indicator styles: Bezier, Classic, Custom, Link, Material, TwoLevel, and WaterDrop
- Support for both refresh and load more operations
- Fully customizable with various animation styles and themes
- Extensive documentation and examples
- Cross-platform compatibility (iOS, Android, Web, Desktop)

## [0.0.1]

### Added
- Initial development release

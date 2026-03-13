# Contributing to smart_scroll

Thank you for your interest in contributing! 🎉

## Getting Started

1. **Fork & clone** the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the example app:
   ```bash
   cd example && flutter run
   ```

## Development Workflow

### Before you code

- Check [existing issues](../../issues) to avoid duplicate work
- For new features, open an issue first to discuss the approach

### Code style

- Run `dart format .` before committing
- Run `flutter analyze --fatal-infos` — must pass with **0 issues**
- Follow existing code patterns and naming conventions

### Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add PlatformHeader indicator
fix: resolve overscroll on NestedScrollView
docs: update README with BuilderHeader example
refactor: simplify physics caching logic
ci: add format check to workflow
```

### Testing

- Add tests for new features when possible
- Run `flutter test` before submitting
- Test on both **iOS** and **Android** for UI changes

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commits
3. Update `CHANGELOG.md` under `## Unreleased`
4. Update the example app if adding new features
5. Open a PR using the template — fill in all sections
6. Wait for CI to pass ✅
7. Request review

## Project Structure

```
lib/
├── smart_scroll.dart              # Public API exports
└── src/
    ├── smart_refresher.dart       # Core SmartScroll widget & RefreshController
    ├── indicator/
    │   ├── classic_indicator.dart  # ClassicHeader / ClassicFooter
    │   ├── platform_indicator.dart # PlatformHeader / PlatformFooter (native)
    │   ├── builder_indicator.dart  # BuilderHeader / BuilderFooter (custom)
    │   ├── material_indicator.dart # MaterialClassicHeader
    │   ├── bezier_indicator.dart   # BezierCircleHeader
    │   ├── waterdrop_header.dart   # WaterDropHeader
    │   └── custom_indicator.dart   # CustomHeader / CustomFooter (legacy)
    └── internals/
        ├── indicator_wrap.dart     # Base indicator state management
        ├── slivers.dart            # Custom render slivers
        ├── refresh_physics.dart    # Scroll physics with overscroll control
        └── refresh_localizations.dart # i18n support
```

## Questions?

Open an issue with the **question** label, or start a discussion.

Thank you for helping make smart_scroll better! 🚀

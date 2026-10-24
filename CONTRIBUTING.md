# Contributing to Fley

Thank you for your interest in contributing to Fley! Please take a moment to review the following guidelines to keep the codebase clean, robust, and maintainable.

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
- Android SDK (`minSdk` 21, `targetSdk` 34+)
- Java Development Kit (JDK 17)

### Development Setup
1. Fork the repository and clone your fork:
   ```bash
   git clone https://github.com/<your-username>/Fley.git
   cd Fley
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run code analysis to verify your environment:
   ```bash
   flutter analyze
   ```
4. Run the app on a connected Android device or emulator:
   ```bash
   flutter run
   ```

---

## Coding Standards

- **Static Analysis**: All code must pass `flutter analyze` without errors or warnings.
- **Performance**:
  - Avoid `shrinkWrap: true` on unconstrained scroll views.
  - Utilize slivers (`CustomScrollView`, `SliverGrid`, `SliverList`) or `ListView.builder` for list virtualization.
  - Avoid blocking the main UI thread with heavy native channel calls.
- **State Management**: Keep state flow predictable. State mutations belong in dedicated domain logic controllers, not embedded directly inside UI rendering widgets.
- **Localization**: User-facing strings must be defined in `lib/l10n/app_en.arb`, `app_id.arb`, and `app_ja.arb`.

---

## Commit Guidelines

We recommend [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` A new feature
- `fix:` A bug fix
- `perf:` Performance improvements
- `refactor:` Code restructuring without functional changes
- `docs:` Documentation updates
- `style:` Formatting or UI styling corrections

---

## Submitting Pull Requests

1. Create a descriptive branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Commit your changes with clear messages.
3. Ensure `flutter analyze` passes:
   ```bash
   flutter analyze
   ```
4. Push your branch and open a Pull Request against `main`.
5. Fill out the PR template with a clear explanation of changes and test steps.

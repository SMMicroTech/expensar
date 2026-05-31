# Expensar

Expensar is an iOS expense-tracking app built with SwiftUI and Xcode. It supports expense entry, dashboards, reports, sharing, and yearly archiving.

## Features

- Track expenses with categories, amounts, dates, and locations
- View dashboard summaries and reports
- Preview receipt images fullscreen
- Open map details for location-based expenses
- Save app settings such as currency and sync options
- Archive completed years and review archived summaries

## Requirements

- macOS with the latest stable Xcode installed
- iOS Simulator or a signed iPhone build target
- GitHub account if you want to use the release workflow

## Project Structure

- `gallery/` — app source code, views, models, and helpers
- `gallery.xcodeproj/` — Xcode project and shared schemes
- `ShareExtension/` — share extension sources and configuration
- `build_and_run.sh` — local build-and-launch helper
- `git.push.bash` — helper that commits dirty changes and pushes the current branch
- `.github/workflows/` — GitHub Actions workflows

## Build and Run

### Open in Xcode

1. Open `gallery.xcodeproj` in Xcode.
2. Select the `gallery` scheme.
3. Choose a simulator or a connected device.
4. Build and run.

### Command line

```bash
./build_and_run.sh
```

## Git Push Helper

The repository includes a helper script that commits uncommitted changes with a default message and pushes the current branch:

```bash
./git.push.bash
```

## GitHub Actions IPA Build

A workflow is available in `.github/workflows/build-ipa.yml` to build an IPA when you push a tag that matches `v*`.

To use it for signed builds, configure the required GitHub secrets for signing certificate and provisioning profile upload.

## Notes

- The app uses shared Xcode schemes stored in `gallery.xcodeproj/xcshareddata/xcschemes/`.
- Derived data and build artifacts are ignored through `.gitignore`.
- The project is configured to use automatic signing in Xcode; CI signing may need secrets depending on your distribution setup.

# Copilot Instructions: Android Native Rebuild for Expensar

## Mission

Rebuild this app as a **native Android application** with the **same core features and user-facing behavior** as the current iOS app, while following modern Android engineering practices. Treat the existing app as the product spec. Prioritize feature parity first, then platform-appropriate Android polish.

## Product Summary

Expensar is an expense-tracking app for personal finance. It lets users:

- create, view, edit, and delete expenses
- attach receipt images and metadata
- see dashboard summaries and trends
- generate reports and export data
- view expenses on a map when location exists
- choose currency and sync settings
- send expenses to Google Sheets through a webhook
- perform yearly wrap-up and archive completed years
- review archived summaries later
- use a sharing entry point for fast capture/import

## Target Platform

Build for **Android 10+** unless a newer minimum is clearly required by a feature or dependency.

Use **native Android** only.

### Preferred Stack

- **Language:** Kotlin
- **UI:** Jetpack Compose + Material 3
- **Architecture:** MVVM with unidirectional state flow
- **DI:** Hilt
- **Async:** Kotlin Coroutines + Flow
- **Persistence:** Room for structured data, DataStore for settings
- **Networking:** Retrofit or Ktor client
- **Images:** Coil
- **Maps:** Google Maps SDK for Android
- **Charts:** native Compose charting library or a well-maintained chart library
- **File export/import:** Storage Access Framework and app-private files
- **Background work:** WorkManager
- **Camera / receipt capture:** CameraX if capture is required

If a feature needs a library, prefer a widely used, maintained Android-first library. Avoid platform-agnostic abstractions unless they reduce risk.

## Rebuild Principles

1. **Match behavior first.** Keep feature semantics aligned with the existing app.
2. **Use Android idioms.** Translate iOS patterns to Android-native navigation, sheets, bottom sheets, and material design.
3. **Keep data stable.** Preserve the logical data model so migration/import/export remains possible.
4. **Make state observable.** UI should derive from ViewModel state, not local mutable UI-only state.
5. **Avoid overengineering.** Use clean, feature-based architecture without unnecessary layers.
6. **Prefer offline-first.** The app should work fully offline, with sync/export as an opt-in capability.

## Core Features to Recreate

### 1. Expense Entry

The app must support adding and editing expenses with at least these fields:

- title or merchant name
- amount
- currency code
- category
- date/time
- notes or memo
- location name
- latitude and longitude
- receipt image(s)
- tags if useful

Rules:

- Amount must support decimal values.
- Date defaults to current time.
- Location should be optional.
- Receipt images should support multiple images if the original product flow allows it.
- Validation must prevent invalid amounts and missing required fields.

### 2. Expense List

Show a primary list of expenses with:

- amount
- title or merchant
- category
- date
- optional image or icon indicator
- optional location indicator

Interactions:

- tap opens expense details
- long press or overflow action should expose quick actions such as map preview, edit, share, or delete
- sorting/filtering by date, category, amount, and search text should be supported

### 3. Expense Details

The detail screen must include:

- all expense fields
- formatted amount using selected currency
- receipt image preview
- map section if location exists
- edit and delete actions
- share/export actions when relevant

Behavior:

- tapping a receipt image opens a fullscreen viewer
- fullscreen viewer supports pinch zoom and pan
- if multiple images exist, allow paging between them

### 4. Dashboard

Create a dashboard with summary cards and visual analytics:

- total spend for the selected range
- spend by category
- count of expenses
- monthly or yearly comparisons
- recent expenses summary

Ranges should include:

- month
- year
- all time

If additional ranges are helpful, they are allowed as long as they do not break parity.

### 5. Reports

Provide a reports area that can:

- visualize spending trends
- produce printable or shareable summaries
- export data to a document or file format
- use the selected currency consistently everywhere

Prefer PDF export if it meaningfully matches the existing app behavior.

### 6. Settings

Provide a settings screen for:

- currency selection
- monthly budget or target amount
- Google Sheets webhook URL
- archive and restore-related preferences if needed
- app/about information

Rules:

- settings must persist locally
- changes must apply immediately to the UI
- save action should be explicit where appropriate

### 7. Google Sheets Export

Support sending expenses to a Google Sheets endpoint via webhook.

Requirements:

- user can enter a webhook URL
- app sends a JSON payload of expenses
- payload should include enough fields for spreadsheet ingestion
- handle network errors gracefully
- show success/failure feedback

Do not hardcode secrets in the app.

### 8. Yearly Wrap-Up and Archiving

When a year is completed:

- move completed-year expense data into an archive store
- keep archived summaries accessible from the UI
- show a yearly wrap-up summary for the completed period
- start a fresh active expense set for the new year

Archive rules:

- archives must be queryable later
- archived data should remain read-only
- archived summaries should include totals, category breakdowns, and counts
- if a file-based archive is used, it must be backed up by the app-private storage and exportable

### 9. Sharing Entry Point

If the original app uses a share extension or fast import entry point, recreate the equivalent Android flow using:

- Android share intent receiver
- system share sheet integration
- deep link or shortcut if useful

The goal is quick capture/import of content into the app.

## Data Model Expectations

Create domain models that preserve the original semantics.

### Expense

Include:

- id
- title
- amount
- currencyCode
- category
- timestamp
- notes
- locationName
- latitude
- longitude
- image paths or image references
- createdAt
- updatedAt

### Archive

Include:

- year
- summary totals
- category breakdown
- expense count
- archived expense records
- archivedAt timestamp

### Settings

Include:

- selected currency code
- monthly target
- webhook URL
- theme preference if added later
- last archived year if useful

## Architecture Guidance

Use a feature-based package structure such as:

- `core/`
- `data/`
- `domain/`
- `feature/dashboard/`
- `feature/expenses/`
- `feature/details/`
- `feature/reports/`
- `feature/settings/`
- `feature/archive/`

Recommended structure:

- `app/` for navigation and app shell
- `data/local/` for Room, DataStore, and file persistence
- `data/remote/` for webhook/export integrations
- `domain/model/` for business models
- `domain/usecase/` for business logic
- `ui/components/` for reusable Compose components

### State Management

- Use immutable UI state data classes.
- Expose state through `StateFlow`.
- Keep business logic in ViewModels or use cases.
- Avoid putting repository logic directly into composables.

### Navigation

Use Jetpack Navigation Compose.

Suggested destinations:

- dashboard/home
- expense list
- expense detail
- add/edit expense
- reports
- settings
- archive summary
- archive detail

Use modal bottom sheets for quick actions where Android UX fits better than full screens.

## UI/UX Requirements

### Visual Style

- clean, modern, material-first design
- strong hierarchy for totals and summaries
- readable typography
- accessible contrast
- responsive layouts for phones and tablets

### Accessibility

- support dynamic font scaling
- provide content descriptions for images and actions
- ensure touch targets are large enough
- avoid relying on color alone for category/state

### Image Experience

- receipt images must load smoothly
- fullscreen viewer must support pinch zoom, drag, and dismiss
- use placeholders and error states for missing media

### Map Experience

- show a map preview for expenses with coordinates
- tapping opens a larger map view or full map screen
- gracefully handle missing permissions or no location data

## Persistence Rules

Prefer a hybrid approach:

- Room for expenses, archives, and structured records
- DataStore for settings
- app-private file storage for exports and attachments when needed

Rules:

- keep migrations explicit
- never block the UI thread for persistence
- preserve data if the app is upgraded
- support export/import for backup

## Networking and Sync

- all sync actions must be user-controlled unless explicitly background-safe
- retries must be bounded
- surface clear errors when the webhook or network fails
- never silently drop user data

## Business Logic Expectations

- currency formatting must be consistent across the entire app
- totals must respect the selected time range
- annual wrap-up must happen once per completed year
- archiving must not destroy recoverable information
- reports should use the same source of truth as dashboard totals

## Acceptance Criteria

The Android rebuild is complete only when these are true:

- users can add, edit, and delete expenses
- expenses appear in a searchable, filterable list
- details show images, maps, and complete metadata
- dashboard totals and charts work for month, year, and all-time ranges
- reports are generated with correct currency formatting
- settings persist and update the UI immediately
- Google Sheets export works from a configured webhook URL
- yearly wrap-up archives completed-year records and keeps archived summaries accessible
- fullscreen receipt image viewing supports zoom and pan
- app launches and works offline

## Implementation Priorities

1. model the data correctly
2. build expense entry and list flows
3. implement dashboard and details
4. add reports and settings
5. add export/sync integration
6. add yearly archive behavior
7. polish accessibility, error handling, and performance

## Coding Rules for Copilot

When generating code:

- use Kotlin and Android-native APIs only
- keep files and functions small and testable
- prefer descriptive names over abbreviations
- avoid unnecessary abstraction
- write code that compiles in a standard Android Studio project
- include ViewModel, repository, and model wiring when creating screens
- use real Android patterns rather than iOS or web analogs
- do not introduce Swift, SwiftUI, or iOS-specific APIs

## Testing Expectations

Add tests for:

- amount formatting
- expense totals and range filtering
- archive rollover logic
- webhook payload generation
- settings persistence
- image/map null and error states

Prefer:

- unit tests for business logic
- UI tests for major navigation paths

## Migration Note

This instruction set defines the Android-native rebuild target. If a future implementation task references the old iOS app, translate the behavior into Android idioms instead of copying iOS UI patterns directly.

# Pharmacy POS (Flutter client)

Desktop and web point-of-sale client for the pharmacy system. Clean Architecture

## What is in this build

- Sidebar shell, **New sale** / **Sales return** tabs
- Medicine table with Rx flag, stock count, and 30/60/90-day expiry colouring
- Cart with batch number preview (FEFO), quantity steppers, discount, Cash/Credit sale
- Split payments (cash, card, mobile), change due, credit-to-account
- Keyboard shortcuts: **F1** search, **F2** checkout, **Esc** clear sale
- HID barcode scanner support (keyboard-emulating scanners)
- Typed failures (`Failure`), integer-minor-unit money, idempotency key per cart state


## Setup

Requires Flutter 3.22 or newer (Dart 3.4+).

```bash
# 1. generate platform folders (does not touch lib/)
flutter create . --platforms=windows,linux,macos,web --project-name pharmacy_pos

# 2. dependencies
flutter pub get

# 3. checks
flutter analyze
flutter test

# 4. run
flutter run -d windows     # or: linux, macos, chrome
```

On Windows, desktop builds need Visual Studio with the "Desktop development with C++" workload
(`flutter doctor` tells you what is missing).

## Build

```bash
flutter build windows --release   # build/windows/x64/runner/Release/
flutter build web --release       # build/web/  (serve over HTTPS)
```

## Layout

```
lib/
  core/            constants, theme, failures, Result, money/date utils, shared widgets
  features/
    checkout/      domain (entities, repositories, use cases), data (demo repos), presentation (bloc, pages, widgets)
    shell/         sidebar + module switching
    returns/       sales return tab (empty state until the API exists)
test/              cart bloc, sale validation, app smoke test
```

## Notes

- Tax is 0% by default (`AppConfig.taxRateBasisPoints`). Confirm with your accountant.
- Discount limits per role must be enforced by the backend. The client only checks the amount is valid.
- The batch number shown on a cart line is a preview. The backend decides the real allocation.

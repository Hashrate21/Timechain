# Budget_App
# Timechain

Desktop budgeting for **projections** and **actuals** — plan ahead, track spending, keep everything offline.

**Privacy first:** no accounts, no sign-up, no cloud sync, no bank linking. Your data stays on your device.

> **Status:** Windows beta (`v0.2.0`) — for friend testing, not for sale yet.

---

## What it does

- **Projection engine** — recurring income/expenses, timeline, paid/skip, running balance, safe-to-spend  
- **Actuals** — transactions, accounts, category spending  
- **Categories** — monthly Set budgets or targets from projection; progress bars (solid or gradient colors)  
- **Analytics** — targets, budget performance, trends, projected vs actual  
- **Modes** — Combined · Projection only · Actuals only  
- **Multi-budget** — create and switch separate budget files  
- **Import / export** — CSV and paste import for transactions; CSV export  

---

## Platforms

| Platform | Status |
|----------|--------|
| **Windows** | Primary beta builds |
| macOS | Planned (not packaged yet) |
| Mobile | Not in scope for v0.x |

---

## Install (Windows beta)

1. Download the latest **Release** zip from this repo.  
2. Unzip anywhere (e.g. `Downloads/Timechain`).  
3. Run `timechain.exe` (or the `.exe` name inside the build folder).  

Windows may show **SmartScreen** (“Windows protected your PC”) because the build is unsigned. Choose **More info** → **Run anyway** if you trust the source.

---

## Data location

Budgets are stored **locally** in app documents (SQLite).  
Use **Settings** to create/switch budgets and to import/export data.

There is no remote backup — back up your budget files if you care about them.

---

## Themes

- Default Blue  
- Tokyo Neon Nights  
- Bitcoin (orange)  
- Mono (neutral grey)  

Light / dark mode is independent of color scheme.

---

## Versioning

- **App version** (e.g. `0.2.0`) — user-facing, GitHub tags  
- **DB schema version** — internal migrations only; not the same number  

---

## Development

```bash
flutter pub get
flutter run -d windows
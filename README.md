# Timechain

Desktop budgeting for **projections** and **actuals** — plan ahead, track spending, keep everything offline.

**Privacy first:** no accounts, no sign-up, no cloud sync, no bank linking. Your data stays on your device.

> **Status:** Windows beta (`v0.2.0`+) — friend testing, not for sale yet.  
> Planned paid model: **one-time** license (~$29–30), not a subscription.

---

## What it does

- **Projection engine** — recurring income/expenses, timeline, paid/skip, running balance, safe-to-spend  
- **Actuals** — transactions, accounts, category spending  
- **Transfers** — move money between accounts without counting as income or expense  
- **Untracked** — transfer to/from places outside this budget (brokerage, kids, external savings). Only the tracked account balance changes; not income/expense; hidden from Accounts. Rename in Settings.  
- **Categories** — monthly Set budgets or targets from projection; progress bars (solid or gradient colors)  
- **Analytics** — targets, budget performance, trends, projected vs actual  
- **Modes** — Combined · Projection only · Actuals only  
- **Multi-budget** — create and switch separate budget files  
- **Import / export** — CSV and paste import for transactions; CSV export (transactions + projections)  
- **Guide** — in-app User Guide, Glossary, and About  

---

## Who it’s for

People who want a **forward cashflow timeline** (“can I make it to payday?”) on a desktop, without linking a bank or creating an online account.

It is **not** a Mint/YNAB/Monarch replacement with bank sync, mobile-first design, or household cloud sharing.

---

## Platforms

| Platform | Status |
|----------|--------|
| **Windows** | Primary beta builds |
| macOS | Planned (not packaged yet) |
| Mobile | Not in scope for v0.x |

---

## Install (Windows beta)

1. Open **Releases** on this repo and download the latest **zip** (not the source tree).  
2. Unzip anywhere (e.g. `Downloads/Timechain`).  
3. Run the `.exe` inside the folder (name matches the build; often `budget_app.exe` or similar until renamed).  

Windows may show **SmartScreen** (“Windows protected your PC”) because the build is **unsigned**. Choose **More info** → **Run anyway** if you trust this repo.

---

## Data location

Budgets are **local SQLite** files under the app documents folder.  
Use **Settings** to create/switch budgets and to import/export.

There is **no remote backup** — copy your budget files yourself if they matter.

---

## Themes

| Scheme | Notes |
|--------|--------|
| Default Blue | Classic |
| Tokyo Neon Nights | High-contrast accents |
| Bitcoin | Warm orange |
| Mono | Neutral grey |

**Light / dark** is independent of color scheme.

---

## Untracked (quick rule)

Use **Transfer** with **Untracked** as the other side when money leaves or enters accounts you don’t fully track in this file.

- Does **not** count as income or expense  
- Does **not** appear under Accounts or net worth  
- Rename the label in **Settings** (e.g. “Kids 529”) — behavior stays the same  
- To track a real balance here, add a normal account instead  

Details are in the in-app **Guide**.

---

## Versioning

| Kind | Example | Meaning |
|------|---------|---------|
| **App version** | `0.2.0` / `0.2.1` | User-facing, GitHub release tags |
| **Build number** | `+2` in `pubspec.yaml` | Monotonic package build; does not reset |
| **DB schema** | e.g. `12` | Internal migrations only |

---

## Development

```bash
flutter pub get
flutter run -d windows
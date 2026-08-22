# Timechain

Desktop budgeting for **projections** and **actuals** — plan ahead, track spending, keep everything offline.

**Privacy first:** no accounts, no sign-up, no cloud sync, no bank linking. Your data stays on your device.

> **Status:** Windows beta (`v0.2.x`) — friend testing, not for sale yet.  
> Planned paid model: **one-time** license (~$29–30), not a subscription.

---

## What it does

- **Projection engine** — recurring income/expenses, timeline, paid/skip, running balance, safe-to-spend  
- **Actuals** — transactions, accounts, category spending, actual form templates  
- **Transfers** — move money between accounts without counting as income or expense  
- **External (untracked) accounts** — multiple named transfer counterparties outside this budget’s net worth (archive/restore; not on Accounts charts)  
- **Fixed vs Variable** — classify projected series; optional badges/mix in Settings  
- **Categories** — monthly Set budgets or targets from projection; progress bars (solid or gradient colors)  
- **Analytics** — Budget / Activity / Comparison tabs (targets, performance, trends, projected vs actual, expense mix, net transfers)  
- **Tools** — debt repayment & savings/growth calculators (what-if only; remember last inputs per account; export schedule CSV)  
- **Modes** — Combined · Projection only · Actuals only  
- **Multi-budget** — create and switch separate budget files  
- **Import / export** — CSV and paste import for transactions; CSV export (transactions + projections + calculator schedules)  
- **Guide** — in-app User Guide, Glossary, and About (with search)  

---

## Who it’s for

People who want a **forward cashflow timeline** (“can I make it to payday?”) on a desktop, without linking a bank or creating an online account.

It is **not** a Mint/YNAB/Monarch replacement with bank sync, mobile-first design, or household cloud sharing.

---

## Platforms

| Platform | Status |
|----------|--------|
| **Windows** | Primary beta builds (GitHub Releases zip) |
| **macOS** | Unsigned CI artifact available on Releases (Right-click → Open) |
| Mobile | Not in scope for v0.x |

---

## Install (Windows beta)

1. Open **Releases** on this repo and download the latest **Windows zip** (not the source tree).  
2. Unzip anywhere (e.g. `Downloads/Timechain`).  
3. Run the `.exe` inside the folder (name matches the build; often still `budget_app.exe` until renamed).  

Windows may show **SmartScreen** (“Windows protected your PC”) because the build is **unsigned**. Choose **More info** → **Run anyway** if you trust this repo.

### macOS (friend beta)

1. Download the **macOS** artifact from the same Release (or Actions).  
2. Unzip → **Right-click the app → Open** (unsigned; Gatekeeper will warn).  
3. Notarization is **not** done for beta.

---

## Data location

Budgets are **local SQLite** files under the app documents folder.  
Use **Settings** to create/switch budgets and to import/export.

Calculator presets are stored **inside each budget file** (switching budgets switches saved calculator inputs too).

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

## External / untracked (quick rule)

Use **Transfer** with an **external** account as the other side when money leaves or enters places you don’t fully track in this file (brokerage, kids’ accounts, etc.).

- Does **not** count as income or expense  
- Does **not** appear on tracked Accounts / net worth  
- Multiple named externals; archive instead of hard delete; at least one always kept  
- Manage under **Accounts** (not Settings)  
- To track a real balance here, add a normal **asset** or **liability** account instead  

Details are in the in-app **Guide**.

---

## Tools (quick rule)

Debt and savings calculators are **what-if only**. They never post transactions or change balances. Press **Calculate** to run; last inputs are remembered (including per linked account).

---

## Versioning

| Kind | Example | Meaning |
|------|---------|---------|
| **App version** | `0.2.2` / `0.2.3` | User-facing, GitHub release tags |
| **Build number** | `+N` in `pubspec.yaml` | Monotonic package build; does not reset |
| **DB schema** | e.g. `16` | Internal migrations only |

---

## Development

```bash
flutter pub get
flutter run -d windows
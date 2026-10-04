# 🍚 ricebucks: Personal Budget & Spending Tracker

A native [Omarchy](https://omarchy.org/) shell plugin for personal spending, monthly income tracking, dynamic savings goals, and category spending caps.

![Omarchy Shell Plugin](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## 🧩 About & Architecture (Omarchy Plugin)

**`ricebucks`** is designed specifically as an extension for the **[Omarchy](https://omarchy.org/)** Wayland desktop environment (plugin ID: `cameronri.budget`). Written in QML/JavaScript with [Quickshell](https://outfoxxed.me/quickshell/), it deeply integrates with the Omarchy system shell and ecosystem:

- **Status Bar Integration**: Mounts as a native bar widget in the Omarchy status bar (right section by default), displaying dynamic balances, tooltips, and real-time over-budget warning badges.
- **Desktop Popup Panel**: Launches a rich, reactive QML desktop panel with category breakdowns, running totals, and transaction management via hotkey (<kbd>Super</kbd> + <kbd>B</kbd>) or bar click.
- **Shell IPC & State**: Real-time communication via `quickshell ipc` to synchronize changes instantly between the GUI panel and the command line. State is preserved locally at `~/.local/state/omarchy/budget.json`.
- **CLI Companion**: Includes a fast CLI (`ricebucks`, aliased with `omarchy-budget`) for tracking purchases, adjusting limits, and checking your balance directly from the terminal.

---

## ✨ Features

- **Bar Widget**: Displays an interactive `$` icon in the Omarchy bar with tooltip balances and immediate over-budget alerts.
- **Monthly Income & Savings Target**: Set your monthly income and savings percentage (e.g. 20%) to dynamically calculate dollar savings reserved before budgeting allowances.
- **Remaining Budget Calculation**: Automatically calculates:
  $$\text{Remaining Allowance} = \text{Monthly Income} - \text{Savings Target} - \text{Total Expenses}$$
- **Category Spending Limits & Warnings**: Set custom spending caps for each category (e.g. $500 for Groceries). Visual progress meters fill toward the limit and turn urgent red with explicit warning alerts when exceeded.
- **Category Management**: Full support to add, rename, delete, and drag-to-reorder categories directly from the desktop popup or via the CLI.
- **Running Totals**: Review spending per category, remaining allowances against limits, percentage share of total monthly expenses, and visual proportion meters.
- **All Transactions Window**: Dedicated multi-month transaction browser with instant search, category filtering, and item deletion.
- **Dual CLI Companion**: Fast command-line companion script callable as both `ricebucks` and `omarchy-budget`.

---

## 📦 Installation

### Via Omarchy's Plugin Manager (Recommended)

```bash
omarchy plugin add https://github.com/Rice-Cameron/ricebucks.git --enable --yes
```

### Manual Installation

Clone directly into your Omarchy plugins directory:

```bash
git clone https://github.com/Rice-Cameron/ricebucks.git ~/.config/omarchy/plugins/cameronri.budget
omarchy-shell shell rescanPlugins
omarchy plugin enable cameronri.budget --section right
```

### Enable the CLI Companion

Symlink the CLI script into your `~/.local/bin`:

```bash
ln -sf ~/.config/omarchy/plugins/cameronri.budget/bin/ricebucks ~/.local/bin/ricebucks
ln -sf ~/.config/omarchy/plugins/cameronri.budget/bin/omarchy-budget ~/.local/bin/omarchy-budget
```

---

## 🗑️ Removal

To disable and remove the plugin from Omarchy:

```bash
omarchy plugin remove cameronri.budget --yes
rm -f ~/.local/bin/ricebucks ~/.local/bin/omarchy-budget
```

*(Optional)* To purge all local budget data and transaction history:
```bash
rm -f ~/.local/state/omarchy/budget.json
```

---

## 📋 Dependencies

- **Omarchy Shell** & **Quickshell** (included with the Omarchy desktop environment)
- **jq** (standard on Omarchy, used by the CLI companion)

---

## 🖥️ Usage

### Hotkeys & Desktop Controls

- <kbd>Super</kbd> + <kbd>B</kbd>: Toggle the `ricebucks` popup panel.
- **Omarchy Menu**: Search `budget`, `spending`, or `ricebucks` from <kbd>Super</kbd> + <kbd>Space</kbd>.
- **Manage Categories & Limits**: Click **Manage** in the popup to add new categories, rename existing ones, delete categories (expenses automatically migrate to "Other"), drag items using the handle to reorder, or click **Limit** to adjust spending caps.
- **All Transactions Window**: Click **View All →** next to Recent Transactions to browse, search, and filter all recorded purchases by month and category.

### Understanding Category Progress Meters

The progress meters adapt automatically based on category settings:

1. **Categories with a spending limit**:
   - The bar tracks **budget allowance consumed** ($\text{Spent} / \text{Limit}$).
   - Displays `$Spent / $Limit ($Remaining left)` in your theme's active accent color.
   - Flashes an urgent red `OVER LIMIT` badge when the limit is exceeded.
2. **Categories without a spending limit**:
   - Designed for fixed recurring expenses (e.g. Rent & Bills) that you do not need to cap.
   - Displays `$Spent (XX.X% of spending)`.
   - The bar renders in a subtle, muted tone representing its **proportional share of total monthly expenses** ($\text{Category Spent} / \text{Total Spent}$), reserving bright accent and warning colors strictly for active budget caps.

---

## 💻 CLI Commands

The CLI companion can be invoked using either `ricebucks` or `omarchy-budget`:

```bash
# Toggle the desktop UI popup
ricebucks

# Open the All Transactions view in the popup
ricebucks transactions

# View terminal budget overview
ricebucks status

# Record a purchase (warns if purchase exceeds category limit)
ricebucks add 45.50 "Groceries" "Trader Joe's"
ricebucks add 12.00 "Dining Out" "Chipotle"

# Manage category spending limits
ricebucks limit "Groceries" 500          # Set $500 monthly limit
ricebucks limit "Groceries"              # View current limit
ricebucks limit "Groceries" clear        # Remove spending limit
ricebucks category limit "Dining" 200    # Alias syntax

# Set monthly income or savings goals
ricebucks income 4500                    # Set $4,500 monthly income
ricebucks savings 20                     # Set 20% savings target ($900 reserved)

# Manage categories
ricebucks categories                     # List categories & limits
ricebucks category add "Subscriptions"   # Create new category
ricebucks category rename "Old" "New"    # Rename category
ricebucks category delete "Entertainment"# Delete category
ricebucks category move 0 3              # Reorder category from index 0 to 3

# Transaction history
ricebucks list                           # List current month's transactions
ricebucks list all                       # List all historical transactions
```

---

## 📄 License

[MIT](LICENSE)

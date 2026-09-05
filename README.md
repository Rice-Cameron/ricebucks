# Omarchy Budget & Spending Tracker

A native [Omarchy](https://omarchy.org/) shell plugin for personal spending, monthly income tracking, savings goals, and fully customizable category budgets.

![Omarchy Shell](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue)

## Features

- **Bar Widget**: Displays a `$` icon in the Omarchy bar with tooltip balances and over-budget alerts.
- **Monthly Income & Savings Target**: Set your monthly income and savings percent (e.g. 20%) to dynamically calculate dollar savings reserved.
- **Remaining Budget Tracker**: Automatically calculates $\text{Income} - \text{Savings Target} - \text{Spending}$.
- **Category Management**: Full support to add, rename, and delete categories directly from the desktop popup or the CLI.
- **Running Totals**: See spending totals per category, percentage share of total monthly expenses, and visual proportion meters.
- **Transaction History**: View recent purchases and delete mistaken entries.
- **CLI Companion**: Full command-line companion script `omarchy-budget`.

## Installation

Install via Omarchy's plugin manager:

```bash
omarchy plugin add <repo-url> --enable --yes
```

Or manually:
```bash
git clone <repo-url> ~/.config/omarchy/plugins/cameronri.budget
omarchy-shell shell rescanPlugins
omarchy plugin enable cameronri.budget --section right
```

Link the CLI script:
```bash
ln -sf ~/.config/omarchy/plugins/cameronri.budget/bin/omarchy-budget ~/.local/bin/omarchy-budget
```

## Usage

### Hotkey & Desktop
- **Super + B**: Toggle the budget panel popup.
- **Omarchy Menu**: Search `budget` or `spending` from <kbd>Super</kbd> + <kbd>Space</kbd>.
- **Manage Categories**: Click the **Manage** button in the popup to add new categories, rename existing ones, or delete categories (expenses in deleted categories are cleanly moved to "Other").

### CLI Commands
```bash
# Toggle UI popup
omarchy-budget

# View terminal budget summary
omarchy-budget status

# Add a purchase
omarchy-budget add 45.50 "Groceries" "Trader Joe's"

# Set income or savings goal
omarchy-budget income 4000
omarchy-budget savings 20

# Category management
omarchy-budget categories                     # List all categories
omarchy-budget category add "Subscriptions"   # Add new category
omarchy-budget category rename "Old" "New"    # Rename category
omarchy-budget category delete "Category"     # Delete category

# List transactions
omarchy-budget list
```

## License
MIT

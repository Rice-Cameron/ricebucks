# Omarchy Budget & Spending Tracker

A native [Omarchy](https://omarchy.org/) shell plugin for personal spending, monthly income tracking, savings goals, and fully customizable category budgets.

![Omarchy Shell](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue)

## Features

- **Bar Widget**: Displays a `$` icon in the Omarchy bar with tooltip balances and over-budget alerts.
- **Monthly Income & Savings Target**: Set your monthly income and savings percent (e.g. 20%) to dynamically calculate dollar savings reserved.
- **Remaining Budget Tracker**: Automatically calculates $\text{Income} - \text{Savings Target} - \text{Spending}$.
- **Category Spending Limits & Warnings**: Set custom spending caps for each category (e.g. $500 for Groceries) to track remaining allowances at a glance. Visual meters fill toward the limit and turn red with explicit warning alerts when exceeded.
- **Category Management**: Full support to add, rename, delete, and drag-to-reorder categories directly from the desktop popup or the CLI.
- **Running Totals**: See spending totals per category, remaining allowances against limits, percentage share of total monthly expenses, and visual proportion meters.
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

## Removal

To disable and remove the plugin from Omarchy:
```bash
omarchy plugin remove cameronri.budget --yes
```

Remove the CLI symlink:
```bash
rm -f ~/.local/bin/omarchy-budget
```

*(Optional)* To purge all local budget data and transaction history:
```bash
rm -f ~/.local/state/omarchy/budget.json
```

## Dependencies

- **Quickshell** (included with Omarchy shell)
- **jq** (standard on Omarchy, used by the `omarchy-budget` CLI)

## Usage

### Hotkey & Desktop
- **Super + B**: Toggle the budget panel popup.
- **Omarchy Menu**: Search `budget` or `spending` from <kbd>Super</kbd> + <kbd>Space</kbd>.
- **Manage Categories & Limits**: Click the **Manage** button in the popup to add new categories, rename existing ones, delete categories (expenses are moved to "Other"), grab the handle on any category card to smoothly drag and reorder, or click **Limit** on any category card to set or clear its spending cap.
- **All Transactions Window**: Click the **View All →** button next to Recent Transactions to open the full transactions menu. View, search, and filter all recorded purchases by month and category with instant totals.

### Understanding Category Progress Meters

The progress meters in the Category Running Totals view adapt automatically:
- **Categories with a spending limit**: The bar tracks your **budget allowance consumed** ($\text{Spent} / \text{Limit}$). It displays `$Spent / $Limit ($Remaining left)` filled in your theme's vibrant accent color, and turns urgent red with an `OVER LIMIT` badge when exceeded.
- **Categories without a spending limit**: For expected fixed expenses (such as Rent & Bills) that you don't cap, it displays `$Spent (XX.X% of spending)`. The progress meter is rendered in a subtle, muted tone to represent its **proportional share of total monthly expenses** ($\text{Category Spent} / \text{Total Spent}$), reserving bright accent and urgent colors exclusively for active budget caps.

### CLI Commands
```bash
# Toggle UI popup
omarchy-budget

# Open All Transactions window directly in popup
omarchy-budget transactions

# View terminal budget summary
omarchy-budget status

# Add a purchase (warns if purchase exceeds category limit)
omarchy-budget add 45.50 "Groceries" "Trader Joe's"

# Category spending limits
omarchy-budget limit "Groceries" 500          # Set $500 monthly limit for Groceries
omarchy-budget limit "Groceries"              # View current limit for Groceries
omarchy-budget limit "Groceries" clear        # Remove limit for Groceries
omarchy-budget category limit "Dining" 200    # Alias syntax under category subcommand

# Set income or savings goal
omarchy-budget income 4000
omarchy-budget savings 20

# Category management
omarchy-budget categories                     # List all categories (with limits)
omarchy-budget category add "Subscriptions"   # Add new category
omarchy-budget category rename "Old" "New"    # Rename category
omarchy-budget category delete "Category"     # Delete category
omarchy-budget category move 0 3              # Reorder category from index 0 to 3

# List transactions (current month, or all recorded)
omarchy-budget list
omarchy-budget list all
```

## License

[MIT](LICENSE)

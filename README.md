# Omarchy Budget & Spending Tracker

A native [Omarchy](https://omarchy.org/) shell plugin for personal spending, monthly income tracking, savings goals, and category budgets.

![Omarchy Shell](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue)

## Features

- **Bar Widget**: Displays a `$` icon in the Omarchy bar with tooltip balances and over-budget alerts.
- **Monthly Income & Savings Target**: Set your monthly income and savings percent (e.g. 20%) to dynamically calculate dollar savings reserved.
- **Remaining Budget Tracker**: Automatically calculates $\text{Income} - \text{Savings Target} - \text{Spending}$.
- **Category Running Totals**: Preloaded with Rent + Utilities, Groceries, Eating Out, Insurance, Car Payment, Random Fun Things, and Other, plus support for custom categories.
- **Transaction History**: View recent purchases and delete mistaken entries.
- **CLI Companion**: Full command-line companion script `omarchy-budget`.

## Installation

Clone or install via Omarchy's plugin manager:

```bash
omarchy plugin add <repo-url> --enable --yes
```

Or manually clone into:
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

# List transactions
omarchy-budget list
```

## License
MIT

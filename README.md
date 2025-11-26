# hledger YouTube Business Template

A complete, beginner-friendly starter template for Canadian YouTube creators to track their business finances using [hledger](https://hledger.org) - free, open-source, plain-text accounting.

**Perfect for:**
- YouTubers and content creators
- Canadian sole proprietors
- Beginners who've never done bookkeeping
- Anyone who wants control over their financial data

## Why Plain-Text Accounting?

| Traditional Software | Plain-Text (hledger) |
|---------------------|----------------------|
| Monthly subscription fees | Free forever |
| Your data locked in their format | Your data in simple text files |
| Company could shut down | Files work forever |
| Limited customization | Fully customizable |
| Can't see "under the hood" | Complete transparency |

**Plain text means:**
- Your finances are in simple text files you can open in any editor
- Back them up anywhere (Dropbox, iCloud, USB drive)
- Version control with git (see your changes over time)
- Never worry about a company going out of business

## What's Included

```
hledger-youtube-business/
├── accounting/
│   ├── main.journal         # Your main file (includes others)
│   ├── accounts.journal     # All account categories
│   └── 2025.journal         # This year's transactions
├── receipts/                # Store your receipt PDFs here
├── taxes/                   # Tax documents and summaries
└── tools/
    ├── import-bank.sh       # Auto-import from bank CSV
    ├── install.sh           # Setup wizard
    └── rules/               # Bank CSV parsing rules
        ├── td.rules         # TD Canada Trust
        ├── rbc.rules        # RBC Royal Bank
        ├── scotiabank.rules
        ├── bmo.rules
        └── cibc.rules
```

## ⚠️ Privacy Note

If you plan to use git with your real financial data, check the `.gitignore` file first! By default, it does NOT ignore your journal files (so you can see the examples).

**To keep your finances private**, edit `.gitignore` and uncomment these lines:
```
accounting/*.journal
receipts/*
taxes/*
```

This prevents your actual transactions from being uploaded if you push to GitHub.

## Quick Start (5 minutes)

### Step 1: Install hledger

**macOS:**
```bash
brew install hledger
```

**Ubuntu/Debian:**
```bash
sudo apt install hledger
```

**Windows:** See [hledger.org/install](https://hledger.org/install.html)

### Step 2: Clone this template

```bash
cd ~
git clone https://github.com/KayleeBeyene/hledger-youtube-business.git
cd hledger-youtube-business
```

### Step 3: Set your opening balance

Edit `accounting/2025.journal` and update the opening balance:

```
2025-01-01 Opening Balance | Starting to track finances
    assets:bank:chequing       YOUR_BALANCE CAD
    equity:opening
```

### Step 4: You're done!

Check your balance:
```bash
hledger -f accounting/main.journal balance
```

## Recording Transactions

### The Basic Format

Every transaction looks like this:
```
DATE DESCRIPTION
    account:where:money:goes    AMOUNT
    account:where:money:comes:from
```

### Example: You bought a microphone

```
2025-02-15 Amazon | Rode microphone
    expenses:equipment:audio    149.99 CAD
    assets:bank:chequing
```

**Translation:** $149.99 went FROM your bank account TO equipment expenses.

### Example: You got paid by YouTube

```
2025-02-20 YouTube AdSense | January 2025 payout
    assets:bank:chequing       523.47 CAD
    income:youtube:adsense
```

**Translation:** $523.47 came FROM AdSense INTO your bank account.

### Example: Monthly subscription (paid by credit card)

```
2025-02-01 Epidemic Sound | Music subscription
    expenses:software:music     16.99 CAD
    liabilities:creditcard
```

## Useful Commands

```bash
# See all account balances
hledger -f accounting/main.journal balance

# See just expenses
hledger -f accounting/main.journal balance expenses

# See income vs expenses (profit/loss)
hledger -f accounting/main.journal incomestatement

# See all transactions
hledger -f accounting/main.journal register

# See just YouTube income
hledger -f accounting/main.journal register income:youtube

# Monthly expense breakdown
hledger -f accounting/main.journal balance expenses --monthly

# How much did I spend on software?
hledger -f accounting/main.journal balance expenses:software
```

**Pro tip:** Create aliases in your `.bashrc` or `.zshrc`:
```bash
alias hl='hledger -f ~/hledger-youtube-business/accounting/main.journal'
```
Then just type: `hl balance`

## Importing Bank Transactions

Instead of typing every transaction, import them from your bank!

### Setup (one time)

```bash
cd tools
./install.sh
```

### Import transactions

1. Log into your bank's website
2. Download transactions as CSV
3. Run the import:
```bash
./tools/import-bank.sh
```

The script will:
- Find your CSV in Downloads
- Show you a preview
- Ask for confirmation before importing

## Canadian Tax Tips for YouTubers (NOT FINANCIAL ADVICE - SPEAK TO YOUR ACCOUNTANT FIRST)

> **⚠️ NOT FINANCIAL ADVICE. SPEAK TO YOUR ACCOUNTANT FIRST.**
> These are general tips only. Tax laws change, and your situation may be different. Always consult a professional.

This template includes detailed tax notes in `accounting/main.journal`, but here are the highlights:

### What You Can Deduct

| Expense | Deductible? | Notes |
|---------|------------|-------|
| Camera, mic, lights | Yes | Depreciate if over $500 |
| Editing software | Yes | Full deduction |
| Music subscriptions | Yes | Epidemic Sound, Artlist, etc. |
| Home office | Yes | % of rent based on square footage |
| Internet | Yes | Business use % only |
| Business meals | 50% | Must be with collaborators, sponsors |
| Courses & education | Yes | Skillshare, YouTube courses |
| Travel to shoot | Yes | Track mileage! |

### What You CAN'T Deduct

- Regular meals (just you eating while editing)
- Clothes (unless literally costumes for videos)
- Personal portion of phone/internet
- Commute to a day job

### GST/HST

- Not required until you hit $30,000 revenue in 12 months
- YouTube AdSense is zero-rated (no GST to charge)
- Canadian sponsorships: charge GST/HST
- US sponsorships: zero-rated export

## File Organization

### Receipts

Save receipts in `receipts/` with this naming convention:
```
YYYY-MM-DD-vendor-description.pdf
```

Examples:
- `2025-01-15-amazon-rode-mic.pdf`
- `2025-02-01-epidemic-sound.pdf`
- `2025-02-20-bestbuy-ring-light.pdf`

Reference them in your transactions:
```
2025-01-15 Amazon | Rode microphone
    expenses:equipment:audio    149.99 CAD
    assets:bank:chequing
    ; Receipt: 2025-01-15-amazon-rode-mic.pdf
```

### Yearly Organization

Each year gets its own transaction file:
- `accounting/2025.journal`
- `accounting/2026.journal` (create when needed)

Add new years to `main.journal`:
```
include 2025.journal
include 2026.journal
```

## Troubleshooting

### "hledger: command not found"

Install hledger first (see Quick Start above).

### Transaction won't balance

Every transaction must balance (money comes from somewhere). Check:
- Did you forget an account line?
- Is there a typo in the amount?
- Are your indents correct? (use spaces, not tabs, or vice versa consistently)

### "could not parse date"

Dates must be YYYY-MM-DD format:
- ✅ `2025-02-15`
- ❌ `02/15/2025`
- ❌ `Feb 15, 2025`

### Import script can't find my CSV

- Check the filename matches patterns in `tools/config`
- Make sure the CSV is in your Downloads folder
- Try: `./import-bank.sh --file /path/to/your/file.csv`

## Learning More

- [hledger documentation](https://hledger.org/docs.html)
- [Plain Text Accounting](https://plaintextaccounting.org/)
- [hledger CSV import guide](https://hledger.org/import-csv.html)

## Contributing

Found an issue? Have a suggestion?
- Open an issue on GitHub
- Or submit a pull request!

Especially welcome:
- Rules files for other Canadian banks
- Improvements to the account structure
- Better documentation

## License

MIT License - use it, modify it, share it!

---

Made for the YouTube creator community 🎬

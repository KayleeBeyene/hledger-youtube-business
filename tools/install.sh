#!/bin/bash
# install.sh - Interactive setup for hledger-bank-import
#
# This script helps you:
# 1. Check/install dependencies
# 2. Create your config file
# 3. Set up your journal file
# 4. Test with sample data
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Print functions
header() { echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}\n"; }
info() { echo -e "${CYAN}→${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
prompt() { echo -e "${BOLD}$1${NC}"; }

echo -e "${BOLD}"
cat << 'EOF'
    __    __          __
   / /_  / /__  ____/ /___ ____  _____
  / __ \/ / _ \/ __  / __ `/ _ \/ ___/
 / / / / /  __/ /_/ / /_/ /  __/ /
/_/ /_/_/\___/\__,_/\__, /\___/_/
                   /____/
    Bank Import Tool - Setup Wizard
EOF
echo -e "${NC}"

# Step 1: Check Dependencies
header "Step 1: Checking Dependencies"

# Check for hledger
if command -v hledger >/dev/null 2>&1; then
    HLEDGER_VERSION=$(hledger --version | head -1)
    success "hledger found: $HLEDGER_VERSION"
else
    error "hledger not found"
    echo ""
    info "Install hledger using one of these methods:"
    echo ""
    echo "  macOS (Homebrew):"
    echo "    brew install hledger"
    echo ""
    echo "  Ubuntu/Debian:"
    echo "    sudo apt install hledger"
    echo ""
    echo "  Other systems:"
    echo "    https://hledger.org/install.html"
    echo ""
    read -p "Press Enter after installing hledger, or Ctrl+C to exit..."

    if ! command -v hledger >/dev/null 2>&1; then
        error "hledger still not found. Please install it and run this script again."
        exit 1
    fi
fi

# Check for bash version
BASH_VERSION_NUM="${BASH_VERSION%%.*}"
if [[ "$BASH_VERSION_NUM" -ge 3 ]]; then
    success "bash version: $BASH_VERSION"
else
    warn "bash version $BASH_VERSION may have compatibility issues"
fi

# Step 2: Create Config File
header "Step 2: Configuration"

if [[ -f "${SCRIPT_DIR}/config" ]]; then
    warn "Config file already exists: ${SCRIPT_DIR}/config"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Keeping existing config file"
        SKIP_CONFIG=true
    else
        SKIP_CONFIG=false
    fi
else
    SKIP_CONFIG=false
fi

if [[ "$SKIP_CONFIG" == "false" ]]; then
    info "Let's set up your configuration..."
    echo ""

    # Downloads directory
    DEFAULT_DOWNLOADS="$HOME/Downloads"
    prompt "Where does your browser download files?"
    read -p "[$DEFAULT_DOWNLOADS]: " DOWNLOADS_DIR
    DOWNLOADS_DIR="${DOWNLOADS_DIR:-$DEFAULT_DOWNLOADS}"

    # Expand ~ and validate
    DOWNLOADS_DIR="${DOWNLOADS_DIR/#\~/$HOME}"
    if [[ ! -d "$DOWNLOADS_DIR" ]]; then
        warn "Directory doesn't exist: $DOWNLOADS_DIR"
        read -p "Create it? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$DOWNLOADS_DIR"
            success "Created: $DOWNLOADS_DIR"
        fi
    fi

    echo ""

    # Journal file location
    DEFAULT_JOURNAL="$HOME/finance/main.journal"
    prompt "Where should your hledger journal be stored?"
    read -p "[$DEFAULT_JOURNAL]: " LEDGER_FILE
    LEDGER_FILE="${LEDGER_FILE:-$DEFAULT_JOURNAL}"

    # Expand ~ and create directory
    LEDGER_FILE="${LEDGER_FILE/#\~/$HOME}"
    LEDGER_DIR=$(dirname "$LEDGER_FILE")
    if [[ ! -d "$LEDGER_DIR" ]]; then
        info "Creating directory: $LEDGER_DIR"
        mkdir -p "$LEDGER_DIR"
    fi

    echo ""

    # Which bank?
    prompt "Which Canadian bank do you use? (for default CSV pattern)"
    echo "  1) TD Canada Trust"
    echo "  2) RBC Royal Bank"
    echo "  3) Scotiabank"
    echo "  4) BMO Bank of Montreal"
    echo "  5) CIBC"
    echo "  6) Other / Multiple"
    read -p "Enter choice [1-6]: " BANK_CHOICE

    case "$BANK_CHOICE" in
        1) CSV_PATTERNS="accountactivity.csv"; BANK_MAPPING="accountactivity:td" ;;
        2) CSV_PATTERNS="*.csv"; BANK_MAPPING="rbc:rbc" ;;
        3) CSV_PATTERNS="export*.csv"; BANK_MAPPING="export:scotiabank" ;;
        4) CSV_PATTERNS="Statement*.csv"; BANK_MAPPING="Statement:bmo" ;;
        5) CSV_PATTERNS="cibc*.csv"; BANK_MAPPING="cibc:cibc" ;;
        *) CSV_PATTERNS="accountactivity.csv export*.csv Statement*.csv cibc*.csv"
           BANK_MAPPING="accountactivity:td
export:scotiabank
Statement:bmo
cibc:cibc" ;;
    esac

    echo ""

    # Archive directory
    prompt "Archive imported CSVs? (recommended)"
    read -p "(y/n) [y]: " -n 1 -r ARCHIVE_CHOICE
    ARCHIVE_CHOICE="${ARCHIVE_CHOICE:-y}"
    echo ""

    if [[ $ARCHIVE_CHOICE =~ ^[Yy]$ ]]; then
        DEFAULT_ARCHIVE="${LEDGER_DIR}/imports"
        read -p "Archive directory [$DEFAULT_ARCHIVE]: " ARCHIVE_DIR
        ARCHIVE_DIR="${ARCHIVE_DIR:-$DEFAULT_ARCHIVE}"
        ARCHIVE_DIR="${ARCHIVE_DIR/#\~/$HOME}"
        mkdir -p "$ARCHIVE_DIR"
        success "Archive directory: $ARCHIVE_DIR"
    else
        ARCHIVE_DIR=""
    fi

    # Write config file
    # Convert back to ~ for portability
    DOWNLOADS_DIR_DISPLAY="${DOWNLOADS_DIR/#$HOME/~}"
    LEDGER_FILE_DISPLAY="${LEDGER_FILE/#$HOME/~}"
    ARCHIVE_DIR_DISPLAY="${ARCHIVE_DIR/#$HOME/~}"

    cat > "${SCRIPT_DIR}/config" << EOF
# hledger Bank Import Configuration
# Generated by install.sh on $(date)

DOWNLOADS_DIR="$DOWNLOADS_DIR_DISPLAY"
LEDGER_FILE="$LEDGER_FILE_DISPLAY"
CSV_PATTERNS="$CSV_PATTERNS"

BANK_MAPPINGS="$BANK_MAPPING"

EOF

    if [[ -n "$ARCHIVE_DIR" ]]; then
        echo "ARCHIVE_DIR=\"$ARCHIVE_DIR_DISPLAY\"" >> "${SCRIPT_DIR}/config"
    else
        echo "# ARCHIVE_DIR=\"~/finance/imports\"" >> "${SCRIPT_DIR}/config"
    fi

    success "Config file created: ${SCRIPT_DIR}/config"
fi

# Step 3: Create Journal File
header "Step 3: Journal Setup"

# Expand for checking
LEDGER_FILE="${LEDGER_FILE/#\~/$HOME}"

if [[ -f "$LEDGER_FILE" ]]; then
    success "Journal file exists: $LEDGER_FILE"
else
    info "Creating starter journal: $LEDGER_FILE"
    cp "${SCRIPT_DIR}/samples/sample-journal.journal" "$LEDGER_FILE"
    success "Created journal with sample accounts"
    echo ""
    info "Edit this file to set your opening balance"
fi

# Step 4: Make scripts executable
header "Step 4: Making Scripts Executable"

chmod +x "${SCRIPT_DIR}/import-bank.sh"
success "import-bank.sh is now executable"

# Step 5: Test with sample data
header "Step 5: Test Run (Optional)"

prompt "Would you like to test with sample data?"
read -p "(y/n) [y]: " -n 1 -r TEST_CHOICE
TEST_CHOICE="${TEST_CHOICE:-y}"
echo ""

if [[ $TEST_CHOICE =~ ^[Yy]$ ]]; then
    info "Copying sample CSV to Downloads..."
    cp "${SCRIPT_DIR}/samples/td-sample.csv" "${DOWNLOADS_DIR}/accountactivity.csv"
    success "Sample file copied"
    echo ""
    info "Running import script in dry-run mode..."
    echo ""
    "${SCRIPT_DIR}/import-bank.sh" --dry-run
    echo ""
    info "Cleaning up sample file..."
    rm -f "${DOWNLOADS_DIR}/accountactivity.csv"
    success "Test complete!"
fi

# Done!
header "Setup Complete!"

echo -e "You're all set! Here's how to use hledger-bank-import:\n"

echo -e "${BOLD}1. Download CSV from your bank${NC}"
echo "   Log into online banking and export transactions as CSV"
echo ""

echo -e "${BOLD}2. Run the import script${NC}"
echo "   cd ${SCRIPT_DIR}"
echo "   ./import-bank.sh"
echo ""

echo -e "${BOLD}3. View your finances${NC}"
echo "   hledger -f $LEDGER_FILE balance"
echo "   hledger -f $LEDGER_FILE register"
echo ""

echo -e "${BOLD}Useful commands:${NC}"
echo "   ./import-bank.sh --help      Show help"
echo "   ./import-bank.sh --dry-run   Preview without importing"
echo "   ./import-bank.sh --list      List available bank profiles"
echo ""

echo -e "${GREEN}Happy budgeting!${NC}"
echo ""

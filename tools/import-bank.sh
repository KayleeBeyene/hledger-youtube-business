#!/bin/bash
# import-bank.sh - Universal bank CSV importer for hledger
# https://github.com/YOUR_USERNAME/hledger-bank-import
#
# Supports Canadian banks: TD, RBC, Scotiabank, BMO, CIBC
# Easy to extend for other banks
set -uo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config"

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Show help
show_help() {
    cat << EOF
hledger Bank Import v${VERSION}

USAGE:
    ./import-bank.sh [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -v, --version   Show version
    -l, --list      List available bank profiles
    -d, --dry-run   Preview only, don't prompt to import
    -f, --file      Specify CSV file directly (skip auto-detect)

EXAMPLES:
    ./import-bank.sh                    # Auto-detect CSV in Downloads
    ./import-bank.sh --dry-run          # Preview without importing
    ./import-bank.sh -f statement.csv   # Import specific file

SETUP:
    1. Copy config.example to config
    2. Edit config with your settings
    3. Download CSV from your bank
    4. Run ./import-bank.sh

For more info: https://github.com/KayleeBeyene/hledger-bank-import
EOF
}

# Show version
show_version() {
    echo "hledger Bank Import v${VERSION}"
}

# List available bank profiles
list_banks() {
    echo "Available bank profiles:"
    echo ""
    for rules_file in "${SCRIPT_DIR}"/rules/*.rules; do
        if [[ -f "$rules_file" ]]; then
            basename "$rules_file" .rules
        fi
    done
    echo ""
    echo "To add a new bank, create a rules file in the rules/ directory."
}

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Config file not found: $CONFIG_FILE"
        echo ""
        echo "To get started:"
        echo "  1. cp config.example config"
        echo "  2. Edit config with your settings"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
}

# Validate configuration
validate_config() {
    local missing=0

    if [[ -z "${DOWNLOADS_DIR:-}" ]]; then
        error "DOWNLOADS_DIR not set in config"
        missing=1
    fi

    if [[ -z "${LEDGER_FILE:-}" ]]; then
        error "LEDGER_FILE not set in config"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        exit 1
    fi

    # Expand ~ in paths
    DOWNLOADS_DIR="${DOWNLOADS_DIR/#\~/$HOME}"
    LEDGER_FILE="${LEDGER_FILE/#\~/$HOME}"

    # Check directories exist
    if [[ ! -d "$DOWNLOADS_DIR" ]]; then
        error "Downloads directory not found: $DOWNLOADS_DIR"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    if ! command -v hledger >/dev/null 2>&1; then
        error "hledger not found. Please install it first:"
        echo ""
        echo "  macOS:   brew install hledger"
        echo "  Ubuntu:  sudo apt install hledger"
        echo "  Other:   https://hledger.org/install.html"
        exit 1
    fi
}

# Find the most recent bank CSV
find_csv() {
    local csv_patterns="${CSV_PATTERNS:-accountactivity*.csv}"

    # Build find arguments from patterns
    local find_args=()
    local first=1
    for pattern in $csv_patterns; do
        if [[ $first -eq 1 ]]; then
            find_args+=(-iname "$pattern")
            first=0
        else
            find_args+=(-o -iname "$pattern")
        fi
    done

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        find "$DOWNLOADS_DIR" -maxdepth 1 \( "${find_args[@]}" \) -type f -exec stat -f '%m %N' {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
    else
        # Linux
        find "$DOWNLOADS_DIR" -maxdepth 1 \( "${find_args[@]}" \) -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
    fi
}

# Determine which rules file to use
get_rules_file() {
    local csv_file="$1"
    local basename
    basename=$(basename "$csv_file")
    local basename_lower
    basename_lower=$(echo "$basename" | tr '[:upper:]' '[:lower:]')

    # Check BANK_MAPPINGS from config
    if [[ -n "${BANK_MAPPINGS:-}" ]]; then
        while IFS=: read -r pattern bank; do
            pattern_lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
            if [[ "$basename_lower" == *"$pattern_lower"* ]]; then
                local rules_file="${SCRIPT_DIR}/rules/${bank}.rules"
                if [[ -f "$rules_file" ]]; then
                    echo "$rules_file"
                    return 0
                fi
            fi
        done <<< "$BANK_MAPPINGS"
    fi

    # Fallback: try to match filename to rules file
    for rules_file in "${SCRIPT_DIR}"/rules/*.rules; do
        if [[ -f "$rules_file" ]]; then
            local rules_name
            rules_name=$(basename "$rules_file" .rules)
            if [[ "$basename_lower" == *"$rules_name"* ]]; then
                echo "$rules_file"
                return 0
            fi
        fi
    done

    # No match found
    return 1
}

# Main import function
do_import() {
    local csv_file="$1"
    local dry_run_only="${2:-false}"

    info "Importing from: $csv_file"
    echo ""

    # Find rules file
    local rules_file
    rules_file=$(get_rules_file "$csv_file")

    if [[ -z "$rules_file" ]]; then
        error "No matching rules file found for: $(basename "$csv_file")"
        echo ""
        echo "Available rules files:"
        list_banks
        echo ""
        echo "Add a mapping in your config file or create a new rules file."
        exit 1
    fi

    info "Using rules: $(basename "$rules_file")"
    echo ""

    # Build hledger command
    local hledger_args=(
        import
        "$csv_file"
        --rules-file "$rules_file"
    )

    # Add ledger file if specified
    if [[ -n "${LEDGER_FILE:-}" ]]; then
        hledger_args=(--file "$LEDGER_FILE" "${hledger_args[@]}")
    fi

    # Preview (dry-run)
    info "Preview of transactions to import:"
    echo "─────────────────────────────────────────────────────────"
    if ! hledger "${hledger_args[@]}" --dry-run; then
        error "Dry-run failed. Check your CSV file and rules."
        exit 1
    fi
    echo "─────────────────────────────────────────────────────────"
    echo ""

    if [[ "$dry_run_only" == "true" ]]; then
        info "Dry-run complete. No changes made."
        exit 0
    fi

    # Confirm import
    read -p "Import these transactions? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if hledger "${hledger_args[@]}"; then
            success "Transactions imported successfully!"

            # Archive CSV if configured
            if [[ -n "${ARCHIVE_DIR:-}" ]]; then
                ARCHIVE_DIR="${ARCHIVE_DIR/#\~/$HOME}"
                if [[ -d "$ARCHIVE_DIR" ]]; then
                    local archive_name
                    archive_name="$(date +%Y%m%d)_$(basename "$csv_file")"
                    mv "$csv_file" "${ARCHIVE_DIR}/${archive_name}"
                    info "Archived to: ${ARCHIVE_DIR}/${archive_name}"
                fi
            fi
        else
            error "Import failed!"
            exit 1
        fi
    else
        warn "Import cancelled."
    fi
}

# Parse command line arguments
parse_args() {
    DRY_RUN=false
    SPECIFIC_FILE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -l|--list)
                list_banks
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--file)
                SPECIFIC_FILE="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

# Main
main() {
    parse_args "$@"
    load_config
    validate_config
    check_dependencies

    # Find CSV file
    local csv_file
    if [[ -n "$SPECIFIC_FILE" ]]; then
        csv_file="$SPECIFIC_FILE"
        if [[ ! -f "$csv_file" ]]; then
            error "File not found: $csv_file"
            exit 1
        fi
    else
        csv_file=$(find_csv)
        if [[ -z "$csv_file" ]]; then
            error "No bank CSV found in: $DOWNLOADS_DIR"
            echo ""
            echo "Looking for patterns: ${CSV_PATTERNS:-accountactivity*.csv}"
            echo ""
            echo "Download a CSV from your bank, or use --file to specify one."
            exit 1
        fi
    fi

    do_import "$csv_file" "$DRY_RUN"
}

main "$@"

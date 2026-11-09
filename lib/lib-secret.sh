#!/usr/bin/env bash
# ==============================================================================
# Diceware Passphrase Generation & Proof-of-Capture Ceremony Library
# Standalone fragment: can be sourced on host or injected into VM Cloud-Init
# ==============================================================================

# Generates a cryptographically strong Diceware passphrase (~75 bits entropy).
# Formatted as: word-word-word-word-XXX-XXXX
generate_diceware_passphrase() {
    local words_count="${1:-4}"
    local digits_count="${2:-7}"
    local wordlist="${3:-}"

    # Try common wordlist locations if not explicitly passed
    if [[ -z "$wordlist" || ! -f "$wordlist" ]]; then
        for candidate in \
            "${REPO_ROOT:-}/provisioning/wordlists/eff-large-words.txt" \
            "/usr/local/share/dict/eff-words.txt" \
            "/usr/share/dict/words"; do
            if [[ -f "$candidate" ]]; then
                wordlist="$candidate"
                break
            fi
        done
    fi

    if [[ -n "$wordlist" && -f "$wordlist" ]] && command -v shuf &>/dev/null; then
        local words
        words=$(shuf -n "$words_count" "$wordlist" | tr '\n' '-' | sed 's/-$//')

        local raw_digits
        raw_digits=$(LC_ALL=C tr -dc '0-9' </dev/urandom 2>/dev/null | head -c "$digits_count")

        local formatted_digits="$raw_digits"
        if [[ "$digits_count" -eq 7 ]]; then
            formatted_digits="${raw_digits:0:3}-${raw_digits:3:4}"
        fi

        echo "${words}-${formatted_digits}"
    else
        # High-entropy fallback without wordlists
        LC_ALL=C tr -dc 'A-Za-z0-9!#$%*+,-.:=?@^_' </dev/urandom 2>/dev/null | head -c 26
    fi
}

# Interactive Proof-of-Capture Ceremony
# Forces operator to safely store the credential and verify it by re-entering.
proof_of_capture_ceremony() {
    local secret="$1"
    local label="${2:-Credential}"

    while true; do
        echo ""
        echo "========================================================================"
        echo " [SECURITY CEREMONY] $label PROOF-OF-CAPTURE"
        echo "========================================================================"
        echo ""
        echo " Generated credential for: $label"
        echo ""
        echo "   -->   $secret   <--"
        echo ""
        echo " INSTRUCTIONS:"
        echo " 1. Copy and store this credential in a password manager or secure vault."
        echo " 2. Type 'captured' or 'got it' when you have safely saved it."
        echo "========================================================================"
        echo ""
        read -r -p "Confirmation: " confirm_input

        local confirm_lower
        confirm_lower="$(echo "$confirm_input" | tr '[:upper:]' '[:lower:]')"

        if [[ "$confirm_lower" == "captured" || "$confirm_lower" == "got it" ]]; then
            echo ""
            echo "Proof of capture required:"
            echo "Please re-type or paste the $label to verify:"
            read -r -s -p "Verify $label: " verify_input
            echo ""

            if [[ "$verify_input" == "$secret" ]]; then
                echo ""
                echo "[OK] $label successfully verified."
                return 0
            else
                echo ""
                echo "[-] Error: Verification mismatch. Please re-check what you saved and retry."
                read -r -p "Press Enter to try again..."
            fi
        else
            echo ""
            echo "[-] You must enter 'captured' or 'got it' to proceed."
            read -r -p "Press Enter to retry..."
        fi
    done
}

#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " LiteOffice OS — Syntax and Integrity Checker"
echo "=================================================="

FAILED=0
CHECKED=0

check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi
    CHECKED=$((CHECKED + 1))
    
    first_line=$(head -n 1 "$file" 2>/dev/null || echo "")
    if [[ "$file" == *.py ]] || echo "$first_line" | grep -q "python"; then
        if python -m py_compile "$file" 2>/dev/null; then
            echo "[OK] Python: $file"
        else
            echo "[FAIL] Python: $file"
            FAILED=$((FAILED + 1))
        fi
    elif [[ "$file" == *.sh ]] || echo "$first_line" | grep -Eq '(bash|sh|openrc-run)'; then
        if bash -n "$file" 2>&1; then
            echo "[OK] Shell:  $file"
        else
            echo "[FAIL] Shell:  $file"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "[SKIP] Unknown type: $file"
    fi
}

for pattern in \
    "build.sh" \
    "initramfs/*.sh" \
    "installer/*.sh" \
    "scripts/*.sh" \
    "tests/*.sh" \
    "branding/logo/*.sh" \
    "branding/wallpapers/*.sh" \
    "branding/tools/liteoffice-automate" \
    "branding/tools/liteoffice-pkg" \
    "branding/tools/liteoffice-security" \
    "branding/tools/liteoffice-manifest" \
    "branding/apps/*.py" \
    "branding/plymouth/*.py" \
    "desktop/bin/*" \
    "office/bin/*" \
    "init/init.d/*"; do
    for f in $pattern; do
        if [ -f "$f" ]; then
            check_file "$f"
        fi
    done
done

echo "=================================================="
echo "Checked: $CHECKED files"
echo "Failed:  $FAILED files"
echo "=================================================="

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
exit 0

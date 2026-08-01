#!/bin/bash
# review-cves.sh - Lista CVEs/fixes do linux-stable para revisão manual
# Uso: ./review-cves.sh [--since="30 days ago"]

set -euo pipefail

SINCE="${1:-30 days ago}"

cd "$(dirname "${BASH_SOURCE[0]}")"

# Quick check: do we have linux-stable refs?
if ! git rev-parse --verify "linux-stable/linux-4.19.y" >/dev/null 2>&1; then
    echo "Fetching linux-stable/linux-4.19.y (shallow, last 200 commits)..."
    git remote add linux-stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git 2>/dev/null || true
    git fetch linux-stable linux-4.19.y --depth=200 2>/dev/null || {
        echo "Failed to fetch. Check network."
        exit 1
    }
fi

# Get latest commit date to show staleness
LATEST_DATE=$(git log -1 --format="%ci" "linux-stable/linux-4.19.y" 2>/dev/null || echo "unknown")
LATEST_VER=$(git log -1 --format="%s" "linux-stable/linux-4.19.y" 2>/dev/null || echo "unknown")

echo "=== linux-stable/linux-4.19.y status ==="
echo "Último commit: $LATEST_VER ($LATEST_DATE)"
echo "⚠️  NOTA: Linux 4.19 é EOL (Fim de Vida) desde Dez/2024 — não recebe updates regulares"
echo

echo "=== Buscando CVEs/fixes desde '$SINCE' ==="
echo

# Use temp file to avoid subshell issue
TMPFILE=$(mktemp)
git log --oneline --since="$SINCE" \
    --grep="CVE" --grep="security" --grep="fix" --grep="vuln" --grep="VULN" \
    "linux-stable/linux-4.19.y" | head -15 > "$TMPFILE"

if [ ! -s "$TMPFILE" ]; then
    echo "(nenhum commit encontrado no período — branch está parado desde $LATEST_DATE)"
else
    while read -r sha msg; do
        echo "[$sha] $msg"
        git show --stat "$sha" -- "linux-stable/linux-4.19.y" 2>/dev/null | head -8
        echo "---"
    done < "$TMPFILE"
fi
rm -f "$TMPFILE"

echo
echo "Para ver últimos commits (sem filtro de data):"
echo "  git log --oneline linux-stable/linux-4.19.y | head -20"
echo
echo "Para ver patch completo: git show <sha>"
echo "Para cherry-pick: git cherry-pick <sha>"
echo "Dica: use './review-cves.sh \"7 days ago\"' para janela menor"
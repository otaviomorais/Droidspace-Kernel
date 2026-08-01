#!/bin/bash
# sync-upstream.sh - Automatiza sync do upstream TIMISONG-dev + CVE check + rebase patches
# Uso: ./sync-upstream.sh [--apply-cves] [--dry-run]

set -euo pipefail

# Config
UPSTREAM_REPO="https://github.com/TIMISONG-dev/kernel_xiaomi_sm8250.git"
UPSTREAM_BRANCH="magictime-new"
LINUX_STABLE_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
LINUX_STABLE_BRANCH="linux-4.19.y"
LOCAL_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_BRANCH="patches"
MAIN_BRANCH="main"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[SYNC]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; }

DRY_RUN=false
APPLY_CVES=false

for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --apply-cves) APPLY_CVES=true ;;
        *) err "Arg desconhecido: $arg"; exit 1 ;;
    esac
done

cd "$LOCAL_REPO"

# 1. Fetch upstreams
log "Fetching upstreams..."
git fetch origin "$MAIN_BRANCH" 2>/dev/null || true
git fetch upstream 2>/dev/null || git remote add upstream "$UPSTREAM_REPO" && git fetch upstream
git fetch linux-stable 2>/dev/null || git remote add linux-stable "$LINUX_STABLE_REPO" && git fetch linux-stable "$LINUX_STABLE_BRANCH"

# 2. Sync main branch with upstream
log "Syncing $MAIN_BRANCH with upstream/$UPSTREAM_BRANCH..."
git checkout "$MAIN_BRANCH"
if $DRY_RUN; then
    git log --oneline HEAD..upstream/"$UPSTREAM_BRANCH" | head -20
    warn "DRY-RUN: não aplicando merge/rebase"
else
    git merge --ff-only upstream/"$UPSTREAM_BRANCH" 2>/dev/null || {
        warn "Fast-forward falhou, tentando rebase..."
        git rebase upstream/"$UPSTREAM_BRANCH"
    }
    git push origin "$MAIN_BRANCH"
    ok "main atualizado"
fi

# 3. Rebase patches branch
log "Rebasing $PATCHES_BRANCH onto $MAIN_BRANCH..."
git checkout "$PATCHES_BRANCH" 2>/dev/null || {
    warn "Branch $PATCHES_BRANCH não existe localmente, criando a partir de main..."
    git checkout -b "$PATCHES_BRANCH" "$MAIN_BRANCH"
}

if $DRY_RUN; then
    git log --oneline "$MAIN_BRANCH".."$PATCHES_BRANCH" | head -10
    warn "DRY-RUN: não fazendo rebase"
else
    # git rerere para lembrar resoluções
    git config rerere.enabled true
    git config rerere.autoupdate true

    if git rebase "$MAIN_BRANCH"; then
        ok "Rebase limpo"
    else
        err "Conflitos no rebase! Resolva e rode: git rebase --continue"
        echo "Arquivos em conflito:"
        git diff --name-only --diff-filter=U
        exit 1
    fi
    git push -f origin "$PATCHES_BRANCH"
    ok "patches branch atualizado (force-pushed)"
fi

# 4. Check CVEs in linux-4.19.y since last sync
log "Verificando CVEs/fixes de segurança em $LINUX_STABLE_BRANCH..."
LAST_SYNC_TAG="sync-$(date -d '30 days ago' +%Y%m%d 2>/dev/null || date -v-30d +%Y%m%d 2>/dev/null || echo 'unknown')"
CVE_COMMITS=$(git log --oneline --since="30 days ago" --grep -i -E "CVE|security|fix|vuln" "linux-stable/$LINUX_STABLE_BRANCH" 2>/dev/null | head -30)

if [ -n "$CVE_COMMITS" ]; then
    warn "CVEs/fixes encontrados nos últimos 30 dias:"
    echo "$CVE_COMMITS"
    echo
    if $APPLY_CVES && ! $DRY_RUN; then
        echo "$CVE_COMMITS" | while read -r sha msg; do
            log "Tentando cherry-pick $sha..."
            if git cherry-pick "$sha" 2>/dev/null; then
                ok "  $sha aplicado"
            else
                warn "  $sha conflita - pulando (resolva manual)"
                git cherry-pick --abort 2>/dev/null || true
            fi
        done
    elif $DRY_RUN; then
        warn "DRY-RUN: use --apply-cves para tentar cherry-pick automático"
    else
        log "Use --apply-cves para tentar aplicar automaticamente (cuidado: pode quebrar)"
    fi
else
    ok "Nenhum CVE/fix crítico novo nos últimos 30 dias"
fi

# 5. Summary
log "=== SUMMARY ==="
echo "main branch:     $(git rev-parse --short HEAD) ($(git log -1 --format=%s HEAD))"
git checkout "$PATCHES_BRANCH" 2>/dev/null && echo "patches branch:  $(git rev-parse --short HEAD) ($(git log -1 --format=%s HEAD))"
echo
log "Próximos passos:"
echo "  1. Push patches branch: git push -f origin $PATCHES_BRANCH"
echo "  2. GitHub Actions vai buildar (verifique Actions tab)"
echo "  3. Se build falhar: resolva conflitos e rebase novamente"
echo "  4. Tag release: git tag v1.5.2 && git push origin v1.5.2"
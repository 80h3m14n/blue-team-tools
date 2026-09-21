#!/usr/bin/env bash
#
# List-all-packages: A comprehensive installed packages / tools inventory across package managers
#
# Supports filtering, summary-only mode, and detection listing.
#
# Usage:
#   ./list-all-packages.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help
#   -l, --list-pms          Only list detected package managers (no package lists)
#   -s, --summary           Show counts only (no full package lists)
#   -f, --filter <list>     Comma-separated PM names to include (case-insensitive)
#                           Example: -f apt,pip,npm,cargo
#   -u, --user              Prefer user-scoped installs where the PM supports it
#                           (affects pip/pip3, npm/pnpm/yarn/bun, cargo, gem,
#                            composer, dotnet, nix profile, go binaries, etc.)
#   -c, --category <cat>    Restrict to category: system, universal, python,
#                           javascript, rust, go, ruby, php, dotnet, nix, jvm
#   -v, --verbose           Extra diagnostic output (detection failures, paths)
#
# Exit codes: 0 success, 1 usage error, 2 no managers detected
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
TOTAL=0
declare -a DETECTED=()          # ordered list of detected PM keys
declare -A COUNT=()             # PM -> count
declare -A CATEGORY=()          # PM -> category
declare -A CMD_CHECK=()         # PM -> binary used for detection
declare -A FILTER_SET=()
SUMMARY_ONLY=0
LIST_PMS_ONLY=0
USER_ONLY=0
VERBOSE=0
CATEGORY_FILTER=""
FILTER_ARG=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() { echo "Error: $*" >&2; exit 1; }
logv() { [[ $VERBOSE -eq 1 ]] && echo "[verbose] $*" >&2 || true; }

has_cmd() { command -v "$1" &>/dev/null; }

# Safe count of non-empty lines
count_lines() {
    local n
    n=$(grep -c . 2>/dev/null || echo 0)
    echo "${n:-0}"
}

# ---------------------------------------------------------------------------
# Detection + counting functions
# Each function must set COUNT[key] and optionally print the package list
# when $1 == "list".  Return 0 if the manager is present, non-zero otherwise.
# ---------------------------------------------------------------------------

# --- System ----------------------------------------------------------------
detect_dnf() {
    has_cmd dnf || return 1
    local c
    c=$(dnf list installed 2>/dev/null | grep -c '^[a-zA-Z0-9]' || true)
    COUNT[dnf]=$c
    if [[ ${1:-} == list ]]; then
        dnf list installed 2>/dev/null | grep '^[a-zA-Z0-9]' | awk '{print $1, $2}'
    fi
}

detect_apt() {
    has_cmd dpkg-query || return 1
    local c
    c=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | count_lines)
    COUNT[apt]=$c
    if [[ ${1:-} == list ]]; then
        dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null
    fi
}

detect_rpm() {
    has_cmd rpm || return 1
    # Avoid double-counting when dnf/zypper already present unless forced
    local c
    c=$(rpm -qa 2>/dev/null | count_lines)
    COUNT[rpm]=$c
    if [[ ${1:-} == list ]]; then
        rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n' 2>/dev/null
    fi
}

detect_pacman() {
    has_cmd pacman || return 1
    local c
    c=$(pacman -Q 2>/dev/null | count_lines)
    COUNT[pacman]=$c
    if [[ ${1:-} == list ]]; then
        pacman -Q 2>/dev/null
    fi
}

detect_apk() {
    has_cmd apk || return 1
    local c
    c=$(apk info 2>/dev/null | count_lines)
    COUNT[apk]=$c
    if [[ ${1:-} == list ]]; then
        apk info -v 2>/dev/null
    fi
}

detect_zypper() {
    has_cmd zypper || return 1
    local c
    c=$(zypper se -si 2>/dev/null | tail -n +5 | grep -c '^i' || true)
    COUNT[zypper]=$c
    if [[ ${1:-} == list ]]; then
        zypper se -si 2>/dev/null | tail -n +5
    fi
}

detect_xbps() {
    has_cmd xbps-query || return 1
    local c
    c=$(xbps-query -l 2>/dev/null | count_lines)
    COUNT[xbps]=$c
    if [[ ${1:-} == list ]]; then
        xbps-query -l 2>/dev/null | awk '{print $2}'
    fi
}

detect_emerge() {
    has_cmd emerge || return 1
    # Portage: list installed packages via qlist or equery if available, else emerge -ep
    if has_cmd qlist; then
        local c
        c=$(qlist -I 2>/dev/null | count_lines)
        COUNT[emerge]=$c
        if [[ ${1:-} == list ]]; then
            qlist -ICv 2>/dev/null
        fi
    elif has_cmd equery; then
        local c
        c=$(equery list '*' 2>/dev/null | count_lines)
        COUNT[emerge]=$c
        if [[ ${1:-} == list ]]; then
            equery list '*' 2>/dev/null
        fi
    else
        # Fallback: approximate via world + system packages is expensive; report presence only
        COUNT[emerge]=0
        if [[ ${1:-} == list ]]; then
            echo "(install app-portage/portage-utils or gentoolkit for full list)"
        fi
    fi
}

detect_eopkg() {
    has_cmd eopkg || return 1
    local c
    c=$(eopkg list-installed 2>/dev/null | count_lines)
    COUNT[eopkg]=$c
    if [[ ${1:-} == list ]]; then
        eopkg list-installed 2>/dev/null
    fi
}

# --- Universal / Desktop ---------------------------------------------------
detect_snap() {
    has_cmd snap || return 1
    local c
    c=$(snap list 2>/dev/null | tail -n +2 | count_lines)
    COUNT[snap]=$c
    if [[ ${1:-} == list ]]; then
        snap list 2>/dev/null | tail -n +2 | awk '{print $1, $2}'
    fi
}

detect_flatpak() {
    has_cmd flatpak || return 1
    local c
    c=$(flatpak list --app --columns=application,version 2>/dev/null | count_lines)
    COUNT[flatpak]=$c
    if [[ ${1:-} == list ]]; then
        flatpak list --app --columns=application,version 2>/dev/null
    fi
}

detect_brew() {
    has_cmd brew || return 1
    local c
    if [[ $USER_ONLY -eq 1 ]]; then
        c=$(brew list --formula 2>/dev/null | count_lines)
        COUNT[brew]=$c
        if [[ ${1:-} == list ]]; then
            echo "── Formulae ──"
            brew list --formula 2>/dev/null
            echo "── Casks ──"
            brew list --cask 2>/dev/null || true
        fi
    else
        c=$(brew list 2>/dev/null | count_lines)
        COUNT[brew]=$c
        if [[ ${1:-} == list ]]; then
            brew list --versions 2>/dev/null
        fi
    fi
}

# --- Python ----------------------------------------------------------------
detect_pip() {
    has_cmd pip || return 1
    local flags=()
    [[ $USER_ONLY -eq 1 ]] && flags+=(--user)
    local c
    c=$(pip list "${flags[@]}" 2>/dev/null | tail -n +3 | count_lines)
    COUNT[pip]=$c
    if [[ ${1:-} == list ]]; then
        pip list "${flags[@]}" 2>/dev/null | tail -n +3 | awk '{print $1, $2}'
    fi
}

detect_pip3() {
    has_cmd pip3 || return 1
    # Avoid double-counting if pip == pip3
    if has_cmd pip && [[ $(command -v pip) == $(command -v pip3) ]]; then
        return 1
    fi
    local flags=()
    [[ $USER_ONLY -eq 1 ]] && flags+=(--user)
    local c
    c=$(pip3 list "${flags[@]}" 2>/dev/null | tail -n +3 | count_lines)
    COUNT[pip3]=$c
    if [[ ${1:-} == list ]]; then
        pip3 list "${flags[@]}" 2>/dev/null | tail -n +3 | awk '{print $1, $2}'
    fi
}

detect_pipx() {
    has_cmd pipx || return 1
    local c
    c=$(pipx list --short 2>/dev/null | count_lines)
    COUNT[pipx]=$c
    if [[ ${1:-} == list ]]; then
        pipx list --short 2>/dev/null
    fi
}

detect_uv() {
    has_cmd uv || return 1
    local c
    c=$(uv tool list 2>/dev/null | count_lines)
    COUNT[uv]=$c
    if [[ ${1:-} == list ]]; then
        uv tool list 2>/dev/null
    fi
}

detect_poetry() {
    has_cmd poetry || return 1
    # Poetry is primarily project-scoped; report global plugins + current project if present
    local c=0
    if [[ -f pyproject.toml ]] && grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
        c=$(poetry show --no-ansi 2>/dev/null | count_lines)
        COUNT[poetry]=$c
        if [[ ${1:-} == list ]]; then
            echo "(project dependencies from $(pwd))"
            poetry show --no-ansi 2>/dev/null
        fi
    else
        # Global plugins
        c=$(poetry self show plugins 2>/dev/null | count_lines || echo 0)
        COUNT[poetry]=$c
        if [[ ${1:-} == list ]]; then
            poetry self show plugins 2>/dev/null || echo "(no global plugins / not in a Poetry project)"
        fi
    fi
}

# --- JavaScript ------------------------------------------------------------
detect_npm() {
    has_cmd npm || return 1
    local flags=(-g --depth=0)
    [[ $USER_ONLY -eq 1 ]] && flags+=(--prefix "$(npm config get prefix)")
    local c
    c=$(npm list "${flags[@]}" 2>/dev/null | grep -cE '^[├└]' || true)
    COUNT[npm]=$c
    if [[ ${1:-} == list ]]; then
        npm list "${flags[@]}" 2>/dev/null | grep -E '^[├└]' || true
    fi
}

detect_pnpm() {
    has_cmd pnpm || return 1
    local c
    c=$(pnpm list -g --depth 0 2>/dev/null | grep -cE '^[├└]' || true)
    COUNT[pnpm]=$c
    if [[ ${1:-} == list ]]; then
        pnpm list -g --depth 0 2>/dev/null
    fi
}

detect_yarn() {
    has_cmd yarn || return 1
    local c
    c=$(yarn global list 2>/dev/null | grep -c '^[a-zA-Z@]' || true)
    COUNT[yarn]=$c
    if [[ ${1:-} == list ]]; then
        yarn global list 2>/dev/null
    fi
}

detect_bun() {
    has_cmd bun || return 1
    local c
    # Bun global packages live under ~/.bun/install/global
    if [[ -d "${HOME}/.bun/install/global/node_modules" ]]; then
        c=$(find "${HOME}/.bun/install/global/node_modules" -maxdepth 1 -type d ! -name node_modules 2>/dev/null | count_lines)
    else
        c=0
    fi
    COUNT[bun]=$c
    if [[ ${1:-} == list ]]; then
        bun pm ls -g 2>/dev/null || ls "${HOME}/.bun/install/global/node_modules" 2>/dev/null || true
    fi
}

# --- Rust ------------------------------------------------------------------
detect_cargo() {
    has_cmd cargo || return 1
    local c
    c=$(cargo install --list 2>/dev/null | grep -c '^[a-zA-Z0-9]' || true)
    COUNT[cargo]=$c
    if [[ ${1:-} == list ]]; then
        cargo install --list 2>/dev/null | grep -v '^$'
    fi
}

# --- Go --------------------------------------------------------------------
detect_go() {
    has_cmd go || return 1
    local gobin gopathbin
    gobin=$(go env GOBIN 2>/dev/null)
    gopathbin=$(go env GOPATH 2>/dev/null)/bin
    local dirs=()
    [[ -n $gobin && -d $gobin ]] && dirs+=("$gobin")
    [[ -d $gopathbin ]] && dirs+=("$gopathbin")

    local c=0
    local -a bins=()
    for d in "${dirs[@]}"; do
        while IFS= read -r -d '' f; do
            bins+=("$f")
            ((c++)) || true
        done < <(find "$d" -maxdepth 1 -type f -executable -print0 2>/dev/null)
    done
    COUNT[go]=$c

    if [[ ${1:-} == list ]]; then
        echo "── Go binaries (GOBIN / GOPATH/bin) ──"
        for b in "${bins[@]}"; do
            local name ver
            name=$(basename "$b")
            ver=$(go version -m "$b" 2>/dev/null | awk '/^\tmod/{print $2, $3; exit}')
            printf "%-30s %s\n" "$name" "${ver:-unknown}"
        done

        if [[ -f go.mod ]]; then
            echo ""
            echo "── Current project (go.mod) dependencies ──"
            go list -m all 2>/dev/null | tail -n +2 || true
        fi
    fi
}

# --- Ruby ------------------------------------------------------------------
detect_gem() {
    has_cmd gem || return 1
    local flags=()
    [[ $USER_ONLY -eq 1 ]] && flags+=(--user-install)
    local c
    c=$(gem list "${flags[@]}" 2>/dev/null | grep -c '^[a-zA-Z]' || true)
    COUNT[gem]=$c
    if [[ ${1:-} == list ]]; then
        gem list "${flags[@]}" 2>/dev/null | grep '^[a-zA-Z]'
    fi
}

detect_bundler() {
    has_cmd bundle || return 1
    if [[ -f Gemfile ]]; then
        local c
        c=$(bundle list 2>/dev/null | grep -c '^\*' || true)
        COUNT[bundler]=$c
        if [[ ${1:-} == list ]]; then
            echo "(project Gemfile: $(pwd))"
            bundle list 2>/dev/null
        fi
    else
        COUNT[bundler]=0
        if [[ ${1:-} == list ]]; then
            echo "(no Gemfile in current directory)"
        fi
    fi
}

# --- PHP -------------------------------------------------------------------
detect_composer() {
    has_cmd composer || return 1
    local c
    c=$(composer global show 2>/dev/null | count_lines)
    COUNT[composer]=$c
    if [[ ${1:-} == list ]]; then
        composer global show 2>/dev/null
    fi
}

# --- .NET ------------------------------------------------------------------
detect_dotnet() {
    has_cmd dotnet || return 1
    local c
    c=$(dotnet tool list -g 2>/dev/null | tail -n +3 | count_lines)
    COUNT[dotnet]=$c
    if [[ ${1:-} == list ]]; then
        dotnet tool list -g 2>/dev/null
    fi
}

# --- Nix -------------------------------------------------------------------
detect_nix() {
    if has_cmd nix; then
        # Modern nix profile
        local c
        c=$(nix profile list 2>/dev/null | count_lines)
        COUNT[nix]=$c
        if [[ ${1:-} == list ]]; then
            nix profile list 2>/dev/null
        fi
    elif has_cmd nix-env; then
        local c
        c=$(nix-env -q 2>/dev/null | count_lines)
        COUNT[nix]=$c
        if [[ ${1:-} == list ]]; then
            nix-env -q 2>/dev/null
        fi
    else
        return 1
    fi
}

# --- JVM / SDKMAN ----------------------------------------------------------
detect_sdkman() {
    # SDKMAN is usually a shell function; check the directory
    local sdkdir="${SDKMAN_DIR:-$HOME/.sdkman}"
    [[ -d $sdkdir/candidates ]] || return 1
    local c=0
    local -a installed=()
    for cand in "$sdkdir"/candidates/*; do
        [[ -d $cand ]] || continue
        local name=$(basename "$cand")
        for ver in "$cand"/*; do
            [[ -d $ver && $(basename "$ver") != current ]] || continue
            installed+=("$name $(basename "$ver")")
            ((c++)) || true
        done
    done
    COUNT[sdkman]=$c
    if [[ ${1:-} == list ]]; then
        if has_cmd sdk; then
            echo "── sdk current ──"
            sdk current 2>/dev/null || true
            echo ""
        fi
        printf "%s\n" "${installed[@]}"
    fi
}

# ---------------------------------------------------------------------------
# Registry of all managers
# ---------------------------------------------------------------------------
register() {
    local key=$1 cat=$2 check=$3
    CATEGORY[$key]=$cat
    CMD_CHECK[$key]=$check
}

register dnf        system      dnf
register apt        system      dpkg-query
register rpm        system      rpm
register pacman     system      pacman
register apk        system      apk
register zypper     system      zypper
register xbps       system      xbps-query
register emerge     system      emerge
register eopkg      system      eopkg

register snap       universal   snap
register flatpak    universal   flatpak
register brew       universal   brew

register pip        python      pip
register pip3       python      pip3
register pipx       python      pipx
register uv         python      uv
register poetry     python      poetry

register npm        javascript  npm
register pnpm       javascript  pnpm
register yarn       javascript  yarn
register bun        javascript  bun

register cargo      rust        cargo

register go         go          go

register gem        ruby        gem
register bundler    ruby        bundle

register composer   php         composer

register dotnet     dotnet      dotnet

register nix        nix         nix

register sdkman     jvm         sdk

# Ordered keys for stable output
ALL_KEYS=(
    dnf apt rpm pacman apk zypper xbps emerge eopkg
    snap flatpak brew
    pip pip3 pipx uv poetry
    npm pnpm yarn bun
    cargo
    go
    gem bundler
    composer
    dotnet
    nix
    sdkman
)

# ---------------------------------------------------------------------------
# CLI parsing
# ---------------------------------------------------------------------------
usage() {
    cat <<'EOF'
list-all-packages.sh — inventory of installed packages/tools

Usage: list-all-packages.sh [OPTIONS]

Options:
  -h, --help              Show this help and exit
  -l, --list-pms          Only list detected package managers + counts
  -s, --summary           Show section headers + counts only
  -f, --filter LIST       Comma-separated PM names (e.g. apt,pip,npm,cargo)
  -u, --user              Prefer user-scoped installs where supported
  -c, --category CAT      One of: system universal python javascript
                          rust go ruby php dotnet nix jvm
  -v, --verbose           Diagnostic output

Examples:
  ./list-all-packages.sh -l
  ./list-all-packages.sh -f apt,pipx,cargo -s
  ./list-all-packages.sh -c python -u
  ./list-all-packages.sh -c javascript
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)      usage; exit 0 ;;
        -l|--list-pms)  LIST_PMS_ONLY=1; shift ;;
        -s|--summary)   SUMMARY_ONLY=1; shift ;;
        -u|--user)      USER_ONLY=1; shift ;;
        -v|--verbose)   VERBOSE=1; shift ;;
        -f|--filter)
            [[ -n ${2:-} ]] || die "--filter requires an argument"
            FILTER_ARG=$2
            shift 2
            ;;
        -c|--category)
            [[ -n ${2:-} ]] || die "--category requires an argument"
            CATEGORY_FILTER=$2
            shift 2
            ;;
        *) die "unknown option: $1 (use -h for help)" ;;
    esac
done

# Build filter set
if [[ -n $FILTER_ARG ]]; then
    IFS=',' read -ra _f <<< "$FILTER_ARG"
    for f in "${_f[@]}"; do
        FILTER_SET[${f,,}]=1
    done
fi

# ---------------------------------------------------------------------------
# Detection pass
# ---------------------------------------------------------------------------
for key in "${ALL_KEYS[@]}"; do
    # Category filter
    if [[ -n $CATEGORY_FILTER && ${CATEGORY[$key]} != "$CATEGORY_FILTER" ]]; then
        continue
    fi
    # Explicit filter
    if [[ ${#FILTER_SET[@]} -gt 0 && -z ${FILTER_SET[$key]+x} ]]; then
        continue
    fi

    detect_fn="detect_$key"
    if declare -f "$detect_fn" >/dev/null; then
        if $detect_fn; then
            DETECTED+=("$key")
            TOTAL=$((TOTAL + COUNT[$key]))
            logv "detected $key → ${COUNT[$key]} items"
        else
            logv "not present: $key"
        fi
    fi
done

if [[ ${#DETECTED[@]} -eq 0 ]]; then
    echo "No matching package managers detected."
    exit 2
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
echo "=========================================="
echo "  Installed Packages / Tools Summary"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

if [[ $LIST_PMS_ONLY -eq 1 ]]; then
    printf "%-12s %-10s %s\n" "MANAGER" "CATEGORY" "COUNT"
    printf "%-12s %-10s %s\n" "-------" "--------" "-----"
    for key in "${DETECTED[@]}"; do
        printf "%-12s %-10s %s\n" "$key" "${CATEGORY[$key]}" "${COUNT[$key]}"
    done
    echo ""
    echo "Total: $TOTAL items across ${#DETECTED[@]} managers"
    exit 0
fi

for key in "${DETECTED[@]}"; do
    title=$(echo "$key" | tr '[:lower:]' '[:upper:]')
    case $key in
        apt)      title="APT/DPKG" ;;
        emerge)   title="Portage/Gentoo" ;;
        sdkman)   title="SDKMAN" ;;
        go)       title="Go" ;;
        bun)      title="Bun" ;;
        uv)       title="uv" ;;
        pipx)     title="pipx" ;;
        poetry)   title="Poetry" ;;
        bundler)  title="Bundler" ;;
        composer) title="Composer" ;;
        dotnet)   title=".NET tools" ;;
    esac

    echo "── $title (${COUNT[$key]}) ──"

    if [[ $SUMMARY_ONLY -eq 0 ]]; then
        detect_fn="detect_$key"
        $detect_fn list
    fi
    echo ""
done

echo "=========================================="
echo "  Total: $TOTAL items across ${#DETECTED[@]} package managers"
echo "=========================================="

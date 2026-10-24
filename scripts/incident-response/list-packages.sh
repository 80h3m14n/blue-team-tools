#!/usr/bin/env bash
#
# A comprehensive installed packages / tools inventory across package managers
#
# Supports filtering, summary-only mode, and detection listing.
#
# Installation:
#    sudo ln -s $(pwd)/list-packages.sh $HOME/.local/bin/list-packages
#
# Usage:
#   ./list-packages.sh [OPTIONS] # list-packages -h
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
declare -A FILTER_SET=()
SUMMARY_ONLY=0
LIST_PMS_ONLY=0
USER_ONLY=0
VERBOSE=0
CATEGORY_FILTER=""
FILTER_ARG=""
SEARCH_REGEX=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() { echo "Error: $*" >&2; exit 1; }
logv() { [[ $VERBOSE -eq 1 ]] && echo "[verbose] $*" >&2 || true; }

has_cmd() { command -v "$1" &>/dev/null; }

get_distro_name() {
    if [[ -f /etc/os-release ]]; then
        # Extract PRETTY_NAME from os-release
        grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' || echo "Linux"
    else
        echo "Linux"
    fi
}

get_native_pm() {
    if has_cmd dnf; then echo "dnf";
    elif has_cmd apt || has_cmd apt-get; then echo "apt";
    elif has_cmd pacman; then echo "pacman";
    elif has_cmd zypper; then echo "zypper";
    elif has_cmd apk; then echo "apk";
    elif has_cmd rpm; then echo "rpm";
    elif has_cmd xbps-query; then echo "xbps";
    elif has_cmd emerge; then echo "portage";
    elif has_cmd eopkg; then echo "eopkg";
    elif has_cmd brew; then echo "brew";
    else echo "unknown"; fi
}

# Safe count of non-empty lines with trailing whitespace removed
count_lines() {
    local n
    n=$(grep -c . 2>/dev/null || echo 0)
    echo "$n" | tr -d '[:space:]'
}

# Standardized column printing
print_table() {
    if [[ -n $SEARCH_REGEX ]]; then
        SEARCH_PATTERN=$SEARCH_REGEX awk '
            BEGIN { re = ENVIRON["SEARCH_PATTERN"] }
            $1 ~ re {
                if (!found) {
                    printf "%-35s %-20s %-12s\n", "NAME", "VERSION", "SIZE"
                    printf "%-35s %-20s %-12s\n", "-----------------------------------", "--------------------", "------------"
                    found=1
                }
                print
            }
        '
        return
    fi
    printf "%-35s %-20s %-12s\n" "NAME" "VERSION" "SIZE"
    printf "%-35s %-20s %-12s\n" "-----------------------------------" "--------------------" "------------"
    cat
}

# ---------------------------------------------------------------------------
# Detection + counting functions
# ---------------------------------------------------------------------------

# --- System ----------------------------------------------------------------
detect_dnf() {
    has_cmd dnf || return 1
    local c
    c=$(dnf list installed --quiet 2>/dev/null | grep -c '^[a-zA-Z0-9]' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')

    if [[ "$c" -eq 0 ]] && has_cmd rpm; then
        c=$(rpm -qa 2>/dev/null | count_lines || echo 0)
    fi

    COUNT[dnf]=$c
    if [[ ${1:-} == list ]]; then
        dnf list installed --quiet 2>/dev/null | grep '^[a-zA-Z0-9]' | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || \
        rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{SIZE}\n' 2>/dev/null | awk -F'\t' '{
            size=$3/1024;
            unit="KB";
            if (size > 1024) { size=size/1024; unit="MB"; }
            printf "%-35s %-20s %-12s\n", $1, $2, sprintf("%.1f %s", size, unit)
        }' | print_table || true
    fi
    return 0
}

detect_apt() {
    has_cmd dpkg-query || return 1
    local c
    c=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | count_lines || echo 0)
    [[ "$c" -gt 0 ]] || return 1
    COUNT[apt]=$c
    if [[ ${1:-} == list ]]; then
        dpkg-query -W -f='${Package}\t${Version}\t${Installed-Size}KB\n' 2>/dev/null | awk -F'\t' '{printf "%-35s %-20s %-12s\n", $1, $2, $3}' | print_table || true
    fi
}

detect_rpm() {
    has_cmd rpm || return 1
    if has_cmd dnf; then return 1; fi
    local c
    c=$(rpm -qa 2>/dev/null | count_lines || echo 0)
    COUNT[rpm]=$c
    if [[ ${1:-} == list ]]; then
        rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{SIZE}\n' 2>/dev/null | awk -F'\t' '{
            size=$3/1024;
            unit="KB";
            if (size > 1024) { size=size/1024; unit="MB"; }
            printf "%-35s %-20s %-12s\n", $1, $2, sprintf("%.1f %s", size, unit)
        }' | print_table || true
    fi
}

detect_pacman() {
    has_cmd pacman || return 1
    local c
    c=$(pacman -Q 2>/dev/null | count_lines || echo 0)
    COUNT[pacman]=$c
    if [[ ${1:-} == list ]]; then
        pacman -Qi 2>/dev/null | awk '
            /^Name/ {pkg=$3}
            /^Version/ {ver=$3}
            /^Installed Size/ {size=$4" "$5; printf "%-35s %-20s %-12s\n", pkg, ver, size}
        ' | print_table || true
    fi
}

detect_apk() {
    has_cmd apk || return 1
    local c
    c=$(apk info 2>/dev/null | count_lines || echo 0)
    COUNT[apk]=$c
    if [[ ${1:-} == list ]]; then
        apk info -s 2>/dev/null | awk '
            /installed size/ {size=$1" "$2}
            /description/ {printf "%-35s %-20s %-12s\n", pkg, "N/A", size}
            {if ($0 !~ /installed size|description/) pkg=$1}
        ' | print_table || true
    fi
}

detect_zypper() {
    has_cmd zypper || return 1
    local c
    c=$(zypper se -si 2>/dev/null | tail -n +5 | grep -c '^i' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')
    COUNT[zypper]=$c
    if [[ ${1:-} == list ]]; then
        zypper se -si 2>/dev/null | tail -n +5 | awk -F'|' '{printf "%-35s %-20s %-12s\n", $2, $4, "N/A"}' | print_table || true
    fi
}

detect_xbps() {
    has_cmd xbps-query || return 1
    local c
    c=$(xbps-query -l 2>/dev/null | count_lines || echo 0)
    COUNT[xbps]=$c
    if [[ ${1:-} == list ]]; then
        xbps-query -l 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $2, "N/A", "N/A"}' | print_table || true
    fi
}

detect_emerge() {
    has_cmd emerge || return 1
    if has_cmd qlist; then
        local c
        c=$(qlist -I 2>/dev/null | count_lines || echo 0)
        COUNT[emerge]=$c
        if [[ ${1:-} == list ]]; then
            qlist -ICv 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, "N/A", "N/A"}' | print_table || true
        fi
    else
        COUNT[emerge]=0
    fi
}

detect_eopkg() {
    has_cmd eopkg || return 1
    local c
    c=$(eopkg list-installed 2>/dev/null | count_lines || echo 0)
    COUNT[eopkg]=$c
    if [[ ${1:-} == list ]]; then
        eopkg list-installed 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, "N/A", "N/A"}' | print_table || true
    fi
}

# --- Universal / Desktop ---------------------------------------------------
detect_snap() {
    has_cmd snap || return 1
    local c
    c=$(snap list 2>/dev/null | tail -n +2 | count_lines || echo 0)
    COUNT[snap]=$c
    if [[ ${1:-} == list ]]; then
        snap list 2>/dev/null | tail -n +2 | awk '{printf "%-35s %-20s %-12s\n", $1, $2, $6}' | print_table || true
    fi
}

detect_flatpak() {
    has_cmd flatpak || return 1
    local c
    c=$(flatpak list --app --columns=application,version,size 2>/dev/null | count_lines || echo 0)
    COUNT[flatpak]=$c
    if [[ ${1:-} == list ]]; then
        flatpak list --app --columns=application,version,size 2>/dev/null | awk -F'\t' '{printf "%-35s %-20s %-12s\n", $1, ($2!=""?$2:"N/A"), ($3!=""?$3:"N/A")}' | print_table || true
    fi
}

detect_brew() {
    has_cmd brew || return 1
    local c
    c=$(brew list 2>/dev/null | count_lines || echo 0)
    COUNT[brew]=$c
    if [[ ${1:-} == list ]]; then
        brew list --versions 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

# --- Python ----------------------------------------------------------------
detect_pip() {
    has_cmd pip || return 1
    local flags=()
    [[ $USER_ONLY -eq 1 ]] && flags+=(--user)
    local c
    c=$(pip list "${flags[@]}" 2>/dev/null | tail -n +3 | count_lines || echo 0)
    COUNT[pip]=$c
    if [[ ${1:-} == list ]]; then
        pip list "${flags[@]}" 2>/dev/null | tail -n +3 | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

detect_pip3() {
    has_cmd pip3 || return 1
    if has_cmd pip && [[ $(command -v pip) == $(command -v pip3) ]]; then
        return 1
    fi
    local flags=()
    [[ $USER_ONLY -eq 1 ]] && flags+=(--user)
    local c
    c=$(pip3 list "${flags[@]}" 2>/dev/null | tail -n +3 | count_lines || echo 0)
    COUNT[pip3]=$c
    if [[ ${1:-} == list ]]; then
        pip3 list "${flags[@]}" 2>/dev/null | tail -n +3 | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

detect_pipx() {
    has_cmd pipx || return 1
    local c
    c=$(pipx list --short 2>/dev/null | count_lines || echo 0)
    COUNT[pipx]=$c
    if [[ ${1:-} == list ]]; then
        pipx list --short 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

detect_uv() {
    has_cmd uv || return 1
    local c
    c=$(uv tool list 2>/dev/null | count_lines || echo 0)
    COUNT[uv]=$c
    if [[ ${1:-} == list ]]; then
        uv tool list 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, ($2!=""?$2:"N/A"), "N/A"}' | print_table || true
    fi
}

detect_poetry() {
    has_cmd poetry || return 1
    local c=0
    if [[ -f pyproject.toml ]] && grep -q '\[tool.poetry\]' pyproject.toml 2>/dev/null; then
        c=$(poetry show --no-ansi 2>/dev/null | count_lines || echo 0)
        COUNT[poetry]=$c
        if [[ ${1:-} == list ]]; then
            poetry show --no-ansi 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
        fi
    else
        c=$(poetry self show plugins 2>/dev/null | count_lines || echo 0)
        COUNT[poetry]=$c
        if [[ ${1:-} == list ]]; then
            poetry self show plugins 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || echo "(no global plugins)"
        fi
    fi
}

# --- JavaScript ------------------------------------------------------------
detect_npm() {
    has_cmd npm || return 1
    local flags=(-g --depth=0)
    [[ $USER_ONLY -eq 1 ]] && flags+=(--prefix "$(npm config get prefix 2>/dev/null || echo "")")
    local c
    c=$(npm list "${flags[@]}" 2>/dev/null | grep -cE '^[├└]' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')
    COUNT[npm]=$c
    if [[ ${1:-} == list ]]; then
        npm list "${flags[@]}" 2>/dev/null | grep -E '^[├└]' | sed 's/[├└]── //g' | awk -F'@' '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

detect_pnpm() {
    has_cmd pnpm || return 1
    local c
    c=$(pnpm list -g --depth 0 2>/dev/null | grep -cE '^[├└]' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')
    COUNT[pnpm]=$c
    if [[ ${1:-} == list ]]; then
        pnpm list -g --depth 0 2>/dev/null | grep -E '^[├└]' | sed 's/[├└]── //g' | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

detect_yarn() {
    has_cmd yarn || return 1
    local c
    c=$(yarn global list 2>/dev/null | grep -c '^[a-zA-Z@]' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')
    COUNT[yarn]=$c
    if [[ ${1:-} == list ]]; then
        yarn global list 2>/dev/null | grep 'info "' | awk -F'"' '{print $2}' | awk -F'@' '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

detect_bun() {
    has_cmd bun || return 1
    local c=0
    if [[ -d "${HOME}/.bun/install/global/node_modules" ]]; then
        c=$(find "${HOME}/.bun/install/global/node_modules" -maxdepth 1 -type d ! -name node_modules 2>/dev/null | count_lines || echo 0)
    fi
    COUNT[bun]=$c
    if [[ ${1:-} == list ]]; then
        find "${HOME}/.bun/install/global/node_modules" -maxdepth 1 -type d ! -name node_modules 2>/dev/null | awk -F'/' '{printf "%-35s %-20s %-12s\n", $NF, "N/A", "N/A"}' | print_table || true
    fi
}

# --- Rust ------------------------------------------------------------------
detect_cargo() {
    has_cmd cargo || return 1
    local c
    c=$(cargo install --list 2>/dev/null | grep -c '^[a-zA-Z0-9]' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')
    COUNT[cargo]=$c
    if [[ ${1:-} == list ]]; then
        cargo install --list 2>/dev/null | grep '^[a-zA-Z0-9]' | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | sed 's/://g' | print_table || true
    fi
}

# --- Go --------------------------------------------------------------------
detect_go() {
    has_cmd go || return 1
    local gobin gopathbin
    gobin=$(go env GOBIN 2>/dev/null || true)
    gopathbin="$(go env GOPATH 2>/dev/null || echo "$HOME/go")/bin"
    local dirs=()
    [[ -n $gobin && -d $gobin ]] && dirs+=("$gobin")
    [[ -d $gopathbin ]] && dirs+=("$gopathbin")

    local c=0
    local -a bins=()
    for d in "${dirs[@]}"; do
        while IFS= read -r -d '' f; do
            bins+=("$f")
            c=$((c + 1))
        done < <(find "$d" -maxdepth 1 -type f -executable -print0 2>/dev/null || true)
    done
    COUNT[go]=$c

    if [[ ${1:-} == list ]]; then
        for b in "${bins[@]}"; do
            local name ver sz
            name=$(basename "$b")
            ver=$(go version -m "$b" 2>/dev/null | awk '/^\tmod/{print $3; exit}' || echo "N/A")
            sz=$(du -h "$b" 2>/dev/null | awk '{print $1}' || echo "N/A")
            printf "%-35s %-20s %-12s\n" "$name" "${ver:-N/A}" "$sz"
        done | print_table || true
    fi
}

# --- Ruby ------------------------------------------------------------------
detect_gem() {
    has_cmd gem || return 1
    local flags=()
    [[ $USER_ONLY -eq 1 ]] && flags+=(--user-install)
    local c
    c=$(gem list "${flags[@]}" 2>/dev/null | grep -c '^[a-zA-Z]' || echo 0)
    c=$(echo "$c" | tr -d '[:space:]')
    COUNT[gem]=$c
    if [[ ${1:-} == list ]]; then
        gem list "${flags[@]}" 2>/dev/null | grep '^[a-zA-Z]' | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | tr -d '()' | print_table || true
    fi
}

detect_bundler() {
    has_cmd bundle || return 1
    if [[ -f Gemfile ]]; then
        local c
        c=$(bundle list 2>/dev/null | grep -c '^\*' || echo 0)
        c=$(echo "$c" | tr -d '[:space:]')
        COUNT[bundler]=$c
        if [[ ${1:-} == list ]]; then
            bundle list 2>/dev/null | grep '^\*' | awk '{printf "%-35s %-20s %-12s\n", $2, $3, "N/A"}' | tr -d '()' | print_table || true
        fi
    else
        COUNT[bundler]=0
    fi
}

# --- PHP -------------------------------------------------------------------
detect_composer() {
    has_cmd composer || return 1
    local c
    c=$(composer global show 2>/dev/null | count_lines || echo 0)
    COUNT[composer]=$c
    if [[ ${1:-} == list ]]; then
        composer global show 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

# --- .NET ------------------------------------------------------------------
detect_dotnet() {
    has_cmd dotnet || return 1
    local c
    c=$(dotnet tool list -g 2>/dev/null | tail -n +3 | count_lines || echo 0)
    COUNT[dotnet]=$c
    if [[ ${1:-} == list ]]; then
        dotnet tool list -g 2>/dev/null | tail -n +3 | awk '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

# --- Nix -------------------------------------------------------------------
detect_nix() {
    if has_cmd nix; then
        local c
        c=$(nix profile list 2>/dev/null | count_lines || echo 0)
        COUNT[nix]=$c
        if [[ ${1:-} == list ]]; then
            nix profile list 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $2, $3, "N/A"}' | print_table || true
        fi
    elif has_cmd nix-env; then
        local c
        c=$(nix-env -q 2>/dev/null | count_lines || echo 0)
        COUNT[nix]=$c
        if [[ ${1:-} == list ]]; then
            nix-env -q 2>/dev/null | awk '{printf "%-35s %-20s %-12s\n", $1, "N/A", "N/A"}' | print_table || true
        fi
    else
        return 1
    fi
}

# --- JVM / SDKMAN ----------------------------------------------------------
detect_sdkman() {
    local sdkdir="${SDKMAN_DIR:-$HOME/.sdkman}"
    [[ -d $sdkdir/candidates ]] || return 1
    local c=0
    local -a installed=()
    for cand in "$sdkdir"/candidates/*; do
        [[ -d $cand ]] || continue
        local name
        name=$(basename "$cand")
        for ver in "$cand"/*; do
            [[ -d $ver && $(basename "$ver") != current ]] || continue
            installed+=("$name\t$(basename "$ver")")
            c=$((c + 1))
        done
    done
    COUNT[sdkman]=$c
    if [[ ${1:-} == list ]]; then
        printf "%b\n" "${installed[@]}" | awk -F'\t' '{printf "%-35s %-20s %-12s\n", $1, $2, "N/A"}' | print_table || true
    fi
}

# ---------------------------------------------------------------------------
# Registry of all managers
# ---------------------------------------------------------------------------
register() {
    local key=$1 cat=$2
    CATEGORY[$key]=$cat
}

register dnf        system
register apt        system
register rpm        system
register pacman     system
register apk        system
register zypper     system
register xbps       system
register emerge     system
register eopkg      system

register snap       universal
register flatpak    universal
register brew       universal

register pip        python
register pip3       python
register pipx       python
register uv         python
register poetry     python

register npm        javascript
register pnpm       javascript
register yarn       javascript
register bun        javascript

register cargo      rust

register go         go

register gem        ruby
register bundler    ruby

register composer   php

register dotnet     dotnet

register nix        nix

register sdkman     jvm

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
list-packages.sh — inventory of installed packages/tools

Usage: list-packages.sh [OPTIONS]

Options:
  -h, --help              Show this help and exit
  -l, --list-pms          Only list detected package managers + counts
  -s, --summary           Show section headers + counts only
  -q, --search REGEX      Search package names using a POSIX extended regex
  -f, --filter LIST       Comma-separated PM names (e.g. apt,pip,npm,cargo)
  -u, --user              Prefer user-scoped installs where supported
  -c, --category CAT      One of: system universal python javascript
                          rust go ruby php dotnet nix jvm
  -v, --verbose           Diagnostic output

Examples:
  ./list-packages.sh -l
  ./list-packages.sh -f apt,pipx,cargo -s
  ./list-packages.sh -q '^python'
  ./list-packages.sh -c python -u
  ./list-packages.sh -c javascript
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)      usage; exit 0 ;;
        -l|--list-pms)  LIST_PMS_ONLY=1; shift ;;
        -s|--summary)   SUMMARY_ONLY=1; shift ;;
        -q|--search)
            [[ -n ${2:-} ]] || die "--search requires a regex argument"
            SEARCH_REGEX=$2
            shift 2
            ;;
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

if [[ -n $SEARCH_REGEX ]]; then
    if ! printf '' | grep -E -q -- "$SEARCH_REGEX"; then
        grep_status=${PIPESTATUS[1]}
        [[ $grep_status -ne 2 ]] || die "invalid search regex: $SEARCH_REGEX"
    fi
    SUMMARY_ONLY=0
fi

# Build filter set
if [[ -n $FILTER_ARG ]]; then
    IFS=',' read -ra _f <<< "$FILTER_ARG"
    for f in "${_f[@]}"; do
        FILTER_SET[${f,,}]=1
    done
fi

# Print immediate feedback to standard error so user knows script is running
echo "Collecting package information..." >&2
#printf '%sCollecting package information...%s\n' "$CYAN" "$RESET" >&2

# ---------------------------------------------------------------------------
# Detection pass
# ---------------------------------------------------------------------------
for key in "${ALL_KEYS[@]}"; do
    # Category filter
    if [[ -n $CATEGORY_FILTER && ${CATEGORY[$key]:-} != "$CATEGORY_FILTER" ]]; then
        continue
    fi
    # Explicit filter
    if [[ ${#FILTER_SET[@]} -gt 0 && -z ${FILTER_SET[$key]+x} ]]; then
        continue
    fi

    detect_fn="detect_$key"
    if declare -f "$detect_fn" >/dev/null; then
        if $detect_fn; then
            c_val=$(echo "${COUNT[$key]:-0}" | tr -d '[:space:]')
            DETECTED+=("$key")
            TOTAL=$(( TOTAL + c_val ))
            logv "detected $key → ${c_val} items"
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
# Output Header
# ---------------------------------------------------------------------------
echo "Package Inventory"
echo "Distro: $(get_distro_name)"
echo "Native manager: $(get_native_pm)"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
if [[ -n $SEARCH_REGEX ]]; then
    echo "Search: $SEARCH_REGEX"
fi
echo ""

if [[ $LIST_PMS_ONLY -eq 1 ]]; then
    printf "%-12s %-10s %s\n" "MANAGER" "CATEGORY" "COUNT"
    printf "%-12s %-10s %s\n" "-------" "--------" "-----"
    for key in "${DETECTED[@]}"; do
        c_val=$(echo "${COUNT[$key]:-0}" | tr -d '[:space:]')
        printf "%-12s %-10s %s\n" "$key" "${CATEGORY[$key]:-unknown}" "$c_val"
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

    c_val=$(echo "${COUNT[$key]:-0}" | tr -d '[:space:]')
    if [[ -n $SEARCH_REGEX ]]; then
        echo "── $title (search results; inventory count: $c_val) ──"
    else
        echo "── $title ($c_val) ──"
    fi

    if [[ $SUMMARY_ONLY -eq 0 ]]; then
        detect_fn="detect_$key"
        $detect_fn list || true
    fi
    echo ""
done

echo "=========================================="
echo "  Total: $TOTAL items across ${#DETECTED[@]} package managers"
echo "=========================================="

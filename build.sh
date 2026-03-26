#!/usr/bin/env bash
set -e

# ──────────────────────────────────────────────
# Omnidea Build Script
# Builds all submodules in dependency order:
#   Omninet (protocol) -> Ore (engine) -> Omny (browser)
# ──────────────────────────────────────────────

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    RED="\033[31m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" RED="" RESET=""
fi

info()  { echo -e "${BOLD}==> $1${RESET}"; }
ok()    { echo -e "${GREEN}==> $1${RESET}"; }
fail()  { echo -e "${RED}==> $1${RESET}"; exit 1; }

# ── Check required tools ──────────────────────

info "Checking required tools..."

command -v cargo >/dev/null 2>&1 || fail "cargo not found. Install Rust: https://rustup.rs"
command -v npm   >/dev/null 2>&1 || fail "npm not found. Install Node.js: https://nodejs.org"
command -v node  >/dev/null 2>&1 || fail "node not found. Install Node.js: https://nodejs.org"

ok "Tools: cargo $(cargo --version | cut -d' ' -f2), npm $(npm --version), node $(node --version)"

# ── Check submodules ──────────────────────────

info "Checking submodules..."

if [ ! -f "$ROOT/Omninet/Cargo.toml" ] || [ ! -f "$ROOT/Ore/package.json" ] || [ ! -f "$ROOT/Omny/omnidaemon/Cargo.toml" ]; then
    info "Initializing submodules..."
    git -C "$ROOT" submodule update --init --recursive
fi

# ── 1. Omninet (protocol) ────────────────────

info "Building Omninet (protocol)..."
(cd "$ROOT/Omninet" && cargo build --workspace)
ok "Omninet built."

# ── 2. Ore (engine + libraries) ──────────────

info "Building Ore (engine + libraries)..."
(cd "$ROOT/Ore" && npm install && npm run build)
ok "Ore built."

# ── 3. Omny -- omnigrams (frontend) ─────────

info "Building Omny/omnigrams (frontend)..."
(cd "$ROOT/Omny/omnigrams" && npm install && npm run build)
ok "Omny/omnigrams built."

# ── 4. Omny -- omnidaemon (node service) ────

info "Building Omny/omnidaemon (node service)..."
(cd "$ROOT/Omny/omnidaemon" && cargo build)
ok "Omny/omnidaemon built."

# ── 5. Omny -- omnishell (window shell) ─────

info "Building Omny/omnishell (window shell)..."
(cd "$ROOT/Omny/omnishell" && cargo build)
ok "Omny/omnishell built."

# ── Done ─────────────────────────────────────

echo ""
ok "Omnidea built successfully."
echo ""
echo "  Omninet:    $ROOT/Omninet/target/"
echo "  Ore:        $ROOT/Ore/"
echo "  omnigrams:  $ROOT/Omny/omnigrams/"
echo "  omnidaemon: $ROOT/Omny/omnidaemon/target/"
echo "  omnishell:  $ROOT/Omny/omnishell/target/"
echo ""

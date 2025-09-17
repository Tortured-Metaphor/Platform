#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QL_DIR="$ROOT_DIR/.quicklisp"
RES_DIR="$ROOT_DIR/resources"
FONT_FILE="$RES_DIR/DejaVuSans.ttf"
QUICKLISP_URL="https://beta.quicklisp.org/quicklisp.lisp"
FONT_URL="https://github.com/dejavu-fonts/dejavu-fonts/raw/master/ttf/DejaVuSans.ttf"

log() { printf '\033[1;32m[platform]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[platform]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[platform]\033[0m %s\n' "$*"; }

die() { err "$1"; exit 1; }

command -v sbcl >/dev/null 2>&1 || die "SBCL is required. Install it via your package manager (e.g. 'brew install sbcl')."

# Ensure SDL is available by checking for the shared library via sdl2-config when possible.
if command -v sdl2-config >/dev/null 2>&1; then
  log "Using SDL2 from $(sdl2-config --prefix)"
else
  warn "Could not find 'sdl2-config' in PATH. Make sure SDL2 / SDL2_ttf are installed before running."
fi

mkdir -p "$RES_DIR"

if [ ! -f "$FONT_FILE" ]; then
  log "Fetching DejaVuSans.ttf font asset..."
  curl -L --fail -o "$FONT_FILE" "$FONT_URL" || die "Failed to download font from $FONT_URL"
fi

if [ ! -f "$QL_DIR/setup.lisp" ]; then
  log "Installing Quicklisp locally..."
  curl -L --fail -o "$ROOT_DIR/quicklisp.lisp" "$QUICKLISP_URL" || die "Failed to download Quicklisp"
  sbcl --non-interactive \
       --load "$ROOT_DIR/quicklisp.lisp" \
       --eval "(quicklisp-quickstart:install :path \"$QL_DIR\")" \
       --quit || die "Quicklisp installation failed"
  rm -f "$ROOT_DIR/quicklisp.lisp"
fi

export PLATFORM_FONT_PATH="$FONT_FILE"
export SDL_HINT_RENDER_SCALE_QUALITY=${SDL_HINT_RENDER_SCALE_QUALITY:-1}

log "Launching Platform..."
sbcl --non-interactive \
     --load "$QL_DIR/setup.lisp" \
     --eval "(pushnew (truename \"$ROOT_DIR\") ql:*local-project-directories* :test #'equal)" \
     --eval "(setf ql:*compile-file-skip-notes* t)" \
     --eval "(ql:quickload :platform)" \
     --eval "(platform:main)"

#!/bin/sh
# Twira installer
# Usage: curl -fsSL https://raw.githubusercontent.com/TwiraHQ/twira/main/install.sh | sh
set -e

REPO="TwiraHQ/twira"
INSTALL_DIR="${TWIRA_INSTALL_DIR:-$HOME/.twira/bin}"
BINARY_NAME="twira"

# ── Detect platform ──────────────────────────────────────────────────────

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Linux)   OS_NAME="unknown-linux-gnu" ;;
    Darwin)  OS_NAME="apple-darwin" ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "Error: Use npm or manual download on Windows." >&2
      echo "  npm install -g @twira/cli" >&2
      exit 1
      ;;
    *)
      echo "Error: Unsupported OS: $OS" >&2
      exit 1
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)  ARCH_NAME="x86_64" ;;
    aarch64|arm64)  ARCH_NAME="aarch64" ;;
    *)
      echo "Error: Unsupported architecture: $ARCH" >&2
      exit 1
      ;;
  esac

  TARGET="${ARCH_NAME}-${OS_NAME}"
  ARCHIVE_EXT="tar.gz"
}

# ── Fetch latest version ─────────────────────────────────────────────────

fetch_latest_version() {
  if command -v curl >/dev/null 2>&1; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  elif command -v wget >/dev/null 2>&1; then
    VERSION=$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  else
    echo "Error: curl or wget is required." >&2
    exit 1
  fi

  if [ -z "$VERSION" ]; then
    echo "Error: Could not determine latest version." >&2
    exit 1
  fi
}

# ── Download and install ─────────────────────────────────────────────────

download_and_install() {
  ARCHIVE="${BINARY_NAME}-${VERSION}-${TARGET}.${ARCHIVE_EXT}"
  URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"
  CHECKSUM_URL="${URL}.sha256"
  SIG_URL="${URL}.sig"

  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  echo "Downloading Twira ${VERSION} for ${TARGET}..."

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$TMPDIR/$ARCHIVE"
    curl -fsSL "$CHECKSUM_URL" -o "$TMPDIR/$ARCHIVE.sha256"
    # ES256 signature sidecar — present from v2.0.0-alpha.8 onwards.
    # Older releases (alpha.1-7) had no .sig or had legacy Ed25519 sigs
    # that were never actually verified; we don't fail if it's missing.
    curl -fsSL "$SIG_URL" -o "$TMPDIR/$ARCHIVE.sig" 2>/dev/null || true
  else
    wget -q "$URL" -O "$TMPDIR/$ARCHIVE"
    wget -q "$CHECKSUM_URL" -O "$TMPDIR/$ARCHIVE.sha256"
    wget -q "$SIG_URL" -O "$TMPDIR/$ARCHIVE.sig" 2>/dev/null || true
  fi

  # Verify checksum (mandatory — fails install if mismatch)
  echo "Verifying checksum..."
  cd "$TMPDIR"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$ARCHIVE.sha256"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c "$ARCHIVE.sha256"
  else
    echo "Warning: No checksum tool found, skipping verification." >&2
  fi

  # Note on cryptographic signature verification:
  # The .sig file contains an ES256 (P-256 ECDSA) signature produced by
  # the release-sign-prod key in our Azure Key Vault. We do NOT verify it
  # in this shell installer to avoid shipping ECDSA crypto in pure POSIX
  # shell (raw r||s → DER conversion is awkward without Python or openssl
  # plumbing). Instead, the trust chain at first install is:
  #
  #   1. HTTPS to github.com  → authenticates the source
  #   2. SHA-256 of archive   → verifies download integrity
  #
  # After install, the binary's `twira update` flow performs full ES256
  # signature verification against the embedded public key in keys/release.pub.
  # So every subsequent update IS cryptographically verified.
  #
  # If you want to verify the .sig at install time yourself, see:
  #   https://github.com/TwiraHQ/twira/blob/main/SECURITY.md#verifying-signatures
  if [ -s "$ARCHIVE.sig" ]; then
    echo "ES256 signature saved alongside: $TMPDIR/$ARCHIVE.sig"
    echo "(Verify externally with openssl — see SECURITY.md for instructions.)"
  fi

  # Extract
  tar xzf "$ARCHIVE"

  # Install
  mkdir -p "$INSTALL_DIR"
  mv "$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
  chmod +x "$INSTALL_DIR/$BINARY_NAME"

  # ONNX Runtime library — bundled only with the Intel-macOS archive (the one
  # target whose runtime is loaded dynamically rather than static-linked).
  # Co-locate it next to the binary so twira auto-discovers it at startup.
  if [ -f "libonnxruntime.dylib" ]; then
    mv "libonnxruntime.dylib" "$INSTALL_DIR/libonnxruntime.dylib"
  fi

  echo ""
  echo "Twira ${VERSION} installed to ${INSTALL_DIR}/${BINARY_NAME}"
  echo ""

  # Make `twira` resolvable. Preferred: a symlink in a directory every
  # shell already searches — works in THIS terminal immediately, zero
  # config. Fallback: shell-profile edit + activation line.
  NEEDS_ACTIVATE=""
  if link_into_path; then
    echo "twira is ready to use in this terminal."
    echo ""
  else
    configure_path
  fi

  echo "Get started:"
  if [ -n "$NEEDS_ACTIVATE" ]; then
    echo "  source ${NEEDS_ACTIVATE}   # activate in THIS terminal (new terminals won't need it)"
  fi
  echo "  twira init       # set up Twira in your repo (wires your AI agent)"
  echo "  twira index      # build the local code graph"
  echo "  twira dashboard  # open the dashboard in your browser"
}

# ── Zero-touch linking ────────────────────────────────────────────────────
#
# A child process can never modify the launching shell, so PATH edits only
# help FUTURE terminals. The seamless route is a symlink in a directory the
# shell already searches: then `twira` works in the CURRENT terminal, new
# terminals, scripts and cron alike, with nothing to source.
#
#   1. A user-writable candidate already on PATH (Homebrew prefixes,
#      /usr/local/bin, or $TWIRA_LINK_DIR)  → link silently. Zero touch.
#   2. /usr/local/bin via ONE polite sudo prompt (interactive runs only —
#      the same password any .pkg installer asks for).
#   3. Neither → return 1 and the profile-edit fallback takes over.
#
# Always a symlink to ~/.twira/bin/twira, never a copy: updates that
# replace the real binary propagate through the link automatically.

link_into_path() {
  LINK_SRC="${INSTALL_DIR}/${BINARY_NAME}"

  for d in "${TWIRA_LINK_DIR:-}" /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    [ -n "$d" ] || continue
    case ":$PATH:" in
      *":${d}:"*) ;;
      *) continue ;;
    esac
    [ -d "$d" ] && [ -w "$d" ] || continue
    if ln -sfn "$LINK_SRC" "${d}/${BINARY_NAME}" 2>/dev/null; then
      echo "Linked ${d}/${BINARY_NAME} -> ${LINK_SRC}"
      return 0
    fi
  done

  # One sudo attempt, interactive terminals only. /dev/tty works even when
  # the script itself is piped from curl.
  case ":$PATH:" in
    *":/usr/local/bin:"*)
      if [ -e /dev/tty ] && [ -z "${TWIRA_NO_SUDO:-}" ]; then
        echo "Linking twira into /usr/local/bin so it works everywhere"
        echo "(your login password may be requested; Ctrl-C skips this)."
        if sudo -p "Password: " sh -c "mkdir -p /usr/local/bin && ln -sfn '${LINK_SRC}' '/usr/local/bin/${BINARY_NAME}'" </dev/tty 2>/dev/tty; then
          echo "Linked /usr/local/bin/${BINARY_NAME} -> ${LINK_SRC}"
          return 0
        fi
        echo "No problem — falling back to a shell-profile entry."
        echo ""
      fi
      ;;
  esac

  return 1
}

# ── PATH setup ────────────────────────────────────────────────────────────
#
# The installer configures PATH ITSELF (idempotently, in the profile of the
# user's login shell) rather than printing a command and hoping. Field
# report 2026-06-12: a fresh install printed the add-to-PATH line followed
# by "Get started: twira init" — the user ran twira init and got "command
# not found". The happy path must work without homework.
# Opt out with TWIRA_NO_MODIFY_PATH=1 (the manual line is printed instead).

configure_path() {
  # Already reachable → nothing to do.
  case ":$PATH:" in
    *":${INSTALL_DIR}:"*) return 0 ;;
  esac

  EXPORT_LINE="export PATH=\"${INSTALL_DIR}:\$PATH\" # added by the Twira installer"

  if [ -n "${TWIRA_NO_MODIFY_PATH:-}" ]; then
    echo "TWIRA_NO_MODIFY_PATH is set, so your shell profile was not touched."
    echo "Add this line to it yourself:"
    echo ""
    echo "  ${EXPORT_LINE}"
    echo ""
    return 0
  fi

  # Profile of the user's LOGIN shell — not the shell running this script
  # (curl | sh runs under sh even for zsh users).
  case "${SHELL:-}" in
    */zsh) PROFILE="$HOME/.zshrc" ;;
    */bash)
      # macOS terminals start login shells (read .bash_profile); Linux
      # terminals start interactive non-login shells (read .bashrc).
      if [ "$(uname -s)" = "Darwin" ]; then
        PROFILE="$HOME/.bash_profile"
      else
        PROFILE="$HOME/.bashrc"
      fi
      ;;
    *) PROFILE="$HOME/.profile" ;;
  esac

  # Idempotent: one entry, ever, even across re-installs.
  if [ -f "$PROFILE" ] && grep -qs "${INSTALL_DIR}" "$PROFILE"; then
    echo "PATH entry already present in ${PROFILE}."
  else
    printf '\n%s\n' "$EXPORT_LINE" >> "$PROFILE"
    echo "Added Twira to your PATH in ${PROFILE}."
  fi
  # Tell the Get started block to lead with the activation line — a child
  # process cannot modify the parent shell, and field testing (2026-06-12,
  # twice) shows eyes skip any standalone "open a new terminal" paragraph.
  NEEDS_ACTIVATE="$PROFILE"
}

# ── Banner ───────────────────────────────────────────────────────────────

print_banner() {
  echo ""
  echo "  Twira — power tools for your AI agents"
  echo "  https://twira.com"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────

print_banner
detect_platform
fetch_latest_version
download_and_install

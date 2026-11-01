#!/usr/bin/env bash
set -euo pipefail

LYNIS_DIR="/opt/lynis"
LYNIS_REPO="https://github.com/CISOfy/lynis"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="$SCRIPT_DIR/reports/lynis"
OUT_DIR="$REPORTS_DIR/$(hostname)-$(date -u +%F_%H%M)"

UPDATE=true

# ---------- arguments ----------
for arg in "$@"; do
  case "$arg" in
    --no-update)
      UPDATE=false
      ;;
    -h|--help)
      echo "Usage: sudo $0 [--no-update]"
      echo "  --no-update   use the Lynis already in $LYNIS_DIR, do not pull"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: sudo $0 [--no-update]" >&2
      exit 1
      ;;
  esac
done

# ---------- checks ----------
if [ "$EUID" -ne 0 ]; then
  echo "Error: run this script with sudo or as root (audit needs root)." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed." >&2
  exit 1
fi

# ---------- get / update lynis ----------
if [ ! -d "$LYNIS_DIR" ]; then
  echo "Cloning Lynis into $LYNIS_DIR ..."
  git clone --depth 1 "$LYNIS_REPO" "$LYNIS_DIR"
elif [ "$UPDATE" = true ]; then
  echo "Updating Lynis in $LYNIS_DIR ..."
  # If the pull fails (e.g. offline), warn and continue with the old version
  git -C "$LYNIS_DIR" pull --ff-only --quiet \
    || echo "Warning: update failed, using existing Lynis version." >&2
else
  echo "--no-update given, using existing Lynis in $LYNIS_DIR."
fi

# ---------- prepare output folder ----------
mkdir -p "$OUT_DIR"
chmod 700 "$REPORTS_DIR" "$OUT_DIR"
echo "Reports will be saved to: $OUT_DIR"

# Save the Lynis version used, so audits stay comparable over time
LYNIS_VERSION="$(cd "$LYNIS_DIR" && ./lynis show version)"
echo "$LYNIS_VERSION" > "$OUT_DIR/lynis-version.txt"
echo "Lynis version: $LYNIS_VERSION"

# ---------- run audit ----------
(
  cd "$LYNIS_DIR"
  ./lynis audit system \
    --logfile "$OUT_DIR/lynis.log" \
    --report-file "$OUT_DIR/lynis-report.dat"
)

# ---------- short summary ----------
REPORT="$OUT_DIR/lynis-report.dat"
INDEX="$(grep '^hardening_index=' "$REPORT" | cut -d= -f2 || true)"
WARNINGS="$(grep -c '^warning\[\]' "$REPORT" || true)"
SUGGESTIONS="$(grep -c '^suggestion\[\]' "$REPORT" || true)"

echo
echo "===== Summary ====="
echo "Hardening index : ${INDEX:-unknown}"
echo "Warnings        : $WARNINGS"
echo "Suggestions     : $SUGGESTIONS"
echo "Full report     : $OUT_DIR"

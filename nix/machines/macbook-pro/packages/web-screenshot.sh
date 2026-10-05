usage() {
  printf '%s\n' \
    'Usage: web-screenshot URL [OUTPUT.png] [PLAYWRIGHT_OPTIONS...]' \
    '' \
    'Defaults: full page, 1440x900 viewport, unique PNG in /tmp.' \
    'Chromium is downloaded to your user cache on first use.' \
    '' \
    'Examples:' \
    '  web-screenshot https://example.com' \
    '  web-screenshot https://example.com ~/Desktop/example.png' \
    '  web-screenshot https://example.com --wait-for-timeout 2000'
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  exit 0
fi
if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi
url=$1
shift
case "$url" in
  http://*|https://*) ;;
  *) printf 'Expected an http:// or https:// URL\n' >&2; exit 1 ;;
esac

output=''
automatic_output=false
if [[ $# -gt 0 && "$1" != -* ]]; then
  output=$1
  shift
fi

# Keep downloaded browsers outside the immutable Nix store.
export PLAYWRIGHT_BROWSERS_PATH="$HOME/Library/Caches/web-screenshot"
playwright install chromium >&2

if [[ -z "$output" ]]; then
  output=$(mktemp /tmp/web-screenshot-XXXXXXXX.png)
  automatic_output=true
fi
cleanup() {
  if [[ "$automatic_output" == true ]]; then
    rm -f -- "$output"
  fi
}
trap cleanup EXIT
mkdir -p -- "$(dirname -- "$output")"
playwright screenshot --browser chromium --full-page --viewport-size '1440,900' "$@" -- "$url" "$output" >&2
automatic_output=false
printf '%s\n' "$(realpath -- "$output")"

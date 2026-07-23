{
  pkgs,
  piMsg,
}:
pkgs.writeShellApplication {
  name = "gitbutler-pi-msg";
  runtimeInputs = [
    piMsg
    pkgs.gnused
  ];
  text = ''
    set -euo pipefail

    if (( $# < 1 || $# > 2 )); then
      echo "usage: gitbutler-pi-msg FILE_PATH [LINE_NUMBER]" >&2
      exit 2
    fi

    file_path="$1"
    line_number="''${2:-}"

    if [[ -n "$line_number" && ! "$line_number" =~ ^[1-9][0-9]*$ ]]; then
      echo "gitbutler-pi-msg: line number must be a positive integer" >&2
      exit 2
    fi

    location="$file_path"
    if [[ -n "$line_number" ]]; then
      location="$file_path:$line_number"
    fi

    printf 'Ask Pi about %s\npi-msg> ' "$location" >&2
    if ! IFS= read -r prompt; then
      printf '\n' >&2
      exit 0
    fi

    if [[ -z "''${prompt//[[:space:]]/}" ]]; then
      exit 0
    fi

    if [[ -n "$line_number" && -r "$file_path" ]]; then
      line_text="$(sed -n "''${line_number}p" -- "$file_path")"
      printf -v message 'I am reviewing the uncommitted changes around this line and have a question.\n\n%s\n\nCurrent line:\n    %s\n\nUser prompt:\n%s' \
        "$location" "$line_text" "$prompt"
    else
      printf -v message '%s\n\nUser prompt:\n%s' "$location" "$prompt"
    fi

    pi-msg "$message"
  '';
}

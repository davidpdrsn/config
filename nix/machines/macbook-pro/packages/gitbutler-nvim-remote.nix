{pkgs}:
pkgs.writeShellApplication {
  name = "gitbutler-nvim-remote";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
    pkgs.neovim
  ];
  text = ''
    set -euo pipefail

    line_number=""
    if [[ "''${1:-}" == "--line" ]]; then
      if (( $# < 3 )); then
        echo "usage: gitbutler-nvim-remote [--line LINE_NUMBER] FILE_PATH..." >&2
        exit 2
      fi

      line_number="$2"
      shift 2

      if [[ ! "$line_number" =~ ^[1-9][0-9]*$ ]]; then
        echo "gitbutler-nvim-remote: line number must be a positive integer" >&2
        exit 2
      fi
    fi

    if (( $# < 1 )); then
      echo "usage: gitbutler-nvim-remote [--line LINE_NUMBER] FILE_PATH..." >&2
      exit 2
    fi

    filepaths_json="$(jq --compact-output --null-input --args '$ARGS.positional' -- "$@")"
    filepaths_base64="$(printf '%s' "$filepaths_json" | base64 | tr -d '\n')"

    expression="v:lua.require'gitbutler'.open_files_base64('$filepaths_base64'"
    if [[ -n "$line_number" ]]; then
      expression+=", $line_number"
    fi
    expression+=")"

    nvim \
      --server /tmp/nvim-server.pipe \
      --remote-expr "$expression"
  '';
}

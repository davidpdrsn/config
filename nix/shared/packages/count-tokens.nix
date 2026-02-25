{
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "count-tokens";
  version = "0.1.0";

  format = "pyproject";

  src = ./.;

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    tiktoken
  ];

  postPatch = ''
    cat > pyproject.toml <<'EOF'
    [build-system]
    requires = ["setuptools>=68"]
    build-backend = "setuptools.build_meta"

    [project]
    name = "count-tokens"
    version = "0.1.0"
    description = "Count tokens for OpenAI-compatible tokenizers"
    requires-python = ">=3.11"

    [project.scripts]
    count-tokens = "count_tokens:main"
    EOF

    cat > count_tokens.py <<'EOF'
    import argparse
    import sys
    from pathlib import Path

    import tiktoken


    DEFAULT_MODEL = "openai/gpt-5.3-codex"


    def parse_args() -> argparse.Namespace:
        parser = argparse.ArgumentParser(
            prog="count-tokens",
            description="Count tokenizer tokens for a file or stdin.",
        )
        parser.add_argument(
            "input",
            nargs="?",
            default="-",
            help="Path to input file, or '-' for stdin (default: stdin).",
        )
        parser.add_argument(
            "--model",
            default=DEFAULT_MODEL,
            help=f"Model name for tokenizer selection (default: {DEFAULT_MODEL}).",
        )
        return parser.parse_args()


    def read_input(input_path: str) -> str:
        if input_path == "-":
            return sys.stdin.read()
        return Path(input_path).read_text(encoding="utf-8")


    def get_encoding(model: str):
        try:
            return tiktoken.encoding_for_model(model)
        except KeyError:
            return tiktoken.get_encoding("o200k_base")


    def main() -> int:
        args = parse_args()

        text = read_input(args.input)
        encoding = get_encoding(args.model)
        token_count = len(encoding.encode(text))

        print(token_count)
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
    EOF
  '';

  doCheck = false;

  meta = {
    description = "Count tokens in a file or stdin";
    mainProgram = "count-tokens";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}

[
  {
    id = "compare-svg";
    name = "Compare SVG";
    executable = {
      type = "pathExecutable";
      nameOrPath = "compare-svg";
      requiresTerminal = false;
    };
    category = "other";
    openArgs = [
      "--open"
      "{{filepath}}"
    ];
    extensions = ["svg"];
  }
  {
    id = "arc";
    name = "Arc";
    executable = {
      type = "pathExecutable";
      nameOrPath = "/usr/bin/open";
      requiresTerminal = false;
    };
    category = "editor";
    openArgs = [
      "-a"
      "/Applications/Arc.app"
      "{{filepath}}"
    ];
    extensions = ["svg"];
  }
  {
    id = "nvim-remote";
    name = "Neovim Remote";
    executable = {
      type = "pathExecutable";
      nameOrPath = "gitbutler-nvim-remote";
      requiresTerminal = false;
    };
    category = "editor";
    openArgs = [
      "{{filepath}}"
    ];
    openAtLineArgs = [
      "--line"
      "{{line_number}}"
      "{{filepath}}"
    ];
    extensions = ["*"];
  }
  {
    id = "cargo-fmt";
    name = "Cargo Format";
    executable = {
      type = "pathExecutable";
      nameOrPath = "nix";
      requiresTerminal = false;
    };
    category = "other";
    openArgs = [
      "develop"
      "-c"
      "cargo"
      "fmt"
    ];
    extensions = ["rs"];
  }
  {
    id = "git-blame";
    name = "Git Blame";
    executable = {
      type = "pathExecutable";
      nameOrPath = "git";
      requiresTerminal = true;
    };
    category = "other";
    openArgs = [
      "blame"
      "--"
      "{{filepath}}"
    ];
    extensions = ["*"];
  }
  {
    id = "ask-pi";
    name = "Ask Pi";
    executable = {
      type = "pathExecutable";
      nameOrPath = "gitbutler-pi-msg";
      requiresTerminal = true;
    };
    category = "other";
    openArgs = [
      "{{filepath}}"
    ];
    openAtLineArgs = [
      "{{filepath}}"
      "{{line_number}}"
    ];
    extensions = ["*"];
  }
]

[
  {
    id = "nvim-remote";
    name = "Neovim Remote";
    executable = {
      nameOrPath = "nvim";
      requiresTerminal = false;
    };
    category = "editor";
    openArgs = [
      "--server"
      "/tmp/nvim-server.pipe"
      "--remote-expr"
      "v:lua.require'gitbutler'.open_file('{{filepath}}')"
    ];
    openAtLineArgs = [
      "--server"
      "/tmp/nvim-server.pipe"
      "--remote-expr"
      "v:lua.require'gitbutler'.open_file('{{filepath}}', {{line_number}})"
    ];
  }
  {
    id = "arc";
    name = "Arc";
    executable = {
      nameOrPath = "/usr/bin/open";
      requiresTerminal = false;
    };
    category = "editor";
    openArgs = [
      "-a"
      "/Applications/Arc.app"
      "{{filepath}}"
    ];
  }
  {
    id = "compare-svg";
    name = "Compare SVG";
    executable = {
      nameOrPath = "compare-svg";
      requiresTerminal = false;
    };
    category = "other";
    openArgs = [
      "--open"
      "{{filepath}}"
    ];
  }
  {
    id = "cargo-fmt";
    name = "Cargo Format";
    executable = {
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
  }
  {
    id = "git-blame";
    name = "Git Blame";
    executable = {
      nameOrPath = "git";
      requiresTerminal = true;
    };
    category = "other";
    openArgs = [
      "blame"
      "--"
      "{{filepath}}"
    ];
  }
  {
    id = "ask-pi";
    name = "Ask Pi";
    executable = {
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
  }
]

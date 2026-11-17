{config, inputs, lib, pkgs, ...}: let
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
in {
  programs."pi-agent" = {
    enable = true;
    keybindings = {
      "tui.select.up" = ["up" "ctrl+p"];
      "tui.select.down" = ["down" "ctrl+n"];
      "tui.editor.historyPrevious" = "ctrl+p";
      "tui.editor.historyNext" = "ctrl+n";
      # Reserve Ctrl+P/N for history and list navigation.
      "app.model.cycleForward" = [];
      "app.session.togglePath" = [];
      "app.session.toggleNamedFilter" = [];
      "app.models.toggleProvider" = [];
      # Reserve Ctrl+R for the prompt-history extension.
      "app.session.rename" = [];
    };
    settings = {
      lastChangelogVersion = pi.version;
      collapseChangelog = true;
      defaultTools = ["+codemode"];
      defaultProvider = "anthropic";
      defaultModel = "claude-opus-5-5";
      defaultThinkingLevel = "high";
      hideThinkingBlock = true;
      enabledModels = [
        "openai-codex/gpt-6-astra"
        "anthropic/*"
      ];
      images = {
        blockImages = false;
      };
      warnings = {
        anthropicExtraUsage = false;
      };
      transport = "websocket";
      tuiMode = "fullscreen";
      terminal = {
        showTerminalProgress = true;
      };
      # Light theme first, dark theme second. Pi picks one from the
      # terminal's background and switches when the terminal changes.
      theme = "catppuccin-latte-contrast/catppuccin-mocha-contrast";
      packages = [
        "${config.home.homeDirectory}/config/pi"
      ];
      skills = [
        "${config.home.homeDirectory}/config/agents/skills"
      ];
    };
    # Sign in once with `pi mcp login <name>`.
    mcpServers = {
      linear = {
        url = "https://mcp.linear.app/mcp";
        description = "Linear issues, projects, cycles, and comments";
      };
      # Slack's server has no dynamic client registration, so this uses the
      # "Pi MCP" app (A0CJJJYAV7G) in the GitButler workspace. Its redirect
      # URL is http://127.0.0.1:8765/callback, and its user scopes must match
      # `scope`.
      slack = {
        url = "https://mcp.slack.com/mcp";
        description = "Slack messages, channels, DMs, threads, canvases, and search";
        oauth = {
          clientId = "4737498559169.12630644369254";
          clientSecret = "!${lib.getExe pkgs._1password-cli} read 'op://Personal/Slack Pi MCP/credential'";
          callbackPort = 8765;
          scope = lib.concatStringsSep " " [
            "canvases:read"
            "channels:history"
            "channels:read"
            "emoji:read"
            "files:read"
            "groups:history"
            "groups:read"
            "im:history"
            "im:read"
            "lists:read"
            "mpim:history"
            "mpim:read"
            "reactions:read"
            "search:read.files"
            "search:read.im"
            "search:read.mpim"
            "search:read.private"
            "search:read.public"
            "search:read.users"
            "users:read"
            "users:read.email"
          ];
        };
      };
    };
  };
}

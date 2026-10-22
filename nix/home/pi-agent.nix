{config, inputs, pkgs, ...}: let
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
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6-astra";
      enabledModels = [
        "openai-codex/gpt-6-astra"
      ];
      images = {
        blockImages = false;
      };
      transport = "websocket";
      tuiMode = "fullscreen";
      theme = "catppuccin-mocha-contrast";
      packages = [
        "${config.home.homeDirectory}/config/pi"
      ];
    };
  };
}

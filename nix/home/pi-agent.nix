{config, inputs, pkgs, ...}: let
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
in {
  programs."pi-agent" = {
    enable = true;
    settings = {
      lastChangelogVersion = pi.version;
      collapseChangelog = true;
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

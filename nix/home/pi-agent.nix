{config, ...}: {
  programs."pi-agent" = {
    enable = true;
    settings = {
      lastChangelogVersion = "0.54.1";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.3-codex";
      enabledModels = [
        "openai-codex/gpt-5.3-codex"
        "openai-codex/gpt-5.3-codex-spark"
      ];
      images = {
        blockImages = false;
      };
      transport = "websocket";
      theme = "catppuccin-mocha-contrast";
      packages = [
        {
          source = "${config.home.homeDirectory}/config/pi";
          extensions = [
            "extensions/extensions-manager.ts"
          ];
        }
      ];
      extensions = [
        "${config.home.homeDirectory}/.pi/agent/extensions-runtime"
      ];
    };
  };
}

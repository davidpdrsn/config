{config, lib, pkgs, ...}: let
  cfg = config.programs."pi-agent";
  jsonFormat = pkgs.formats.json {};
in {
  options.programs."pi-agent" = {
    enable = lib.mkEnableOption "PI agent settings.json";

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      description = "Settings attrset written to ~/.pi/agent/settings.json as JSON.";
      example = lib.literalExpression ''
        {
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.3-codex";
          enabledModels = [
            "openai-codex/gpt-5.3-codex"
            "openai-codex/gpt-5.3-codex-spark"
          ];
          images.blockImages = false;
          transport = "websocket";
          theme = "catppuccin-mocha";
          packages = [];
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".pi/agent/settings.json".source =
      jsonFormat.generate "pi-agent-settings.json" cfg.settings;
  };
}

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
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".pi/agent/settings.json".source =
      jsonFormat.generate "pi-agent-settings.json" cfg.settings;
  };
}

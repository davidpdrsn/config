{config, lib, pkgs, ...}: let
  cfg = config.programs."pi-agent";
  jsonFormat = pkgs.formats.json {};
in {
  options.programs."pi-agent" = {
    enable = lib.mkEnableOption "PI agent configuration";

    keybindings = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      description = "Keybindings attrset written to ~/.pi/agent/keybindings.json as JSON.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      description = "Settings attrset written to ~/.pi/agent/settings.json as JSON.";
    };

    mcpServers = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      description = ''
        MCP servers written to ~/.pi/agent/mcp.json under `mcpServers`.
        The file is read-only, so change exposure or enabled state here
        rather than through `/mcp`. OAuth tokens live in mcp-auth.json.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".pi/agent/keybindings.json".source =
      jsonFormat.generate "pi-agent-keybindings.json" cfg.keybindings;
    home.file.".pi/agent/settings.json".source =
      jsonFormat.generate "pi-agent-settings.json" cfg.settings;
    home.file.".pi/agent/mcp.json" = lib.mkIf (cfg.mcpServers != {}) {
      source = jsonFormat.generate "pi-agent-mcp.json" {inherit (cfg) mcpServers;};
    };
  };
}

{config, ...}: {
  home.file.".codex/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/config/codex/config.toml";
}

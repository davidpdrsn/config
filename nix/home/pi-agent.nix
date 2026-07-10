{config, inputs, pkgs, ...}: let
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  piPromptSuggester = pkgs.buildNpmPackage {
    pname = "pi-prompt-suggester";
    version = "unstable";
    src = inputs.pi-prompt-suggester;
    npmDepsHash = "sha256-W/fLqGLj6fqAZx3Jcn1DVbxikvvb6yQMzF4q6L4Sl4s=";
    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp package.json "$out/package.json"
      cp -r dist "$out/dist"
      if [ -d config ]; then
        cp -r config "$out/config"
      fi

      runHook postInstall
    '';
  };
in {
  programs."pi-agent" = {
    enable = true;
    settings = {
      lastChangelogVersion = pi.version;
      collapseChangelog = true;
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-sol";
      enabledModels = [
        "openai-codex/gpt-5.6-sol"
      ];
      images = {
        blockImages = false;
      };
      transport = "websocket";
      theme = "catppuccin-mocha-contrast";
      packages = [
        "${config.home.homeDirectory}/config/pi"
        "${piPromptSuggester}"
      ];
    };
  };
}

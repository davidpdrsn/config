{config, inputs, pkgs, ...}: let
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

  piRalphWiggum = pkgs.runCommand "pi-ralph-wiggum" {} ''
    mkdir -p "$out"
    cp -R ${inputs.pi-extensions}/ralph-wiggum/. "$out"/
  '';
in {
  programs."pi-agent" = {
    enable = true;
    settings = {
      lastChangelogVersion = "0.70.2";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.5";
      enabledModels = [
        "openai-codex/gpt-5.5"
      ];
      images = {
        blockImages = false;
      };
      transport = "websocket";
      theme = "catppuccin-mocha-contrast";
      packages = [
        "${config.home.homeDirectory}/config/pi"
        "${piPromptSuggester}"
        # "${piRalphWiggum}"
      ];
    };
  };
}

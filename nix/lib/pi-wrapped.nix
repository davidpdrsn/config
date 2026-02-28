{
  pkgs,
  inputs,
}: let
  llmAgentPackages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
  pkgs.writeShellScriptBin "pi" ''
    export PATH="${pkgs.bun}/bin:${pkgs.nodejs_24}/bin:$PATH"
    exec ${pkgs.lib.getExe llmAgentPackages.pi} "$@"
  ''

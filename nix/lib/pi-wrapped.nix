{
  pkgs,
  inputs,
}: let
  llmAgentPackages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
  pkgs.writeShellScriptBin "pi" ''
    # Keep bun available for local scripts/plugins.
    export PATH="${pkgs.bun}/bin:$PATH"

    # Do not force a specific `node` onto PATH here.
    # Upstream `pi` already launches with its own packaged Node runtime,
    # and preserving ambient PATH keeps dev-shell-selected Node for child tools.
    exec ${pkgs.lib.getExe llmAgentPackages.pi} "$@"
  ''

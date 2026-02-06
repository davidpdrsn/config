{pkgs, lib ? pkgs.lib}:
{
  name,
  env ? {},
  command,
  account ? "",
}:
let
  commandPath =
    if builtins.isPath command
    then toString command
    else if lib.isDerivation command
    then lib.getExe command
    else builtins.throw "op-wrapper: command must be a path or derivation";
  accountValue =
    if builtins.isString account
    then account
    else builtins.throw "op-wrapper: account must be a string";
  envExportLines = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (key: value: "export ${key}=${lib.escapeShellArg value}") env
  );
  jqBin = lib.getExe pkgs.jq;
  opBin = lib.getExe pkgs._1password-cli;
in
  pkgs.writeShellScriptBin name ''
    set -euo pipefail

    ${envExportLines}

    account="${accountValue}"
    if [ -z "$account" ]; then
      account="$(${jqBin} -r '.[0].account_uuid' < <(${opBin} account list --format json))"
    fi

    if [ -z "$account" ]; then
      echo "op-wrapper: no account found" >&2
      exit 1
    fi

    exec ${opBin} run --account "$account" -- "${commandPath}" "$@"
  ''

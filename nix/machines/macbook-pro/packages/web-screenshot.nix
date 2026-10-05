{pkgs, ...}:
pkgs.writeShellApplication {
  name = "web-screenshot";
  runtimeInputs = [pkgs.coreutils];
  text = ''
    playwright() {
      # Use the driver directly: playwright-test pulls in Linux-only browser derivations.
      ${pkgs.nodejs}/bin/node ${pkgs.playwright-driver}/cli.js "$@"
    }
    ${builtins.readFile ./web-screenshot.sh}
  '';
}

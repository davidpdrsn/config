{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tailnet-sites;
  opWrapped = import ./op-wrapper.nix {inherit pkgs;};
  stateDir = "${config.home.homeDirectory}/.local/state/tailnet-sites";

  # Every site plus the directory gets its own Tailscale node. The directory
  # serves a static page; sites forward to a local port.
  nodes =
    lib.mapAttrs (name: site: {target = "http://127.0.0.1:${toString site.port}";}) cfg.sites
    // {${cfg.directoryName} = {target = "${directoryPage}";};};

  siteUrl = name: "https://${name}.${cfg.tailnet}";

  siteCard = name: site: ''
    <a class="site" href="${siteUrl name}">
      <span class="initial">${lib.toUpper (lib.substring 0 1 name)}</span>
      <span class="text">
        <span class="name">${name}</span>
        <span class="host">${name}.${cfg.tailnet}</span>
      </span>
      <span class="port">:${toString site.port}</span>
    </a>
  '';

  directoryPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <title>Sites</title>
        <style>
          :root {
            --bg: #f5f5f4;
            --card: #ffffff;
            --border: #e7e5e4;
            --border-hover: #a8a29e;
            --text: #1c1917;
            --muted: #78716c;
            --initial-bg: #e7e5e4;
            --pill-bg: #f5f5f4;
            --shadow: 0 1px 2px rgb(0 0 0 / 0.04), 0 4px 12px rgb(0 0 0 / 0.04);
          }

          @media (prefers-color-scheme: dark) {
            :root {
              --bg: #0c0a09;
              --card: #1c1917;
              --border: #292524;
              --border-hover: #57534e;
              --text: #f5f5f4;
              --muted: #a8a29e;
              --initial-bg: #292524;
              --pill-bg: #0c0a09;
              --shadow: none;
            }
          }

          * { box-sizing: border-box; }

          body {
            margin: 0;
            background: var(--bg);
            color: var(--text);
            font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
            -webkit-font-smoothing: antialiased;
          }

          main {
            max-width: 44rem;
            margin: 0 auto;
            padding: 4rem 1rem;
          }

          header { margin-bottom: 2rem; }

          h1 {
            margin: 0;
            font-size: 1.75rem;
            font-weight: 650;
            letter-spacing: -0.02em;
          }

          .tailnet {
            margin: 0.25rem 0 0;
            color: var(--muted);
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 0.875rem;
          }

          .sites {
            display: grid;
            gap: 0.75rem;
          }

          .site {
            display: flex;
            align-items: center;
            gap: 1rem;
            padding: 1rem 1.25rem;
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 0.75rem;
            box-shadow: var(--shadow);
            color: inherit;
            text-decoration: none;
            transition: border-color 120ms, transform 120ms;
          }

          .site:hover { border-color: var(--border-hover); }
          .site:active { transform: scale(0.99); }

          .site:focus-visible {
            outline: 2px solid var(--text);
            outline-offset: 2px;
          }

          .initial {
            display: grid;
            place-items: center;
            flex: none;
            width: 2.5rem;
            height: 2.5rem;
            border-radius: 0.5rem;
            background: var(--initial-bg);
            font-weight: 600;
          }

          .text {
            display: flex;
            flex-direction: column;
            gap: 0.125rem;
            min-width: 0;
            flex: 1;
          }

          .name { font-weight: 600; }

          .host {
            color: var(--muted);
            font-size: 0.875rem;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }

          .port {
            flex: none;
            padding: 0.25rem 0.5rem;
            border: 1px solid var(--border);
            border-radius: 999px;
            background: var(--pill-bg);
            color: var(--muted);
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 0.75rem;
          }

          .empty { color: var(--muted); }
        </style>
      </head>
      <body>
        <main>
          <header>
            <h1>Sites</h1>
            <p class="tailnet">${cfg.tailnet}</p>
          </header>
          ${
      if cfg.sites == {}
      then ''<p class="empty">No sites yet. Add one to services.tailnet-sites.sites.</p>''
      else ''
        <nav class="sites">
        ${lib.concatStrings (lib.mapAttrsToList siteCard cfg.sites)}
        </nav>
      ''
    }
        </main>
      </body>
    </html>
  '';

  # Runs a userspace tailscaled for one node. Once the node is logged in, a
  # background job replaces the node's serve config with the one from this
  # module. tailscaled replaces the shell, so launchd stops it directly.
  nodeScript = name: node:
    pkgs.writeShellApplication {
      name = "tailnet-site-${name}";
      runtimeInputs = [pkgs.tailscale pkgs.jq];
      text = ''
        dir="${stateDir}/${name}"
        sock="$dir/tailscaled.sock"
        mkdir -p "$dir"

        # $$ stays this script's pid, which becomes tailscaled's after exec.
        (
          until tailscale --socket="$sock" status --json 2>/dev/null | jq -e '.BackendState == "Running"' >/dev/null; do
            kill -0 "$$" 2>/dev/null || exit 0
            sleep 5
          done

          tailscale --socket="$sock" serve reset
          tailscale --socket="$sock" serve --bg --https=443 "${node.target}"
          echo "serving ${siteUrl name} -> ${node.target}"
        ) &

        exec tailscaled --tun=userspace-networking --statedir="$dir" --socket="$sock" --port=0
      '';
    };

  # Logs in the nodes named in its arguments. op-wrapper puts the auth key from
  # 1Password in TS_AUTHKEY. The key goes through stdin, so it never shows up in
  # the process list.
  joinScript = opWrapped {
    name = "tailnet-site-join";
    env.TS_AUTHKEY = cfg.authKey;
    # Shells started before OP_ACCOUNT was set don't have it in their environment.
    account = config.home.sessionVariables.OP_ACCOUNT or "";
    command = pkgs.writeShellApplication {
      name = "tailnet-site-join";
      runtimeInputs = [pkgs.tailscale];
      text = ''
        for name in "$@"; do
          echo "joining $name.${cfg.tailnet}"
          tailscale --socket="${stateDir}/$name/tailscaled.sock" up \
            --auth-key=file:/dev/stdin --hostname="$name" --accept-dns=false <<<"$TS_AUTHKEY"
        done
      '';
    };
  };

  cli = pkgs.writeShellApplication {
    name = "tailnet-site";
    runtimeInputs = [pkgs.tailscale pkgs.jq];
    text = ''
      nodes="${lib.concatStringsSep " " (lib.attrNames nodes)}"

      usage() {
        echo "usage: tailnet-site join             log in nodes that aren't on the tailnet yet"
        echo "       tailnet-site status           list nodes and their state"
        echo "       tailnet-site ts <name> ...    run a tailscale command against <name>'s node"
        echo
        echo "nodes: $nodes"
      }

      sock() {
        case " $nodes " in
          *" $1 "*) echo "${stateDir}/$1/tailscaled.sock" ;;
          *) echo "unknown node: $1" >&2; usage >&2; exit 1 ;;
        esac
      }

      case "''${1:-}" in
        join)
          # A node's tailscaled may still be starting right after a switch.
          need_login=()
          for name in $nodes; do
            state=
            for _ in $(seq 1 20); do
              if [ -S "$(sock "$name")" ]; then
                state=$(tailscale --socket="$(sock "$name")" status --json 2>/dev/null | jq -r '.BackendState' || true)
                [ -n "$state" ] && [ "$state" != NoState ] && break
              fi
              sleep 0.5
            done
            case "$state" in
              NeedsLogin) need_login+=("$name") ;;
              "") echo "$name: tailscaled isn't running, skipping" >&2 ;;
            esac
          done
          [ ''${#need_login[@]} -eq 0 ] || exec ${joinScript}/bin/tailnet-site-join "''${need_login[@]}"
          ;;
        status)
          for name in $nodes; do
            state=$(tailscale --socket="${stateDir}/$name/tailscaled.sock" status --peers=false 2>&1 | head -n 1 || true)
            printf '%-12s %s\n' "$name" "$state"
          done
          ;;
        ts)
          [ $# -ge 2 ] || { usage >&2; exit 1; }
          name=$2
          shift 2
          tailscale --socket="$(sock "$name")" "$@"
          ;;
        *)
          usage
          ;;
      esac
    '';
  };
in {
  options.services.tailnet-sites = {
    enable = lib.mkEnableOption "one Tailscale node per local site, plus a directory page";

    tailnet = lib.mkOption {
      type = lib.types.str;
      example = "tailbfde08.ts.net";
      description = "The tailnet's DNS name. Used to build the links on the directory page.";
    };

    authKey = lib.mkOption {
      type = lib.types.str;
      default = "op://Personal/Tailscale auth key/credential";
      description = ''
        1Password reference to a reusable Tailscale auth key. `tailnet-site join`
        reads it when a node needs to log in.
      '';
    };

    directoryName = lib.mkOption {
      type = lib.types.str;
      default = "sites";
      description = "Hostname of the node that serves the directory page.";
    };

    sites = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.port = lib.mkOption {
          type = lib.types.port;
          description = "Local port the site listens on. You start the site yourself.";
        };
      });
      default = {};
      description = "Sites to serve at https://<name>.<tailnet>, keyed by hostname.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.sites ? ${cfg.directoryName});
        message = "services.tailnet-sites.sites can't contain the directory name \"${cfg.directoryName}\".";
      }
    ];

    home.packages = [cli];

    launchd.agents = lib.mapAttrs' (name: node:
      lib.nameValuePair "tailnet-site-${name}" {
        enable = true;
        config = {
          Label = "com.davidpdrsn.tailnet-site.${name}";
          ProgramArguments = ["${nodeScript name node}/bin/tailnet-site-${name}"];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/tailnet-site-${name}.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/tailnet-site-${name}.err.log";
        };
      })
    nodes;
  };
}

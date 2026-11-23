{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.tailnet-sites;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  opWrapped = import ./op-wrapper.nix {inherit pkgs;};
  stateDir = "${config.home.homeDirectory}/.local/state/tailnet-sites";
  appsDir = "${config.xdg.dataHome}/tailnet-sites";
  logDir = "${config.home.homeDirectory}/Library/Logs";

  local = target: {target = "http://127.0.0.1:${toString target}";};
  directoryHere = cfg.directory.machine == cfg.machine;

  # Every site plus the directory gets its own Tailscale node, and each node
  # forwards to a local port. This machine runs the nodes for its own sites, and
  # the directory's if the directory lives here. The directory page has its own
  # small web server, because tagged nodes may not serve files directly.
  localSites = lib.filterAttrs (name: site: site.machine == cfg.machine) cfg.sites;
  nodes =
    lib.mapAttrs (name: site: local site.port) localSites
    // lib.optionalAttrs directoryHere {${cfg.directory.name} = local cfg.directory.port;};

  siteUrl = name: "https://${name}.${cfg.tailnet}";
  machinesWithSites = lib.filter (machine: lib.any (site: site.machine == machine) (lib.attrValues cfg.sites)) cfg.machines;
  siteCount = builtins.length (lib.attrNames cfg.sites);
  machineButton = machine: ''
    <button type="button" data-machine="${lib.escapeXML machine}" aria-pressed="false">${lib.escapeXML machine}</button>
  '';
  siteRow = name: site: ''
    <tr data-machine="${lib.escapeXML site.machine}">
      <td><a href="${lib.escapeXML (siteUrl name)}">${lib.escapeXML name}</a></td>
      <td>${lib.escapeXML site.machine}</td><td class="port">${toString site.port}</td>
    </tr>
  '';

  directoryPage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Sites</title>
        <style>
          :root {
            color-scheme: light dark;
            --bg: light-dark(#f5f5f6, #1a1c20);
            --rail: light-dark(#e9eaee, #23262b);
            --panel: light-dark(white, #282b31);
            --ink: light-dark(#272b31, #edeef1);
            --muted: light-dark(#585e68, #b0b5c0);
            --line: light-dark(#dfe1e6, #3c4049);
            --selected: light-dark(#d3dae7, #35445c);
            --link: light-dark(#1759a4, #91bfff);
          }
          * { box-sizing: border-box; }
          body { margin: 0; display: grid; grid-template-columns: clamp(12rem, 24vw, 17rem) minmax(0, 1fr); min-height: 100vh; font: 1rem/1.45 system-ui, sans-serif; color: var(--ink); background: var(--bg); }
          aside { display: flex; flex-direction: column; padding: 2.5rem 1rem 2rem; background: var(--rail); }
          h1, h2 { margin: 0; font-size: 2.2rem; line-height: 1.2; letter-spacing: -.035em; overflow-wrap: anywhere; }
          h1, .tailnet, .label { padding-inline: .85rem; }
          nav { margin-top: 2.5rem; }
          .label { margin: 1.6rem 0 .4rem; font-size: .85rem; font-weight: 600; color: var(--muted); }
          button { display: block; width: 100%; min-height: 44px; padding: .55rem .85rem; border: 0; border-radius: .5rem; background: transparent; color: inherit; font: inherit; text-align: left; overflow-wrap: anywhere; cursor: pointer; }
          button:hover { background: var(--line); }
          button[aria-pressed="true"] { background: var(--selected); font-weight: 600; }
          :focus-visible { outline: 2px solid var(--link); outline-offset: 2px; }
          .tailnet { margin: auto 0 0; padding-top: 2rem; color: var(--muted); font: .8rem/1.4 ui-monospace, monospace; overflow-wrap: anywhere; }
          main { width: 100%; max-width: 74rem; padding: 2.5rem clamp(1.25rem, 4vw, 4rem); }
          #count { margin: .65rem 0 2.5rem; color: var(--muted); }
          table { width: 100%; border-spacing: 0; border-radius: .65rem; padding: .35rem 1.25rem; background: var(--panel); text-align: left; }
          th { color: var(--muted); font-size: .85rem; }
          th, td { padding: .85rem .5rem; overflow-wrap: anywhere; }
          td { border-top: 1px solid var(--line); }
          a { display: inline-flex; align-items: center; min-height: 44px; color: var(--link); font-weight: 600; text-decoration: none; }
          a:hover { text-decoration: underline; }
          td:first-child { padding-block: .3rem; }
          .port { font-family: ui-monospace, monospace; }
          @media (max-width: 42rem) {
            body { display: block; }
            aside { padding: 1.25rem 1rem .85rem; }
            h1, .tailnet { padding: 0; }
            h1 { font-size: 1.65rem; }
            .tailnet { order: -1; margin: 0 0 .3rem; }
            nav { display: flex; flex-wrap: wrap; gap: .25rem; margin-top: .85rem; }
            nav .label { display: none; }
            button { width: auto; max-width: 100%; padding-inline: .7rem; }
            main { padding: 1.5rem 1rem; }
            h2 { font-size: 1.5rem; }
            #count { margin: .3rem 0 1rem; }
            table { table-layout: fixed; padding: .15rem .5rem; font-size: .95rem; }
            th:last-child { width: 4rem; }
            th, td { padding-inline: .3rem; }
          }
        </style>
      </head>
      <body>
        <aside>
          <h1>Sites</h1>
          <nav aria-label="Filter sites">
            <p class="label">Directory</p>
            <button type="button" aria-pressed="true">All sites</button>
            ${lib.optionalString (machinesWithSites != []) ''<p class="label">Machines</p>''}
            ${lib.concatMapStrings machineButton machinesWithSites}
          </nav>
          <p class="tailnet">${lib.escapeXML cfg.tailnet}</p>
        </aside>
        <main>
          <h2 id="view">All sites</h2>
          <p id="count" aria-live="polite">${toString siteCount} ${
      if siteCount == 1
      then "site"
      else "sites"
    }</p>
          ${
      if cfg.sites == {}
      then ''<p>No sites yet. Add one to services.tailnet-sites.sites.</p>''
      else ''
        <table aria-labelledby="view">
          <thead><tr><th>Name</th><th>Machine</th><th>Port</th></tr></thead>
          <tbody>${lib.concatStrings (lib.mapAttrsToList siteRow cfg.sites)}</tbody>
        </table>
      ''
    }
        </main>
        <script>
          const filters = document.querySelectorAll('nav button');
          const rows = document.querySelectorAll('tbody tr');
          for (const button of filters) {
            button.addEventListener('click', () => {
              const machine = button.dataset.machine;
              let visible = 0;
              for (const row of rows) {
                row.hidden = machine !== undefined && row.dataset.machine !== machine;
                if (!row.hidden) visible++;
              }
              for (const filter of filters) filter.setAttribute('aria-pressed', filter === button);
              document.querySelector('#view').textContent = button.textContent;
              document.querySelector('#count').textContent = visible + (visible === 1 ? ' site' : ' sites');
            });
          }
        </script>
      </body>
    </html>
  '';

  # Serves the directory page on every path. Reads the page on each request and
  # tells browsers not to keep it, so a browser never shows an old list.
  directoryScript = pkgs.writers.writePython3Bin "tailnet-sites-directory" {} ''
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    PAGE = "${directoryPage}/index.html"


    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            with open(PAGE, "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            pass


    server = ThreadingHTTPServer(("127.0.0.1", ${toString cfg.directory.port}), Handler)
    server.serve_forever()
  '';

  # Runs a userspace tailscaled for one node. A background job sets the node's
  # serve config from this module once the node is logged in, replacing any
  # config from an earlier version. After that it sets it again whenever the
  # config is gone, which happens when the node logs in again. tailscaled
  # replaces the shell, so launchd or systemd stops it directly.
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
          applied=false
          while kill -0 "$$" 2>/dev/null; do
            if tailscale --socket="$sock" status --json 2>/dev/null | jq -e '.BackendState == "Running"' >/dev/null; then
              if [ "$applied" = false ] || tailscale --socket="$sock" serve status --json | jq -e '. == {}' >/dev/null; then
                # Inside an if, a failure doesn't end the job, so it tries again.
                if tailscale --socket="$sock" serve reset \
                  && tailscale --socket="$sock" serve --bg --https=443 "${node.target}"; then
                  echo "serving ${siteUrl name} -> ${node.target}"
                  applied=true
                fi
              fi
            fi
            sleep 5
          done
        ) &

        exec tailscaled --tun=userspace-networking --statedir="$dir" --socket="$sock" --port=0
      '';
    };

  # Carries out the actions sync decided on, each written as <action>:<name>.
  # Expects the OAuth client in TS_CLIENT_ID and TS_CLIENT_SECRET, which
  # applyScript puts there. Secrets go through stdin, so they never show up in
  # the process list.
  #
  #   join    log the node in, tagged so its key doesn't expire
  #   retag   replace an untagged node with a tagged one
  #   remove  delete the node from the tailnet and its state from disk
  applyCommand = pkgs.writeShellApplication {
    name = "tailnet-site-apply";
    runtimeInputs = [pkgs.tailscale pkgs.jq pkgs.curl pkgs.coreutils];
    text = ''
      api=https://api.tailscale.com/api/v2
      token=

      api_call() {
        if [ -z "$token" ]; then
          token=$(printf 'client_id=%s&client_secret=%s' "$TS_CLIENT_ID" "$TS_CLIENT_SECRET" \
            | curl -fsS --data @- "$api/oauth/token" | jq -r '.access_token')
        fi
        curl -sS -H @<(printf 'Authorization: Bearer %s\n' "$token") "$@"
      }

      # Recorded at join. Falls back to the login profile, and then to the
      # hostname, for nodes that joined before node-id files existed.
      node_id() {
        local name=$1 dir="${stateDir}/$1" id
        id=$(cat "$dir/node-id" 2>/dev/null || true)
        if [ -z "$id" ] && [ -f "$dir/tailscaled.state" ]; then
          id=$(jq -r '._profiles // empty' "$dir/tailscaled.state" | base64 -d 2>/dev/null \
            | jq -r '[.[].NodeID][0] // empty' 2>/dev/null || true)
        fi
        if [ -z "$id" ]; then
          id=$(api_call "$api/tailnet/-/devices" \
            | jq -r --arg name "$name" '[.devices[] | select(.hostname == $name)] | if length == 1 then .[0].nodeId else empty end')
        fi
        echo "$id"
      }

      delete_device() {
        local name=$1 id=$2 status
        if [ -z "$id" ]; then
          echo "couldn't find $name on the tailnet. Remove it in the admin console if it's still there." >&2
          return
        fi
        status=$(api_call -o /dev/null -w '%{http_code}' -X DELETE "$api/device/$id")
        case "$status" in
          200 | 404) echo "deleted $name.${cfg.tailnet}" ;;
          *) echo "couldn't delete $name ($id): HTTP $status. Remove it in the admin console." >&2 ;;
        esac
      }

      join() {
        local name=$1 sock="${stateDir}/$1/tailscaled.sock"
        echo "joining $name.${cfg.tailnet}"
        tailscale --socket="$sock" up --auth-key=file:/dev/stdin \
          --advertise-tags=${cfg.tag} --hostname="$name" --accept-dns=false \
          <<<"$TS_CLIENT_SECRET?ephemeral=false&preauthorized=true"
        tailscale --socket="$sock" status --json | jq -r '.Self.ID' >"${stateDir}/$name/node-id"
      }

      for action in "$@"; do
        name=''${action#*:}
        [ -n "$name" ] || continue
        case "$action" in
          join:*)
            join "$name"
            ;;
          retag:*)
            id=$(node_id "$name")
            tailscale --socket="${stateDir}/$name/tailscaled.sock" logout
            delete_device "$name" "$id"
            join "$name"
            ;;
          remove:*)
            delete_device "$name" "$(node_id "$name")"
            rm -rf "${stateDir}/$name"
            ;;
        esac
      done
    '';
  };

  # Runs applyCommand with the OAuth client in its environment.
  applyScript =
    if cfg.oauthClient ? onePassword
    then
      opWrapped {
        name = "tailnet-site-apply";
        env = {
          TS_CLIENT_ID = cfg.oauthClient.onePassword.id;
          TS_CLIENT_SECRET = cfg.oauthClient.onePassword.secret;
        };
        # Shells started before OP_ACCOUNT was set don't have it in their environment.
        account = config.home.sessionVariables.OP_ACCOUNT or "";
        command = applyCommand;
      }
    else
      pkgs.writeShellApplication {
        name = "tailnet-site-apply";
        text = ''
          file=${lib.escapeShellArg cfg.oauthClient.file}
          if [ ! -r "$file" ]; then
            echo "tailnet-site: $file is missing. Run 'just tailnet-sites-secret <host>' on the Mac." >&2
            exit 1
          fi
          set -a
          # shellcheck source=/dev/null
          . "$file"
          set +a
          exec ${lib.getExe applyCommand} "$@"
        '';
      };

  # Makes the tailnet match the configured nodes: logs in new nodes, replaces
  # untagged ones and removes nodes that are no longer configured. Reads the
  # OAuth client only when there's something to do, so a switch on the Mac that
  # changes no sites doesn't ask for Touch ID.
  syncScript = pkgs.writeShellApplication {
    name = "tailnet-site-sync";
    runtimeInputs = [pkgs.tailscale pkgs.jq];
    text = ''
      stateDir="${stateDir}"
      nodes=(${lib.concatStringsSep " " (lib.attrNames nodes)})
      actions=()

      for name in "''${nodes[@]}"; do
        sock="$stateDir/$name/tailscaled.sock"
        # A node's tailscaled may still be starting right after a switch.
        status=
        for _ in $(seq 1 20); do
          if [ -S "$sock" ]; then
            status=$(tailscale --socket="$sock" status --json 2>/dev/null || true)
            state=$(jq -r '.BackendState // empty' <<<"$status" 2>/dev/null || true)
            [ -n "$state" ] && [ "$state" != NoState ] && break
          fi
          sleep 0.5
        done
        case "''${state:-}" in
          NeedsLogin) actions+=("join:$name") ;;
          Running)
            if ! jq -e '.Self.Tags // [] | index("${cfg.tag}")' <<<"$status" >/dev/null; then
              actions+=("retag:$name")
            fi
            ;;
          "") echo "$name: tailscaled isn't running, skipping" >&2 ;;
        esac
      done

      for dir in "$stateDir"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        case " ''${nodes[*]} " in
          *" $name "*) ;;
          *) actions+=("remove:$name") ;;
        esac
      done

      [ ''${#actions[@]} -eq 0 ] || exec ${applyScript}/bin/tailnet-site-apply "''${actions[@]}"
    '';
  };

  cli = pkgs.writeShellApplication {
    name = "tailnet-site";
    runtimeInputs = [pkgs.tailscale pkgs.jq];
    text = ''
      nodes="${lib.concatStringsSep " " (lib.attrNames nodes)}"

      usage() {
        echo "usage: tailnet-site sync             make the tailnet match the configured sites"
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
        sync)
          exec ${syncScript}/bin/tailnet-site-sync
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

  # Runs a site's package in its own directory, with the site's port in PORT.
  # The app keeps its data in the directory.
  appScript = name: site:
    pkgs.writeShellScript "tailnet-app-${name}" ''
      dir=${lib.escapeShellArg "${appsDir}/${name}"}
      mkdir -p "$dir"
      cd "$dir"
      export PORT=${toString site.port}
      exec ${lib.getExe site.package} ${lib.escapeShellArgs site.args}
    '';

  # The long-running programs on this machine, keyed by service name.
  programs =
    lib.mapAttrs' (name: node:
      lib.nameValuePair "tailnet-site-${name}" "${nodeScript name node}/bin/tailnet-site-${name}")
    nodes
    // lib.mapAttrs' (name: site: lib.nameValuePair "tailnet-app-${name}" "${appScript name site}")
    (lib.filterAttrs (name: site: site.package != null) localSites)
    // lib.optionalAttrs directoryHere {
      tailnet-sites-directory = "${directoryScript}/bin/tailnet-sites-directory";
    };

  inMachines = machine: lib.elem machine cfg.machines;
in {
  options.services.tailnet-sites = {
    machine = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "macbook-pro";
      description = ''
        The machine this configuration is for. It runs the nodes for the sites
        on this machine, and the directory's node if the directory is here.
        Null runs nothing.
      '';
    };

    machines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Every machine that can run sites, in the order the directory lists them.";
    };

    tailnet = lib.mkOption {
      type = lib.types.str;
      example = "tailbfde08.ts.net";
      description = "The tailnet's DNS name. Used to build the links on the directory page.";
    };

    oauthClient = lib.mkOption {
      type = lib.types.attrTag {
        onePassword = lib.mkOption {
          type = lib.types.submodule {
            options.id = lib.mkOption {
              type = lib.types.str;
              description = "1Password reference to the client's ID.";
            };
            options.secret = lib.mkOption {
              type = lib.types.str;
              description = "1Password reference to the client's secret.";
            };
          };
          description = "Read the client from 1Password, which asks for Touch ID.";
        };
        file = lib.mkOption {
          type = lib.types.str;
          description = ''
            Read the client from a file that sets TS_CLIENT_ID and
            TS_CLIENT_SECRET. `just tailnet-sites-secret <host>` writes it.
          '';
        };
      };
      default =
        if isDarwin
        then {
          onePassword = {
            id = "op://Personal/Tailscale OAuth client/username";
            secret = "op://Personal/Tailscale OAuth client/credential";
          };
        }
        else {file = "${config.xdg.configHome}/tailnet-sites/oauth-client";};
      defaultText = lib.literalMD "1Password on macOS, `~/.config/tailnet-sites/oauth-client` elsewhere";
      description = ''
        Where to find the Tailscale OAuth client that logs nodes in and deletes
        removed ones. The client needs write access to devices and to auth
        keys for `tag`.
      '';
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "tag:site";
      description = "Tag every node joins with. Tagged nodes don't expire.";
    };

    directory = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "sites";
        description = "Hostname of the node that serves the directory page.";
      };
      machine = lib.mkOption {
        type = lib.types.str;
        description = "Machine that serves the directory page.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7780;
        description = "Local port of the web server for the directory page.";
      };
    };

    sites = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.machine = lib.mkOption {
          type = lib.types.str;
          description = "Machine the site runs on.";
        };
        options.port = lib.mkOption {
          type = lib.types.port;
          description = "Local port the site listens on.";
        };
        options.package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = ''
            Package to run on the site's machine, with PORT set to the site's
            port and ~/.local/share/tailnet-sites/<name> as its working
            directory, where it keeps its data. Only that machine builds it.
            Without a package, you start the site yourself.
          '';
        };
        options.args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Arguments for the package's main program.";
        };
      });
      default = {};
      description = "Sites to serve at https://<name>.<tailnet>, keyed by hostname.";
    };
  };

  config = lib.mkIf (cfg.machine != null) {
    assertions = [
      {
        assertion = lib.all inMachines ([cfg.machine cfg.directory.machine] ++ lib.mapAttrsToList (name: site: site.machine) cfg.sites);
        message = "services.tailnet-sites: every machine must be in services.tailnet-sites.machines.";
      }
      {
        assertion = !(cfg.sites ? ${cfg.directory.name});
        message = "services.tailnet-sites.sites can't contain the directory name \"${cfg.directory.name}\".";
      }
      {
        assertion = !(lib.any (site: site.machine == cfg.directory.machine && site.port == cfg.directory.port) (lib.attrValues cfg.sites));
        message = "services.tailnet-sites.directory.port ${toString cfg.directory.port} is also the port of a site on ${cfg.directory.machine}.";
      }
    ];

    home.packages = [cli];

    # Runs after the agents or units have started, so new nodes are waiting
    # for a login.
    home.activation.tailnetSites =
      lib.hm.dag.entryAfter [
        (
          if isDarwin
          then "setupLaunchAgents"
          else "reloadSystemd"
        )
      ] ''
        run ${syncScript}/bin/tailnet-site-sync \
          || warnEcho "tailnet-site sync failed. Run 'tailnet-site sync' to retry."
      '';

    launchd.agents = lib.mkIf isDarwin (lib.mapAttrs (service: program: {
        enable = true;
        config = {
          Label = "com.davidpdrsn.${service}";
          ProgramArguments = [program];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${logDir}/${service}.log";
          StandardErrorPath = "${logDir}/${service}.err.log";
        };
      })
      programs);

    # Lingering starts these at boot, without a login.
    systemd.user.services = lib.mkIf (!isDarwin) (lib.mapAttrs (service: program: {
        Unit.Description = service;
        Service = {
          ExecStart = program;
          Restart = "always";
          RestartSec = 5;
        };
        Install.WantedBy = ["default.target"];
      })
      programs);
  };
}

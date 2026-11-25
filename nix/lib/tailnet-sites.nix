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

  # Every site and the directory is a Tailscale Service, svc:<name>, at
  # https://<name>.<tailnet>. The machine a site runs on hosts its service and
  # forwards it to the site's local port. The directory machine defines every
  # service in the tailnet. The directory page has its own small web server,
  # because a service can't serve files directly.
  directoryHere = cfg.directory.machine == cfg.machine;
  localSites = lib.filterAttrs (name: site: site.machine == cfg.machine) cfg.sites;
  localPorts =
    lib.mapAttrs (name: site: site.port) localSites
    // lib.optionalAttrs directoryHere {${cfg.directory.name} = cfg.directory.port;};
  serviceNames = lib.attrNames cfg.sites ++ [cfg.directory.name];

  # Only tagged nodes can host services. A "node" host runs its own tagged
  # userspace tailscaled for that, and only while it has services to host.
  runsNode = cfg.host == "node" && localPorts != {};
  hostsServices = cfg.host == "system" || runsNode;
  nodeDir = "${stateDir}/node";
  nodeName = "${cfg.machine}-sites";
  socketFlag = lib.optionalString (cfg.host == "node") "--socket=${nodeDir}/tailscaled.sock";

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

  # The tagged userspace tailscaled of a "node" host. tailscaled replaces the
  # shell, so launchd or systemd stops it directly.
  nodeScript = pkgs.writeShellApplication {
    name = "tailnet-sites-node";
    runtimeInputs = [pkgs.tailscale];
    text = ''
      mkdir -p "${nodeDir}"
      exec tailscaled --tun=userspace-networking --statedir="${nodeDir}" --socket="${nodeDir}/tailscaled.sock" --port=0
    '';
  };

  # Makes the host serve exactly this machine's services. Services from an
  # earlier config that aren't here anymore are cleared.
  serveScript = pkgs.writeShellApplication {
    name = "tailnet-site-serve";
    runtimeInputs = [pkgs.tailscale pkgs.jq];
    text = ''
      ${lib.concatStrings (lib.mapAttrsToList (name: port: ''
          tailscale ${socketFlag} serve --service=svc:${name} --https=443 http://127.0.0.1:${toString port} >/dev/null
          echo "serving https://${name}.${cfg.tailnet} -> http://127.0.0.1:${toString port}"
        '')
        localPorts)}
      wanted="${toString (map (name: "svc:${name}") (lib.attrNames localPorts))}"
      for service in $(tailscale ${socketFlag} serve status --json | jq -r '.Services // {} | keys[]'); do
        case " $wanted " in
          *" $service "*) ;;
          *)
            tailscale ${socketFlag} serve clear "$service"
            echo "stopped serving $service"
            ;;
        esac
      done
    '';
  };

  # The services the directory machine defined last, so a switch that changes
  # none of them doesn't need the OAuth client.
  definedFile = "${stateDir}/defined-services";
  definedServices = pkgs.writeText "tailnet-sites-services" (lib.concatMapStrings (name: "${cfg.tag} svc:${name}\n") serviceNames);

  # Carries out the actions sync decided on. Expects the OAuth client in
  # TS_CLIENT_ID and TS_CLIENT_SECRET, which applyScript puts there. Secrets go
  # through stdin, so they never show up in the process list.
  #
  #   join    log this machine's userspace node in, tagged so its key doesn't expire
  #   define  make the tailnet's services tagged with the tag match the sites
  applyCommand = pkgs.writeShellApplication {
    name = "tailnet-site-apply";
    runtimeInputs = [pkgs.tailscale pkgs.jq pkgs.curl pkgs.coreutils];
    text = ''
      api=https://api.tailscale.com/api/v2
      token=

      # Prints the response body, and fails on an HTTP error.
      api_call() {
        if [ -z "$token" ]; then
          token=$(printf 'client_id=%s&client_secret=%s' "$TS_CLIENT_ID" "$TS_CLIENT_SECRET" \
            | curl -fsS --data @- "$api/oauth/token" | jq -r '.access_token')
        fi
        local response status
        response=$(curl -sS -w '\n%{http_code}' -H @<(printf 'Authorization: Bearer %s\n' "$token") "$@")
        status=''${response##*$'\n'}
        response=''${response%$'\n'*}
        if [ "$status" -ge 300 ]; then
          echo "tailnet-site: HTTP $status from $*: $response" >&2
          return 1
        fi
        printf '%s\n' "$response"
      }

      join() {
        echo "joining ${nodeName}.${cfg.tailnet}"
        tailscale ${socketFlag} up --auth-key=file:/dev/stdin \
          --advertise-tags=${cfg.nodeTag} --hostname=${nodeName} --accept-dns=false \
          <<<"$TS_CLIENT_SECRET?ephemeral=false&preauthorized=true"
      }

      define() {
        local wanted="${toString (map (name: "svc:${name}") serviceNames)}" services name
        services=$(api_call "$api/tailnet/-/services")
        for name in $wanted; do
          if ! jq -e --arg name "$name" '.vipServices // [] | any(.name == $name)' <<<"$services" >/dev/null; then
            api_call -X PUT "$api/tailnet/-/services/$name" -H 'Content-Type: application/json' \
              --data "{\"name\": \"$name\", \"ports\": [\"tcp:443\"], \"tags\": [\"${cfg.tag}\"]}" >/dev/null
            echo "defined $name"
          fi
        done
        for name in $(jq -r --arg tag "${cfg.tag}" '.vipServices // [] | .[] | select(.tags // [] | index($tag)) | .name' <<<"$services"); do
          case " $wanted " in
            *" $name "*) ;;
            *)
              api_call -X DELETE "$api/tailnet/-/services/$name" >/dev/null
              echo "deleted $name"
              ;;
          esac
        done
        cat ${definedServices} >"${definedFile}"
      }

      for action in "$@"; do
        "$action"
      done
    '';
  };

  # Runs applyCommand with the OAuth client from 1Password in its environment.
  applyScript = opWrapped {
    name = "tailnet-site-apply";
    env = {
      TS_CLIENT_ID = cfg.oauthClient.id;
      TS_CLIENT_SECRET = cfg.oauthClient.secret;
    };
    # Shells started before OP_ACCOUNT was set don't have it in their environment.
    account = config.home.sessionVariables.OP_ACCOUNT or "";
    command = applyCommand;
  };

  # Logs this machine's userspace node in, defines the services if this is the
  # directory machine, and serves this machine's services. Reads the OAuth
  # client only when there's something to do with it, so a switch that changes
  # no services doesn't ask for Touch ID. --force defines the services even
  # when they haven't changed since last time.
  syncScript = pkgs.writeShellApplication {
    name = "tailnet-site-sync";
    runtimeInputs = [pkgs.tailscale pkgs.jq pkgs.diffutils pkgs.coreutils];
    text = ''
      actions=()
      mkdir -p "${stateDir}"

      ${lib.optionalString runsNode ''
        # The node's tailscaled may still be starting right after a switch.
        state=
        for _ in $(seq 1 20); do
          state=$(tailscale ${socketFlag} status --json 2>/dev/null | jq -r '.BackendState // empty' || true)
          [ -n "$state" ] && [ "$state" != NoState ] && break
          sleep 0.5
        done
        case "$state" in
          NeedsLogin) actions+=(join) ;;
          Running) ;;
          *) echo "tailnet-site: ${nodeName}'s tailscaled isn't running" >&2; exit 1 ;;
        esac
      ''}

      ${lib.optionalString directoryHere ''
        if [ "''${1:-}" = --force ] || ! cmp -s ${definedServices} "${definedFile}"; then
          actions+=(define)
        fi
      ''}

      ${lib.optionalString (runsNode || directoryHere) ''
        if [ ''${#actions[@]} -gt 0 ]; then
          ${applyScript}/bin/tailnet-site-apply "''${actions[@]}"
        fi
      ''}

      ${lib.optionalString hostsServices "${serveScript}/bin/tailnet-site-serve"}
    '';
  };

  cli = pkgs.writeShellApplication {
    name = "tailnet-site";
    runtimeInputs = [pkgs.tailscale];
    text = ''
      case "''${1:-}" in
        sync)
          exec ${syncScript}/bin/tailnet-site-sync --force
          ;;
        ts)
          shift
          exec tailscale ${socketFlag} "$@"
          ;;
        *)
          echo "usage: tailnet-site sync          make the tailnet and this machine serve the configured sites"
          echo "       tailnet-site ts ...        run a tailscale command against the node that hosts this machine's sites"
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
    lib.optionalAttrs runsNode {tailnet-sites-node = lib.getExe nodeScript;}
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
        The machine this configuration is for. It hosts the services for the
        sites on this machine, and the directory's if the directory is here.
        Null runs nothing.
      '';
    };

    machines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Every machine that can run sites, in the order the directory lists them.";
    };

    host = lib.mkOption {
      type = lib.types.enum ["system" "node"];
      default =
        if isDarwin
        then "node"
        else "system";
      defaultText = lib.literalMD ''"node" on macOS, "system" elsewhere'';
      description = ''
        Which tailscaled hosts this machine's services. "system" is the
        machine's own, which must be tagged and have this user as its
        operator. "node" is a userspace tailscaled that this module runs, with
        its own node tagged `nodeTag`, for a machine whose own node belongs to
        a user.
      '';
    };

    tailnet = lib.mkOption {
      type = lib.types.str;
      example = "tailbfde08.ts.net";
      description = "The tailnet's DNS name. Used to build the links on the directory page.";
    };

    oauthClient = {
      id = lib.mkOption {
        type = lib.types.str;
        default = "op://Personal/Tailscale OAuth client/username";
        description = "1Password reference to the client's ID.";
      };
      secret = lib.mkOption {
        type = lib.types.str;
        default = "op://Personal/Tailscale OAuth client/credential";
        description = "1Password reference to the client's secret.";
      };
    };

    tag = lib.mkOption {
      type = lib.types.str;
      default = "tag:site";
      description = ''
        Tag of every service. The directory machine deletes services with this
        tag that aren't sites, so don't give it to other services. The OAuth
        client needs the `services` scope and this tag.
      '';
    };

    nodeTag = lib.mkOption {
      type = lib.types.str;
      default = "tag:server";
      description = ''
        Tag a "node" host's node joins with. Tagged nodes don't expire. The
        tailnet policy must auto-approve hosts with this tag for services with
        `tag`, and the OAuth client needs the `auth_keys` scope for it.
      '';
    };

    directory = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "sites";
        description = "Name of the service that serves the directory page.";
      };
      machine = lib.mkOption {
        type = lib.types.str;
        description = "Machine that serves the directory page and defines every service in the tailnet.";
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
      description = "Sites to serve at https://<name>.<tailnet>, keyed by service name.";
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

    # Runs after the agents or units have started, so a new node is waiting
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

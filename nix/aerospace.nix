{...}: let
  aerospaceConfig = {
    "start-at-login" = true;
    "on-focus-changed" = ["move-mouse window-lazy-center"];
    accordion-padding = 20;
    gaps = {
      inner = {
        horizontal = [{monitor."DELL U3223QE" = 10;} 5];
        vertical = [{monitor."DELL U3223QE" = 10;} 5];
      };
      outer = {
        top = [{monitor."DELL U3223QE" = 10;} 0];
        bottom = [{monitor."DELL U3223QE" = 10;} 0];
        left = [{monitor."DELL U3223QE" = 10;} 0];
        right = [{monitor."DELL U3223QE" = 10;} 0];
      };
    };
    on-window-detected = [
      {
        "if" = {
          app-id = "com.apple.MobileSMS";
        };
        run = ["layout floating"];
      }
      {
        "if" = {
          app-id = "com.apple.finder";
        };
        run = ["layout floating"];
      }
    ];
    mode = {
      main = {
        binding = {
          # Layouts
          "alt-u" = "layout tiles horizontal vertical";
          "alt-i" = "layout accordion horizontal vertical";

          # Focus
          "alt-k" = "focus up";
          "alt-h" = "focus left";
          "alt-j" = "focus down";
          "alt-l" = "focus right";

          "alt-shift-f" = "fullscreen";
          "alt-space" = "focus-back-and-forth";

          # Move
          "alt-shift-h" = "move left";
          "alt-shift-j" = "move down";
          "alt-shift-k" = "move up";
          "alt-shift-l" = "move right";

          # Resize
          "alt-minus" = "resize smart -50";
          "alt-equal" = "resize smart +50";

          # Workspaces
          "alt-1" = "workspace 1";
          "alt-2" = "workspace 2";
          "alt-3" = "workspace 3";
          "alt-4" = "workspace 4";
          "alt-5" = "workspace 5";
          "alt-6" = "workspace 6";
          "alt-7" = "workspace 7";
          "alt-8" = "workspace 8";
          "alt-9" = "workspace 9";

          "alt-n" = "workspace prev";
          "alt-p" = "workspace next";

          "alt-tab" = "workspace-back-and-forth";

          # Move node to workspace
          "alt-shift-1" = "move-node-to-workspace 1";
          "alt-shift-2" = "move-node-to-workspace 2";
          "alt-shift-3" = "move-node-to-workspace 3";
          "alt-shift-4" = "move-node-to-workspace 4";
          "alt-shift-5" = "move-node-to-workspace 5";
          "alt-shift-6" = "move-node-to-workspace 6";
          "alt-shift-7" = "move-node-to-workspace 7";
          "alt-shift-8" = "move-node-to-workspace 8";
          "alt-shift-9" = "move-node-to-workspace 9";

          # Move workspace to monitor
          "alt-shift-tab" = "move-workspace-to-monitor --wrap-around next";

          # Mode
          "alt-shift-semicolon" = "mode service";
        };
      };
      service = {
        binding = {
          esc = ["reload-config" "mode main"];
          r = ["flatten-workspace-tree" "mode main"];
          f = ["layout floating tiling" "mode main"];
          backspace = ["close-all-windows-but-current" "mode main"];

          "alt-shift-h" = ["join-with left" "mode main"];
          "alt-shift-j" = ["join-with down" "mode main"];
          "alt-shift-k" = ["join-with up" "mode main"];
          "alt-shift-l" = ["join-with right" "mode main"];
        };
      };
    };
  };
in {
  programs.aerospace = {
    enable = true;
    userSettings = aerospaceConfig;
  };
}

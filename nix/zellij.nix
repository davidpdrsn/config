{pkgs, ...}: {
  programs.zellij = {
    enable = true;
  };

  xdg.configFile."zellij/config.kdl".text = ''
    on_force_close "quit"
    simplified_ui true
    pane_frames false
    default_mode "locked"
    mouse_mode true
    show_startup_tips false
    default_shell "nu"
    styled_underlines true
    theme "catppuccin-macchiato"

    ui {
        pane_frames {
            hide_session_name true
        }
    }

    keybinds clear-defaults=true {
        normal {
            bind "h" { MoveFocus "Left"; }
            bind "l" { MoveFocus "Right"; }
            bind "j" { MoveFocus "Down"; }
            bind "k" { MoveFocus "Up"; }
            bind "[" { GoToPreviousTab; }
            bind "]" { GoToNextTab; }
            bind "i" { ToggleTab; SwitchToMode "Locked"; }
            bind "Space" "Enter" "Esc" { SwitchToMode "Locked"; }
        }
        locked {
            bind "Ctrl Space" { SwitchToMode "Normal"; }
        }
        shared_except "locked" {
            bind "Ctrl Space" { SwitchToMode "Locked"; }
            bind "Ctrl q" { Quit; }
        }
        shared_except "normal" "renametab" "locked" {
            bind "Space" "Enter" "Esc" { SwitchToMode "Locked"; }
        }
        shared_except "pane" "renametab" "entersearch" "locked" {
            bind "p" { SwitchToMode "Pane"; }
        }
        shared_except "move" "renametab" "entersearch" "locked" {
            bind "h" { SwitchToMode "Move"; }
        }
        shared_except "resize" "renametab" "entersearch" "locked" {
            bind "r" { SwitchToMode "Resize"; }
        }
        shared_except "scroll" "renametab" "entersearch" "locked" {
            bind "s" { SwitchToMode "Scroll"; }
        }
        shared_except "session" "renametab" "entersearch" "locked" {
            bind "o" { SwitchToMode "Session"; }
        }
        shared_except "tab" "renametab" "entersearch" "locked" {
            bind "t" { SwitchToMode "Tab"; }
        }
        pane {
            bind "p" { SwitchToMode "Normal"; }
            bind "p" { SwitchFocus; SwitchToMode "Locked"; }
            bind "n" { NewPane; SwitchToMode "Locked"; }
            bind "d" { NewPane "Down"; SwitchToMode "Locked"; }
            bind "r" { NewPane "Right"; SwitchToMode "Locked"; }
            bind "x" { CloseFocus; SwitchToMode "Locked"; }
            bind "f" { ToggleFocusFullscreen; SwitchToMode "Locked"; }
            bind "z" { TogglePaneFrames; SwitchToMode "Locked"; }
            bind "w" { ToggleFloatingPanes; SwitchToMode "Locked"; }
            bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "Locked"; }
            bind "i" { TogglePanePinned; SwitchToMode "Locked"; }
        }
        tab {
            bind "t" { SwitchToMode "Normal"; }
            bind "r" { SwitchToMode "RenameTab"; TabNameInput 0; }
            bind "h" "k" { GoToPreviousTab; }
            bind "l" "j" { GoToNextTab; }
            bind "n" { NewTab; SwitchToMode "Locked"; }
            bind "x" { CloseTab; SwitchToMode "Locked"; }
            bind "s" { ToggleActiveSyncTab; SwitchToMode "Locked"; }
            bind "b" { BreakPane; SwitchToMode "Locked"; }
            bind "]" { BreakPaneRight; SwitchToMode "Locked"; }
            bind "[" { BreakPaneLeft; SwitchToMode "Locked"; }
            bind "1" { GoToTab 1; SwitchToMode "Locked"; }
            bind "2" { GoToTab 2; SwitchToMode "Locked"; }
            bind "3" { GoToTab 3; SwitchToMode "Locked"; }
            bind "4" { GoToTab 4; SwitchToMode "Locked"; }
            bind "5" { GoToTab 5; SwitchToMode "Locked"; }
            bind "6" { GoToTab 6; SwitchToMode "Locked"; }
            bind "7" { GoToTab 7; SwitchToMode "Locked"; }
            bind "8" { GoToTab 8; SwitchToMode "Locked"; }
            bind "9" { GoToTab 9; SwitchToMode "Locked"; }
            bind "Tab" { ToggleTab; SwitchToMode "Locked"; }
            bind "Left" { MoveTab "Left"; }
            bind "Right" { MoveTab "Right"; }
        }
        resize {
            bind "n" { SwitchToMode "Normal"; }
            bind "h" "Left" { Resize "Increase Left"; }
            bind "j" "Down" { Resize "Increase Down"; }
            bind "k" "Up" { Resize "Increase Up"; }
            bind "l" "Right" { Resize "Increase Right"; }
            bind "H" { Resize "Decrease Left"; }
            bind "J" { Resize "Decrease Down"; }
            bind "K" { Resize "Decrease Up"; }
            bind "L" { Resize "Decrease Right"; }
            bind "=" "+" { Resize "Increase"; }
            bind "-" { Resize "Decrease"; }
        }
        move {
            bind "h" { SwitchToMode "Normal"; }
            bind "n" "Tab" { MovePane; }
            bind "p" { MovePaneBackwards; }
            bind "h" "Left" { MovePane "Left"; }
            bind "j" "Down" { MovePane "Down"; }
            bind "k" "Up" { MovePane "Up"; }
            bind "l" "Right" { MovePane "Right"; }
        }
        scroll {
            bind "s" { SwitchToMode "Normal"; }
            bind "e" { EditScrollback; SwitchToMode "Locked"; }
            bind "s" { SwitchToMode "EnterSearch"; SearchInput 0; }
            bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
            bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
            bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
            bind "d" { HalfPageScrollDown; }
            bind "u" { HalfPageScrollUp; }
        }
        search {
            bind "Ctrl s" { SwitchToMode "Normal"; }
            bind "Ctrl c" { ScrollToBottom; SwitchToMode "Locked"; }
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
            bind "Ctrl f" "PageDown" "Right" "l" { PageScrollDown; }
            bind "Ctrl b" "PageUp" "Left" "h" { PageScrollUp; }
            bind "d" { HalfPageScrollDown; }
            bind "u" { HalfPageScrollUp; }
            bind "n" { Search "down"; }
            bind "p" { Search "up"; }
            bind "c" { SearchToggleOption "CaseSensitivity"; }
            bind "w" { SearchToggleOption "Wrap"; }
            bind "o" { SearchToggleOption "WholeWord"; }
        }
        entersearch {
            bind "Ctrl c" "Esc" { SwitchToMode "Scroll"; }
            bind "Enter" { SwitchToMode "Search"; }
        }
        renametab {
            bind "Ctrl c" { SwitchToMode "Normal"; }
            bind "Enter" { SwitchToMode "Locked"; }
            bind "Esc" { UndoRenameTab; SwitchToMode "Tab"; }
        }
        session {
            bind "o" { SwitchToMode "Normal"; }
            bind "Ctrl s" { SwitchToMode "Scroll"; }
            bind "d" { Detach; }
            bind "w" {
                LaunchOrFocusPlugin "session-manager" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "c" {
                LaunchOrFocusPlugin "configuration" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "p" {
                LaunchOrFocusPlugin "plugin-manager" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
            bind "a" {
                LaunchOrFocusPlugin "zellij:about" {
                    floating true
                    move_to_focused_tab true
                };
                SwitchToMode "Locked"
            }
        }
    }

    plugins {
      zjstatus location="file:${pkgs.zjstatus}/bin/zjstatus.wasm" {
        hide_frame_for_single_pane "false"

        // catppuccin
        color_bg     "#0e0801"
        color_fg     "#9399B2"
        color_fg_dim "#6C7086"
        color_blue   "#89b4fa"
        color_orange "#ffc387"

        format_left  "#[fg=$fg,bg=$bg,bold] {session}#[bg=$bg] {tabs}"
        format_right "{notifications}{command_aws}{command_kubectx}{command_kubens}{datetime}"
        format_space "#[bg=$bg]"

        notification_format_unread           "#[fg=$blue,bg=$bg,blink]  #[fg=$blue,bg=$bg] {message} "
        notification_format_no_notifications ""
        notification_show_interval           "10"

        mode_normal          "#[bg=$blue] "
        mode_tmux            "#[bg=$orange] "
        mode_default_to_mode "tmux"

        tab_normal               "#[fg=$fg_dim,bg=$bg] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
        tab_active               "#[fg=$fg,bg=$bg,bold] {index} {name} {fullscreen_indicator}{sync_indicator}{floating_indicator}"
        tab_sync_indicator       " "
        tab_fullscreen_indicator "󰊓 "
        tab_floating_indicator   "󰹙 "

        command_kubectx_command  "${pkgs.kubectx}/bin/kubectx -c"
        command_kubectx_format   "#[fg=$fg_dim,bg=$bg,italic]{stdout}#[fg=#424554,bg=$bg]::"
        command_kubectx_interval "2"

        command_kubens_command  "${pkgs.kubectx}/bin/kubens -c"
        command_kubens_format   "#[fg=$fg_dim,bg=$bg]{stdout} "
        command_kubens_interval "2"

        command_aws_command    "${pkgs.fish}/bin/fish -c 'if test $AWS_PROFILE; echo -n \"#[fg=#928374,bg=#1d2021,italic]aws#[fg=#424554,bg=#1d2021]::#[fg=#928374,bg=#1d2021]$AWS_PROFILE  \"; end'"
        command_aws_format     "{stdout}"
        command_aws_interval   "2"
        command_aws_rendermode "dynamic"

        datetime          "#[fg=$fg,bg=$bg] {format} "
        datetime_format   "%A, %d %b %Y %H:%M"
        datetime_timezone "Europe/Berlin"
      }

    // load_plugins {
    // }
  '';

  # home.file = {
  #   ".config/zellij/config.kdl".source = ../zellij/config.kdl;
  # };
}

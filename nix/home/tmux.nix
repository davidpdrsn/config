{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    shell = "${pkgs.fish}/bin/fish";

    # Remap prefix to Control + space
    prefix = "C-Space";

    # Modern settings
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "macchiato"
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_text " #W"
          set -g @catppuccin_window_current_text " #W"
          set -g @catppuccin_window_flags "icon"
          set -g @catppuccin_status_left_separator "█"
          set -g @catppuccin_status_right_separator "█"
          set -g @catppuccin_date_time_text " %H:%M"
        '';
      }
      tmux-fzf
    ];

    extraConfig = ''
      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Hyperlink/URL passthrough
      # Use Shift+Cmd+click to open URLs (Shift bypasses tmux mouse capture)
      set -ga terminal-features "*:hyperlinks"
      set -g allow-passthrough on

      # Extended keys support (for Shift+Enter, etc.)
      set -g extended-keys on
      set -as terminal-features ',*:extkeys'

      # Status bar (2 lines, content on second row)
      set -g status-position top
      set -g status 2
      set -g status-format[0] "#[fill=default]"
      set -g status-format[1] "#[align=left,list=on]#{W:#[range=window|#{window_index}]#{E:window-status-format}#[norange],#[range=window|#{window_index}]#{E:window-status-current-format}#[norange]}#[align=right,nolist]#{E:status-right}"
      set -g status-right-length 150
      set -g status-left ""
      set -g status-right "#[fg=#a6da95,bg=default] 󰁹 #(pmset -g batt | grep -o '[0-9]*%%' | head -1) #{E:@catppuccin_status_date_time}#{E:@catppuccin_status_session}"

      # Space between window tabs (append to formats set by Catppuccin)
      set -ag window-status-format "#[bg=default]  "
      set -ag window-status-current-format "#[bg=default]  "

      # Focus events for vim
      set -g focus-events on

      # Copy mode with vim bindings
      set -g mode-keys vi
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi V send -X select-line
      bind -T copy-mode-vi y send -X copy-selection-and-cancel
      bind -T copy-mode-vi Escape send -X cancel

      # Intuitive splits (open in current path)
      bind \\ split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Window navigation
      bind f last-window
      bind -n M-h previous-window
      bind -n M-l next-window

      # Window reordering (no wrap)
      bind Left swap-window -t -1 \; select-window -t -1
      bind Right swap-window -t +1 \; select-window -t +1

      # Swap panes with Shift + hjkl (similar to winshift.nvim)
      bind H swap-pane -s '{left-of}'
      bind J swap-pane -s '{down-of}'
      bind K swap-pane -s '{up-of}'
      bind L swap-pane -s '{right-of}'

      # Jump to previous pane
      bind k last-pane

      # Popup for jjui
      bind j display-popup -E -w 80% -h 80% -d "#{pane_current_path}" jjui

      # Popup for vim
      bind v display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "nvim"

      # Popup for shell
      bind p display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "${pkgs.fish}/bin/fish"

      # Popup for window reordering
      bind W display-popup -E -w 80% -h 80% -d "#{pane_current_path}" "tmux-window-reorder"

      # Easy config reload
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Update PATH from client on attach
      set -g update-environment "PATH"

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Smart pane switching with awareness of Vim splits
      # See: https://github.com/mrjones2014/smart-splits.nvim
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|nvim?x?|fzf)(diff)?$'"
      bind-key -n C-h if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
      bind-key -n C-j if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
      bind-key -n C-k if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
      bind-key -n C-l if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
    '';
  };
}

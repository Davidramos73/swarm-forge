#!/usr/bin/env zsh

terminal_backend_label() {
  echo "GNOME Terminal"
}

terminal_backend_can_open_sessions() {
  has_command gnome-terminal
}

terminal_backend_tracks_windows() {
  return 1
}

terminal_window_exists() {
  return 1
}

terminal_open_session() {
  local session="$1"
  local title="$2"

  gnome-terminal \
    --title="$title" \
    --working-directory="$WORKING_DIR" \
    -- \
    tmux -S "$TMUX_SOCKET" attach-session -t "$session" &
}

terminal_close_window() {
  return 0
}

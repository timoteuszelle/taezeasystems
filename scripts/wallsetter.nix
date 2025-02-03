{ pkgs, ... }:

pkgs.writeShellScriptBin "wallsetter" ''
  set -e
  set -o pipefail
  TIMEOUT=720

  # Log start and setup trap for termination signals
  echo "Wallsetter script started with PID: $$" >> ~/wallsetter_start.log
  trap 'echo "Received SIGTERM at $(date)" >> ~/wallsetter_trap.log' SIGTERM

  # Kill other instances of wallsetter
  for pid in $(pidof -o %PPID -x wallsetter); do
    if [ "$pid" != "$$" ]; then
      kill -s SIGTERM $pid
      #wait for cleanup else just SIGKILL
      sleep 0.5
      if kill -0 $pid 2>/dev/null; then
        echo "Process $pid did not terminate, sending SIGKILL" >> ~/wallsetter_trap.log
        kill -s SIGKILL $pid
      fi
    fi
  done

  # Check if wallpaper directory exists and contains images
  if ! [ -d ~/Pictures/Wallpapers ]; then 
    notify-send -t 5000 "~/Pictures/Wallpapers does not exist" 
    exit 1
  fi
  if [ $(ls -1 ~/Pictures/Wallpapers | wc -l) -lt 1 ]; then 
    notify-send -t 9000 "The wallpaper folder is expected to have more than 1 image. Exiting Wallsetter." 
    exit 1
  fi

  # Main loop for changing wallpapers
  while true; do
    while [ "$WALLPAPER" == "$PREVIOUS" ] || [ -z "$WALLPAPER" ]; do
      WALLPAPER=$(find -L ~/Pictures/Wallpapers -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) | shuf -n 1)
      echo "Attempted to find wallpaper: $WALLPAPER" >> ~/wallsetter_debug.log
    done

    PREVIOUS=$WALLPAPER
    echo "Setting wallpaper: $WALLPAPER" >> ~/wallsetter_debug.log

    if ! ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type random --transition-step 1 --transition-fps 60; then
      notify-send -t 5000 "Failed to set wallpaper: $WALLPAPER"
    fi

    sleep $TIMEOUT
  done
''

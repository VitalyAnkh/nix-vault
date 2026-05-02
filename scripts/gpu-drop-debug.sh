#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/gpu-drop-debug.sh [options]

Continuously records read-only evidence for the next NVIDIA GPU bus-loss /
black-screen incident. Logs are written to persistent user storage by default.

Options:
  -o, --output DIR        Output root directory.
                          Default: /persistent/home/<real-user>/.local/share/gpu-drop-debug
                          if available, otherwise <real-user> home/.local/share/gpu-drop-debug.
  --gpu-interval SECONDS  NVIDIA telemetry interval. Default: 1.
  --slow-interval SECONDS Sensors/process/PCIe interval. Default: 10.
  --no-sudo              Do not attempt passwordless sudo for metadata commands.
  --once                 Capture metadata and one snapshot, then exit.
  -h, --help             Show this help.

Recommended launch:
  sudo -v
  nohup scripts/gpu-drop-debug.sh >/tmp/gpu-drop-debug.nohup 2>&1 &

After a crash/reboot, send the latest run directory under the output root.
USAGE
}

have() {
  command -v "$1" >/dev/null 2>&1
}

ts() {
  date -Is
}

real_user() {
  if [[ -n "${SUDO_USER:-}" ]]; then
    printf '%s\n' "$SUDO_USER"
  else
    id -un
  fi
}

real_home() {
  local user="$1"
  getent passwd "$user" 2>/dev/null | awk -F: '{print $6; exit}'
}

sanitize() {
  printf '%s' "$1" | tr -cs 'A-Za-z0-9_.-' '_' | cut -c1-80
}

SCRIPT_USER="$(real_user)"
SCRIPT_HOME="$(real_home "$SCRIPT_USER")"
if [[ -z "$SCRIPT_HOME" ]]; then
  SCRIPT_HOME="${HOME:-/tmp}"
fi

if [[ -d "/persistent/home/$SCRIPT_USER" ]]; then
  OUTPUT_ROOT="/persistent/home/$SCRIPT_USER/.local/share/gpu-drop-debug"
else
  OUTPUT_ROOT="$SCRIPT_HOME/.local/share/gpu-drop-debug"
fi

GPU_INTERVAL=1
SLOW_INTERVAL=10
USE_SUDO=1
MODE="watch"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    --gpu-interval)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      GPU_INTERVAL="$2"
      shift 2
      ;;
    --slow-interval)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      SLOW_INTERVAL="$2"
      shift 2
      ;;
    --no-sudo)
      USE_SUDO=0
      shift
      ;;
    --once)
      MODE="once"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ "$GPU_INTERVAL" =~ ^[0-9]+$ ]] || { echo "--gpu-interval must be an integer" >&2; exit 2; }
[[ "$SLOW_INTERVAL" =~ ^[0-9]+$ ]] || { echo "--slow-interval must be an integer" >&2; exit 2; }
(( GPU_INTERVAL >= 1 )) || { echo "--gpu-interval must be >= 1" >&2; exit 2; }
(( SLOW_INTERVAL >= 2 )) || { echo "--slow-interval must be >= 2" >&2; exit 2; }

BOOT_ID="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || printf 'unknown')"
RUN_ID="$(date +%Y%m%d-%H%M%S)-boot-${BOOT_ID:0:8}"
RUN_DIR="$OUTPUT_ROOT/$RUN_ID"
SNAPSHOT_DIR="$RUN_DIR/snapshots"
ERROR_LOG="$RUN_DIR/errors.log"

JOURNAL_CMD=(journalctl)
if ! journalctl -k -b 0 -n 1 >/dev/null 2>&1; then
  if (( USE_SUDO )) && have sudo && sudo -n true 2>/dev/null; then
    JOURNAL_CMD=(sudo -n journalctl)
  fi
fi

mkdir -p "$SNAPSHOT_DIR"
touch "$ERROR_LOG"

flush_file() {
  local file="$1"
  sync -f "$file" 2>/dev/null || true
}

priv() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  elif (( USE_SUDO )) && have sudo && sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    "$@"
  fi
}

append_cmd() {
  local file="$1"
  local title="$2"
  shift 2
  {
    printf '\n## %s (%s)\n' "$title" "$(ts)"
    "$@"
  } >>"$file" 2>&1 || true
  flush_file "$file"
}

append_shell() {
  local file="$1"
  local title="$2"
  local script="$3"
  {
    printf '\n## %s (%s)\n' "$title" "$(ts)"
    bash -lc "$script"
  } >>"$file" 2>&1 || true
  flush_file "$file"
}

snapshot_due() {
  local now last
  now="$(date +%s)"
  last=0
  if [[ -r "$RUN_DIR/.last-snapshot-epoch" ]]; then
    read -r last < "$RUN_DIR/.last-snapshot-epoch" || last=0
  fi
  if (( now - last < 30 )); then
    return 1
  fi
  printf '%s\n' "$now" > "$RUN_DIR/.last-snapshot-epoch"
  return 0
}

capture_snapshot() {
  local reason="${1:-manual}"
  local trigger="${2:-}"
  local safe_reason snap_dir summary

  if ! snapshot_due; then
    return 0
  fi
  if ! mkdir "$RUN_DIR/.snapshot-lock" 2>/dev/null; then
    return 0
  fi
  trap 'rmdir "$RUN_DIR/.snapshot-lock" 2>/dev/null || true' RETURN

  safe_reason="$(sanitize "$reason")"
  snap_dir="$SNAPSHOT_DIR/$(date +%Y%m%d-%H%M%S)-$safe_reason"
  summary="$snap_dir/summary.txt"
  mkdir -p "$snap_dir"

  {
    printf 'snapshot_time=%s\n' "$(ts)"
    printf 'reason=%s\n' "$reason"
    printf 'trigger=%s\n' "$trigger"
    printf 'boot_id=%s\n' "$BOOT_ID"
    printf 'run_dir=%s\n' "$RUN_DIR"
  } >"$summary"
  flush_file "$summary"

  append_cmd "$summary" "nvidia-smi query" nvidia-smi --query-gpu=timestamp,name,driver_version,pstate,temperature.gpu,fan.speed,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,utilization.gpu,utilization.memory,memory.used,memory.total,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv,noheader,nounits
  append_cmd "$summary" "nvidia-smi full" nvidia-smi -q
  append_cmd "$summary" "nvidia-smi processes" nvidia-smi
  append_shell "$summary" "DRM connector status" "for path in /sys/class/drm/card*-*; do [ -e \"\$path/status\" ] || continue; printf '### %s\n' \"\${path##*/}\"; printf 'status='; cat \"\$path/status\" 2>/dev/null || true; [ -r \"\$path/enabled\" ] && { printf 'enabled='; cat \"\$path/enabled\"; }; [ -r \"\$path/modes\" ] && { printf 'modes:\n'; sed -n '1,20p' \"\$path/modes\"; }; done"
  append_shell "$summary" "GPU endpoint PCIe status" "lspci -vvv -s 01:00.0 | grep -E 'LnkCap|LnkSta|DevCap|DevCtl|DevSta|AERCap|UESta|CESta|RootCtl|RootSta|ASPM|Speed|Width|Status|BadTLP|BadDLLP' || true"
  append_shell "$summary" "GPU root-port PCIe status" "lspci -vvv -s 00:01.1 | grep -E 'LnkCap|LnkSta|DevCap|DevCtl|DevSta|AERCap|UESta|CESta|RootCtl|RootSta|ASPM|Speed|Width|Status|BadTLP|BadDLLP' || true"
  append_cmd "$summary" "sensors" sensors
  append_cmd "$summary" "memory" free -h
  append_cmd "$summary" "swap" swapon --show
  append_cmd "$summary" "zram" zramctl
  append_cmd "$summary" "oomctl" oomctl
  append_shell "$summary" "top RSS processes" "ps -eo pid,ppid,comm,rss,%mem,cmd --sort=-rss | head -n 80"
  append_shell "$summary" "recent kernel journal" "journalctl -k -b 0 --since '5 minutes ago' -o short-iso --no-pager | tail -n 400"
  append_shell "$summary" "recent relevant journal" "journalctl -b 0 --since '5 minutes ago' -o short-iso --no-pager | grep -Ei 'NVRM|Xid|nvidia|gpu|uvm|drm|pcie|aer|thermal|thrott|watchdog|oom|killed|page allocation|gnome-shell|mutter|gdm|sunshine|chrome|roxy|steam|vulkan|opengl|wayland|xwayland|sysrq' | tail -n 500 || true"

  sync "$snap_dir" 2>/dev/null || true
}

capture_metadata() {
  local meta="$RUN_DIR/metadata.txt"
  {
    printf 'run_start=%s\n' "$(ts)"
    printf 'run_dir=%s\n' "$RUN_DIR"
    printf 'output_root=%s\n' "$OUTPUT_ROOT"
    printf 'script_user=%s\n' "$SCRIPT_USER"
    printf 'boot_id=%s\n' "$BOOT_ID"
    printf 'gpu_interval=%s\n' "$GPU_INTERVAL"
    printf 'slow_interval=%s\n' "$SLOW_INTERVAL"
    printf 'use_sudo=%s\n' "$USE_SUDO"
    printf 'note=%s\n' "Read-only GPU bus-loss recorder. Stop with Ctrl-C or kill."
  } >"$meta"
  flush_file "$meta"

  append_cmd "$meta" "uname" uname -a
  append_cmd "$meta" "uptime" uptime
  append_cmd "$meta" "hostnamectl" hostnamectl
  append_cmd "$meta" "current system" readlink -f /run/current-system
  append_cmd "$meta" "system profile" readlink -f /nix/var/nix/profiles/system
  append_cmd "$meta" "kernel cmdline" cat /proc/cmdline
  append_cmd "$meta" "sysrq" cat /proc/sys/kernel/sysrq
  append_shell "$meta" "PCIe ASPM policy" "cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true"
  append_cmd "$meta" "baseboard manufacturer" priv dmidecode -s baseboard-manufacturer
  append_cmd "$meta" "baseboard product" priv dmidecode -s baseboard-product-name
  append_cmd "$meta" "BIOS version" priv dmidecode -s bios-version
  append_cmd "$meta" "BIOS release date" priv dmidecode -s bios-release-date
  append_cmd "$meta" "journal boots" journalctl --list-boots --no-pager
  append_shell "$meta" "last crash history" "last -x | head -n 60"
  append_cmd "$meta" "lsblk" lsblk -o NAME,MODEL,SIZE,TRAN,TYPE,MOUNTPOINTS
  append_cmd "$meta" "nvme list" nvme list
  append_shell "$meta" "findmnt key paths" "findmnt /nix/store /persistent /boot -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null || true"
  append_cmd "$meta" "PCI tree" lspci -tv
  append_cmd "$meta" "PCI devices" lspci -nn
  append_cmd "$meta" "GPU endpoint full lspci" lspci -vvv -s 01:00.0
  append_cmd "$meta" "GPU root-port full lspci" lspci -vvv -s 00:01.1
  append_cmd "$meta" "nvidia-smi full" nvidia-smi -q
  append_cmd "$meta" "nvidia-smi processes" nvidia-smi
  append_cmd "$meta" "sensors" sensors
  append_cmd "$meta" "free" free -h
  append_cmd "$meta" "swap" swapon --show
  append_cmd "$meta" "zram" zramctl
  append_cmd "$meta" "oomctl" oomctl
  append_shell "$meta" "top RSS processes" "ps -eo pid,ppid,comm,rss,%mem,cmd --sort=-rss | head -n 80"
  append_cmd "$meta" "smart nvme0" priv smartctl -x /dev/nvme0
  append_cmd "$meta" "smart nvme1" priv smartctl -x /dev/nvme1
}

gpu_sampler() {
  local file="$RUN_DIR/gpu-sample.csv"
  local fields="timestamp,name,driver_version,pstate,temperature.gpu,fan.speed,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,utilization.gpu,utilization.memory,memory.used,memory.total,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max"
  printf 'sample_iso,%s\n' "$fields" >"$file"
  flush_file "$file"

  while true; do
    if have nvidia-smi; then
      {
        printf '%s,' "$(ts)"
        nvidia-smi --query-gpu="$fields" --format=csv,noheader,nounits
      } >>"$file" 2>>"$ERROR_LOG" || {
        printf '%s,nvidia-smi failed\n' "$(ts)" >>"$file"
      }
    else
      printf '%s,nvidia-smi not found\n' "$(ts)" >>"$file"
    fi
    flush_file "$file"
    sleep "$GPU_INTERVAL"
  done
}

slow_sampler() {
  local sensors_log="$RUN_DIR/sensors.log"
  local pci_log="$RUN_DIR/pci-link.log"
  local display_log="$RUN_DIR/display-status.log"
  local mem_log="$RUN_DIR/memory-oom.log"
  local ps_log="$RUN_DIR/processes.log"

  while true; do
    {
      printf '\n### %s\n' "$(ts)"
      sensors
    } >>"$sensors_log" 2>>"$ERROR_LOG" || true
    flush_file "$sensors_log"

    {
      printf '\n### %s GPU endpoint 01:00.0\n' "$(ts)"
      lspci -vvv -s 01:00.0 | grep -E 'LnkCap|LnkSta|DevCap|DevCtl|DevSta|AERCap|UESta|CESta|ASPM|Speed|Width|Status|BadTLP|BadDLLP' || true
      printf '\n### %s root port 00:01.1\n' "$(ts)"
      lspci -vvv -s 00:01.1 | grep -E 'LnkCap|LnkSta|DevCap|DevCtl|DevSta|AERCap|UESta|CESta|RootCtl|RootSta|ASPM|Speed|Width|Status|BadTLP|BadDLLP' || true
      printf '\n### %s nvidia pcie replay summary\n' "$(ts)"
      nvidia-smi -q | grep -E 'Bus Id|Link Width|Link Speed|Replays Since Reset|Replay Number Rollovers|Current|Maximum|Performance State|Power Draw|Power Limit|GPU Current Temp|GPU Slowdown Temp|GPU Shutdown Temp' || true
    } >>"$pci_log" 2>>"$ERROR_LOG" || true
    flush_file "$pci_log"

    {
      printf '\n### %s DRM connector status\n' "$(ts)"
      for path in /sys/class/drm/card*-*; do
        [[ -e "$path/status" ]] || continue
        printf '%s ' "${path##*/}"
        printf 'status='
        cat "$path/status" 2>/dev/null || true
        if [[ -r "$path/enabled" ]]; then
          printf '%s ' "${path##*/}"
          printf 'enabled='
          cat "$path/enabled" 2>/dev/null || true
        fi
        if [[ -r "$path/modes" ]]; then
          printf '%s modes=' "${path##*/}"
          sed -n '1,5p' "$path/modes" 2>/dev/null | paste -sd, -
          printf '\n'
        fi
      done
      printf '\n-- loginctl sessions --\n'
      loginctl list-sessions --no-legend || true
    } >>"$display_log" 2>>"$ERROR_LOG" || true
    flush_file "$display_log"

    {
      printf '\n### %s\n' "$(ts)"
      free -h
      printf '\n-- swapon --show --\n'
      swapon --show || true
      printf '\n-- zramctl --\n'
      zramctl || true
      printf '\n-- oomctl --\n'
      oomctl || true
    } >>"$mem_log" 2>>"$ERROR_LOG" || true
    flush_file "$mem_log"

    {
      printf '\n### %s top RSS\n' "$(ts)"
      ps -eo pid,ppid,comm,rss,%mem,cmd --sort=-rss | head -n 80
      printf '\n### %s nvidia processes\n' "$(ts)"
      nvidia-smi || true
    } >>"$ps_log" 2>>"$ERROR_LOG" || true
    flush_file "$ps_log"

    sleep "$SLOW_INTERVAL"
  done
}

kernel_watcher() {
  local file="$RUN_DIR/kernel-follow.log"
  local trigger_re='NVRM|Xid|fallen off the bus|GPU has fallen|GPU is lost|NV_ERR_GPU_IS_LOST|AER|PCIe Bus Error|BadTLP|BadDLLP|page allocation failure|Out of memory|oom-killer|Killed process|watchdog|thermal|thrott|lockup|sysrq|panic|I/O error'
  append_shell "$file" "kernel watcher started" "printf 'time=%s\n' '$(ts)'"

  "${JOURNAL_CMD[@]}" -kf -o short-iso --no-pager 2>>"$ERROR_LOG" | while IFS= read -r line; do
    printf '%s\n' "$line" >>"$file"
    flush_file "$file"
    if [[ "$line" =~ $trigger_re ]]; then
      capture_snapshot "kernel-trigger" "$line" &
    fi
  done
}

journal_suspect_watcher() {
  local file="$RUN_DIR/journal-suspects.log"
  local pattern='NVRM|Xid|nvidia|gpu|uvm|drm|pcie|aer|thermal|thrott|watchdog|oom|killed|page allocation|gnome-shell|mutter|gdm|sunshine|chrome|roxy|warp|steam|vulkan|opengl|wayland|xwayland|sysrq|black|hang|freeze'
  local display_trigger_re='Failed to post KMS update|GDBus\.Error:System\.Error\.EBUSY|There are no outputs|no outputs - creating placeholder screen'
  append_shell "$file" "journal suspect watcher started" "printf 'time=%s\n' '$(ts)'"

  "${JOURNAL_CMD[@]}" -b 0 -f -o short-iso --no-pager 2>>"$ERROR_LOG" | while IFS= read -r line; do
    if printf '%s\n' "$line" | grep -Eiq "$pattern"; then
      printf '%s\n' "$line" >>"$file"
      flush_file "$file"
      if printf '%s\n' "$line" | grep -Eiq "$display_trigger_re"; then
        capture_snapshot "display-trigger" "$line" &
      fi
    fi
  done
}

PIDS=()

start_bg() {
  "$@" &
  PIDS+=("$!")
}

cleanup() {
  local status=$?
  trap - INT TERM EXIT
  {
    printf '\nstop_time=%s\n' "$(ts)"
    printf 'exit_status=%s\n' "$status"
  } >>"$RUN_DIR/metadata.txt" 2>/dev/null || true
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  flush_file "$RUN_DIR/metadata.txt" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

cat >"$RUN_DIR/README.txt" <<EOF
GPU-drop debug run: $RUN_ID
Started: $(ts)
Output directory: $RUN_DIR

Important files:
- metadata.txt: startup hardware/config snapshot.
- gpu-sample.csv: 1-second NVIDIA power/temp/fan/PCIe telemetry.
- kernel-follow.log: live kernel journal.
- journal-suspects.log: filtered user/system display/GPU journal lines.
- pci-link.log: repeated PCIe endpoint/root-port status.
- display-status.log: repeated DRM connector/output status.
- sensors.log: repeated temperature/fan sensor output.
- memory-oom.log: memory/swap/zram/oomd samples.
- processes.log: top RSS and NVIDIA process snapshots.
- snapshots/: extra event captures triggered by Xid/NVRM/AER/OOM/thermal patterns.
EOF
flush_file "$RUN_DIR/README.txt"

capture_metadata
capture_snapshot "startup" "initial startup snapshot"

if [[ "$MODE" == "once" ]]; then
  echo "Captured one-shot GPU-drop debug data in: $RUN_DIR"
  exit 0
fi

echo "GPU-drop debug recorder started."
echo "Run directory: $RUN_DIR"
echo "Stop with Ctrl-C, or leave it running until the next crash/reboot."

start_bg gpu_sampler
start_bg slow_sampler
start_bg kernel_watcher
start_bg journal_suspect_watcher

wait

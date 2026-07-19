#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/app"
cd "$ROOT"

export DISPLAY="${DISPLAY:-:98}"
export PYTHONUNBUFFERED="${PYTHONUNBUFFERED:-1}"
export PYTHONPATH="${PYTHONPATH:-/app}"

mkdir -p \
  "$ROOT/runtime_outlook/logs" \
  "$ROOT/runtime_outlook/rt_tokens" \
  "$ROOT/runtime_outlook/rt_input" \
  "$ROOT/runtime_outlook/fail_dumps" \
  "$ROOT/邮箱注册/mihomo_runtime" \
  "$ROOT/邮箱注册/xray_runtime" \
  "$ROOT/云端注册邮箱"

# subscription_proxy.py only looks inside 邮箱注册/mihomo_runtime.
# Recreate the symlink after bind mounts are attached.
if [[ -x /usr/local/bin/mihomo && ! -e "$ROOT/邮箱注册/mihomo_runtime/mihomo-linux" ]]; then
  ln -s /usr/local/bin/mihomo "$ROOT/邮箱注册/mihomo_runtime/mihomo-linux"
fi

# Convenience bootstrap for proxy subscriptions.
if [[ -n "${SUBSCRIPTION_URL:-}" && ! -s "$ROOT/邮箱注册/mihomo_runtime/subscriptions.json" ]]; then
  python - <<'PY'
import json, os
from pathlib import Path

root = Path("/app/邮箱注册/mihomo_runtime")
root.mkdir(parents=True, exist_ok=True)
items = []
for idx, url in enumerate(os.environ.get("SUBSCRIPTION_URL", "").split(","), start=1):
    url = url.strip()
    if url:
        items.append({"name": f"sub-{idx}", "url": url})
(root / "subscriptions.json").write_text(
    json.dumps(items, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
print(f"[docker] wrote {len(items)} subscription(s) to {root / 'subscriptions.json'}", flush=True)
PY
fi

start_xvfb() {
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    echo "[docker] X display already ready: $DISPLAY"
    return 0
  fi
  display_num="${DISPLAY#:}"
  display_num="${display_num%%.*}"
  rm -f "/tmp/.X${display_num}-lock" "/tmp/.X11-unix/X${display_num}" 2>/dev/null || true
  echo "[docker] starting Xvfb $DISPLAY"
  Xvfb "$DISPLAY" -screen 0 1366x768x24 -ac -nolisten tcp \
    >> "$ROOT/runtime_outlook/logs/xvfb.log" 2>&1 &
  for _ in $(seq 1 20); do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
      echo "[docker] Xvfb ready: $DISPLAY"
      return 0
    fi
    sleep 0.5
  done
  echo "[docker] Xvfb failed to become ready; see runtime_outlook/logs/xvfb.log" >&2
  return 1
}

start_xvfb

mode="${1:-${APP_MODE:-dashboard}}"

case "$mode" in
  dashboard)
    exec python -u outlook_dashboard_server.py
    ;;
  daemon)
    echo "[docker] starting daemon: this mode can run scheduled registration batches"
    exec python -u outlook_daemon.py
    ;;
  launcher)
    shift || true
    exec python -u outlook_launcher.py "$@"
    ;;
  status)
    exec python -u outlook_launcher.py status
    ;;
  fetch-rt)
    shift || true
    exec python -u post_register_fetch_rt.py "$@"
    ;;
  shell|bash)
    exec /bin/bash
    ;;
  *)
    exec "$@"
    ;;
esac

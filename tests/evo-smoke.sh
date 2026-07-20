#!/usr/bin/env bash
# evo CLI 冒烟测试：EVO_HOME 隔离，不触碰真实 ~/.evotools
set -euo pipefail
EVO_BIN="${EVO_BIN:-$HOME/.evotools/bin/evo}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export EVO_HOME="$TMP/home"
git init -q --bare "$TMP/origin.git"
mkdir -p "$EVO_HOME"
git init -q -b main "$EVO_HOME"
git -C "$EVO_HOME" remote add origin "$TMP/origin.git"
git -C "$EVO_HOME" config user.email test@example.com
git -C "$EVO_HOME" config user.name test
printf '{"version": 1, "tools": []}\n' > "$EVO_HOME/index.json"

fails=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else echo "FAIL: $1 (want [$2] got [$3])"; fails=$((fails+1)); fi
}

# --- new ---
"$EVO_BIN" new pdf-toc --lang py --desc "提取 PDF 大纲" >/dev/null
check "new creates executable file" "yes" "$([ -x "$EVO_HOME/tools/pdf-toc.py" ] && echo yes)"
check "new index lang" "python" "$(jq -r '.tools[0].lang' "$EVO_HOME/index.json")"
check "new index name" "pdf-toc" "$(jq -r '.tools[0].name' "$EVO_HOME/index.json")"
check "new auto commit" "1" "$(git -C "$EVO_HOME" rev-list --count HEAD)"
if "$EVO_BIN" new pdf-toc --lang py --desc x 2>/dev/null; then
  check "new duplicate rejected" "rejected" "accepted"
else
  check "new duplicate rejected" "rejected" "rejected"
fi

echo "---"
if [ "$fails" -gt 0 ]; then echo "$fails FAIL"; exit 1; else echo "all ok"; fi

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

# --- error contract & name validation ---
check "error is valid JSON" "usage" "$("$EVO_BIN" new 2>&1 >/dev/null | jq -r '.error' | grep -o '^usage')"
if "$EVO_BIN" new Bad_Name --lang py --desc x 2>/dev/null; then
  check "non-kebab name rejected" "rejected" "accepted"
else
  check "non-kebab name rejected" "rejected" "rejected"
fi
if "$EVO_BIN" new ../evil --lang py --desc x 2>/dev/null; then
  check "path traversal rejected" "rejected" "accepted"
else
  check "path traversal rejected" "rejected" "rejected"
fi
if "$EVO_BIN" new foo2 --lang 2>/dev/null; then
  check "flag without value rejected" "rejected" "accepted"
else
  check "flag without value rejected" "rejected" "rejected"
fi

# --- register ---
cat > "$EVO_HOME/tools/hello.ts" <<'EOF'
#!/usr/bin/env bun
console.log("hello")
EOF
"$EVO_BIN" register tools/hello.ts --desc "测试工具" --tags demo >/dev/null
check "register lang from ext" "bun" "$(jq -r '.tools[] | select(.name=="hello") | .lang' "$EVO_HOME/index.json")"
check "register tags" "demo" "$(jq -r '.tools[] | select(.name=="hello") | .tags[0]' "$EVO_HOME/index.json")"
if "$EVO_BIN" register tools/hello.ts --desc x 2>/dev/null; then
  check "register duplicate rejected" "rejected" "accepted"
else
  check "register duplicate rejected" "rejected" "rejected"
fi
"$EVO_BIN" register tools/hello.ts --update >/dev/null
check "register --update single entry" "1" "$(jq '[.tools[] | select(.name=="hello")] | length' "$EVO_HOME/index.json")"
if "$EVO_BIN" register tools/missing.py --desc x 2>/dev/null; then
  check "register missing file rejected" "rejected" "accepted"
else
  check "register missing file rejected" "rejected" "rejected"
fi

# --- search / list / show ---
check "search hit" "pdf-toc" "$("$EVO_BIN" search pdf | cut -f1 | head -1)"
check "search case-insensitive" "pdf-toc" "$("$EVO_BIN" search PDF | cut -f1 | head -1)"
check "search miss empty" "" "$("$EVO_BIN" search nonexistent-xyz)"
check "list all" "2" "$("$EVO_BIN" list | wc -l | tr -d ' ')"
check "list --lang py" "1" "$("$EVO_BIN" list --lang py | wc -l | tr -d ' ')"
check "list --lang ts" "1" "$("$EVO_BIN" list --lang ts | wc -l | tr -d ' ')"
check "show name" "pdf-toc" "$("$EVO_BIN" show pdf-toc | jq -r .name)"
if "$EVO_BIN" show ghost 2>/dev/null; then
  check "show missing rejected" "rejected" "accepted"
else
  check "show missing rejected" "rejected" "rejected"
fi

# --- run / sync ---
if command -v uv >/dev/null 2>&1; then
  cat > "$EVO_HOME/tools/echoargs.py" <<'EOF'
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
import sys
print("ran:" + sys.argv[1])
EOF
  "$EVO_BIN" register tools/echoargs.py --desc "echo" >/dev/null
  check "run python tool" "ran:ok" "$("$EVO_BIN" run echoargs -- ok)"
fi
if command -v bun >/dev/null 2>&1; then
  check "run bun tool" "hello" "$("$EVO_BIN" run hello)"
fi
check "sync" '{"status": "synced"}' "$("$EVO_BIN" sync)"

echo "---"
if [ "$fails" -gt 0 ]; then echo "$fails FAIL"; exit 1; else echo "all ok"; fi

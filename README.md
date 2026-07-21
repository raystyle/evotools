# evotools

Agent 按需生成的可复用小命令行工具库（python + bun 混合），`index.json` 登记，`bin/evo` 管理。

**核心闭环：单文件自包含 → 一个脚本 = 一个命令 → 工具库随用随长。** python 工具靠 PEP 723 内联元数据声明依赖（`uv run` 自动解析），bun 工具靠 import auto-install——都不需要项目脚手架，shebang 直接可执行，所以每个工具就是一个文件，`evo new` 即建即得。

## 安装

```bash
git clone https://github.com/raystyle/evotools ~/.evotools
# 加入 PATH（写进你的 shell rc）：
export PATH="$HOME/.evotools/bin:$HOME/.evotools/tools:$PATH"
```

## 使用

```bash
evo new <name> --lang py|ts --desc "一句话描述"   # 生成工具模板并登记
evo register tools/<file> --desc "..." [--tags a,b] [--update]
evo search <关键词>                               # 按名称/描述/标签搜索
evo list [--lang py|ts]
evo show <name>
evo run <name> [-- args...]
evo sync                                          # pull --rebase + push
```

## 约定

- 工具名 kebab-case、全库唯一；python 工具用 PEP 723 声明依赖，bun 工具依赖走 import auto-install
- 注册即自动 commit + push；多机器使用前 `evo sync`

## 工具契约 v1.1(所有工具必须满足)

| 维度 | 约定 |
|------|------|
| 输入 | 位置参数为主;无参数且 stdin 非 TTY → 自动读 stdin(管道可串联) |
| 输出 | stdout 只出结果:单结果 JSON、多结果 JSONL;jq 可整形;**结果对象顶层带 `"v": 1`**(schema 版本,向后兼容只加字段不改名删字段) |
| 错误 | `{"error": "..."}` stderr + exit 1(参数)/2(运行时);提示/进度走 stderr |
| `--help` | 必支持:usage + ≤3 示例 + 输入/输出契约一句话,exit 0(agent 自省) |
| `--dry-run` | 必支持:不执行副作用,输出执行计划 JSON(agent 先验证再真跑) |

`evo new` 生成的 py/ts 模板已自带契约脚手架,填实现即可。

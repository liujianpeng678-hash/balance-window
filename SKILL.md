---
name: api-balance-watch
description: 每轮用户对话开始时检查在用 API 余额（DeepSeek 等）与各中转/视觉/3D API 可用性，低于阈值（默认 ¥5）或 Key 失效/服务不可达时在回复开头提醒。适用于用户要求的"所有 API 没钱/挂了都要提醒我"长期约定。
---

# API 余额监控提醒（api-balance-watch）

## 概览
用户长期约定：**所有在用的 API 都要监控**——余额低于 ¥5 每轮对话提醒一次；Key 失效/服务不可达也要提醒。本机 API 清单（2026-08-15 盘点）：

| API | 用途 | Key 位置 | 可查余额 | 充值页 |
|-----|------|----------|----------|--------|
| DeepSeek 官方 | DSH 主模型 | D:\deepseek\.env 的 DEEPSEEK_API_KEY | ✅ /user/balance | platform.deepseek.com/top_up |
| 阿里百炼 DashScope | DSH 视觉识别 qwen3-vl-flash | C:\Users\刘健鹏\.config\see\config.env 的 SEE_API_KEY | ❌（百炼控制台查） | expense.console.aliyun.com |
| sheapi.top | Codex gpt-5.6-sol 中转 | C:\Users\刘健鹏\.codex\auth.json 的 OPENAI_API_KEY | ❌（sheapi.top 用户中心） | www.sheapi.top |
| feixueapi.xyz | Claude Sonnet 4.6 中转 | Key 未存本机（在 Codex 应用内） | ❌（飞雪用户中心） | feixueapi.xyz |
| Tripo | 3D 生成 | C:\Users\刘健鹏\.codex\.env 的 TRIPO_API_KEY | ❌（tripo3d.ai 控制台） | platform.tripo3d.ai |

充值链接由 check-api-balance.ps1 写入 balance-state.json 的 url 字段，悬浮窗每行「充值↗」按钮一键打开对应充值页（缩略药丸的「充值」= DeepSeek 充值）。

注：~/.codex 下 deepseek-flash/pro.config.toml 引用的 moonbridge provider 在本机无定义，属废弃配置，不监控。

## 触发时机
- 每轮收到真人用户消息、开始回答前（先于任务处理）：先跑检查脚本，再干活。
- 输出含 LOW: 行（余额低于阈值 / Key 失效 / 服务不可达）→ 回复**开头**提醒，含具体内容；DeepSeek 余额低于 ¥5 是硬性提醒（用户要求每轮都提）。
- 一切正常 → 不提醒（除非用户主动问）。

## 步骤
1. 运行检查脚本：
\`\`\`
powershell -NoProfile -ExecutionPolicy Bypass -File 'D:\deepseek\scripts\check-api-balance.ps1' -Threshold 5
\`\`\`
输出各 API 一行状态；问题项带 LOW: 前缀并写日志 D:\deepseek\scripts\balance-watch.log。
2. 有 LOW: 行 → 回复开头逐条提醒；DeepSeek 余额行无论是否 LOW 都看一眼数字。
3. 脚本缺失时内联查 DeepSeek：
\`\`\`powershell
$key = [regex]::Match((Get-Content 'D:\deepseek\.env' -Raw), 'DEEPSEEK_API_KEY\s*=\s*([^\r\n]+)').Groups[1].Value.Trim()
curl.exe -s -m 20 'https://api.deepseek.com/user/balance' -H ("Authorization: Bearer " + $key)
\`\`\`
解析 balance_infos[0].total_balance（CNY 字符串转 double）。
4. 新增 API 时：在脚本里按现有 provider 段追加（Key 路径 + 探测/余额接口），并更新本表。

## 坑
- 不要把完整 API Key 打印到对话或日志：只显示前 4~6 位 + **** + 后 4 位。
- D:\deepseek\.env 与 ~/.config/see/config.env 是 GBK/ANSI 编码：用 Get-Content -Raw + 正则提取，别按行号。
- 脚本文件必须是 UTF-8 带 BOM（PowerShell 5.1 按 ANSI 读无 BOM 的 .ps1 会乱码）。
- sheapi.top 需要走 Clash 代理（127.0.0.1:7897）才能访问，且服务本身时通时断（000/404 都见过）。
- feixueapi.xyz 不需要代理，直接可达；401 = 该 Key 不是飞雪的 Key（本机未存）。
- 余额接口 401/403 = Key 失效；is_available:false = 账户不可用；HTTP 000 = 网络不通。
- 余额单位是字符串形式的 CNY（如 "13.15"），比较前转 double。
- msg 弹窗（-Popup）只在交互会话可用，后台服务里别依赖。

## 验证
- 跑脚本输出每行无乱码；DeepSeek 有余额数字；
- 临时把阈值调高（-Threshold 999）能看到 DeepSeek LOW: 行与日志追加；
- 断代理时 sheapi.top 行会报不可达并出 LOW 提醒。

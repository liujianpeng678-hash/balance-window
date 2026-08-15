# 余额窗口（Balance Window）

> 悬浮在桌面上，实时告诉你所有 API 还剩多少钱——不够了提醒你，点一下直达充值页。

为 DeepSeek Harness（DSH）设计的 **API 余额监控悬浮窗 + 对话提醒技能**：
- **悬浮窗**：WPF 置顶半透明小组件，DeepSeek 余额大字显示，各 API 状态绿/黄/红点，低于阈值变黄弹告警；支持**双击缩略/展开**、拖动、每 5 分钟自动刷新、开机自启；
- **一键充值**：每个 API 行都有「充值↗」按钮，直达对应平台的充值页；
- **对话提醒**：配套「api-balance-watch」技能，AI 每轮对话开始自动检查余额，低于阈值（默认 ¥5）在回复开头提醒充值。

## 界面预览

展开态（400x320 深色半透明圆角面板）：

    ┌─────────────────────────────────────┐
    │ API 余额监控          更新于 20:11:27 │
    │ 剩余余额：¥7.83 [充值↗]              │
    │ 🟢 阿里百炼(视觉): Key 有效 [充值↗]   │
    │ 🔴 sheapi.top(Codex): 不可达 [充值↗]  │
    │ 🟡 feixueapi.xyz(飞雪): ...  [充值↗]  │
    │ 🟢 Tripo(3D): Key 有效       [充值↗]  │
    └─────────────────────────────────────┘

缩略态（小药丸，仅显示余额 + 状态点 + ⚠ 告警 + 充值入口），双击或右键菜单随时切换。

## 监控的 API

| API | 用途 | 余额可查 | 充值页 |
|-----|------|----------|--------|
| DeepSeek 官方 | 主模型 | ✅ /user/balance | platform.deepseek.com/top_up |
| 阿里百炼 DashScope | 视觉识别（qwen3-vl） | ❌ | expense.console.aliyun.com |
| sheapi.top | Codex 中转（gpt-5.6-sol） | ❌ | www.sheapi.top |
| feixueapi.xyz | Claude 中转 | ❌ | feixueapi.xyz |
| Tripo | 3D 生成 | ❌ | platform.tripo3d.ai |
| 阿里云账户（BSS） | 账户总余额（含百炼消费） | ✅ QueryAccountBalance（需配置 AK） | expense.console.aliyun.com |

仅 DeepSeek 有公开余额接口；其余通过 Key 有效性/连通性探测，失效或不可达会在悬浮窗标红并（可选）弹窗提醒。

## 目录结构

    balance-window/
    ├── SKILL.md                      # api-balance-watch 技能定义（DSH 技能库）
    ├── scripts/
    │   ├── check-api-balance.ps1     # 余额/可用性检查（输出 balance-state.json）
│   ├── aliyun-balance.ps1       # 阿里云账户余额（BSS QueryAccountBalance，读本地 AK）
    │   ├── api-balance-widget.ps1    # 悬浮窗本体（WPF，缩略/展开 + 一键充值）
    │   └── launch-widget.vbs         # 悬浮窗启动器（explorer 代拉，解决窗口站隔离）
    └── README.md

## 快速开始（Windows）

1. **准备密钥文件**（脚本只读文件，仓库不含任何密钥）：
   - D:\deepseek\.env → DEEPSEEK_API_KEY=sk-xxx（DeepSeek）
   - C:\Users\<你>\.config\see\config.env → SEE_API_KEY=sk-ws-xxx（阿里百炼视觉）
   - C:\Users\<你>\.codex\auth.json → {"OPENAI_API_KEY": "sk-xxx"}（sheapi.top）
   - C:\Users\<你>\.codex\.env → TRIPO_API_KEY=tsk_xxx（Tripo）
   - 路径按你的机器修改脚本里的常量即可。
2. **启动悬浮窗**：双击 scripts\launch-widget.vbs（或 powershell -NoProfile -ExecutionPolicy Bypass -File scripts\api-balance-widget.ps1）。
3. **开机自启**：把指向 api-balance-widget.ps1 的快捷方式放入 shell:startup 文件夹。
4. **DSH 技能**：将 SKILL.md 放入 ~/.agents/skills/api-balance-watch/，AI 即会在每轮对话开始时自动查余额并提醒。

## 交互操作

| 操作 | 效果 |
|------|------|
| 双击 | 缩略 ⇄ 展开 |
| 左键拖动 | 移动位置 |
| 点「充值↗」 | 打开对应充值页 |
| 右键菜单 | 缩略/展开、立即刷新、DeepSeek 充值、打开日志、置顶、退出 |

## 运行要求

- Windows 10/11 + PowerShell 5.1（脚本需 UTF-8 BOM 编码，已内置）
- WPF（系统自带）
- sheapi.top 探测需要本地 Clash 代理（127.0.0.1:7897，可按需修改）

## 安全说明

- 仓库内**不含任何 API 密钥**；密钥全部从本机文件读取，balance-state.json、日志、锁文件已 gitignore。
- 悬浮窗显示余额时对密钥零接触；AI 对话中只展示打码前缀。

## 许可证

MIT © liujianpeng678-hash

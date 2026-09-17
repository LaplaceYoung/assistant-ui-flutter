# Flutter 移植计划（对照 assistant-ui 官方仓库）

本文件是移植的唯一进度来源。每一行都对应官方仓库里的一个真实文件，状态只有四种：
`ported`（行为与样式已对齐并有测试/截图证据）、`partial`（已实现但有明确缺口）、
`planned`（未开始，按波次排队）、`n/a`（依赖 web 专有能力，Dart 侧无对应物，已记录原因）。

## 权威来源（对照基线）

| 类别 | 官方路径 |
|---|---|
| Element 实现 | `packages/ui/src/components/react/assistant-ui/elements/*.tsx`（140 个） |
| RN Element | `packages/ui/src/components/react-native/assistant-ui/elements/*`（43 个，作为 Flutter 布局的第一参照） |
| Primitive 文档 | `apps/docs/content/docs/primitives/*.mdx` |
| Element 文档（含配色/尺寸表） | `apps/docs/content/elements/*.mdx` |
| 厂商复刻页 | `apps/docs/components/pages/examples/{chatgpt,claude,gemini,grok}.tsx` + 同名 `.mdx` |
| Runtime/协议 | `packages/core`、`packages/store`、`packages/tap`、`packages/assistant-stream` |

移植时的保真规则（对每个组件逐条核对）：

1. **颜色、圆角、间距、字号直接抄官方数值**，不做“看起来差不多”的近似。
2. **状态集合必须一致**：例如 chatgpt 的主按钮有 Cancel / StopDictation / Send / Dictate+voice 四态且互斥优先。
3. **默认行为必须一致**：action bar 的 autohide、streaming 时禁用、copy 的 2-3 秒状态等。
4. **缺口要写进本文件**，不允许静默简化。

## 波次

| 波次 | 内容 | 状态 |
|---|---|---|
| Wave 0 | 核心模型、LocalRuntime、data stream 协议、基础 primitives、默认样式组件 | 完成（26 测试） |
| Wave A | 厂商复刻页所需共享件：tooltip 图标按钮、菜单/下拉、markdown 保真升级（表格/代码复制/链接）、附件卡片、消息耗时、typing/thinking/loading 指示器、四态主按钮、speech/dictation/feedback 适配器与运行时接线 | 完成（35 测试） |
| Wave B | 4 个厂商复刻页（ChatGPT / Claude / Gemini / Grok），逐页对照官方 tsx 的配色表与版式 | 完成（4 页已在浏览器逐页截图核对） |
| Wave C | 线程列表子系统（threads runtime + ThreadList primitives + 侧边栏 shell，官方 `clone-thread-shell.tsx` 的侧栏部分） | 完成（8 条新测试 + 浏览器验证） |
| Wave D | Composer 家族（mentions、slash、trigger popover、model picker、context、voice、queue、draft、mobile composer） | 完成：trigger/mentions/slash/directive/context ring/voice/queue/draft/model picker/mobile composer 全部交付（`composer`、`model-picker`、`model-selector`、`mobile-composer` 均为 ported）；model picker 与 quote preview 经 `leading`/`footer` 槽位接线并有接线测试 |
| Wave E | 工具家族（tool group/timeline/error、approval、elicitation、MCP 面板、command palette） | 完成：7 个 element + `GroupedParts` 分组原语（35 条新测试 + 浏览器逐元素验证）；`mcp-config.aui` 依赖 MCP runtime，未做（已记录） |
| Wave F | Agent/编排家族（plan、status、handoff、agent card、subagent、task、job、schedule、checkpoint、memory、background inbox、canvas split、flow canvas、computer use） | 完成：14 个 element（32 条新测试 + 浏览器验证） |
| Wave G | 观测/成本家族（trace waterfall、cost meter、context breakdown、activity/heat graph、confidence、score breakdown、chart、data table、comparison、recommendation、connection、number ticker、spec sheet、timeline、todo list、flow graph） | 完成：17 个 element（26 条新测试 + 浏览器验证） |
| Wave H | 内容与展示家族（chart、data table、math、artifact、sources、file tree、syntax highlighter、generative UI、diagram、mermaid、map、image、document reference、retrieval、research、citation、conversation/thread/web search、speaker identity、image generation） | 完成：19 个 element（chart / data-table 随 Wave G 交付，其余 17 个本轮完成，26 条新测试 + 浏览器验证）；`code-diff`/`code-runner`/`terminal-block` 归入 E 余项 |
| Wave I | 线程周边（search、thread list、shared conversation、timeline、day separator、draft restore、empty/error state、suggestions、streaming text、regenerate menu、read aloud、settings…） | 完成：empty-state、error-state、suggestions、day-separator、streaming-text、shared-conversation、regenerate-menu、scroll-anchor pill、edit-message 丢弃提示，连同 read-aloud、reasoning-panel/effort、settings-panel、quota-banner、onboarding、logos、launcher-bubble、chat-panel、message-attachment、prompt-library、threadlist-sidebar、conversation-map、flow、flow-expand、assistant-modal、voice-conversation、model-picker/selector、mobile-composer、quote-reply、feedback-dialog 全部交付；矩阵中均为 ported，余下 5 个 partial 见 `docs/element-coverage.md` |

### Wave D 交付物（完成）

| 官方 element | Flutter 实现 | 说明 |
|---|---|---|
| `composer-trigger-popover` | `AuiComposerTriggerRoot` + `AuiComposerTriggerPopover` + `AuiTriggerAdapter/Controller` | 按字符触发、光标处 token 识别（含词边界，`a@b` 不触发）、↑↓/Enter/Tab/Esc 接管、面板按输入框矩形锚定并做视口钳制 |
| `composer-mentions` | `AssistantMentionPopover` + `AssistantMentionAdapter` | 头像/姓名/描述、过滤、插入 `@[Name](id)` directive |
| `composer-slash-commands` | `AssistantSlashCommandMenu` + `AssistantSlashCommandAdapter` | 过滤、执行命令并消费 token |
| `directive-text` | `AssistantDirectiveText` | directive 渲染为行内 chip |
| `composer-context` | `AssistantContextRing` + `ThreadState.contextUsage` | 环形用量指示（`maxTokens=0` 时自动隐藏）、可选 token 文案；官方按 token 计数，这里是 `chars/4` 估算 |
| `composer-voice` | `AssistantComposerVoice` + `DictationAdapter` | 麦克风/停止双态、条状电平波形、转写累积进 composer、无适配器时禁用 |
| `message-queue` | `AssistantMessageQueue` + `ComposerRuntimeApi.queuedMessages` | 运行中发送进队列不打断流、运行结束后自动发出、点击取消单条 |
| `draft-restore` | `LocalRuntime` 的 per-thread 草稿 | 切线程保留各自草稿，线程删除时一并清理 |

### Wave E 交付物（完成）

| 官方 element | Flutter 实现 | 保真说明 |
|---|---|---|
| `tool-group` | `components/tool_group.dart` `AssistantToolGroup` | paper 卡（圆角 16、最大 384）、头部 chevron 旋转 200ms、`done/total` 与 `N failed`/`N done` 计数、运行中 spinner / 失败红叉 / 完成绿勾、行内 mono 名称 + target + `Nms` |
| `tool-timeline` | `components/tool_timeline.dart` `AssistantToolTimeline` | 折叠触发器 + `SwapLabel` 双标签（streaming ↔ resting）、逐步显隐、行内 chip、变更文件 `+N/−N`；CSS 模糊与逐行入场动画未做（Flutter 无等价物，已标注） |
| `tool-error` | `components/tool_error.dart` `AssistantToolError` | 名称/target/`attempt/maxAttempts`、红色等宽消息块、Retry（重试时 spinner + `Retrying`）与 Skip（无回调即禁用） |
| `approval-card` | `components/approval_card.dart` `AssistantApprovalCard` | 四态 `request/running/done/denied`；请求态 Deny/Always allow/Allow once 互斥出现，终态渲染状态行（`Approved, running`/`Denied`/`Finished with exit 0`） |
| `elicitation-form` | `components/elicitation_form.dart` `AssistantElicitationForm` | text/choice/toggle 三类字段、必填标记、三态 `request/accepted/declined`；比官方多了 `selected` + `onFieldChanged`（官方是只读展示，这里补上可交互） |
| `mcp-server-panel` | `components/mcp_server_panel.dart` `AssistantMcpServerPanel` | 头部连接计数、四态状态点（connecting 脉冲）、展开显示 transport/状态/工具 chips、needs-auth 时 Authorize |
| `command-palette` | `components/command_palette.dart` `AssistantCommandPalette` | 过滤 + 分组排序、`activeId` 高亮、↑↓ 环绕（active 被过滤掉时从边界起步）、Enter 执行、key cap、空态文案 |
| `GroupedParts` | `primitives/message.dart` 的 `AuiMessageParts.groupBy/partGroupBuilder` | 官方 `MessagePrimitive.GroupedParts` 的 Dart 版：连续同 key 的 part 合并成一组；`AssistantMessageParts(groupToolCalls: true)` 直接用 `AssistantToolGroup` 折叠连续 tool call |

共享底座：`components/surfaces.dart`（`auiPaper`/`auiField`/`auiMono`/`auiFg`/`AuiSpinner`/`AuiShimmerLabel`/`AuiSwapLabel`/`AuiPillButton`），即官方 `elements/surfaces.tsx` 的 Dart 版。

未移植：`tool-group.aui` 的 Root/Trigger/Content 三件套（其能力已由 `GroupedParts` + `AssistantToolGroup` 覆盖）、`mcp-config.aui` 配置编辑器（依赖 `@assistant-ui/react-mcp` 的连接/鉴权 runtime，不只是 UI）。两条都写进了覆盖表。

浏览器验证（`?page=tools`，headless Chrome over CDP）：tool-group 的 2/3 运行态、1 failed 态与行内耗时；tool-timeline 的 `Working…` → `Worked for 12s` 切换、逐步显隐、`+12/−3` 变更文件 chips；tool-error 的重试预算；approval-card 从 request 到 `Approved, running`；elicitation-form 的 chip 选中与 toggle；mcp-server-panel 的三色状态点与工具列表；command-palette 的分组、key cap、点击执行（`ran: model`）。

### Wave C 交付物

| 官方能力 | Flutter 实现 | 说明 |
|---|---|---|
| `s.threads.threadIds / archivedThreadIds / mainThreadId / items / isLoading` | `ThreadsState` + `AuiState.threads` | 与官方 state 形状一致 |
| `threads.switchToThread / create / archive / unarchive / delete / rename / loadMore` | `ThreadsRuntimeApi`（`LocalRuntime` 内存实现） | 切换会保存/加载各自消息并取消进行中的 run |
| `ThreadListPrimitive` 家族 | `AuiThreadListRoot/New/Search/Items/Item(Title/Archive/Delete/Trigger)/LoadMore` | `searchQuery` 过滤与归档区与官方相同 |
| `ThreadList` 元素 | `AssistantThreadList` | 新建按钮、搜索框、逐行 hover 才出现的归档/删除、自动标题（本地启发式，替代官方 title adapter） |
| `CloneThreadShell` 侧栏 | `AssistantShell` | 桌面可折叠 rail（默认展开）+ <768px 抽屉 |

### 厂商复刻页（Wave B）

| Widget | 官方来源 | 已核对项 | 已知保真缺口 |
|---|---|---|---|
| `ChatGptClone` | `pages/examples/chatgpt.tsx` | `#ffffff`/`#000000`、`#212121` 深色 composer、半径 28、`#0d0d0d` 用户气泡配白字、22px 气泡圆角、常显助手 action bar（copy/好评/差评/朗读/分享/重生成/更多）、脚注 | Share 与 More 无宿主能力，渲染为禁用；无听写/语音适配器时主按钮落到禁用态 |
| `ClaudeClone` | `pages/examples/claude.tsx` | `#F0ECE0`/`#2b2a27` 米色、全 serif、`#c96442` 橙、16px 无阴影 composer、模式标签（Write/Learn/Code/From Drive/From Calendar）、Sonnet 4.5/Opus 4.7/Haiku 4.5 选择器、hover 才出现的 action bar、脚注 | 标题字号按 28px 呈现（官方 `text-3xl`） |
| `GeminiClone` | `pages/examples/gemini.tsx` | `#fdfcfc`/`#0c0c0c`、径向蓝色光晕（`#a9d1fb`/60% 与 `#1b2f9c`/50%，blur 90）、单行 pill composer、`+` 菜单（含 Deep Research/Canvas/Create image/Guided Learning）、Fast/Thinking 选择器、发送按钮 `#1f3b9b`/禁用 `#e8eaed`、`#f2f0f0` 用户气泡（深色 `#333537`） | 无语音适配器，麦克风态不可达 |
| `GrokClone` | `pages/examples/grok.tsx` | `#fdfdfd`/`#141414`、`#f8f8f8`+`#e5e5e5` 内描边 pill、回形针、模型 pill 在输入时收起为图标、Mic/Send/Stop 动画槽（反色主按钮）、`#f0f0f0` 用户气泡（右下角 8px）、消息耗时 chip、hover action bar | 词标用文字近似（官方是 SVG 字标），已标注 |

### 已完成组件（Wave 0 + A）

| 官方 element | Flutter 文件 | 保真说明 |
|---|---|---|
| thread | `components/thread.dart` + `primitives/thread.dart` | 对齐 Root/Viewport/ViewportFooter/Messages；`turnAnchor` 只做 top/bottom，未做 clamp |
| message-pair | `components/thread.dart` | 用户气泡右对齐、助手头像与 action bar 行 |
| message-actions / message-branches | `components/action_bar.dart` | autohide(`never/notLast/always`)、float、copy 的 2s 状态、分支选择器 |
| markdown-text | `components/markdown.dart` | 标题/列表/引用/表格/围栏代码（带复制）/行内格式/链接；缺语法高亮与 LaTeX |
| reasoning | `components/parts.dart` | 折叠卡，streaming 时自动展开 |
| tool-call / tool-fallback | `components/parts.dart` | 状态点、参数与结果的等宽 JSON |
| tooltip-icon-button | `components/tooltip_icon_button.dart` | 32/36px、8px 圆角或圆形、hover-only 背景、tooltip、disabled |
| attachment | `components/attachment.dart` | 图片缩略图（进度条+移除）、文件卡（类型图标+mime） |
| message-timing | `components/message_timing.dart` | tooltip 内展示首 token/总时长/速度/chunk |
| typing-indicator / thinking-indicator / loading-state | `components/indicators.dart` | 三点错峰、状态行+计时、脉冲矩阵 |
| dropdown-menu | `components/menu.dart` | MenuAnchor 封装，支持描述行、选中态、分隔线 |
| composer 主按钮 | `components/composer.dart` | 官方四态优先级 Cancel → StopDictation → Send → Dictate(+voice mode) |

依赖 web 专有能力的条目（`n/a` 或需替代方案，逐条在矩阵里注明）：iframe 沙箱预览、Web Speech API
驱动的听写/朗读、shadcn Sheet/Radix 的具体 DOM 行为、Shiki/Prism 高亮（Dart 侧用自研解析+主题色）。

## 落地页 1:1 复刻（独立交付物）

| 项 | 内容 | 状态 |
|---|---|---|
| 规格抓取 | `docs/landing/`：DOM 快照、站点 CSS、全文案（`copy.md`）、OKLCH→sRGB 主题令牌（`theme.md`）、6 张 1440×813 参考截图 | 完成 |
| 设计说明 | `docs/landing/DESIGN.md`：逐区块布局/字号/色值/交互 + Flutter 组件映射 + 已知缺口 | 完成 |
| 实现 | `landing/`：独立 Flutter Web 应用，9 个区块全部实现，品牌字体（Public Sans / JetBrains Mono 可变字体）内置 | 完成 |
| 验证 | 双主题逐屏截图（`?theme=light` 深链）+ 2 条 widget 测试（首屏/demo、页脚主题切换） | 完成 |

复刻页与官方站点的差异（已记录）：品牌 logo 用字标替代（不随附第三方 SVG）；`⌘K` 搜索面板与 docs playground 为视觉复刻，后端不在范围内；hero 的点阵插画为等价实现（官方为 SVG 资源）。

## 验证协议

1. `flutter analyze` 零问题，`flutter test` 全绿（每个 ported 组件至少有一条断言其可观察行为的测试）。
2. 视觉验证用 headless Chrome + CDP 打开 example，逐页截图对照官方 `.mdx` 中的配色表与版式说明。
3. 行为验证覆盖：流式、取消、重生成、分支、编辑、工具往返、附件、四态主按钮、hover 显隐。

组件级状态见 `docs/element-coverage.md`（由 `tool/sync_element_coverage.dart` 生成，避免手写漂移）。

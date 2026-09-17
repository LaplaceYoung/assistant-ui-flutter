# 动效对齐计划（对照上游 element 源码）

上游 `packages/ui/src/components/react/assistant-ui/elements/*.tsx` 里的动效词汇已经抓成
`docs/motion-inventory.json`（121 个 element 带动效标记）。刷新方式：

```bash
rm -rf /tmp/aui-upstream
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/assistant-ui/assistant-ui /tmp/aui-upstream
cd /tmp/aui-upstream && git sparse-checkout set packages/ui/src/components/react/assistant-ui
# 然后按下表逐元素核对
```

## 上游的动效词汇（出现次数）

| token | 次数 | Dart 侧的对应物 |
|---|---|---|
| `animate-in` / `animate-out` | 99 / 3 | `AnimatedSwitcher` / `FadeTransition` + `SlideTransition`（入场 150–300ms ease-out） |
| `transition-colors` | 74 | `AnimatedContainer` / `AnimatedDefaultTextStyle`（150–200ms） |
| `transition-` / `transition-none` | 73 / 76 | 同上；`transition-none` 表示无动效，Dart 侧必须**不动** |
| `duration-300 / 200 / 150 / 500` | 72 / 58 / 38 / 22 | 对应 `Duration(milliseconds: …)` |
| `ease-out` | 14 | `Curves.easeOut`（其余 `ease-` 变体按 tailwind 表映射） |
| `animate-spin` | 28 | `CircularProgressIndicator` / `RotationTransition` |
| `animate-pulse` | 23 | `AnimationController(repeat(reverse: true))` |
| `transition-transform` | 25 | `AnimatedRotation` / `AnimatedScale` / `AnimatedSlide` |
| `transition-opacity` | 11 | `AnimatedOpacity` |
| `animate-collapsible-up/down` | 3 / 3 | `AnimatedSize` 或 `SizeTransition` |
| `zoom-in-95` / `zoom-out-95` + `fade-in-0` / `fade-out-0` | 3+3 | 对话框开合：`ScaleTransition(0.95→1)` + 淡入，150ms |

## 逐元素核对流程

1. 从 `docs/motion-inventory.json` 取一个 element 的 token 集合；
2. 打开上游 `elements/<name>.tsx`，确认每个 token 挂在**哪个交互**上（hover、打开、流式、完成、失败）；
3. 在对应的 Dart 组件里核对：同交互是否有动画、时长与曲线是否一致、`transition-none` 处是否确实静止；
4. 不一致就改 Dart 侧；改完在 `test/` 里加断言（时长/曲线/状态切换），并在浏览器复核一次；
5. 全部核对完的元素在 `docs/element-coverage.md` 的 note 里注明动效已对齐。

## 已对齐（本文件维护）

| element | 动效 | 证据 |
|---|---|---|
| `agent-status` | 工作态圆点 `animate-pulse`（1400ms 往复）+ 标签 `fade-in blur-in-[2px] duration-300`（状态变化时重播） | `test/motion_test.dart` |
| `agent-plan` | 进度条 `transition-[width] duration-500` 缓动到新比例 | `test/motion_test.dart` |
| `approval-card` | 终态行 `fade-in animate-in duration-300`；按钮 `active:scale-[0.96]` + 150ms 颜色过渡（`AuiPillButton` 统一实现） | `test/motion_test.dart` |
| `artifact-card` | 悬停上抬 1px（150ms）+ `active:scale-[0.98]`；角标箭头 150ms 淡入；word-count 行 `fade-in blur-in-[2px] duration-300` | `test/motion_test.dart` |
| `tool-group` | 头部 chevron 200ms 旋转 + `hover:bg-[0.03] transition-colors`；展开体 `fade-in slide-in-from-top-1 duration-200`（现已补齐） | `test/motion_test.dart` |
| `tool-timeline` | 触发器 chevron 200ms + `cubic-bezier(0.32,0.72,0,1)`；每一步 `fade-in slide-in-from-bottom-1 duration-300` 逐行入场（现已补齐） | `test/motion_test.dart` |
| `command-palette` / `model-selector` / `composer-trigger-popover` | 行底色 `transition-colors`（本为瞬时切换，现统一为 150ms 缓动） | `test/motion_test.dart` |
| `settings-panel` | 开关轨道 200ms 颜色 + 旋钮位移（`transition-colors/transform duration-200`）；分段控件 150ms | `test/motion_test.dart` |
| `message-queue` | 队列行 `fade-in slide-in-from-bottom-1 fill-mode-both duration-300` 入场（已补齐） | `test/motion_test.dart` |
| `attachment` | 上传线 `transition-[width] duration-300` 缓动（已补齐） | `test/motion_test.dart` |
| `composer-voice` | 电平条 `transition-[height,background-color] duration-150` 缓动（已补齐）；mic 旋转/波形原为动画 | `test/composer_extras_test.dart` |
| `streaming-text` | 最末词 500ms 淡入与旧词 `transition-colors duration-700`、光标 `animate-pulse` | 待补（当前为着色高亮） |
| `tool-error` | Retry/Skip 走 `AuiPillButton`（150ms 颜色 + 0.96 按压），重试时 `AuiSpinner` 旋转 | `test/motion_test.dart` |
| `mermaid-diagram` | streaming 骨架 + 内置绘制 | `test/mermaid_renderer_test.dart` |

## 共享动效原语（`components/motion.dart`）

| 原语 | 覆盖的上游写法 |
|---|---|
| `AuiFadeInBlur` | `fade-in blur-in-[2px] animate-in duration-300`（含 `trigger` 重播与可选位移入场） |
| `AuiPressable` | `active:scale-[0.96/0.98]` + `hover:-translate-y-px`，150ms |
| `AuiAnimatedProgressBar` | `transition-[width] duration-500` |
| `AuiHoverColor` | `transition-colors duration-150/200` |

`AuiPillButton`（所有 pill 按钮共用）现在自带 150ms 颜色过渡 + 按压 0.96 缩放，因此 tool 错误重试/跳过、elicitation、对话框等元素一并获得同一套按压反馈。

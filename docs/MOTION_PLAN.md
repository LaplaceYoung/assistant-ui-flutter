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
| `tool-group` | 头部 chevron 200ms 旋转 | `test/tool_family_test.dart` |
| `tool-timeline` | 折叠触发器 + 双标签切换；**CSS blur/逐行入场未做** | 待补 |
| `approval-card` | 状态切换 | 待核对时长 |
| `mermaid-diagram` | streaming 骨架 + 内置绘制 | `test/mermaid_renderer_test.dart` |

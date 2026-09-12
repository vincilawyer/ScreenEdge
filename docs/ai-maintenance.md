# AI 维护与 Apple 芯片 Mac 接续说明

## 接续当前任务

用户需要新增“仅鼠标所在屏幕显示”：鼠标在哪块屏幕，就只显示该屏幕已有的通道；通过通用控制离开本机时，本机隐藏提示线。两台 Mac 各自运行新版并选择此模式。用户已要求在另一台 Apple 芯片 Mac 上由当地的 GPT 执行构建与安装。

- 仓库：`https://github.com/vincilawyer/ScreenEdge`。
- 此功能的任务分支：`codex/pointer-screen-20260912`。开始前确认它是否已经合并；尚未合并时从此分支取得代码，不要只下载旧 Release 或仅构建旧 `main`。
- 源码版本为 **1.4.0，构建号 5**；现有 **v1.3.0 Release 不包含新模式**。
- 先读取根目录 `AGENTS.md`，再读本文件、`docs/pointer-screen.md` 和 `docs/lock-screen.md`。保留当前机器自己的显示器排列、通用控制配置和应用偏好。
- 本次仅提供原生 AppKit/SwiftUI 覆盖层，不增加键鼠共享服务、网络配对、输入拦截或显示器管理。

## 当前已验证与待验证

- Intel / macOS 15.7.9：120 项几何与配置检查通过；原生窗口、模式切换、隐藏/未知鼠标状态、返回和模拟锁屏检查通过。
- 真实通用控制只读查询、镜像通道映射、实际覆盖层绘制，以及空结果/错误/停用后的清除检查通过。用户往返移动鼠标时，本机采样观察到可见状态隐藏/恢复。
- Intel 本机已安装 1.4.0 并选中 `pointerScreen`，旧应用与偏好仅在该机器的忽略目录中保留，不在 GitHub。
- 用户已在安装新版后实际通过通用控制移出、移回本机，确认本机边缘能够正确隐藏和恢复。另一台 Mac 尚未升级，因此仍不能称为两个新版应用均已验收。
- 最终界面整理后的 Apple 芯片版本由目标 Mac 接续构建与运行验收。此前核心功能的 arm64 交叉编译不代表这一最终版本在 Apple 芯片机器上运行通过。
- 既有锁屏功能曾获用户真实锁屏确认；本次新增鼠标筛选的锁屏行为目前只完成模拟检查。两台新版应用的实际往返切换仍需一起验收，不要把单端成功写成双端完成。

## 在 Apple 芯片 Mac 上构建

先检查本机架构、系统与编译器：

```sh
uname -m
sw_vers
xcode-select -p
xcrun swiftc --version
```

应在原生 arm64 终端中执行。缺少 Command Line Tools 时先按系统提供的正常安装流程处理。不要把 Intel 机器 `.build` 下的模块缓存、SDK 覆盖文件或构建辅助脚本复制到这台机器。

没有本地仓库时，可在用户正常工作目录中克隆；下面以桌面为例，已有同名目录时先检查，避免覆盖：

```sh
cd ~/Desktop
git clone https://github.com/vincilawyer/ScreenEdge.git
cd ScreenEdge
git fetch origin
git switch --track origin/codex/pointer-screen-20260912
./scripts/test.sh
SCREENEDGE_ARCH=arm64 ./scripts/build.sh
lipo -archs "build/跨屏边缘.app/Contents/MacOS/ScreenEdge"
codesign --verify --strict "build/跨屏边缘.app"
```

若任务分支已经删除，先确认合并记录及 `main` 中存在 `Sources/PointerState.swift`、`Sources/OverlayVisibility.swift` 和设置中的三种模式，再从最新 `main` 构建。已有仓库时先检查 `git status`；不覆盖未提交修改，需改代码时另建任务分支和 worktree。

正常结果：120 项检查通过、应用包含 arm64、签名验证成功，Info.plist 显示 1.4.0 / 5。输出为 `build/跨屏边缘.app`。如需本地 ZIP，可执行 `SCREENEDGE_ARCH=arm64 ./scripts/package.sh`；上传 Release 是单独的发布工作，不要自动替换现有 v1.3.0 附件。

## 安装与启用

1. 先备份该 Mac 已安装的“跨屏边缘.app”和 `local.screenedge.app` 偏好域；备份留在本机，不提交。不要使用 Intel Mac 的个人配置替换这台 Mac 的配置。
2. 正常退出旧应用，确认其进程退出后再用新构建替换 `/Applications/跨屏边缘.app`。对新文件再次运行签名检查；替换失败时恢复原应用。
3. 打开新应用：`open -a "/Applications/跨屏边缘.app" --args --settings`。
4. 在“边缘显示”页的“显示模式”选择“仅鼠标所在屏幕显示”；菜单栏中也有对应子菜单。两台 Mac 都要选中这个模式。原有常显/靠近模式会按旧偏好迁移，升级不会擅自替用户全局切换模式。
5. 确认原线条粗细、手动标记、通用控制开关和登录项保持原值。本次操作不要顺带修改 BetterDisplay、显示器排列或 macOS 通用控制设置。

## 验收顺序

在已登录的图形会话中运行：

```sh
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --smoke-test
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --uc-check
```

这些检查使用临时配置，不写入用户设置。`--uc-check` 没有实际通道时返回 `INCONCLUSIVE` / 退出码 2；它不是通道显示成功。受限执行环境无法连接 WindowServer 时，应使用正常图形会话重试，不修改系统安全设置。

接着实际验证：

- 同一 Mac 多块扩展屏：鼠标在屏幕中央时仅该屏幕的已有通道显示；移到另一屏后两边正确切换，静止不超时隐藏。
- 通用控制：鼠标由 A 移到 B 后 A 隐藏、B 显示；返回后反过来。分别检查两台机器的实际边缘，不只看系统坐标或日志。
- 系统或应用隐藏光标（例如打字）时，本模式也暂时隐藏提示线；再次移动鼠标后恢复。这是当前实现的明确边界，不能把“光标不可见”日志直接称为“已确认另一台设备获得控制”。
- 保留原有锁屏设置，经过用户实际锁屏验证：仍只显示鼠标所在屏幕；解锁恢复，关闭锁屏显示后全部移除。不支持重启首次登录或 FileVault 预启动画面。
- 切回另两种模式应恢复原行为；停止自动通用控制后移除自动通道；设置中的示例预览仍可在所有本机屏幕显示。

发现问题时记录本机系统版本、架构、所选模式、光标是否可见及匿名化屏幕布局。不要提交真实屏幕 UUID、用户偏好、进程转储或截图中的私人内容。修复后复跑受影响检查，并明确区分本机验证、交叉编译和双端验收。

## 设置界面维护

设置使用固定侧栏分成“边缘显示、屏幕与通道、手动标记、锁屏与启动”四页。默认 820 × 720，最小内容区域 760 × 610；正文可以滚动，侧栏、主开关和页脚固定。三种模式直接选择，滑块旁显示即时线条示例；版本号从应用 Info.plist 读取。不要把所有开关和长说明重新堆回一个页面。

修改界面后可输出本进程设置视图的本机 PNG，用于检查实际渲染、最小窗口和深色模式：

```sh
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --settings-snapshots "$PWD/.build/settings-snapshots"
```

命令使用临时配置和示意通道，不采集桌面、不需要屏幕录制权限、不写入用户偏好。需要正常图形会话；生成的图片仍可能显示本机屏幕名称，仅保留本机，不上传仓库。逐张检查文字裁切、控件对齐、滚动和选中状态，不能只把命令成功当作视觉验收。

## 代码入口

| 文件 | 作用 |
| --- | --- |
| `Sources/OverlayVisibility.swift` | 三种模式、屏幕归属与锁屏优先级的纯逻辑 |
| `Sources/PointerState.swift` | 只读鼠标坐标/可见性，动态加载已弃用接口 |
| `Sources/Overlay.swift` | 约 80 毫秒更新透明度、窗口生命周期与锁屏层 |
| `Sources/Preferences.swift` | 模式保存、旧 `nearOnly` 迁移和降级兼容字段 |
| `Sources/SettingsView.swift`、`Sources/SettingsPages.swift` | 设置侧栏、四个页面、模式选择与分组卡片 |
| `Sources/App.swift`、`Sources/SettingsSnapshots.swift` | 菜单栏、原生检查与设置视图渲染工具 |
| `Sources/Model.swift`、`Sources/UCBridge.m` | 屏幕快照、镜像成员归属、基本只读通用控制查询 |
| `Sources/ScreenLock.swift` | 锁屏状态和应用专用临时覆盖层 |
| `Tests/GeometryTests.swift` | 无真实设备标识的逻辑与配置检查 |

只改本次问题相关代码；中文提交。先本机验证，再提交到任务分支供审查。已经合并的临时修复分支可以删除，提交历史仍由 `main` 和 PR 记录保留。

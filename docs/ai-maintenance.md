# AI 维护与 Apple 芯片 Mac 接续说明

## 接续当前任务

用户需要自选两类边缘的渐变、纯色和透明度，并整理成原生 macOS 风格界面；最新要求将粗细统一放到“边缘样式”页，并移除毛玻璃选项。旧毛玻璃配色迁移为同颜色和透明度的纯色；此前已新增“仅鼠标所在屏幕显示”：鼠标在哪块屏幕，就只显示该屏幕已有的通道；通过通用控制离开本机时，本机隐藏提示线。两台 Mac 各自运行新版并选择此模式。用户已要求在另一台 Apple 芯片 Mac 上由当地的 GPT 执行构建与安装。

- 仓库：`https://github.com/vincilawyer/ScreenEdge`。
- 交付分支：`main`。从最新 `main` 获取下面的功能与界面更新，不要只下载旧 Release；已经合并的临时任务分支会清理。
- 源码版本为 **1.5.0，构建号 7**；现有 **v1.3.0 Release 不包含新模式和外观编辑**。
- 先读取根目录 `AGENTS.md`，再读本文件、`docs/pointer-screen.md`、`docs/appearance.md` 和 `docs/lock-screen.md`。保留当前机器自己的显示器排列、通用控制配置和应用偏好。
- 本次仅提供原生 AppKit/SwiftUI 覆盖层，不增加键鼠共享服务、网络配对、输入拦截或显示器管理。

## 当前已验证与待验证

- Intel / macOS 15.7.9：138 项几何与配置检查通过；原生窗口、模式切换、隐藏/未知鼠标状态、返回和模拟锁屏检查通过。
- 此前 1.4.0 的真实通用控制只读查询、镜像通道映射、实际覆盖层绘制，以及空结果/错误/停用后的清除检查通过。用户往返移动鼠标时，本机采样观察到可见状态隐藏/恢复。
- Intel 本机已安装 1.5.0 并选中 `pointerScreen`，旧应用与偏好仅在该机器的忽略目录中保留，不在 GitHub。
- 用户已在安装 1.4.0 后实际通过通用控制移出、移回本机，确认本机边缘能够正确隐藏和恢复。另一台 Mac 尚未升级，因此仍不能称为两个新版应用均已验收。
- 最终界面整理后的 Apple 芯片版本由目标 Mac 接续构建与运行验收。此前核心功能的 arm64 交叉编译不代表这一最终版本在 Apple 芯片机器上运行通过。
- 新增外观的原生检查包括：所有渐变和自定义双色的方向/长度采样、纯色像素、透明度、配色切换和旧毛玻璃迁移。16 张设置视图覆盖两种配色方式、浅色、深色、最小窗口及滚动。
- 1.5.0 本轮系统未返回活动通用控制通道，`--uc-check` 为 INCONCLUSIVE / 2；本轮新增合成通道验证两种配色路由与鼠标移出/返回后的不透明度保留。先前真实通道验证不等于本轮新材质的真实连接验收。
- 既有锁屏功能曾获用户真实锁屏确认；本次新增鼠标筛选和材质的锁屏行为目前只完成模拟检查。两台新版应用的实际往返切换仍需一起验收，不要把单端成功写成双端完成。

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
git switch main
git pull --ff-only origin main
./scripts/test.sh
SCREENEDGE_ARCH=arm64 ./scripts/build.sh
lipo -archs "build/跨屏边缘.app/Contents/MacOS/ScreenEdge"
codesign --verify --strict "build/跨屏边缘.app"
```

构建前确认最新 `main` 中存在 `Sources/PointerState.swift`、`Sources/OverlayVisibility.swift`、`Sources/EdgeAppearance.swift`、`Sources/StyleSettings.swift` 和设置中的三种模式及“边缘样式”页。已有仓库时先检查 `git status`，再切换并快进更新 `main`；不覆盖未提交修改。需要改代码时默认直接在 `main` 上修改、检查并提交，只有用户明确要求在分支上进行时才创建任务分支或配套 worktree。

正常结果：138 项检查通过、应用包含 arm64、签名验证成功，Info.plist 显示 1.5.0 / 7。输出为 `build/跨屏边缘.app`。如需本地 ZIP，可执行 `SCREENEDGE_ARCH=arm64 ./scripts/package.sh`；上传 Release 是单独的发布工作，不要自动替换现有 v1.3.0 附件。

## 安装与启用

1. 先备份该 Mac 已安装的“跨屏边缘.app”和 `local.screenedge.app` 偏好域；备份留在本机，不提交。不要使用 Intel Mac 的个人配置替换这台 Mac 的配置。
2. 正常退出旧应用，确认其进程退出后再用新构建替换 `/Applications/跨屏边缘.app`。对新文件再次运行签名检查；替换失败时恢复原应用。
3. 打开新应用：`open -a "/Applications/跨屏边缘.app" --args --settings`。
4. 在“边缘显示”页的“显示模式”选择“仅鼠标所在屏幕显示”；菜单栏中也有对应子菜单。两台 Mac 都要选中这个模式。原有常显/靠近模式会按旧偏好迁移，升级不会擅自替用户全局切换模式。
5. 在“边缘样式”中分别选择扩展屏、通用控制卡片；两端颜色各自保存，不自动同步。旧渐变和纯色保持原值，已移除的毛玻璃自动迁移为同色纯色。粗细在此页与配色、透明度一起调整，两类通道共用。不要照搬 Intel Mac 的个人颜色选择。
6. 确认原线条粗细、手动标记、通用控制开关和登录项保持原值。本次操作不要顺带修改 BetterDisplay、显示器排列或 macOS 通用控制设置。

## 验收顺序

在已登录的图形会话中运行：

```sh
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --smoke-test
"build/跨屏边缘.app/Contents/MacOS/ScreenEdge" --uc-check
```

这些检查使用临时配置，不写入用户设置。`--uc-check` 没有实际通道时返回 `INCONCLUSIVE` / 退出码 2；它不是通道显示成功。受限执行环境无法连接 WindowServer 时，应使用正常图形会话重试，不修改系统安全设置。

接着实际验证：

- 外观：分别改变两类通道的材质和颜色，确认立即生效且互不影响；自定义双色、透明度、重启保存、恢复默认均检查。用“在屏幕上预览”检查左侧扩展屏和右侧通用控制样式；关闭预览后仅保留真实通道。仅保留渐变和纯色，不再提供或绘制毛玻璃。
- 同一 Mac 多块扩展屏：鼠标在屏幕中央时仅该屏幕的已有通道显示；移到另一屏后两边正确切换，静止不超时隐藏。
- 通用控制：鼠标由 A 移到 B 后 A 隐藏、B 显示；返回后反过来。分别检查两台机器的实际边缘，不只看系统坐标或日志。
- 系统或应用隐藏光标（例如打字）时，本模式也暂时隐藏提示线；再次移动鼠标后恢复。这是当前实现的明确边界，不能把“光标不可见”日志直接称为“已确认另一台设备获得控制”。
- 保留原有锁屏设置，经过用户实际锁屏验证：仍只显示鼠标所在屏幕；解锁恢复，关闭锁屏显示后全部移除。不支持重启首次登录或 FileVault 预启动画面。
- 切回另两种模式应恢复原行为；停止自动通用控制后移除自动通道；设置中的示例预览仍可在所有本机屏幕显示。

发现问题时记录本机系统版本、架构、所选模式、光标是否可见及匿名化屏幕布局。不要提交真实屏幕 UUID、用户偏好、进程转储或截图中的私人内容。修复后复跑受影响检查，并明确区分本机验证、交叉编译和双端验收。

## 设置界面维护

设置使用固定侧栏分成“边缘显示、边缘样式、屏幕与通道、手动标记、锁屏与启动”五页。默认 820 × 720，最小内容区域 760 × 610；正文可以滚动，侧栏、主开关和页脚固定。“边缘显示”页只放显示模式；粗细、配色、不透明度统一放在“边缘样式”页，顶部两类通道预览实时反映粗细；版本号从应用 Info.plist 读取。不要把所有开关和长说明重新堆回一个页面。

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
| `Sources/Preferences.swift`、`Sources/EdgeAppearance.swift` | 独立外观保存、旧颜色/模式迁移、配色与颜色值 |
| `Sources/EdgeStripView.swift`、`Sources/AppearanceChecks.swift` | 统一原生条带绘制、透明度与像素检查 |
| `Sources/SettingsView.swift`、`Sources/SettingsPages.swift`、`Sources/StyleSettings.swift` | 设置侧栏、五个页面、模式选择与分组卡片 |
| `Sources/ColorPickerButton.swift` | 轻量选色按钮，沿用系统颜色面板与颜色通知 |
| `Sources/App.swift`、`Sources/SettingsSnapshots.swift` | 菜单栏、原生检查与设置视图渲染工具 |
| `Sources/Model.swift`、`Sources/UCBridge.m` | 屏幕快照、镜像成员归属、基本只读通用控制查询 |
| `Sources/ScreenLock.swift` | 锁屏状态和应用专用临时覆盖层 |
| `Tests/GeometryTests.swift` | 无真实设备标识的逻辑与配置检查 |

只改本次问题相关代码；中文提交。默认先本机验证，再直接提交到 `main`，通过提交记录追溯和回退，不默认创建分支或 PR。只有用户明确要求使用分支时才另建任务分支；经授权合并完成后清理该临时分支，提交历史与 PR 仍可追溯。

# 登录后锁屏的边缘提示（未发布）

## 行为

“锁屏时显示边缘”控制已登录会话进入系统锁屏后是否继续显示提示线。“锁屏时保持常显”可以覆盖桌面的靠近显示模式；解锁后恢复原设置。两项默认开启，升级保留原有线条粗细、靠近显示和通道开关。

只显示仍有效的通道。通用控制接口返回空结果、错误或关闭自动开关时，继续清除对应提示；锁屏不会冻结、伪造或永久保留旧通道。手动标记仍是手动标记。

## 实现范围

- 观察当前用户的锁屏通知，并每秒核对 `IOConsoleLocked`。不锁屏、不解锁、不读取或注入键鼠；切换到其他用户时移除锁屏层。
- 仅边缘 `EdgePanel` 可设置 `canBecomeVisibleWithoutLogin`。这些窗口始终穿透点击，不取得键盘焦点；设置窗口和预览不会加入锁屏层。
- 锁屏时创建应用独有的临时 SkyLight 空间，使用锁屏通知层的绝对层级 400。接口通过动态符号加载；核实实际层级与窗口所属空间后才显示，不依赖没有可靠返回值的移动操作结果。
- 重建、关闭开关、解锁和退出时，先关闭提示线窗口，再隐藏并销毁应用创建的临时空间。不会修改已有桌面空间、显示器排列、登录项、认证方式或隐私显示配置。
- API 不兼容时不创建替代假通道，解锁后可在设置中看到失败提示。

## 验证记录

Intel / macOS 15.7.9：90 项几何与配置检查通过；原生窗口检查已验证临时空间层级、窗口归属、仅边缘窗口可见、鼠标穿透、常显/靠近选项、关闭与模拟解锁清理。真实通用控制通道的下边缘读取和绘制检查仍通过。

**尚待真实锁屏与解锁验收。** 模拟 `screenLocked` 切换不等于实际锁屏成功。特别需要核对系统锁屏状态、实际提示线可见性，以及锁屏时通用控制是否仍向接口提供活动通道。当前实现不支持重启后的首次登录界面或 FileVault 预启动认证。

## 接口参考

Apple 的 [`canBecomeVisibleWithoutLogin`](https://developer.apple.com/documentation/appkit/nswindow/canbecomevisiblewithoutlogin) 说明窗口的登录界面显示属性，但单独提高普通窗口层级不能据此保证锁屏显示。

系统覆盖层空间的接口研究参考 [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow/blob/main/Sources/SkyLightWindow/SkyLightOperator.swift) 和 [CGSInternal 空间声明](https://github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h)。本项目未增加第三方运行时依赖。SkyLight 层级与会话锁定状态键属于未公开的系统约定，macOS 更新后需要重新验证。

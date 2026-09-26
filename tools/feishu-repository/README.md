# 无限异常飞书恢复工具

本工具沿用指定飞书代码仓库已有的 v1 存储协议；配置只包含《无限异常》，不会将其他游戏作为发布目标。

环境：Python 3.10+、Git、飞书 CLI（以有知识库权限的用户登录）。Windows 默认检测 `%APPDATA%/npm/node_modules/@larksuite/cli/bin/lark-cli.exe`，也可设置 `LARK_CLI_EXE` 为 CLI 可执行文件。

```powershell
python repository.py list --project infinite-anomaly
python repository.py restore --project infinite-anomaly --version latest --output "D:\Recovered-Infinite-Anomaly"
```

恢复到新目录或空目录，工具校验所有文件 SHA-256。完成后使用 Godot 4.7.1 打开 project.godot。

完整范围说明见工程 docs/备份与恢复.md。库中的 Windows 游戏包和原始参考 ZIP 是独立附件，不属于源码恢复清单。缓存默认写入当前用户 LOCALAPPDATA/GameFeishuRepository，可用 --cache 指定其他位置。

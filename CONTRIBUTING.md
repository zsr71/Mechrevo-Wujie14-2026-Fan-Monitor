# 参与项目 / Contributing

[简体中文](#简体中文) · [English](#english)

## 简体中文

感谢你帮助验证机械革命无界 14 系列的固件接口。当前项目的首要原则是：**先证明读取安全，再讨论任何写入实验**。

### 提交兼容性结果

请使用[兼容性报告表单](https://github.com/zsr71/Mechrevo-Wujie14-2026-Fan-Monitor/issues/new?template=compatibility-report.yml)，提供：

- 完整机型、主板型号和 BIOS 版本。
- Windows 版本和程序 Release 版本。
- 两把风扇的 RPM 是否合理，以及性能模式代码是否变化。
- 已脱敏的错误消息或日志片段。

不要提交 Windows 产品密钥、`MSDM.bin`、用户名目录、账号令牌、完整固件转储或原厂软件二进制文件。

### Pull Request 边界

- 读取路径必须有 ACPI/WMI 分析依据，并清楚说明请求字节、返回格式和实机验证范围。
- 监控工作进程不得加入 `SPFM`、`FanControl`、直接 EC 写入或第三方内核驱动。
- 新机型支持必须默认失败关闭，不能将本机 EC 地址直接套用到其他型号。
- 修改 PowerShell 文件后，请先完成语法检查和只读边界检查。
- 任何未来写入实验都必须独立设计、明确标注风险，并且不能直接并入当前只读监视器。

## English

Thank you for helping verify firmware interfaces across the MECHREVO WUJIE 14 family. The project's primary rule is: **prove that reading is safe before discussing any write experiment**.

### Report compatibility results

Use the [compatibility report form](https://github.com/zsr71/Mechrevo-Wujie14-2026-Fan-Monitor/issues/new?template=compatibility-report.yml) and include:

- Exact model, mainboard, and BIOS version.
- Windows version and project Release version.
- Whether both RPM values look reasonable and whether the performance-mode code changes.
- Redacted error messages or log excerpts.

Do not submit Windows product keys, `MSDM.bin`, user-profile paths, account tokens, complete firmware dumps, or vendor software binaries.

### Pull request boundaries

- A read path must be supported by ACPI/WMI analysis and document its request bytes, response format, and hardware-validation scope.
- The monitor worker must not add `SPFM`, `FanControl`, direct EC writes, or third-party kernel drivers.
- New-model support must fail closed by default. Never reuse EC addresses from one model on another without proof.
- Run syntax and read-only boundary checks after changing PowerShell files.
- Any future write experiment must be designed separately, clearly marked as risky, and kept out of the current read-only monitor.

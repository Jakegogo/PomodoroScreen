# RELEASE.md

> Created: 2026-01-09  
> Purpose: Document how to build Release packages (including Universal ARM64 + Intel).

### Release 打包（推荐：同时支持 Apple Silicon + Intel）

在项目根目录执行：

```bash
make universal
```

等价命令：

```bash
./build-universal.sh
```

### 输出产物

- **Universal DMG（发布用）**：`PomodoroScreen-<版本>-Universal.dmg`（在项目根目录）
- **中间产物（build/）**：
  - `build/ARM64_PomodoroScreen.app`
  - `build/Intel_PomodoroScreen.app`
  - `build/Universal/PomodoroScreen.app`

### 验证二进制架构（确认包含 arm64 + x86_64）

```bash
lipo -info build/Universal/PomodoroScreen.app/Contents/MacOS/PomodoroScreen
```

期望输出包含：`are: x86_64 arm64`

### 跳过测试说明

- `build-universal.sh` **默认不运行单元测试**（相当于天然跳过测试）。
- 如果你构建“单一架构 Release/DMG”，可使用 `build.sh` 并显式跳过测试：

```bash
./build.sh release --skip-tests
./build.sh dmg --skip-tests
```

### 常见问题

- **脚本无执行权限**

```bash
chmod +x build.sh build-universal.sh quick-build.sh ci-build.sh
```

- **构建失败（建议先清理）**

```bash
make clean
make universal
```


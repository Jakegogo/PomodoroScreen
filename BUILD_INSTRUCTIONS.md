# PomodoroScreen 构建说明

## 🚀 快速开始

### 构建通用二进制包（推荐）

构建同时支持 ARM64 (Apple Silicon) 和 Intel (x86_64) 架构的通用应用：

```bash
# 使用 Makefile（推荐）
make universal

# 或直接使用脚本
./build-universal.sh
```

### 其他构建选项

```bash
# 查看所有可用命令
make help

# 快速构建 DMG（单一架构）
make quick

# 构建 Release 版本
make release

# 构建 Debug 版本
make debug

# 清理构建环境
make clean

# 显示构建产物信息
make show-build
```

## 📦 构建产物

### 通用构建后的文件结构：

```
PomodoroScreen/
├── PomodoroScreen-1.0-Universal.dmg    # 通用 DMG 安装包 (~49MB)
├── build/
│   ├── ARM64_PomodoroScreen.app         # ARM64 版本
│   ├── Intel_PomodoroScreen.app         # Intel 版本
│   └── Universal/
│       └── PomodoroScreen.app           # 通用版本 (~50MB)
```

### 架构验证

验证通用二进制包含的架构：

```bash
lipo -info build/Universal/PomodoroScreen.app/Contents/MacOS/PomodoroScreen
# 输出: Architectures in the fat file: ... are: x86_64 arm64
```

## 🔧 构建要求

- macOS 14.0+
- Xcode 15.0+
- Xcode Command Line Tools

## 📋 构建脚本说明

### build-universal.sh
- **功能**: 构建通用二进制包
- **输出**: ARM64、Intel 和通用版本 + DMG
- **时间**: ~45秒
- **推荐**: 用于发布版本

### build.sh
- **功能**: 标准构建流程
- **输出**: 单一架构版本
- **时间**: ~20秒
- **推荐**: 用于开发调试

### quick-build.sh
- **功能**: 快速构建 DMG
- **输出**: 当前架构的 DMG
- **时间**: ~15秒
- **推荐**: 用于快速测试

## 🎯 使用建议

1. **开发阶段**: 使用 `make debug` 或 `make quick`
2. **测试阶段**: 使用 `make release`
3. **发布阶段**: 使用 `make universal`

## 📊 性能对比

| 构建类型 | 时间 | 大小 | 兼容性 |
|---------|------|------|--------|
| Debug | ~15s | ~45MB | 当前架构 |
| Release | ~20s | ~25MB | 当前架构 |
| Universal | ~45s | ~50MB | ARM64 + Intel |

## 🔍 故障排除

### 常见问题

1. **构建失败**: 运行 `make clean` 清理环境
2. **权限错误**: 确保脚本有执行权限 `chmod +x *.sh`
3. **Xcode 错误**: 确保安装了最新版本的 Xcode

### 调试命令

```bash
# 检查项目状态
make stats

# 验证构建环境
xcodebuild -version

# 清理所有构建产物
make clean-all
```

---

**注意**: 通用构建会生成较大的应用包，但确保在所有 Mac 设备上的兼容性。根据发布需求选择合适的构建方式。

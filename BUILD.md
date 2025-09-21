# PomodoroScreen 构建指南

本文档介绍如何使用提供的构建脚本来编译和打包 PomodoroScreen 应用。

## 📋 构建脚本概览

项目提供了三个构建脚本，适用于不同的使用场景：

### 1. `build.sh` - 完整构建脚本 🔧
功能最全面的构建脚本，支持多种构建选项和配置。

**特性：**
- 支持 Debug 和 Release 构建
- 自动运行单元测试
- 创建 Archive 和 DMG 安装包
- 详细的构建日志和错误处理
- 灵活的命令行参数

### 2. `quick-build.sh` - 快速构建脚本 ⚡
用于快速创建 Release 版本和 DMG 安装包的简化脚本。

**特性：**
- 快速构建 Release 版本
- 自动创建 DMG 安装包
- 最小化输出，专注于结果

### 3. `ci-build.sh` - 持续集成脚本 🤖
专为持续集成环境设计的自动化构建脚本。

**特性：**
- 环境检查和验证
- 自动化测试执行
- 构建报告生成
- 错误处理和日志记录

## 🚀 使用方法

### 快速开始

如果你只想快速构建一个可安装的 DMG 包：

```bash
./quick-build.sh
```

### 完整构建流程

使用完整的构建脚本进行详细的构建过程：

```bash
# 完整构建（包括测试、Debug、Release 和 DMG）
./build.sh

# 或者明确指定完整构建
./build.sh all
```

### 特定构建任务

```bash
# 仅清理构建环境
./build.sh clean

# 仅运行单元测试
./build.sh test

# 仅构建 Debug 版本
./build.sh debug

# 仅构建 Release 版本
./build.sh release

# 创建 Archive
./build.sh archive

# 仅创建 DMG 安装包
./build.sh dmg
```

### 跳过特定步骤

```bash
# 跳过单元测试的完整构建
./build.sh all --skip-tests

# 跳过清理步骤的构建
./build.sh all --skip-clean

# 构建 Release 版本但跳过测试
./build.sh release --skip-tests
```

### 持续集成构建

在 CI 环境中使用：

```bash
./ci-build.sh
```

## 📁 构建输出

构建完成后，你会在以下位置找到构建产物：

### 使用 `build.sh`：
```
build/
├── Debug-PomodoroScreen.app          # Debug 版本应用
├── Release-PomodoroScreen.app        # Release 版本应用
├── PomodoroScreen-[版本].dmg         # DMG 安装包
├── archives/                         # Archive 文件
├── export/                          # 导出的应用
└── TestResults.xcresult             # 测试结果
```

### 使用 `quick-build.sh`：
```
PomodoroScreen-[版本].dmg            # DMG 安装包（项目根目录）
```

### 使用 `ci-build.sh`：
```
build/
├── TestResults-[时间戳].xcresult     # 测试结果
└── ci-report-[时间戳].txt           # 构建报告
```

## 🔧 系统要求

### 必需工具：
- **Xcode** (推荐最新版本)
- **Xcode Command Line Tools**
- **macOS** 14.0 或更高版本

### 验证环境：
```bash
# 检查 Xcode 是否安装
xcodebuild -version

# 检查 Command Line Tools
xcode-select --print-path
```

## 🐛 故障排除

### 常见问题：

#### 1. 权限错误
```bash
# 确保脚本有执行权限
chmod +x build.sh quick-build.sh ci-build.sh
```

#### 2. 构建失败
```bash
# 清理构建环境后重试
./build.sh clean
./build.sh all
```

#### 3. 测试失败
```bash
# 跳过测试进行构建
./build.sh all --skip-tests
```

#### 4. DMG 创建失败
```bash
# 检查是否有足够的磁盘空间
df -h

# 手动清理临时文件
rm -rf build/
```

### 调试模式

如果需要查看详细的构建过程，可以启用调试模式：

```bash
# 启用详细输出
set -x
./build.sh all
set +x
```

## 📊 性能优化

### 加速构建：

1. **使用 SSD 存储**：确保项目在 SSD 上
2. **增加内存**：关闭不必要的应用释放内存
3. **并行构建**：Xcode 会自动使用多核心
4. **跳过测试**：开发阶段可以使用 `--skip-tests`

### 构建时间参考：
- **快速构建**：1-3 分钟
- **完整构建**：3-8 分钟（包括测试）
- **仅测试**：1-2 分钟

## 🔄 自动化集成

### GitHub Actions 示例：

```yaml
name: Build PomodoroScreen
on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - name: Build and Test
      run: ./ci-build.sh
```

### 本地自动化：

可以设置 Git hooks 来自动运行构建：

```bash
# 在 .git/hooks/pre-commit 中添加
#!/bin/bash
./ci-build.sh
```

## 📞 支持

如果在构建过程中遇到问题：

1. 检查系统要求是否满足
2. 查看构建日志中的错误信息
3. 尝试清理构建环境后重新构建
4. 确保 Xcode 和 Command Line Tools 是最新版本

---

**注意**：首次构建可能需要较长时间，因为需要下载和编译依赖项。后续构建会更快。

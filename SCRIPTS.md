# PomodoroScreen 构建脚本集合

本项目提供了一套完整的构建和版本管理脚本，帮助开发者高效地构建、测试和发布应用。

## 📁 脚本文件概览

### 🔧 构建脚本

| 脚本文件 | 用途 | 推荐场景 |
|---------|------|----------|
| `build.sh` | 完整构建脚本 | 详细构建、调试、完整测试 |
| `quick-build.sh` | 快速构建脚本 | 快速打包、日常开发 |
| `ci-build.sh` | 持续集成脚本 | 自动化构建、CI/CD |
| `Makefile` | Make构建系统 | 便捷命令、开发工作流 |

### 📋 管理脚本

| 脚本文件 | 用途 | 功能 |
|---------|------|------|
| `version.sh` | 版本管理脚本 | 版本号管理、发布流程 |

### 📖 文档文件

| 文档文件 | 内容 |
|---------|------|
| `BUILD.md` | 详细构建指南 |
| `SCRIPTS.md` | 脚本集合说明（本文档） |

## 🚀 快速开始

### 1. 最简单的构建方式
```bash
# 快速构建DMG安装包
./quick-build.sh
```

### 2. 使用Make命令（推荐）
```bash
# 查看所有可用命令
make help

# 快速构建
make quick

# 开发模式（构建并运行Debug版本）
make dev

# 打包模式（构建并打开DMG）
make package
```

### 3. 完整构建流程
```bash
# 完整构建（包括测试、Debug、Release、DMG）
./build.sh all

# 或使用Make
make all
```

## 📊 脚本功能对比

### 构建功能对比

| 功能 | build.sh | quick-build.sh | ci-build.sh | Makefile |
|------|----------|----------------|-------------|----------|
| Debug构建 | ✅ | ❌ | ✅ | ✅ |
| Release构建 | ✅ | ✅ | ✅ | ✅ |
| 单元测试 | ✅ | ❌ | ✅ | ✅ |
| DMG创建 | ✅ | ✅ | ❌ | ✅ |
| Archive创建 | ✅ | ❌ | ❌ | ❌ |
| 构建报告 | ✅ | ❌ | ✅ | ❌ |
| 错误处理 | ✅ | ✅ | ✅ | ✅ |
| 彩色输出 | ✅ | ✅ | ✅ | ✅ |

### 使用场景建议

#### 🎯 日常开发
```bash
# 开发时快速测试
make dev

# 快速构建安装包
make quick
```

#### 🔍 调试问题
```bash
# 详细构建过程
./build.sh debug --skip-tests

# 仅运行测试
make test
```

#### 📦 发布准备
```bash
# 完整构建和测试
./build.sh all

# 版本管理
./version.sh bump patch
./version.sh release
```

#### 🤖 自动化构建
```bash
# CI环境
./ci-build.sh

# 定时构建
make ci
```

## 🛠️ 高级用法

### 1. 版本管理工作流
```bash
# 查看当前版本
./version.sh show

# 升级补丁版本并发布
./version.sh release patch

# 升级次版本
./version.sh bump minor

# 创建Git标签
./version.sh tag
```

### 2. 自定义构建选项
```bash
# 跳过测试的完整构建
./build.sh all --skip-tests

# 跳过清理的构建
./build.sh release --skip-clean

# 仅清理环境
./build.sh clean
```

### 3. 构建产物管理
```bash
# 查看构建产物
make show-build

# 安装到Applications
make install

# 清理所有产物
make clean-all
```

## 📈 性能优化建议

### 构建速度优化
1. **使用SSD存储**：确保项目在SSD上
2. **增加内存**：关闭不必要的应用
3. **跳过测试**：开发阶段使用`--skip-tests`
4. **使用快速构建**：日常开发使用`quick-build.sh`

### 构建时间参考
- **快速构建** (`quick-build.sh`): 1-3分钟
- **完整构建** (`build.sh all`): 3-8分钟
- **仅测试** (`make test`): 1-2分钟
- **CI构建** (`ci-build.sh`): 2-5分钟

## 🔧 自定义和扩展

### 添加新的构建配置
在`build.sh`中添加新的构建函数：
```bash
build_custom() {
    print_title "🎨 自定义构建"
    # 自定义构建逻辑
}
```

### 集成代码检查工具
安装SwiftLint后，使用：
```bash
make lint
```

### 添加部署脚本
可以扩展`ci-build.sh`添加自动部署功能。

## 🐛 故障排除

### 常见问题

#### 1. 权限错误
```bash
chmod +x *.sh
```

#### 2. 构建失败
```bash
make clean
make quick
```

#### 3. 版本号问题
```bash
./version.sh set 1.0.0 1
```

#### 4. DMG创建失败
检查磁盘空间：
```bash
df -h
```

### 调试模式
启用详细输出：
```bash
set -x
./build.sh all
set +x
```

## 📞 技术支持

如果遇到问题：

1. 查看构建日志中的错误信息
2. 确保满足系统要求（Xcode、Command Line Tools）
3. 尝试清理构建环境后重新构建
4. 检查磁盘空间是否充足

## 🎉 最佳实践

### 开发工作流
```bash
# 1. 开发阶段
make dev

# 2. 测试验证
make test

# 3. 发布准备
./version.sh bump patch
make package

# 4. 正式发布
./version.sh release
```

### 团队协作
- 使用`ci-build.sh`进行持续集成
- 统一使用Make命令简化操作
- 定期运行完整构建验证代码质量

---

**提示**：建议将这些脚本加入版本控制，确保团队成员使用相同的构建流程。

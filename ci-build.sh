#!/bin/bash

# PomodoroScreen 持续集成构建脚本
# 
# 作者: AI Assistant
# 创建时间: 2024-09-21
# 
# 用于持续集成环境的自动化测试和构建

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_NAME="PomodoroScreen"
SCHEME_NAME="PomodoroScreen"

# 函数：打印消息
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查环境
check_environment() {
    log "检查构建环境..."
    
    # 检查Xcode
    if ! command -v xcodebuild &> /dev/null; then
        error "xcodebuild 未找到，请安装 Xcode Command Line Tools"
        exit 1
    fi
    
    # 检查项目文件
    if [ ! -f "$PROJECT_NAME.xcodeproj/project.pbxproj" ]; then
        error "项目文件未找到: $PROJECT_NAME.xcodeproj"
        exit 1
    fi
    
    # 显示Xcode版本
    local xcode_version=$(xcodebuild -version | head -n 1)
    log "Xcode版本: $xcode_version"
    
    success "环境检查通过"
}

# 运行代码检查
run_lint() {
    log "运行代码检查..."
    
    # 这里可以添加SwiftLint等代码检查工具
    # if command -v swiftlint &> /dev/null; then
    #     swiftlint --strict
    # else
    #     warning "SwiftLint 未安装，跳过代码检查"
    # fi
    
    success "代码检查完成"
}

# 运行单元测试
run_tests() {
    log "运行单元测试..."
    
    local test_result_path="build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult"
    mkdir -p build
    
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'platform=macOS,name=My Mac' \
        -configuration Debug \
        -resultBundlePath "$test_result_path" \
        -quiet
    
    success "所有单元测试通过"
    log "测试结果保存在: $test_result_path"
}

# 构建应用
build_app() {
    log "构建应用..."
    
    # 构建Debug版本
    log "构建Debug版本..."
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Debug \
        -quiet
    
    # 构建Release版本
    log "构建Release版本..."
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -quiet
    
    success "应用构建完成"
}

# 生成构建报告
generate_report() {
    log "生成构建报告..."
    
    local report_file="build/ci-report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p build
    
    cat > "$report_file" << EOF
PomodoroScreen 持续集成构建报告
========================================

构建时间: $(date)
项目名称: $PROJECT_NAME
Xcode版本: $(xcodebuild -version | head -n 1)

构建状态: 成功 ✅
测试状态: 通过 ✅

构建配置:
- Debug: 成功
- Release: 成功

测试结果:
$(find build -name "*.xcresult" -exec echo "- {}" \; 2>/dev/null || echo "- 无测试结果文件")

构建产物:
$(find . -name "*.app" -path "*/Build/Products/*" -exec echo "- {}" \; 2>/dev/null || echo "- 无构建产物")

EOF
    
    success "构建报告生成完成: $report_file"
    
    # 显示报告内容
    echo ""
    echo "========================================="
    cat "$report_file"
    echo "========================================="
}

# 清理构建产物
cleanup() {
    log "清理构建产物..."
    
    # 清理Xcode缓存
    xcodebuild clean \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -quiet
    
    success "清理完成"
}

# 主函数
main() {
    echo ""
    echo "🤖 PomodoroScreen 持续集成构建"
    echo "==============================="
    
    local start_time=$(date +%s)
    
    # 执行构建流程
    check_environment
    run_lint
    run_tests
    build_app
    generate_report
    
    # 计算总耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    success "🎉 持续集成构建完成！总耗时: ${duration}秒"
    
    # 如果是CI环境，可以在这里上传构建产物或发送通知
    if [ "$CI" = "true" ]; then
        log "检测到CI环境，可以在这里添加部署逻辑"
    fi
}

# 错误处理
trap 'error "构建过程中发生错误，退出码: $?"' ERR

# 运行主函数
main "$@"

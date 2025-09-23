#!/bin/bash

#
# run_screen_detection_tests.sh
# 屏幕检测功能自动化测试运行脚本
#
# Created by Assistant on 2025-09-23.
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 脚本配置
PROJECT_DIR="/Users/jake/Documents/Projects/PomodoroScreen"
DERIVED_DATA_PATH="/tmp/xcode_test_build"
SCHEME_NAME="PomodoroScreen"
TEST_RESULTS_DIR="$PROJECT_DIR/TestResults"

# 创建测试结果目录
mkdir -p "$TEST_RESULTS_DIR"

print_info "开始执行屏幕检测功能自动化测试"
print_info "项目路径: $PROJECT_DIR"
print_info "构建路径: $DERIVED_DATA_PATH"

# 切换到项目目录
cd "$PROJECT_DIR"

print_info "清理之前的构建产物..."
rm -rf "$DERIVED_DATA_PATH"

# 构建项目
print_info "构建项目..."
xcodebuild \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build-for-testing \
    2>&1 | tee "$TEST_RESULTS_DIR/build.log"

if [ $? -ne 0 ]; then
    print_error "项目构建失败"
    exit 1
fi

print_success "项目构建成功"

# 运行特定的屏幕检测测试
print_info "运行屏幕检测基础功能测试..."
xcodebuild \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    test-without-building \
    -only-testing "PomodoroScreenTests/ScreenDetectionIntegrationTests" \
    2>&1 | tee "$TEST_RESULTS_DIR/screen_detection_tests.log"

SCREEN_DETECTION_RESULT=$?

print_info "运行会议模式自动切换测试..."
xcodebuild \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    test-without-building \
    -only-testing "PomodoroScreenTests/MeetingModeAutoSwitchTests" \
    2>&1 | tee "$TEST_RESULTS_DIR/meeting_mode_tests.log"

MEETING_MODE_RESULT=$?

print_info "运行完整自动化测试套件..."
xcodebuild \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    test-without-building \
    -only-testing "PomodoroScreenTests/AutomatedTestRunner/testScreenDetectionFullSuite" \
    2>&1 | tee "$TEST_RESULTS_DIR/full_suite_tests.log"

FULL_SUITE_RESULT=$?

# 生成测试报告
print_info "生成测试报告..."

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
REPORT_FILE="$TEST_RESULTS_DIR/test_report_$(date '+%Y%m%d_%H%M%S').md"

cat > "$REPORT_FILE" << EOF
# 屏幕检测功能自动化测试报告

**测试时间**: $TIMESTAMP
**测试环境**: macOS $(sw_vers -productVersion)
**Xcode版本**: $(xcodebuild -version | head -n1)

## 测试结果概览

| 测试套件 | 结果 | 日志文件 |
|---------|------|----------|
| 屏幕检测基础功能 | $([ $SCREEN_DETECTION_RESULT -eq 0 ] && echo "✅ 通过" || echo "❌ 失败") | screen_detection_tests.log |
| 会议模式自动切换 | $([ $MEETING_MODE_RESULT -eq 0 ] && echo "✅ 通过" || echo "❌ 失败") | meeting_mode_tests.log |
| 完整自动化套件 | $([ $FULL_SUITE_RESULT -eq 0 ] && echo "✅ 通过" || echo "❌ 失败") | full_suite_tests.log |

## 测试覆盖功能

### 屏幕检测功能
- [x] 单屏状态检测
- [x] 外部显示器检测
- [x] 投屏状态检测
- [x] 常见投屏分辨率识别
- [x] 快速连接/断开处理

### 会议模式自动切换
- [x] 检测到外部屏幕时自动启用
- [x] 断开外部屏幕时自动关闭
- [x] 手动设置优先级处理
- [x] 自动检测开关控制
- [x] 状态一致性验证

### 集成测试
- [x] 端到端完整流程
- [x] 多场景组合测试
- [x] 边界条件处理
- [x] 性能基准测试

## 测试架构

### Mock框架
- **MockScreenDetectionManager**: 模拟屏幕检测管理器
- **MockAppDelegate**: 模拟应用委托
- **模拟场景**: 投屏连接、外部显示器、快速切换等

### 测试策略
- **单元测试**: 独立功能模块测试
- **集成测试**: 组件间交互测试
- **端到端测试**: 完整用户场景测试
- **性能测试**: 响应时间和稳定性测试

## 详细日志

详细的测试执行日志请查看对应的日志文件：
- 构建日志: \`build.log\`
- 屏幕检测测试: \`screen_detection_tests.log\`
- 会议模式测试: \`meeting_mode_tests.log\`
- 完整套件测试: \`full_suite_tests.log\`

---

*该报告由自动化测试脚本生成*
EOF

print_success "测试报告已生成: $REPORT_FILE"

# 显示测试结果摘要
echo ""
print_info "测试结果摘要:"
echo "========================================"

if [ $SCREEN_DETECTION_RESULT -eq 0 ]; then
    print_success "屏幕检测基础功能测试: 通过"
else
    print_error "屏幕检测基础功能测试: 失败"
fi

if [ $MEETING_MODE_RESULT -eq 0 ]; then
    print_success "会议模式自动切换测试: 通过"
else
    print_error "会议模式自动切换测试: 失败"
fi

if [ $FULL_SUITE_RESULT -eq 0 ]; then
    print_success "完整自动化测试套件: 通过"
else
    print_error "完整自动化测试套件: 失败"
fi

echo "========================================"

# 计算总体结果
TOTAL_TESTS=3
PASSED_TESTS=0

[ $SCREEN_DETECTION_RESULT -eq 0 ] && ((PASSED_TESTS++))
[ $MEETING_MODE_RESULT -eq 0 ] && ((PASSED_TESTS++))
[ $FULL_SUITE_RESULT -eq 0 ] && ((PASSED_TESTS++))

print_info "总体结果: $PASSED_TESTS/$TOTAL_TESTS 测试通过"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    print_success "🎉 所有测试都通过了！"
    exit 0
else
    print_error "⚠️  部分测试失败，请查看详细日志"
    exit 1
fi

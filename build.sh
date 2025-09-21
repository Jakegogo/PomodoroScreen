#!/bin/bash

# PomodoroScreen 构建脚本
# 
# 作者: AI Assistant
# 创建时间: 2024-09-21
# 
# 功能：
# - 清理构建缓存
# - 编译应用
# - 运行单元测试
# - 创建发布版本
# - 打包DMG安装包

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="PomodoroScreen"
SCHEME_NAME="PomodoroScreen"
WORKSPACE_PATH="."
BUILD_DIR="build"
ARCHIVE_DIR="$BUILD_DIR/archives"
EXPORT_DIR="$BUILD_DIR/export"
DMG_DIR="$BUILD_DIR/dmg"
APP_NAME="PomodoroScreen.app"

# 版本信息
VERSION=$(defaults read "$PWD/PomodoroScreen/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
BUILD_NUMBER=$(defaults read "$PWD/PomodoroScreen/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

# 函数：打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 函数：打印标题
print_title() {
    echo ""
    print_message $CYAN "============================================"
    print_message $CYAN "$1"
    print_message $CYAN "============================================"
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_message $RED "错误: $1 命令未找到，请确保已安装 Xcode Command Line Tools"
        exit 1
    fi
}

# 函数：清理构建目录
clean_build() {
    print_title "🧹 清理构建环境"
    
    print_message $YELLOW "清理 Xcode 构建缓存..."
    xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration Release
    
    print_message $YELLOW "清理本地构建目录..."
    rm -rf "$BUILD_DIR"
    rm -rf DerivedData
    
    print_message $GREEN "✅ 构建环境清理完成"
}

# 函数：创建构建目录
create_directories() {
    print_title "📁 创建构建目录"
    
    mkdir -p "$BUILD_DIR"
    mkdir -p "$ARCHIVE_DIR"
    mkdir -p "$EXPORT_DIR"
    mkdir -p "$DMG_DIR"
    
    print_message $GREEN "✅ 构建目录创建完成"
}

# 函数：运行单元测试
run_tests() {
    print_title "🧪 运行单元测试"
    
    print_message $YELLOW "运行所有单元测试..."
    xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'platform=macOS,name=My Mac' \
        -configuration Debug \
        -resultBundlePath "$BUILD_DIR/TestResults.xcresult"
    
    print_message $GREEN "✅ 所有测试通过"
}

# 函数：构建Debug版本
build_debug() {
    print_title "🔨 构建 Debug 版本"
    
    print_message $YELLOW "构建 Debug 配置..."
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Debug \
        -derivedDataPath "$BUILD_DIR/DerivedData"
    
    # 复制Debug版本到构建目录
    cp -R "$BUILD_DIR/DerivedData/Build/Products/Debug/$APP_NAME" "$BUILD_DIR/Debug-$APP_NAME"
    
    print_message $GREEN "✅ Debug 版本构建完成: $BUILD_DIR/Debug-$APP_NAME"
}

# 函数：构建Release版本
build_release() {
    print_title "🚀 构建 Release 版本"
    
    print_message $YELLOW "构建 Release 配置..."
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData"
    
    # 复制Release版本到构建目录
    cp -R "$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME" "$BUILD_DIR/Release-$APP_NAME"
    
    print_message $GREEN "✅ Release 版本构建完成: $BUILD_DIR/Release-$APP_NAME"
}

# 函数：创建Archive
create_archive() {
    print_title "📦 创建 Archive"
    
    local archive_path="$ARCHIVE_DIR/$PROJECT_NAME-$VERSION-$BUILD_NUMBER.xcarchive"
    
    print_message $YELLOW "创建 Archive..."
    xcodebuild archive \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$archive_path" \
        -derivedDataPath "$BUILD_DIR/DerivedData"
    
    print_message $GREEN "✅ Archive 创建完成: $archive_path"
    echo "$archive_path" > "$BUILD_DIR/archive_path.txt"
}

# 函数：导出应用
export_app() {
    print_title "📤 导出应用"
    
    local archive_path=$(cat "$BUILD_DIR/archive_path.txt")
    
    # 创建导出配置文件
    cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
    
    print_message $YELLOW "导出应用..."
    xcodebuild -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"
    
    print_message $GREEN "✅ 应用导出完成: $EXPORT_DIR"
}

# 函数：创建DMG安装包
create_dmg() {
    print_title "💿 创建 DMG 安装包"
    
    local dmg_name="$PROJECT_NAME-$VERSION.dmg"
    local dmg_path="$BUILD_DIR/$dmg_name"
    local temp_dmg_dir="$DMG_DIR/temp"
    
    # 创建临时目录
    mkdir -p "$temp_dmg_dir"
    
    # 复制应用到临时目录
    if [ -d "$EXPORT_DIR/$APP_NAME" ]; then
        cp -R "$EXPORT_DIR/$APP_NAME" "$temp_dmg_dir/"
    else
        cp -R "$BUILD_DIR/Release-$APP_NAME" "$temp_dmg_dir/$APP_NAME"
    fi
    
    # 创建应用程序文件夹的符号链接
    ln -sf /Applications "$temp_dmg_dir/Applications"
    
    # 创建DMG
    print_message $YELLOW "创建 DMG 文件..."
    hdiutil create -volname "$PROJECT_NAME" \
        -srcfolder "$temp_dmg_dir" \
        -ov -format UDZO \
        "$dmg_path"
    
    # 清理临时目录
    rm -rf "$temp_dmg_dir"
    
    print_message $GREEN "✅ DMG 安装包创建完成: $dmg_path"
}

# 函数：显示构建信息
show_build_info() {
    print_title "📋 构建信息"
    
    echo "项目名称: $PROJECT_NAME"
    echo "版本号: $VERSION"
    echo "构建号: $BUILD_NUMBER"
    echo "构建时间: $(date)"
    echo "构建目录: $BUILD_DIR"
    echo ""
    
    if [ -f "$BUILD_DIR/$PROJECT_NAME-$VERSION.dmg" ]; then
        local dmg_size=$(du -h "$BUILD_DIR/$PROJECT_NAME-$VERSION.dmg" | cut -f1)
        print_message $GREEN "📦 DMG 安装包: $BUILD_DIR/$PROJECT_NAME-$VERSION.dmg ($dmg_size)"
    fi
    
    if [ -d "$BUILD_DIR/Release-$APP_NAME" ]; then
        local app_size=$(du -sh "$BUILD_DIR/Release-$APP_NAME" | cut -f1)
        print_message $GREEN "🚀 Release 应用: $BUILD_DIR/Release-$APP_NAME ($app_size)"
    fi
    
    if [ -d "$BUILD_DIR/Debug-$APP_NAME" ]; then
        local debug_size=$(du -sh "$BUILD_DIR/Debug-$APP_NAME" | cut -f1)
        print_message $BLUE "🔨 Debug 应用: $BUILD_DIR/Debug-$APP_NAME ($debug_size)"
    fi
}

# 函数：显示帮助信息
show_help() {
    echo "PomodoroScreen 构建脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  clean          仅清理构建环境"
    echo "  test           仅运行单元测试"
    echo "  debug          构建 Debug 版本"
    echo "  release        构建 Release 版本"
    echo "  archive        创建 Archive"
    echo "  dmg            创建 DMG 安装包"
    echo "  all            执行完整构建流程 (默认)"
    echo "  --skip-tests   跳过单元测试"
    echo "  --skip-clean   跳过清理步骤"
    echo "  -h, --help     显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                    # 完整构建"
    echo "  $0 debug              # 仅构建 Debug 版本"
    echo "  $0 all --skip-tests   # 完整构建但跳过测试"
    echo "  $0 clean              # 仅清理"
}

# 主函数
main() {
    print_title "🍅 PomodoroScreen 构建脚本"
    
    # 检查必要的命令
    check_command "xcodebuild"
    check_command "hdiutil"
    
    # 解析命令行参数
    local action="all"
    local skip_tests=false
    local skip_clean=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            clean|test|debug|release|archive|dmg|all)
                action="$1"
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --skip-clean)
                skip_clean=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_message $RED "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 执行相应的操作
    case $action in
        clean)
            clean_build
            ;;
        test)
            run_tests
            ;;
        debug)
            if [ "$skip_clean" = false ]; then
                clean_build
            fi
            create_directories
            if [ "$skip_tests" = false ]; then
                run_tests
            fi
            build_debug
            ;;
        release)
            if [ "$skip_clean" = false ]; then
                clean_build
            fi
            create_directories
            if [ "$skip_tests" = false ]; then
                run_tests
            fi
            build_release
            ;;
        archive)
            if [ "$skip_clean" = false ]; then
                clean_build
            fi
            create_directories
            if [ "$skip_tests" = false ]; then
                run_tests
            fi
            create_archive
            export_app
            ;;
        dmg)
            if [ "$skip_clean" = false ]; then
                clean_build
            fi
            create_directories
            if [ "$skip_tests" = false ]; then
                run_tests
            fi
            build_release
            create_dmg
            ;;
        all)
            if [ "$skip_clean" = false ]; then
                clean_build
            fi
            create_directories
            if [ "$skip_tests" = false ]; then
                run_tests
            fi
            build_debug
            build_release
            create_dmg
            ;;
    esac
    
    # 计算构建时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 显示构建信息
    show_build_info
    
    print_title "🎉 构建完成"
    print_message $GREEN "总耗时: ${duration}秒"
    
    # 如果创建了DMG，询问是否打开
    if [ -f "$BUILD_DIR/$PROJECT_NAME-$VERSION.dmg" ]; then
        echo ""
        print_message $YELLOW "是否打开构建目录? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            open "$BUILD_DIR"
        fi
    fi
}

# 运行主函数
main "$@"

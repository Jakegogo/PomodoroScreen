#!/bin/bash

# PomodoroScreen 通用构建脚本
# 
# 作者: AI Assistant
# 创建时间: 2024-09-23
# 
# 功能：构建同时支持 ARM64 和 x86_64 架构的通用二进制包

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
BUILD_DIR="build"
UNIVERSAL_DIR="$BUILD_DIR/Universal"
APP_NAME="PomodoroScreen.app"

# 版本信息
VERSION=$(defaults read "$PWD/PomodoroScreen/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

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
    mkdir -p "$UNIVERSAL_DIR"
    
    print_message $GREEN "✅ 构建目录创建完成"
}

# 函数：构建指定架构的版本
build_architecture() {
    local arch=$1
    local arch_name=$2
    
    print_title "🔨 构建 $arch_name 架构版本"
    
    print_message $YELLOW "构建 $arch_name ($arch) 架构..."
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -arch "$arch" \
        -derivedDataPath "$BUILD_DIR/DerivedData_$arch"
    
    # 复制架构版本到构建目录
    local arch_app_path="$BUILD_DIR/${arch_name}_$APP_NAME"
    cp -R "$BUILD_DIR/DerivedData_$arch/Build/Products/Release/$APP_NAME" "$arch_app_path"
    
    print_message $GREEN "✅ $arch_name 架构版本构建完成: $arch_app_path"
    echo "$arch_app_path"
}

# 函数：创建通用二进制
create_universal_binary() {
    print_title "🔄 创建通用二进制"
    
    local arm64_app="$BUILD_DIR/ARM64_$APP_NAME"
    local intel_app="$BUILD_DIR/Intel_$APP_NAME"
    local universal_app="$UNIVERSAL_DIR/$APP_NAME"
    
    print_message $YELLOW "复制 ARM64 版本作为基础..."
    cp -R "$arm64_app" "$universal_app"
    
    print_message $YELLOW "合并二进制文件..."
    local arm64_binary="$arm64_app/Contents/MacOS/$PROJECT_NAME"
    local intel_binary="$intel_app/Contents/MacOS/$PROJECT_NAME"
    local universal_binary="$universal_app/Contents/MacOS/$PROJECT_NAME"
    
    # 使用 lipo 创建通用二进制
    lipo -create "$arm64_binary" "$intel_binary" -output "$universal_binary"
    
    print_message $GREEN "✅ 通用二进制创建完成"
    
    # 验证通用二进制
    print_message $YELLOW "验证通用二进制..."
    lipo -info "$universal_binary"
    
    print_message $GREEN "✅ 通用应用创建完成: $universal_app"
}

# 函数：创建DMG安装包
create_dmg() {
    print_title "💿 创建通用 DMG 安装包"
    
    local dmg_name="$PROJECT_NAME-$VERSION-Universal.dmg"
    local dmg_path="$dmg_name"
    local temp_dmg_dir="$BUILD_DIR/dmg_temp"
    local universal_app="$UNIVERSAL_DIR/$APP_NAME"
    
    # 创建临时目录
    mkdir -p "$temp_dmg_dir"
    
    # 复制通用应用到临时目录
    cp -R "$universal_app" "$temp_dmg_dir/"
    
    # 创建应用程序文件夹的符号链接
    ln -sf /Applications "$temp_dmg_dir/Applications"
    
    # 创建DMG
    print_message $YELLOW "创建通用 DMG 文件..."
    hdiutil create -volname "$PROJECT_NAME Universal" \
        -srcfolder "$temp_dmg_dir" \
        -ov -format UDZO \
        "$dmg_path"
    
    # 清理临时目录
    rm -rf "$temp_dmg_dir"
    
    print_message $GREEN "✅ 通用 DMG 安装包创建完成: $dmg_path"
}

# 函数：显示构建信息
show_build_info() {
    print_title "📋 构建信息"
    
    echo "项目名称: $PROJECT_NAME"
    echo "版本号: $VERSION"
    echo "构建时间: $(date)"
    echo "构建目录: $BUILD_DIR"
    echo ""
    
    local universal_app="$UNIVERSAL_DIR/$APP_NAME"
    local dmg_path="$PROJECT_NAME-$VERSION-Universal.dmg"
    
    if [ -d "$universal_app" ]; then
        local app_size=$(du -sh "$universal_app" | cut -f1)
        print_message $GREEN "🌍 通用应用: $universal_app ($app_size)"
        
        # 显示二进制架构信息
        local binary_path="$universal_app/Contents/MacOS/$PROJECT_NAME"
        if [ -f "$binary_path" ]; then
            print_message $BLUE "🔍 支持的架构:"
            lipo -info "$binary_path" | sed 's/^/    /'
        fi
    fi
    
    if [ -f "$dmg_path" ]; then
        local dmg_size=$(du -h "$dmg_path" | cut -f1)
        print_message $GREEN "📦 通用 DMG: $dmg_path ($dmg_size)"
    fi
}

# 主函数
main() {
    print_title "🍅 PomodoroScreen 通用构建脚本"
    
    # 检查必要的命令
    check_command "xcodebuild"
    check_command "lipo"
    check_command "hdiutil"
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 执行构建流程
    clean_build
    create_directories
    
    # 构建不同架构版本
    build_architecture "arm64" "ARM64"
    build_architecture "x86_64" "Intel"
    
    # 创建通用二进制
    create_universal_binary
    
    # 创建DMG安装包
    create_dmg
    
    # 计算构建时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 显示构建信息
    show_build_info
    
    print_title "🎉 通用构建完成"
    print_message $GREEN "总耗时: ${duration}秒"
    
    # 询问是否打开构建目录
    echo ""
    print_message $YELLOW "是否打开构建目录? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        open "$BUILD_DIR"
    fi
}

# 运行主函数
main "$@"

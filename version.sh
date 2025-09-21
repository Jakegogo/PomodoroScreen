#!/bin/bash

# PomodoroScreen 版本管理脚本
# 
# 作者: AI Assistant
# 创建时间: 2024-09-21
# 
# 用于管理应用版本号和构建号

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目配置
PLIST_PATH="PomodoroScreen/Info.plist"
PROJECT_NAME="PomodoroScreen"

# 函数：打印消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 函数：获取当前版本信息
get_current_version() {
    local version=$(defaults read "$PWD/$PLIST_PATH" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
    local build=$(defaults read "$PWD/$PLIST_PATH" CFBundleVersion 2>/dev/null || echo "1")
    echo "$version|$build"
}

# 函数：设置版本号
set_version() {
    local new_version=$1
    local new_build=${2:-"1"}
    
    if [ -z "$new_version" ]; then
        print_message $RED "错误: 版本号不能为空"
        exit 1
    fi
    
    # 验证版本号格式 (x.y.z)
    if [[ ! $new_version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        print_message $RED "错误: 版本号格式不正确，应为 x.y.z 格式"
        exit 1
    fi
    
    print_message $YELLOW "设置版本号: $new_version"
    print_message $YELLOW "设置构建号: $new_build"
    
    # 更新 Info.plist
    defaults write "$PWD/$PLIST_PATH" CFBundleShortVersionString "$new_version"
    defaults write "$PWD/$PLIST_PATH" CFBundleVersion "$new_build"
    
    print_message $GREEN "✅ 版本信息更新完成"
}

# 函数：增加版本号
bump_version() {
    local bump_type=$1
    local current_info=$(get_current_version)
    local current_version=$(echo "$current_info" | cut -d'|' -f1)
    local current_build=$(echo "$current_info" | cut -d'|' -f2)
    
    # 解析当前版本号
    local major=$(echo "$current_version" | cut -d'.' -f1)
    local minor=$(echo "$current_version" | cut -d'.' -f2)
    local patch=$(echo "$current_version" | cut -d'.' -f3 2>/dev/null || echo "0")
    
    local new_version
    local new_build
    
    case $bump_type in
        major)
            new_version="$((major + 1)).0.0"
            new_build="1"
            ;;
        minor)
            new_version="$major.$((minor + 1)).0"
            new_build="1"
            ;;
        patch)
            new_version="$major.$minor.$((patch + 1))"
            new_build="1"
            ;;
        build)
            new_version="$current_version"
            new_build="$((current_build + 1))"
            ;;
        *)
            print_message $RED "错误: 无效的版本类型。支持: major, minor, patch, build"
            exit 1
            ;;
    esac
    
    print_message $CYAN "版本升级: $current_version ($current_build) -> $new_version ($new_build)"
    set_version "$new_version" "$new_build"
}

# 函数：显示当前版本
show_version() {
    local current_info=$(get_current_version)
    local current_version=$(echo "$current_info" | cut -d'|' -f1)
    local current_build=$(echo "$current_info" | cut -d'|' -f2)
    
    print_message $CYAN "📋 当前版本信息"
    echo "项目名称: $PROJECT_NAME"
    echo "版本号: $current_version"
    echo "构建号: $current_build"
    echo "完整版本: $current_version ($current_build)"
}

# 函数：创建版本标签
create_tag() {
    local current_info=$(get_current_version)
    local current_version=$(echo "$current_info" | cut -d'|' -f1)
    local current_build=$(echo "$current_info" | cut -d'|' -f2)
    
    if [ ! -d ".git" ]; then
        print_message $YELLOW "⚠️  不是Git仓库，跳过标签创建"
        return
    fi
    
    local tag_name="v$current_version"
    local tag_message="Release version $current_version (build $current_build)"
    
    print_message $YELLOW "创建Git标签: $tag_name"
    
    # 检查标签是否已存在
    if git tag -l | grep -q "^$tag_name$"; then
        print_message $YELLOW "⚠️  标签 $tag_name 已存在"
        read -p "是否覆盖现有标签? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git tag -d "$tag_name"
            git tag -a "$tag_name" -m "$tag_message"
            print_message $GREEN "✅ 标签已更新: $tag_name"
        else
            print_message $YELLOW "跳过标签创建"
        fi
    else
        git tag -a "$tag_name" -m "$tag_message"
        print_message $GREEN "✅ 标签已创建: $tag_name"
    fi
}

# 函数：发布版本
release_version() {
    local release_type=${1:-"patch"}
    
    print_message $CYAN "🚀 准备发布新版本"
    
    # 检查工作目录是否干净
    if [ -d ".git" ] && ! git diff --quiet; then
        print_message $YELLOW "⚠️  工作目录有未提交的更改"
        read -p "是否继续? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $YELLOW "发布已取消"
            exit 0
        fi
    fi
    
    # 升级版本
    bump_version "$release_type"
    
    # 构建应用
    print_message $YELLOW "构建发布版本..."
    ./quick-build.sh
    
    # 创建标签
    create_tag
    
    local current_info=$(get_current_version)
    local current_version=$(echo "$current_info" | cut -d'|' -f1)
    
    print_message $GREEN "🎉 版本 $current_version 发布完成！"
    print_message $CYAN "📦 安装包: $PROJECT_NAME-$current_version.dmg"
}

# 函数：显示版本历史
show_history() {
    if [ ! -d ".git" ]; then
        print_message $YELLOW "⚠️  不是Git仓库，无法显示版本历史"
        return
    fi
    
    print_message $CYAN "📚 版本历史"
    git tag -l --sort=-version:refname | head -10 | while read tag; do
        if [ -n "$tag" ]; then
            local date=$(git log -1 --format=%ai "$tag" 2>/dev/null || echo "未知日期")
            local message=$(git tag -l --format='%(contents:subject)' "$tag" 2>/dev/null || echo "无描述")
            echo "  $tag - $date"
            echo "    $message"
        fi
    done
}

# 函数：显示帮助信息
show_help() {
    echo "PomodoroScreen 版本管理脚本"
    echo ""
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  show                   显示当前版本信息"
    echo "  set <version> [build]  设置版本号和构建号"
    echo "  bump <type>            升级版本号"
    echo "    - major              升级主版本号 (x.0.0)"
    echo "    - minor              升级次版本号 (x.y.0)"
    echo "    - patch              升级补丁版本号 (x.y.z)"
    echo "    - build              升级构建号"
    echo "  tag                    为当前版本创建Git标签"
    echo "  release [type]         发布新版本 (默认: patch)"
    echo "  history                显示版本历史"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 show                # 显示当前版本"
    echo "  $0 set 2.1.0           # 设置版本为 2.1.0"
    echo "  $0 bump minor          # 升级次版本号"
    echo "  $0 release major       # 发布新的主版本"
}

# 主函数
main() {
    case ${1:-show} in
        show)
            show_version
            ;;
        set)
            if [ -z "$2" ]; then
                print_message $RED "错误: 请提供版本号"
                show_help
                exit 1
            fi
            set_version "$2" "$3"
            ;;
        bump)
            if [ -z "$2" ]; then
                print_message $RED "错误: 请提供版本类型"
                show_help
                exit 1
            fi
            bump_version "$2"
            ;;
        tag)
            create_tag
            ;;
        release)
            release_version "$2"
            ;;
        history)
            show_history
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_message $RED "错误: 未知命令 '$1'"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"

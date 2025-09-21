#!/bin/bash

# PomodoroScreen 快速构建脚本
# 
# 作者: AI Assistant
# 创建时间: 2024-09-21
# 
# 快速构建Release版本并创建DMG安装包

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_NAME="PomodoroScreen"
VERSION=$(defaults read "$PWD/PomodoroScreen/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

echo -e "${CYAN}🍅 快速构建 PomodoroScreen v$VERSION${NC}"
echo ""

# 1. 清理并构建Release版本
echo -e "${YELLOW}🔨 构建Release版本...${NC}"
xcodebuild clean build \
    -project PomodoroScreen.xcodeproj \
    -scheme PomodoroScreen \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    -quiet

# 2. 创建构建目录
mkdir -p build/dmg-temp

# 3. 复制应用
cp -R build/DerivedData/Build/Products/Release/PomodoroScreen.app build/dmg-temp/

# 4. 创建Applications链接
ln -sf /Applications build/dmg-temp/Applications

# 5. 创建DMG
echo -e "${YELLOW}📦 创建DMG安装包...${NC}"
hdiutil create -volname "PomodoroScreen" \
    -srcfolder build/dmg-temp \
    -ov -format UDZO \
    "PomodoroScreen-$VERSION.dmg" \
    -quiet

# 6. 清理临时文件
rm -rf build

echo -e "${GREEN}✅ 构建完成: PomodoroScreen-$VERSION.dmg${NC}"

# 显示文件大小
if [ -f "PomodoroScreen-$VERSION.dmg" ]; then
    SIZE=$(du -h "PomodoroScreen-$VERSION.dmg" | cut -f1)
    echo -e "${GREEN}📦 安装包大小: $SIZE${NC}"
fi

echo ""
echo -e "${CYAN}🚀 安装包已准备就绪！${NC}"

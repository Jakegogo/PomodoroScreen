# PomodoroScreen Makefile
# 
# 作者: AI Assistant
# 创建时间: 2024-09-21
# 
# 提供便捷的构建命令

.PHONY: help clean test debug release dmg quick ci install run universal

# 默认目标
.DEFAULT_GOAL := help

# 项目配置
PROJECT_NAME := PomodoroScreen
VERSION := $(shell defaults read "$(PWD)/PomodoroScreen/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

# 颜色定义
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## 显示帮助信息
	@echo "$(CYAN)🍅 PomodoroScreen 构建系统$(NC)"
	@echo ""
	@echo "可用命令:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-12s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "项目信息:"
	@echo "  名称: $(PROJECT_NAME)"
	@echo "  版本: $(VERSION)"

clean: ## 清理构建环境
	@echo "$(YELLOW)🧹 清理构建环境...$(NC)"
	@./build.sh clean

test: ## 运行单元测试
	@echo "$(YELLOW)🧪 运行单元测试...$(NC)"
	@./build.sh test

debug: ## 构建Debug版本
	@echo "$(YELLOW)🔨 构建Debug版本...$(NC)"
	@./build.sh debug

release: ## 构建Release版本
	@echo "$(YELLOW)🚀 构建Release版本...$(NC)"
	@./build.sh release

dmg: ## 创建DMG安装包
	@echo "$(YELLOW)📦 创建DMG安装包...$(NC)"
	@./build.sh dmg

quick: ## 快速构建DMG（推荐）
	@echo "$(CYAN)⚡ 快速构建DMG安装包...$(NC)"
	@./quick-build.sh

ci: ## 持续集成构建
	@echo "$(YELLOW)🤖 持续集成构建...$(NC)"
	@./ci-build.sh

universal: ## 构建通用二进制（ARM64 + Intel）
	@echo "$(CYAN)🌍 构建通用二进制包...$(NC)"
	@./build-universal.sh

all: ## 完整构建流程
	@echo "$(YELLOW)🔄 执行完整构建流程...$(NC)"
	@./build.sh all

install: ## 安装构建的应用到Applications文件夹
	@echo "$(YELLOW)📲 安装应用到Applications文件夹...$(NC)"
	@if [ -d "build/Release-$(PROJECT_NAME).app" ]; then \
		cp -R "build/Release-$(PROJECT_NAME).app" "/Applications/"; \
		echo "$(GREEN)✅ 应用已安装到 /Applications/$(PROJECT_NAME).app$(NC)"; \
	elif [ -d "build/DerivedData/Build/Products/Release/$(PROJECT_NAME).app" ]; then \
		cp -R "build/DerivedData/Build/Products/Release/$(PROJECT_NAME).app" "/Applications/"; \
		echo "$(GREEN)✅ 应用已安装到 /Applications/$(PROJECT_NAME).app$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  未找到构建的应用，请先运行 make release$(NC)"; \
	fi

run: ## 运行Debug版本的应用
	@echo "$(YELLOW)🏃 运行Debug版本...$(NC)"
	@if [ -d "build/Debug-$(PROJECT_NAME).app" ]; then \
		open "build/Debug-$(PROJECT_NAME).app"; \
	elif [ -d "build/DerivedData/Build/Products/Debug/$(PROJECT_NAME).app" ]; then \
		open "build/DerivedData/Build/Products/Debug/$(PROJECT_NAME).app"; \
	else \
		echo "$(YELLOW)⚠️  未找到Debug版本，正在构建...$(NC)"; \
		make debug && make run; \
	fi

open-dmg: ## 打开最新的DMG文件
	@echo "$(YELLOW)📂 打开DMG文件...$(NC)"
	@DMG_FILE=$$(ls -t *.dmg 2>/dev/null | head -n1); \
	if [ -n "$$DMG_FILE" ]; then \
		open "$$DMG_FILE"; \
		echo "$(GREEN)✅ 已打开: $$DMG_FILE$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  未找到DMG文件，请先运行 make quick$(NC)"; \
	fi

show-build: ## 显示构建产物信息
	@echo "$(CYAN)📋 构建产物信息:$(NC)"
	@echo ""
	@if [ -f "$(PROJECT_NAME)-$(VERSION).dmg" ]; then \
		SIZE=$$(du -h "$(PROJECT_NAME)-$(VERSION).dmg" | cut -f1); \
		echo "  $(GREEN)📦 DMG安装包:$(NC) $(PROJECT_NAME)-$(VERSION).dmg ($$SIZE)"; \
	fi
	@if [ -d "build/Release-$(PROJECT_NAME).app" ]; then \
		SIZE=$$(du -sh "build/Release-$(PROJECT_NAME).app" | cut -f1); \
		echo "  $(GREEN)🚀 Release应用:$(NC) build/Release-$(PROJECT_NAME).app ($$SIZE)"; \
	fi
	@if [ -d "build/Debug-$(PROJECT_NAME).app" ]; then \
		SIZE=$$(du -sh "build/Debug-$(PROJECT_NAME).app" | cut -f1); \
		echo "  $(GREEN)🔨 Debug应用:$(NC) build/Debug-$(PROJECT_NAME).app ($$SIZE)"; \
	fi
	@if [ -d "build/archives" ] && [ -n "$$(ls -A build/archives 2>/dev/null)" ]; then \
		echo "  $(GREEN)📚 Archive文件:$(NC)"; \
		ls -la build/archives/ | grep -v "^total" | grep -v "^d" | awk '{print "    " $$9 " (" $$5 " bytes)"}'; \
	fi

dev: debug run ## 开发模式：构建并运行Debug版本

package: quick open-dmg ## 打包模式：快速构建并打开DMG

# 清理所有构建产物
clean-all: ## 清理所有构建产物（包括DMG文件）
	@echo "$(YELLOW)🗑️  清理所有构建产物...$(NC)"
	@rm -rf build/
	@rm -f *.dmg
	@echo "$(GREEN)✅ 清理完成$(NC)"

# 显示项目统计信息
stats: ## 显示项目统计信息
	@echo "$(CYAN)📊 项目统计信息:$(NC)"
	@echo ""
	@echo "Swift文件数量: $$(find . -name "*.swift" -not -path "./build/*" | wc -l | tr -d ' ')"
	@echo "代码行数: $$(find . -name "*.swift" -not -path "./build/*" -exec wc -l {} + | tail -n1 | awk '{print $$1}')"
	@echo "测试文件数量: $$(find . -name "*Tests.swift" | wc -l | tr -d ' ')"
	@if [ -d ".git" ]; then \
		echo "Git提交数量: $$(git rev-list --count HEAD 2>/dev/null || echo "N/A")"; \
	fi

# 检查代码风格（如果安装了SwiftLint）
lint: ## 检查代码风格
	@if command -v swiftlint >/dev/null 2>&1; then \
		echo "$(YELLOW)🔍 检查代码风格...$(NC)"; \
		swiftlint; \
	else \
		echo "$(YELLOW)⚠️  SwiftLint未安装，跳过代码风格检查$(NC)"; \
		echo "安装方法: brew install swiftlint"; \
	fi

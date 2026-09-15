#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Maxim Selin (Mournweiss) <info@mournweiss.ru>
#
# SPDX-License-Identifier: Apache-2.0

# Build Script for Continue Project
#
# Provides a unified build interface for all project components.
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options:
#   --core       Build only the core library
#   --gui        Build only the GUI
#   --vscode     Build only the VS Code extension
#   --cli        Build only the CLI
#   --packages   Build only the shared packages
#   --all        Build all components (default)
#   --force      Force dependency update (npm install --force)
#   --help       Show this help message
#
# Examples:
#   ./build.sh                  # Build all components
#   ./build.sh --core           # Build only core
#   ./build.sh --vscode --force # Build vscode with forced dependency update
#   ./build.sh --all --force    # Full rebuild with forced dependencies

set -o pipefail

# ── Initialization ───────────────────────────────────────────────────────────

# Load sources
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$PROJECT_ROOT/scripts/common/shell_utils.sh"
source "$PROJECT_ROOT/scripts/common/env_utils.sh"
source "$PROJECT_ROOT/scripts/common/submodule_utils.sh"

# ── Configuration ────────────────────────────────────────────────────────────

# Global variables
FORCE="false"
BUILD_PACKAGES="false"
BUILD_CORE="false"
BUILD_GUI="false"
BUILD_VSCODE="false"
BUILD_CLI="false"
BUILD_ALL="false"

# Component directories (relative to PROJECT_ROOT)
PACKAGES_DIR="packages"
CORE_DIR="core"
GUI_DIR="gui"
VSCODE_DIR="extensions/vscode"
CLI_DIR="extensions/cli"
VSCODE_BUILD_DIR="$VSCODE_DIR/build"
CLI_DIST_DIR="$CLI_DIR/dist"

# Shared packages that must be built first (in dependency order)
SHARED_PACKAGES=(
    "config-types"
    "fetch"
    "llm-info"
    "terminal-security"
    "config-yaml"
    "openai-adapters"
)

# ── Help ─────────────────────────────────────────────────────────────────────

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build script for the Continue project.

Options:
    --core       Build only the core library
    --gui        Build only the GUI (React webview)
    --vscode     Build only the VS Code extension
    --cli        Build only the CLI application
    --packages   Build only the shared packages
    --all        Build all components (default)
    --force      Force dependency update (npm install --force)
    --help       Show this help message

Components (in build order):
    packages     Shared packages (config-types, fetch, llm-info,
                 terminal-security, config-yaml, openai-adapters)
    core         Core library
    gui          React GUI
    vscode       VS Code extension
    cli          CLI application

Examples:
    $(basename "$0")                  # Build all components
    $(basename "$0") --core           # Build only core
    $(basename "$0") --vscode         # Build core + vscode
    $(basename "$0") --all --force    # Full rebuild with forced dependencies
    $(basename "$0") --packages --cli # Build packages and cli

EOF
}

# ── Argument Parsing ─────────────────────────────────────────────────────────

# Parse command-line arguments and set global variables.
#
# Parameters:
#   $@: array - command-line arguments
#
# Returns:
#   None (sets global variables: FORCE, BUILD_PACKAGES, BUILD_CORE, etc.)
parse_args() {
    for arg in "$@"; do
        case $arg in
            --core)
                BUILD_CORE="true"
                BUILD_ALL="true"
                ;;
            --gui)
                BUILD_GUI="true"
                BUILD_ALL="true"
                ;;
            --vscode)
                BUILD_VSCODE="true"
                BUILD_ALL="true"
                ;;
            --cli)
                BUILD_CLI="true"
                BUILD_ALL="true"
                ;;
            --packages)
                BUILD_PACKAGES="true"
                BUILD_ALL="true"
                ;;
            --all)
                BUILD_ALL="true"
                ;;
            --force)
                FORCE="true"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                warn "Unknown argument: $arg (ignoring)"
                ;;
        esac
    done

    # Default to building all if no component specified
    if [[ "$BUILD_ALL" == "false" ]]; then
        BUILD_ALL="true"
    fi
}

# ── Build Functions ──────────────────────────────────────────────────────────

# Install dependencies for a given directory
#
# Parameters:
#   $1: directory - path to the directory (relative to PROJECT_ROOT)
#   $2: force     - whether to force dependency update (true/false)
#
# Returns:
#   0 on success, 1 on failure
install_deps() {
    local dir="$1"
    local force="${2:-false}"
    local dir_name
    dir_name="$(basename "$dir")"

    if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
        warn "Directory not found: $PROJECT_ROOT/$dir"
        return 0
    fi

    if [[ ! -f "$PROJECT_ROOT/$dir/package.json" ]]; then
        warn "package.json not found in: $PROJECT_ROOT/$dir"
        return 0
    fi

    info "Installing dependencies for: $dir_name"
    cd "$PROJECT_ROOT/$dir"

    if [[ "$force" == "true" ]]; then
        info "Force mode: updating dependencies..."
        if ! npm install --force; then
            error "Failed to install dependencies for: $dir_name"
            return 1
        fi
    else
        if ! npm install; then
            error "Failed to install dependencies for: $dir_name"
            return 1
        fi
    fi

    success "Dependencies installed for: $dir_name"
    cd "$PROJECT_ROOT"
}

# Build shared packages in dependency order
#
# Parameters:
#   $1: force - whether to force dependency update (true/false)
#
# Returns:
#   0 on success, 1 on failure
build_packages() {
    info "── Building shared packages ──"

    for pkg in "${SHARED_PACKAGES[@]}"; do
        local pkg_dir="$PACKAGES_DIR/$pkg"

        if [[ ! -d "$PROJECT_ROOT/$pkg_dir" ]]; then
            warn "Package directory not found: $pkg_dir (skipping)"
            continue
        fi

        info "Building package: $pkg"
        cd "$PROJECT_ROOT/$pkg_dir"

        # Install deps if not already installed
        if [[ ! -d "node_modules" ]]; then
            install_deps "$pkg_dir" "$FORCE" || return 1
        fi

        # Build if build script exists in package.json
        if grep -q '"build"' package.json; then
            info "Building $pkg..."
            if ! npm run build; then
                error "Failed to build package: $pkg"
                return 1
            fi
        fi

        success "Package built: $pkg"
        cd "$PROJECT_ROOT"
    done

    success "── All shared packages built ──"
}

# Build the core library
#
# Parameters:
#   $1: force - whether to force dependency update (true/false)
#
# Returns:
#   0 on success, 1 on failure
build_core() {
    info "── Building core ──"

    if [[ ! -d "$PROJECT_ROOT/$CORE_DIR" ]]; then
        error "Core directory not found: $CORE_DIR"
        return 1
    fi

    info "Installing dependencies for core..."
    install_deps "$CORE_DIR" "$FORCE" || return 1

    info "Building core..."
    cd "$PROJECT_ROOT/$CORE_DIR"

    if ! npm run build; then
        error "Failed to build core"
        cd "$PROJECT_ROOT"
        return 1
    fi

    success "── Core built successfully ──"
    cd "$PROJECT_ROOT"
}

# Build the GUI
#
# Parameters:
#   $1: force - whether to force dependency update (true/false)
#
# Returns:
#   0 on success, 1 on failure
build_gui() {
    info "── Building GUI ──"

    if [[ ! -d "$PROJECT_ROOT/$GUI_DIR" ]]; then
        error "GUI directory not found: $GUI_DIR"
        return 1
    fi

    info "Installing dependencies for GUI..."
    install_deps "$GUI_DIR" "$FORCE" || return 1

    info "Building GUI..."
    cd "$PROJECT_ROOT/$GUI_DIR"

    if ! npm run build; then
        error "Failed to build GUI"
        cd "$PROJECT_ROOT"
        return 1
    fi

    success "── GUI built successfully ──"
    cd "$PROJECT_ROOT"
}

# Build the VS Code extension
#
# Parameters:
#   $1: force - whether to force dependency update (true/false)
#
# Returns:
#   0 on success, 1 on failure
build_vscode() {
    info "── Building VS Code extension ──"

    if [[ ! -d "$PROJECT_ROOT/$VSCODE_DIR" ]]; then
        error "VS Code extension directory not found: $VSCODE_DIR"
        return 1
    fi

    info "Installing dependencies for VS Code extension..."
    install_deps "$VSCODE_DIR" "$FORCE" || return 1

    info "Building VS Code extension..."
    cd "$PROJECT_ROOT/$VSCODE_DIR"

    # Build Rust native module first
    if [[ -f "../../sync/Cargo.toml" ]]; then
        info "Building Rust sync module..."
        if ! npm run build-release:rust 2>&1; then
            warn "Rust build failed or skipped (native module may not be available)"
        fi
    fi

    # Build the extension
    if ! npm run esbuild; then
        error "Failed to build VS Code extension"
        cd "$PROJECT_ROOT"
        return 1
    fi

    # Generate .vsix package
    info "Generating .vsix package..."
    mkdir -p "$VSCODE_BUILD_DIR"

    if npm run package; then
        local vsix_file
        vsix_file=$(find "$VSCODE_BUILD_DIR" -name "*.vsix" -type f 2>/dev/null | head -n 1)
        if [[ -n "$vsix_file" ]]; then
            success ".vsix package generated: $vsix_file"
        else
            warn ".vsix package generation completed but no .vsix file found"
        fi
    else
        warn "Failed to generate .vsix package"
    fi

    success "── VS Code extension built successfully ──"

    cd "$PROJECT_ROOT"
}

# Build the CLI
#
# Parameters:
#   $1: force - whether to force dependency update (true/false)
#
# Returns:
#   0 on success, 1 on failure
build_cli() {
    info "── Building CLI ──"

    if [[ ! -d "$PROJECT_ROOT/$CLI_DIR" ]]; then
        error "CLI directory not found: $CLI_DIR"
        return 1
    fi

    info "Installing dependencies for CLI..."
    install_deps "$CLI_DIR" "$FORCE" || return 1

    info "Building CLI..."
    cd "$PROJECT_ROOT/$CLI_DIR"

    if ! npm run build; then
        error "Failed to build CLI"
        cd "$PROJECT_ROOT"
        return 1
    fi

    # Display CLI binary location
    if [[ -f "$CLI_DIST_DIR/cn.js" ]]; then
        local bundle_size
        bundle_size=$(du -sh "$CLI_DIST_DIR" 2>/dev/null | cut -f1)
        info "CLI binary bundle: $CLI_DIST_DIR (size: $bundle_size) ──"
    fi

    success "── CLI built successfully ──"

    cd "$PROJECT_ROOT"
}

# ── Main ─────────────────────────────────────────────────────────────────────

# Main function - orchestrates the build process
#
# Parameters:
#   $@: array - command-line arguments (passed to parse_args)
#
# Returns:
#   0 on success, 1 on failure
main() {
    # Parse arguments
    parse_args "$@"

    # Display build info
    info "── Continue Project Build ──"
    info "Force mode: $FORCE"
    info "Components: $(
        components=()
        [[ "$BUILD_PACKAGES" == "true" ]] && components+=("packages")
        [[ "$BUILD_CORE" == "true" ]] && components+=("core")
        [[ "$BUILD_GUI" == "true" ]] && components+=("gui")
        [[ "$BUILD_VSCODE" == "true" ]] && components+=("vscode")
        [[ "$BUILD_CLI" == "true" ]] && components+=("cli")
        [[ "$BUILD_ALL" == "true" && "${#components[@]}" -eq 0 ]] && components+=("all")
        echo "${components[*]:-all}"
    )"

    # Track overall success
    local BUILD_SUCCESS="true"

    # Build packages first if needed
    if [[ "$BUILD_PACKAGES" == "true" || "$BUILD_ALL" == "true" ]]; then
        build_packages || { BUILD_SUCCESS="false"; }
    fi

    # Build core if needed (required by other components)
    if [[ "$BUILD_CORE" == "true" || "$BUILD_ALL" == "true" ]]; then
        build_core || { BUILD_SUCCESS="false"; }
    fi

    # Build GUI if needed
    if [[ "$BUILD_GUI" == "true" || "$BUILD_ALL" == "true" ]]; then
        build_gui || { BUILD_SUCCESS="false"; }
    fi

    # Build VS Code extension if needed (depends on core)
    if [[ "$BUILD_VSCODE" == "true" || "$BUILD_ALL" == "true" ]]; then
        # Ensure core is built first
        if [[ "$BUILD_CORE" != "true" ]]; then
            build_core || { BUILD_SUCCESS="false"; }
        fi
        build_vscode || { BUILD_SUCCESS="false"; }
    fi

    # Build CLI if needed (depends on core)
    if [[ "$BUILD_CLI" == "true" || "$BUILD_ALL" == "true" ]]; then
        # Ensure core is built first
        if [[ "$BUILD_CORE" != "true" ]]; then
            build_core || { BUILD_SUCCESS="false"; }
        fi
        build_cli || { BUILD_SUCCESS="false"; }
    fi

    # Final result
    if [[ "$BUILD_SUCCESS" == "true" ]]; then
        success "── Build completed successfully ──"
        
        # Display output locations
        if [[ "$BUILD_VSCODE" == "true" || "$BUILD_ALL" == "true" ]] && [[ -d "$VSCODE_BUILD_DIR" ]]; then
            local vsix_files
            vsix_files=$(find "$VSCODE_BUILD_DIR" -name "*.vsix" -type f 2>/dev/null)
            if [[ -n "$vsix_files" ]]; then
                info "VS Code packages: $vsix_files"
            fi
        fi
        if [[ "$BUILD_CLI" == "true" || "$BUILD_ALL" == "true" ]] && [[ -d "$CLI_DIST_DIR" ]]; then
            info "CLI binary: $CLI_DIST_DIR/cn.js"
        fi
        
        exit 0
    else
        error "── Build failed ──"
        exit 1
    fi
}

# Entry point
main "$@"

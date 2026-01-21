#!/usr/bin/env bash
set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# 检查必需的工具
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl jq nix-prefetch-url sed; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install them before running this script."
        exit 1
    fi
}

# 更新 NapCat 版本
update_napcat() {
    log_info "Fetching latest NapCat release information..."
    
    local api_response
    if ! api_response=$(curl -s "https://api.github.com/repos/NapNeko/NapCatQQ/releases/latest"); then
        log_error "Failed to fetch GitHub API"
        exit 1
    fi
    
    local version
    version=$(echo "$api_response" | jq -r '.tag_name')
    
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        log_error "Failed to extract version from GitHub API response"
        log_error "API response: $api_response"
        exit 1
    fi
    
    log_info "Latest NapCat version: $version"
    
    local amd64_url="https://github.com/NapNeko/NapCatQQ/releases/download/$version/NapCat.Shell.zip"
    log_info "Downloading and computing hash for: $amd64_url"
    
    local amd64_hash
    if ! amd64_hash=$(nix-prefetch-url "$amd64_url" 2>&1); then
        log_error "Failed to download or hash NapCat package"
        log_error "URL: $amd64_url"
        exit 1
    fi
    
    # Extract hash from output (last line)
    amd64_hash=$(echo "$amd64_hash" | tail -n1)
    
    # Convert to SRI format
    if ! amd64_hash=$(nix hash convert --hash-algo sha256 "$amd64_hash" 2>&1); then
        log_error "Failed to convert hash to SRI format"
        exit 1
    fi
    
    log_info "Hash: $amd64_hash"
    log_info "Updating src/sources.nix..."
    
    # Update sources.nix
    sed -i "s|# Last updated: .*\.|# Last updated: $(date +%F).|g" ./src/sources.nix
    sed -i "s|napcat_version = \".*\";|napcat_version = \"$version\";|g" ./src/sources.nix
    sed -i "s|napcat_url = \".*\";|napcat_url = \"$amd64_url\";|g" ./src/sources.nix
    sed -i "s|napcat_hash = \".*\";|napcat_hash = \"$amd64_hash\";|g" ./src/sources.nix
    
    log_info "NapCat updated successfully to $version"
}

# 更新 QQ 版本
update_qq() {
    local url=$1
    
    if [ -z "$url" ]; then
        log_error "QQ download URL is required"
        log_error "Usage: $0 qq <url>"
        log_error "Example: $0 qq https://dldir1v6.qq.com/qqfile/qq/QQNT/a5fab4ff/linuxqq_3.2.18-36580_amd64.deb"
        exit 1
    fi
    
    log_info "Extracting version information from URL..."
    
    local hash
    hash=$(echo "$url" | grep -oP '/QQNT/\K[^/]+')
    local version
    version=$(echo "$url" | grep -oP 'linuxqq_\K[^_]+')
    
    if [ -z "$hash" ] || [ -z "$version" ]; then
        log_error "Failed to extract version information from URL"
        log_error "URL format should be: https://dldir1v6.qq.com/qqfile/qq/QQNT/<hash>/linuxqq_<version>_<arch>.deb"
        exit 1
    fi
    
    log_info "QQ version: $version"
    log_info "QQNT hash: $hash"
    
    local amd64_url="https://dldir1v6.qq.com/qqfile/qq/QQNT/${hash}/linuxqq_${version}_amd64.deb"
    local arm64_url="https://dldir1v6.qq.com/qqfile/qq/QQNT/${hash}/linuxqq_${version}_arm64.deb"
    
    log_info "Downloading and computing hash for amd64..."
    local amd64_hash
    if ! amd64_hash=$(nix-prefetch-url "$amd64_url" 2>&1 | tail -n1); then
        log_error "Failed to download or hash QQ amd64 package"
        exit 1
    fi
    
    log_info "Downloading and computing hash for arm64..."
    local arm64_hash
    if ! arm64_hash=$(nix-prefetch-url "$arm64_url" 2>&1 | tail -n1); then
        log_error "Failed to download or hash QQ arm64 package"
        exit 1
    fi
    
    # Convert to SRI format
    amd64_hash=$(nix hash convert --to-sri --hash-algo sha256 "$amd64_hash")
    arm64_hash=$(nix hash convert --to-sri --hash-algo sha256 "$arm64_hash")
    
    log_info "amd64 hash: $amd64_hash"
    log_info "arm64 hash: $arm64_hash"
    log_info "Updating src/sources.nix..."
    
    # Update sources.nix
    sed -i "s|# Last updated: .*\.|# Last updated: $(date +%F).|g" ./src/sources.nix
    sed -i "s|qq_version = \".*\";|qq_version = \"$version\";|g" ./src/sources.nix
    sed -i "s|qq_amd64_url = \".*\";|qq_amd64_url = \"$amd64_url\";|g" ./src/sources.nix
    sed -i "s|qq_amd64_hash = \".*\";|qq_amd64_hash = \"$amd64_hash\";|g" ./src/sources.nix
    sed -i "s|qq_arm64_url = \".*\";|qq_arm64_url = \"$arm64_url\";|g" ./src/sources.nix
    sed -i "s|qq_arm64_hash = \".*\";|qq_arm64_hash = \"$arm64_hash\";|g" ./src/sources.nix
    
    log_info "QQ updated successfully to $version"
}

# 显示使用说明
show_usage() {
    cat << USAGE
Usage: $0 <command> [args]

Commands:
  napcat          Update NapCat to the latest version
  qq <url>        Update QQ from the given download URL

Examples:
  $0 napcat
  $0 qq https://dldir1v6.qq.com/qqfile/qq/QQNT/a5fab4ff/linuxqq_3.2.18-36580_amd64.deb

USAGE
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    # Show help without checking dependencies
    case "$1" in
        -h|--help|help)
            show_usage
            exit 0
            ;;
    esac
    
    check_dependencies
    
    case "$1" in
        napcat)
            update_napcat
            ;;
        qq)
            update_qq "${2:-}"
            ;;
        -h|--help|help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"

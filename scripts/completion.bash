#!/bin/bash
_ANDROID_BUILD_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build-image.py"
android-build() { python3 "$_ANDROID_BUILD_SCRIPT" "$@"; }
_build_image_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}" key=options values
    case "$prev" in
        --system|-s) key=system ;;
        --version|-v) key=version ;;
        --desktop|-d) key=desktop ;;
        --jdk-provider) key=jdk-provider ;;
        --jdk-version|-j) key=jdk-version ;;
        --password|-p|--namespace|--config|--desktop-image|--project-name|--timezone|-z) COMPREPLY=(); return ;;
    esac
    values=$(python3 "$_ANDROID_BUILD_SCRIPT" --completion "$key") || return
    COMPREPLY=( $(compgen -W "$values" -- "$cur") )
}
complete -F _build_image_completion android-build

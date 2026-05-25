#!/bin/bash

_build_image_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--jdk-provider -j --jdk-version -c --create-env -p --password -h --help -b --build -D --dev -S --start -P --publish -m --multi-arch -i --system-image --latest --no-snapshot -s --system -v --version --cn-mirror --no-cn-mirror -d --desktop -z --timezone -T --stop"

    case "${prev}" in
        --jdk-provider)
            COMPREPLY=( $(compgen -W "openjdk temurin" -- ${cur}) )
            return 0
            ;;
        -s|--system)
            COMPREPLY=( $(compgen -W "debian ubuntu fedora arch alpine" -- ${cur}) )
            return 0
            ;;
        --version|-v)
            COMPREPLY=( $(compgen -W "trixie bookworm noble jammy resolute 41 42 43 44 latest 3.21 3.22" -- ${cur}) )
            return 0
            ;;
        -d|--desktop)
            COMPREPLY=( $(compgen -W "xfce lxqt mate" -- ${cur}) )
            return 0
            ;;
        -j|--jdk-version)
            # Suggest common LTS versions
            COMPREPLY=( $(compgen -W "8 11 17 21 25" -- ${cur}) )
            return 0
            ;;
        -p|--password)
             # No completion for passwords
             COMPREPLY=()
             return 0
             ;;
        *)
            ;;
    esac

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}

complete -F _build_image_completion ./build-image.sh
complete -F _build_image_completion ./scripts/build-image.sh

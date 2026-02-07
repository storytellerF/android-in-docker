#!/bin/bash

_build_image_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-j --jdk-version -c --create-env -p --password -h --help"

    case "${prev}" in
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

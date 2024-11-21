#!/bin/bash

function cleanup_apt() {
    local remove_var_lib_apt_lists=$1
    apt-get autoremove -y && rm -rf "$HOME"/.cache
    if [[ $remove_var_lib_apt_lists == true ]]; then
        rm -rf /var/lib/apt/lists/*
    fi
}

cleanup_apt "$@"

#!/usr/bin/env bash

export TARGET_RELEASE="bookworm"
export SOURCE_LISTS=()

setup_source_list() {
    menu_init

    if [[ ${#SOURCE_LISTS[@]} == 0 ]]
    then
        local index=0
        readarray SOURCE_LISTS <<< "$(get_source_list)"
        for list in "${SOURCE_LISTS[@]}"
        do
            list="$(process_source "bullseye" "$list" | tail -n 1)"
            SOURCE_LISTS[index]="$list"
            index=$((index + 1))
        done
    fi

    for list in "${SOURCE_LISTS[@]}"
    do
        IFS="|" read -r -a list <<< "$list"
        menu_add setup_source "${list[5]} ${list[6]}"
    done

    if menu_show "Please check following source list, and select one to setup"
    then
        save_source_list
    fi
}

pre_system_upgrade() {
    apt-get update
    apt-get remove 8852be-dkms

    if ! apt-get install dpkg
    then
        echo "Unable to install dpkg."
        return 1
    fi
}

post_system_upgrade() {
    if grep -q "rk3588" <<< "$(get_product_soc)"
    then
        apt-get update && apt-get install gdm3
    fi
}

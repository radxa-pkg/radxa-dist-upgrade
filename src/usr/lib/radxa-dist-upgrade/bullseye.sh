#!/usr/bin/env bash

export TARGET_RELEASE="bookworm"

setup_source_list() {
    if [[ "$STEP" != "2" ]] && [[ "$STEP" != "3" ]]
    then
        msgbox "Please run \"Check for upgrade\" first. $STEP"
        return
    fi

    menu_init
    if [[ $FLAG == "1" ]]
    then
        source_list="$(get_source_list)"
        readarray -t lists <<< "$source_list"
        export lists
    fi
    index=0
    for list in "${lists[@]}"
    do
        if [[ $FLAG == "1" ]]
        then
            list="$(process_source "bullseye" "$list" | tail -n 1)"
            list="$list|$index"
            lists[index]="$list"
        fi
        IFS="|" read -r -a list <<< "$list"
        menu_add setup_source "${list[7]}: ${list[2]} -> ${list[5]}, ${list[3]} -> ${list[6]}"
        index=$((index + 1))
    done
    menu_add "save_source_list" "Save source list"
    menu_show "Please check following source list, and select one to setup"
    FLAG="0"
    STEP="3"
}

pre_system_upgrade() {
    if [[ "$STEP" != "3" ]]
    then
        msgbox "Please run \"Setup source list\" first."
        return
    fi

    apt-get update
    apt-get remove 8852be-dkms

    if ! apt-get install dpkg
    then
        echo "Unable to install dpkg."
        return 1
    fi
    STEP="4"
}

post_system_upgrade() {
    if [[ "$STEP" != "6" ]]
    then
        msgbox "Please run \"System upgrade\" first."
        return
    fi

    if ! grep -q "rk3588" <<< "$(get_product_soc)"
    then
        apt-get update && apt-get install gdm
    fi
    STEP="7"
}

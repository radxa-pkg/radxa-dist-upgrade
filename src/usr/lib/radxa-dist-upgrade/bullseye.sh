#!/usr/bin/env bash

RELEASE="bookworm"

get_source_list() {
    for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list
    do
        grep -oP "^\s*deb\s+\K.*" "$file"| awk -v file="$file" '{
            if ($1 ~ /signed-by=/) {
                remaining = ""
                for (i = 4; i <= NF; i++) {
                    remaining = remaining $i " "
                }
                print file "|" $1 "|" $2 "|" $3 "|" remaining
            } else {
                remaining = ""
                for (i = 3; i <= NF; i++) {
                    remaining = remaining $i " "
                }
                print file "|" "" "|" $1 "|" $2 "|" remaining
            }
        }'
    done
}

setup_source_list() {
    if [[ "$STEP" != "1" ]] && [[ "$STEP" != "2" ]]
    then
        msgbox "Please run \"Check for upgrade\" first. $STEP"
        return
    fi

    menu_init
    if [[ $FLAG == "1" ]]
    then
        source_list="$(get_source_list)"
        readarray -t lists <<< "$source_list"
    fi
    index=0
    for list in "${lists[@]}"
    do
        if [[ $FLAG == "1" ]]
        then
            list="$(process_source "bullseye" "$list" | tail -n 1)"
            list="$list|$index"
        fi
        lists[index]="$list"
        IFS="|" read -r -a list <<< "$list"
        menu_add setup_source "${list[7]}: ${list[2]} -> ${list[5]}, ${list[3]} -> ${list[6]}"
        index=$((index + 1))
    done
    menu_add "save_source_list" "Save source list"
    menu_show "Please check following source list, and select one to setup"
    FLAG="0"
    STEP="2"
}

setup_source() {
    IFS=": " read -r -a index <<< "$RTUI_MENU_SELECTED"
    IFS="|" read -r -a list <<< "${lists[index[0]]}"
    item="$(inputbox "Original URL is ""${list[2]}"", Please input the new URL:" "${list[5]}")"
    list[5]="$item"
    item="$(inputbox "Original dist is ""${list[3]}"", Please input the new dist:" "${list[6]}")"
    list[6]="$item"
    lists[index[0]]="${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}|${list[7]}"
    msgbox "${lists[*]}"
}

save_source_list() {
    if yesno "Rename all sources.list to *.bak"
    then
        if [[ -e /etc/apt/sources.list ]]
        then
            mv /etc/apt/sources.list /etc/apt/sources.list.bak
        fi

        for source in /etc/apt/sources.list.d/*.list
        do
            mv "$source" "$source.bak"
        done
    fi

    for list in "${lists[@]}"
    do
        IFS="|" read -r -a list <<< "$list"
        if yesno "Save \"deb ${list[1]} ${list[5]} ${list[6]} ${list[4]}\" to ${list[0]}"
        then
            echo "deb ${list[1]} ${list[5]} ${list[6]} ${list[4]}" > "${list[0]}"
        fi
    done
    msgbox "Source list saved."
}

system_upgrade() {
    if [[ "$STEP" != "3" ]] && [[ "$STEP" != "0" ]]
    then
        msgbox "Please run \"Pre system upgrade\" first."
        return
    fi
    rsetup system_update
    STEP="4"
}

pre_system_upgrade() {
    if [[ "$STEP" != "2" ]]
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
    STEP="3"
}

post_system_upgrade() {
    if [[ "$STEP" != "4" ]]
    then
        msgbox "Please run \"System upgrade\" first."
        return
    fi

    if yesno "Remove all autoremove packages?"
    then
        apt-get autoremove
    fi

    if ! grep -q "rk3588" <<< "$(get_product_soc)" && [[ "$RELEASE" == "bookworm" ]]
    then
        apt-get update && apt-get install gdm
    fi
}

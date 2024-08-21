#!/usr/bin/env bash

export TARGET_RELEASE="bookworm"
export SOURCE_LISTS=()

setup_source_list() {
    while true
    do
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
        if ! menu_call "Please check following source list, and select one to setup"
        then
            save_source_list
            break
        fi
    done
}

pre_system_upgrade() {
    for i in /etc/apt/preferences.d/*
    do
        # Prevent backup of .bak, .dpkg-old, .dpkg-new and other files
        if [[ "$i" != *"."* ]]
        then
            mv "$i" "$i.bak"
        fi
    done

    apt-get update
    if ! apt-get install --download-only rtw89-dkms dpkg
    then
        msgbox "Unable to download rtw89-dkms or dpkg."
        return 1
    fi

    if ! apt-get remove 8852be-dkms
    then
        msgbox "Unable to remove 8852be-dkms."
        return 1
    fi

    if ! apt-get install rtw89-dkms dpkg
    then
        msgbox "Unable to install rtw89-dkms or dpkg."
        return 1
    fi
}

post_system_upgrade() {
    if grep -q "rk3588" <<< "$(get_product_soc)"
    then
        if ! apt-get remove libmali-valhall-g610-g6p0-x11-gbm
        then
            msgbox "Unable to remove libmali-valhall-g610-g6p0-x11-gbm."
            return 1
        fi

        echo "gdm3 shared/default-x-display-manager select gdm3" | debconf-set-selections
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y gdm3
        echo "/usr/sbin/gdm3" > "/etc/X11/default-display-manager"
        ln -sf "/lib/systemd/system/gdm3.service" "/etc/systemd/system/display-manager.service"
    fi

    if yesno "Do you want to reboot now? (recommend)"
    then
        reboot
    fi
}

#!/usr/bin/env bash

get_product_id() {
    rsetup get_product_id
}

get_product_soc() {
    data="$(curl -s "https://gate.radxa.com/https://raw.githubusercontent.com/RadxaOS-SDK/rsdk/main/src/share/rsdk/configs/products.json")"
    yq -e ".[] | select(.product == \"$(get_product_id)\").soc" <<< "$data"
}

checks() {
    check_packages
    check_dkms_status
    check_system_upgrade
    export STEP="1"
}

check_packages() {
    local product package
    product="$(tr $"\0" $"\n" < /proc/device-tree/compatible | tail -n 2 | head -n 1 | cut -d "," -f 2)"
    package="task-$product"

    if [[ "$(dpkg --get-selections "$package" | awk '{print $2}')" == "install" ]]
    then
        echo "$package is installed."
    else
        if yesno "$package is not installed. Do you want to install it?"
        then
            echo "Installing $package"
            if apt-get install -y "$package"
            then
                echo "$package installed."
            else
                echo "Failed to install $package."
                return 1
            fi
        else
            echo "Skipping $package installation."
            return 1
        fi
    fi
}

check_system_upgrade() {
    apt-get update
    upgradable="$(apt-get -s upgrade)"

    if echo "$upgradable" | grep -q "0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded"; then
        echo "All packages are up to date."
    else
        if yesno "Some packages are not up to date, please upgrade first"
        then
            system_upgrade
        fi
    fi
}

check_dkms_status() {
    if [[ "$(dkms status | awk '{print $5}' | grep -v installed)" == "" ]]
    then
        echo "DKMS is ready."
    else
        echo "Some dkms modules are not installed, please check "dkms status""
        return 1
    fi
}

process_source() {
    local original="$1" list="$2"
    IFS="|" read -r -a list <<< "$list"
    list[0]="${list[0]//$original/$RELEASE}"
    list[5]="${list[2]//$original/$RELEASE}"
    list[6]="${list[3]//$original/$RELEASE}"

    if grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && grep -q "rockchip-" <<< "${list[6]}" && grep -q "rk3588" <<< "$(get_product_soc)"
    then
        list[5]="${list[5]//$RELEASE/$(get_product_soc)-$RELEASE}"
        list[6]="${list[6]//rockchip/$(get_product_soc)}"
        list[0]="/etc/apt/sources.list.d/80-$(basename "${list[0]}")"
    elif grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && grep -q "rockchip-" <<< "${list[6]}" && grep -e "rk3582" <<< "$(get_product_soc)"
    then
        list[5]="${list[5]//$RELEASE/rk3582-$RELEASE}"
        list[6]="${list[6]//rockchip/rk3582}"
        list[0]="/etc/apt/sources.list.d/80-$(basename "${list[0]}")"
    fi

    if grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && [[ "${list[6]}" == "$RELEASE" ]]
    then
        list[0]="/etc/apt/sources.list.d/70-$(basename "${list[0]}")"
    fi

    if grep -q "/debian" <<< "${list[2]}" && grep -e "$RELEASE" <<< "${list[6]}"
    then
        if [[ "${list[6]}" == "$RELEASE" ]]
        then
            list[0]="/etc/apt/sources.list.d/$RELEASE.list"
        fi
        list[0]="/etc/apt/sources.list.d/50-$(basename "${list[0]}")"
    fi

    echo "${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}"
}

setup_source() {
    IFS=": " read -r -a index <<< "$RTUI_MENU_SELECTED"
    IFS="|" read -r -a list <<< "${lists[index[0]]}"
    item="$(inputbox "Original URL is ""${list[2]}"", Please input the new URL:" "${list[5]}")"
    list[5]="$item"
    item="$(inputbox "Original dist is ""${list[3]}"", Please input the new dist:" "${list[6]}")"
    list[6]="$item"
    lists[index[0]]="${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}|${list[7]}"
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

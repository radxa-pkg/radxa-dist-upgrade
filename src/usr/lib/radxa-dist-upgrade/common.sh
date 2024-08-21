#!/usr/bin/env bash

get_product_soc() {
    curl -s "https://gate.radxa.com/https://raw.githubusercontent.com/RadxaOS-SDK/rsdk/main/src/share/rsdk/configs/products.json" | \
    jq -r ".[] | select(.product == \"$(rsetup get_product_id)\").soc"
}

checks() {
    system_upgrade
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
    list[0]="${list[0]//$original/$TARGET_RELEASE}"
    list[5]="${list[2]//$original/$TARGET_RELEASE}"
    list[6]="${list[3]//$original/$TARGET_RELEASE}"

    if grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && grep -q "rockchip-" <<< "${list[6]}" && grep -q -e "rk3588" -e "rk3582" -e "rk3528a"<<< "$(get_product_soc)"
    then
        list[5]="${list[5]//$TARGET_RELEASE/$(get_product_soc)-$TARGET_RELEASE}"
        list[6]="${list[6]//rockchip/$(get_product_soc)}"
        # SC2001 (style): See if you can use ${variable//search/replace} instead. But search cannot use regular expressions
        # shellcheck disable=SC2001
        list[0]="/etc/apt/sources.list.d/80-$(basename "${list[0]}" | sed 's/^[0-9]\+-//')"
    fi

    if grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && [[ "${list[6]}" == "$TARGET_RELEASE" ]]
    then
        # SC2001 (style): See if you can use ${variable//search/replace} instead. But search cannot use regular expressions
        # shellcheck disable=SC2001
        list[0]="/etc/apt/sources.list.d/70-$(basename "${list[0]}" | sed 's/^[0-9]\+-//')"
    fi

    if grep -q "/debian" <<< "${list[2]}" && grep -e "$TARGET_RELEASE" <<< "${list[6]}"
    then
        if [[ "${list[6]}" == "$TARGET_RELEASE" ]]
        then
            list[0]="/etc/apt/sources.list.d/$TARGET_RELEASE.list"
        fi
        # SC2001 (style): See if you can use ${variable//search/replace} instead. But search cannot use regular expressions
        # shellcheck disable=SC2001
        list[0]="/etc/apt/sources.list.d/50-$(basename "${list[0]}" | sed 's/^[0-9]\+-//')"
    fi

    echo "${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}"
}

setup_source() {
    IFS="|" read -r -a list <<< "${SOURCE_LISTS[RTUI_MENU_SELECTED_INDEX]}"
    if item="$(inputbox "Original URL is ""${list[2]}"", Please input the new URL:" "${list[5]}")"
    then
        list[5]="$item"
    fi
    if item="$(inputbox "Original dist is ""${list[3]}"", Please input the new dist:" "${list[6]}")"
    then
        list[6]="$item"
    fi
    SOURCE_LISTS[RTUI_MENU_SELECTED_INDEX]="${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}"
}

check_source_worker() {
    __lock_fd "$mutex"

    if ! curl -Lsqf "$1" -o /dev/null
    then
        echo "${list[5]}/dists/${list[6]}/Release," >> "$mutex"
		__unlock_fd
        return 1
    fi
}

save_source_list() {
    local mutex
	mutex="$(mktemp)"

    for list in "${SOURCE_LISTS[@]}"
    do
        IFS="|" read -r -a list <<< "$list"
        __request_parallel
		check_source_worker "${list[5]}/dists/${list[6]}/Release" &
    done

    if ! __wait_parallel; then
        msgbox "Can't access $(cat "$mutex") please check the URL and dist."
        return 1
	fi

    rm "$mutex"

    if [[ -e /etc/apt/sources.list ]]
    then
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    for source in /etc/apt/sources.list.d/*.list
    do
        mv "$source" "$source.bak"
    done

    for list in "${SOURCE_LISTS[@]}"
    do
        IFS="|" read -r -a list <<< "$list"
        # Empty key addresses are not saved
        if [[ -n "${list[1]}" ]]
        then
            echo "deb ${list[1]} ${list[5]} ${list[6]} ${list[4]}" > "${list[0]}"
        else
            echo "deb ${list[5]} ${list[6]} ${list[4]}" > "${list[0]}"
        fi
    done
    msgbox "Source list saved."
}

system_upgrade() {
    rsetup system_update
}

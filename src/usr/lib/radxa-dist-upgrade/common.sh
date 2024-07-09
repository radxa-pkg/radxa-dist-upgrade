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

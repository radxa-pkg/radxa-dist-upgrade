#!/usr/bin/env bash

check_release_bookworm() {
    if grep -q "bullseye" <(lsb_release -c)
    then
        echo "Upgrading system to Bookworm."
    elif grep -q "bookworm" <(lsb_release -c)
    then
        echo "Bookworm is already installed."
        return 1
    else
        echo "Unsupported release."
        return 1
    fi
}

system_upgrade() {
    if ! apt-get update
    then
        echo "Unable to update package list."
        return 1
    fi
    if ! apt-get dist-upgrade --allow-downgrades
    then
        echo "Unable to upgrade packages."
        return 1
    fi
    if ! apt-get dist-upgrade --allow-downgrades
    then
        echo "Unable to upgrade pinned packages."
        return 1
    fi
    if ! apt-get autoremove
    then
        echo "Unable to remove packages."
        return 1
    fi
}

pre_system_upgrade() {
    local vendor soc pin
    pin="10"
    soc="$(tr $"\0" $"\n" < /proc/device-tree/compatible | tail -n 1 | cut -d "," -f 2)"
    vendor="$(tr $"\0" $"\n" < /proc/device-tree/compatible | tail -n 1 | cut -d "," -f 1)"

    if [[ -e /etc/apt/sources.list ]]
    then
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    for source in /etc/apt/sources.list.d/*.list
    do
        mv "$source" "$source.bak"
    done

    if grep -q -e "rk3588" -e "rk3528a" <<< "$soc"
    then
        pin="80"
    else
        soc="$vendor"
    fi

    if [[ -d /etc/apt/preferences.d ]]
    then
        mv /etc/apt/preferences.d /etc/apt/preferences.d.bak
        mkdir /etc/apt/preferences.d
    fi

    if [ -n "$soc" ]
    then
        echo "Creating $pin-radxa-$soc.list"
        tee "/etc/apt/sources.list.d/$pin-radxa-$soc.list" <<< "deb [signed-by=/usr/share/keyrings/radxa-archive-keyring.gpg] https://radxa-repo.github.io/$soc-$RELEASE/ $soc-$RELEASE main"
    fi

    for source in "/usr/share/radxa-dist-upgrade/$RELEASE/"*.list
    do
        echo "$source"
        cp "$source" /etc/apt/sources.list.d/
    done

    if [[ "$RELEASE" == "bookworm" ]]
    then
        apt-get remove 8852be-dkms
    fi

    if ! apt-get update && ! apt-get install dpkg
    then
        echo "Unable to install dpkg."
        return 1
    fi
}

post_system_upgrade() {
    local soc
    soc="$(tr $"\0" $"\n" < /proc/device-tree/compatible | tail -n 1 | cut -d "," -f 2)"
    if ! grep -q "rk3588" <<< "$soc" && [[ "$RELEASE" == "bookworm" ]]
    then
        apt-get update && apt-get install gdm
    fi
}

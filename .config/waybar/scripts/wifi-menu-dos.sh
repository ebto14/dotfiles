#!/bin/bash

# =====================================================
# NetworkManager UI (Hyprland / Rofi)
# Fuente de verdad: NetworkManager
# =====================================================

NM="nmcli -t"

# =====================================================
# FUNCIONES
# =====================================================

get_active_vpns() {
    nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="vpn" {print $1}'
}

is_vpn_active() {
    get_active_vpns | grep -qxF "$1"
}

# =====================================================
# WIFI LIST
# =====================================================

wifi_list=$(
    nmcli -t -f SSID,SECURITY,BARS device wifi list | awk -F: '
    NF>=3 && $1!="" {
        ssid=$1
        sec=$2
        bars=$3

        if (sec=="") sec="Open"

        printf "%s|%s|%s\n", ssid, sec, bars
    }'
)

# =====================================================
# VPN LIST
# =====================================================

vpn_list=$(
    nmcli -t -f NAME,TYPE connection show | awk -F: '
    $2=="vpn" || $2=="wireguard" {print $1}'
)

# =====================================================
# MENU BUILD (UI LIMPIA)
# =====================================================

menu=""

# ---------------- VPN ----------------
while read -r vpn; do
    [ -z "$vpn" ] && continue

    if is_vpn_active "$vpn"; then
        menu+="󰖂  ● $vpn (Conectada)\n"
    else
        menu+="󰖂      $vpn\n"
    fi
done <<< "$vpn_list"

# ---------------- WIFI ----------------
while IFS="|" read -r ssid sec bars; do
    [ -z "$ssid" ] && continue

    # icono señal
    icon="󰤯"
    if [ "$bars" -ge 4 ]; then icon="󰤨"
    elif [ "$bars" -ge 3 ]; then icon="󰤥"
    elif [ "$bars" -ge 2 ]; then icon="󰤢"
    else icon="󰤟"
    fi

    menu+="$icon  $ssid  ($sec)\n"
done <<< "$wifi_list"

# =====================================================
# ROFI
# =====================================================

chosen=$(echo -e "$menu" | rofi -dmenu -i -p "Redes / VPN" -config ~/.config/rofi/wifi-menu.rasi)

[ -z "$chosen" ] && exit 0

type=$(echo "$chosen" | awk '{print $1}')

# =====================================================
# VPN HANDLER (FIXED TOGGLE REAL)
# =====================================================

if [[ "$chosen" == *"󰖂"* ]]; then

    vpn_name=$(echo "$chosen" | sed 's/󰖂//g' | sed 's/●//g' | sed 's/(Conectada)//g' | xargs)

    active_vpn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="vpn"{print $1}')

    if echo "$active_vpn" | grep -qxF "$vpn_name"; then
        notify-send "VPN" "Desconectando $vpn_name"
        nmcli connection down "$vpn_name"
    else
        notify-send "VPN" "Conectando $vpn_name"
        nmcli connection up "$vpn_name"
    fi

    exit 0
fi

# =====================================================
# WIFI HANDLER
# =====================================================

ssid=$(echo "$chosen" | sed 's/^[^ ]*  //' | sed 's/  (.*)//')

# ya conectado
if nmcli -t -f ACTIVE,SSID dev wifi | grep -q "yes:$ssid"; then
    notify-send "WiFi" "Ya conectado a $ssid"
    exit 0
fi

# red abierta
if [[ "$chosen" == *"(Open)"* ]]; then
    nmcli dev wifi connect "$ssid" && notify-send "WiFi" "Conectado a $ssid"
    exit 0
fi

# red con contraseña
if nmcli connection show | grep -qxF "$ssid"; then
    nmcli connection up id "$ssid" && notify-send "WiFi" "Conectado a $ssid"
else
    pass=$(rofi -dmenu -p "Password $ssid" -password -config ~/.config/rofi/wifi-menu.rasi)
    [ -z "$pass" ] && exit 0

    nmcli dev wifi connect "$ssid" password "$pass" \
        && notify-send "WiFi" "Conectado a $ssid" \
        || notify-send "WiFi" "Error de autenticación"
fi

#!/bin/bash

# 1. Obtener lista de Wi-Fi usando ':' como separador nativo.
# Eliminamos el 'rescan' para evitar que NetworkManager dispare notificaciones del sistema.
wifi_list=$(nmcli -t -f "SSID,SECURITY,BARS" device wifi list | grep -v '^:')

# 2. Obtener lista de VPNs/Wireguard
vpn_list=$(nmcli -t -f NAME,TYPE connection show | grep -E ":vpn|:wireguard" | cut -d: -f1)

# 3. Formatear lista de Wi-Fi para Rofi (Filtrando duplicados)
formatted_wifi=""
declare -A seen_ssids # Array asociativo para rastrear redes ya agregadas

while IFS=':' read -r ssid security bars; do
    if [ -n "$ssid" ]; then
        # Si ya procesamos este SSID en este ciclo, lo ignoramos (mantiene la primera coincidencia, que suele ser la de mejor señal)
        if [[ -n "${seen_ssids[$ssid]}" ]]; then
            continue
        fi
        seen_ssids[$ssid]=1

        [ "$security" == " " ] || [ -z "$security" ] && security="Abierta"
        formatted_wifi+="$bars  $ssid  ($security)\n"
    fi
done <<< "$wifi_list"

# 4. Formatear lista de VPNs e identificar cuáles están activas
formatted_vpns=""
active_connections=$(nmcli -t -f NAME connection show --active)

while read -r vpn_name; do
    if [ -n "$vpn_name" ]; then
        if echo "$active_connections" | grep -qxF "$vpn_name"; then
            formatted_vpns+="󰖂  ● $vpn_name  (VPN Conectada)\n"
        else
            formatted_vpns+="󰖂    $vpn_name  (VPN)\n"
        fi
    fi
done <<< "$vpn_list"

# Combinar listas limpiando líneas vacías
menu_list=$(echo -e "${formatted_vpns}${formatted_wifi}" | grep -v '^[[:space:]]*$')

# 5. Lanzar Rofi directamente
chosen_item=$(echo -e "$menu_list" | rofi -dmenu -i -p "Redes/VPN" -config ~/.config/rofi/wifi-menu.rasi)

if [ -z "$chosen_item" ]; then
    exit 0
fi

# 6. Procesar Selección de VPN
if [[ "$chosen_item" == *"(VPN"* ]]; then
    vpn_name=$(echo "$chosen_item" | sed -E 's/^󰖂  (● )?//' | sed -E 's/  \(VPN.*\)$//')

    if echo "$active_connections" | grep -qxF "$vpn_name"; then
        notify-send "VPN" "Desconectando de: $vpn_name"
        nmcli connection down id "$vpn_name" && notify-send "VPN" "Desconectado de $vpn_name"
    else
        notify-send "VPN" "Conectando a: $vpn_name..."
        nmcli connection up id "$vpn_name" && notify-send "VPN" "Conectado a $vpn_name" || notify-send "VPN" "Error al conectar a $vpn_name"
    fi

# 7. Procesar Selección de Wi-Fi
else
    # Extraer el SSID limpiando iconos iniciales y formato final
    ssid=$(echo "$chosen_item" | sed -E 's/^[^ ]+  //' | sed -E 's/  \([^)]+\)$//')

    if nmcli -t -f NAME connection show --active | grep -qxF "$ssid"; then
        notify-send "WiFi" "Ya estás conectado a $ssid"
        exit 0
    fi

    if [[ "$chosen_item" == *"(Abierta)"* ]]; then
        nmcli device wifi connect "$ssid" && notify-send "WiFi" "Conectado a $ssid"
    else
        if nmcli connection show | grep -qxF "$ssid"; then
            nmcli connection up id "$ssid" && notify-send "WiFi" "Conectado a $ssid"
        else
            pass=$(rofi -dmenu -p "Password para $ssid: " -password -config ~/.config/rofi/wifi-menu.rasi)
            [ -z "$pass" ] && exit 0

            nmcli device wifi connect "$ssid" password "$pass" && notify-send "WiFi" "Conectado a $ssid" || notify-send "WiFi" "Error de autenticación"
        fi
    fi
fi

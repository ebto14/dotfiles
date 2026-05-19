#!/bin/bash

# 1. Escaneo activo (le damos 1 segundo para refrescar)
notify-send "  Escaneando redes y VPNs..."
nmcli device wifi rescan
sleep 1

# 2. Obtener la lista de Wi-Fi de forma más simple y robusta
wifi_list=$(nmcli -f "SSID,SECURITY,BARS" device wifi list | sed 's/^\*//' | sed '1d')

# 3. Obtener la lista de VPNs (mostrando el nombre completo sin importar los espacios)
# Usamos -t --fields NAME para obtener solo los nombres limpios uno por línea
vpn_list=$(nmcli -t -f NAME,TYPE connection show | grep -E ":vpn|:wireguard" | cut -d: -f1)

# 4. Formatear ambas listas para Rofi
# Formato Wi-Fi: [Barras] Nombre (Seguridad)
formatted_wifi=$(echo "$wifi_list" | awk -F'  +' '{printf "%s  %s  (%s)\n", $3, $1, $2}')

# Formato VPN: 󰖂   Nombre Completo (VPN)
formatted_vpns=""
while read -r vpn_name; do
    if [ -n "$vpn_name" ]; then
        formatted_vpns+=$'󰖂   '"$vpn_name"'  (VPN)\n'
    fi
done <<< "$vpn_list"

# Combinar las listas limpiando líneas vacías
menu_list=$(echo -e "${formatted_vpns}${formatted_wifi}" | grep -v '^[[:space:]]*$')

# 5. Lanzar Rofi
chosen_item=$(echo "$menu_list" | rofi -dmenu -i -p "Redes " -config ~/.config/rofi/wifi-menu.rasi)

# 6. Si el usuario cierra Rofi, salir
if [ -z "$chosen_item" ]; then
    exit
fi

# 7. Procesar la selección
if [[ "$chosen_item" == *"(VPN)"* ]]; then
    # Extraer el nombre de la VPN eliminando el icono del principio y el "  (VPN)" del final
    # Esto asegura que capture TODO el nombre, incluyendo espacios intermedios
    vpn_name=$(echo "$chosen_item" | sed 's/^󰖂   //' | sed 's/  (VPN)$//')

    # Revisar si la VPN ya está activa (buscando coincidencia exacta con ^nombre$)
    if nmcli -t -f NAME,STATE connection show --active | grep -q "^${vpn_name}:"; then
        notify-send "VPN" "Desconectando de: $vpn_name"
        nmcli connection down id "$vpn_name" && notify-send "VPN" "Desconectado de $vpn_name"
    else
        notify-send "VPN" "Conectando a: $vpn_name"
        # Forzar a nmcli a ejecutarse en modo estándar.
        # NOTA: Si la VPN requiere interacción/credenciales no guardadas, podría fallar aquí.
        nmcli connection up id "$vpn_name" && notify-send "VPN" "Conectado a $vpn_name" || notify-send "VPN" "Error crítico al conectar a $vpn_name"
    fi

else
    # --- Lógica Original para Wi-Fi ---
    # Extraer el SSID
    ssid=$(echo "$chosen_item" | awk -F'  +' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')

    # Intentar conectar
    if [[ "$chosen_item" == *"(--)"* ]]; then
        nmcli device wifi connect "$ssid" && notify-send "WiFi" "Conectado a $ssid"
    else
        # Revisar si ya conocemos la red para no pedir pass
        if nmcli -t -f TYPE,NAME connection show --active | grep -q "802-11-wireless.$ssid"; then
            nmcli device wifi connect "$ssid" && notify-send "WiFi" "Conectado a $ssid"
        else
            pass=$(rofi -dmenu -p "Password para $ssid: " -password -config ~/.config/rofi/wifi-menu.rasi)
            [ -z "$pass" ] && exit
            nmcli device wifi connect "$ssid" password "$pass" && notify-send "WiFi" "Conectado a $ssid"
        fi
    fi
fi

#!/bin/bash

# Comprobar estado del Bluetooth de forma robusta
if ! bluetoothctl show | grep -q "Powered: yes"; then
    action=$(echo -e "  Encender Bluetooth" | rofi -dmenu -p "Bluetooth" -config ~/.config/rofi/wifi-menu.rasi)
    if [ "$action" == "  Encender Bluetooth" ]; then
        bluetoothctl power on
        notify-send "Bluetooth" "Encendido"
    fi
    exit 0
fi

# NOTA: Quité el 'sleep 3' de aquí porque congelaba la apertura del menú.
# Si quieres escanear en tiempo real, es mejor disparar el escaneo en segundo plano ANTES
# o confiar en los dispositivos ya emparejados/vistos por el demonio.
devices=$(bluetoothctl devices | awk '{mac=$2; $1=$2=""; name=substr($0,3); printf "%s [%s]\n", name, mac}')

# Si no hay dispositivos detectados, evitamos un menú vacío
if [ -z "$devices" ]; then
    menu_list="  Apagar Bluetooth"
else
    menu_list="$devices\n  Apagar Bluetooth"
fi

chosen=$(echo -e "$menu_list" | rofi -dmenu -i -p "Bluetooth" -config ~/.config/rofi/wifi-menu.rasi)

if [ -z "$chosen" ]; then
    exit 0
elif [ "$chosen" == "  Apagar Bluetooth" ]; then
    bluetoothctl power off
    notify-send "Bluetooth" "Apagado"
else
    # Extraer la MAC de forma segura buscando lo que está dentro de los corchetes [MAC]
    mac=$(echo "$chosen" | grep -oP '\[\K[^\]]+')
    # Extraer el nombre quitando los corchetes del final
    name=$(echo "$chosen" | sed 's/ \[.*\]//')

    if [ -z "$mac" ]; then
        notify-send "Bluetooth" "No se pudo determinar la dirección MAC"
        exit 1
    fi

    notify-send "Bluetooth" "Intentando conectar a $name..."

    # Intentamos conectar. Si falla, enviamos error.
    if bluetoothctl connect "$mac" | grep -q "Connection successful"; then
        notify-send "Bluetooth" "Conectado a $name"
    else
        # Reintento genérico por si el buffer de bluetoothctl falló la primera respuesta
        bluetoothctl connect "$mac" && notify-send "Bluetooth" "Conectado a $name" || notify-send "Bluetooth" "Error al conectar"
    fi
fi

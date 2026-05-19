#!/bin/bash

# Comprobar estado del Bluetooth
status=$(bluetoothctl show | grep "Powered: yes" | wc -l)

if [ "$status" -eq 0 ]; then
    action=$(echo -e "  Encender Bluetooth" | rofi -dmenu -p "Bluetooth" -config ~/.config/rofi/wifi-menu.rasi)
    if [ "$action" == "  Encender Bluetooth" ]; then
        bluetoothctl power on
        notify-send "Bluetooth" "Encendido"
    fi
    exit
fi

# Obtener lista de dispositivos emparejados y cercanos
# Nota: scan on se ejecuta en segundo plano un momento para refrescar
bluetoothctl scan on & sleep 3 && kill $! > /dev/null 2>&1

devices=$(bluetoothctl devices | awk '{print $3 " " $2}')
chosen=$(echo -e "$devices\n  Apagar Bluetooth" | rofi -dmenu -p "Bluetooth" -config ~/.config/rofi/wifi-menu.rasi)

if [ -z "$chosen" ]; then
    exit
elif [ "$chosen" == "  Apagar Bluetooth" ]; then
    bluetoothctl power off
    notify-send "Bluetooth" "Apagado"
else
    # Extraer la MAC (el segundo campo)
    mac=$(echo "$chosen" | awk '{print $NF}')
    name=$(echo "$chosen" | awk '{$NF=""; print $0}')

    notify-send "Bluetooth" "Intentando conectar a $name..."
    bluetoothctl connect "$mac" && notify-send "Bluetooth" "Conectado a $name" || notify-send "Bluetooth" "Error al conectar"
fi

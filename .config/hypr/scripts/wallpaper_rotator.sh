#!/bin/bash

# Directorio de imágenes
DIR="/home/ebto/Imágenes"

# Tiempo de espera entre cambios (10 minutos x 60 segundos = 600)
# Solo cambia el '10' por los minutos que tú quieras
INTERVAL=$((3 * 60))

# Iniciar el demonio de awww si no está corriendo
if ! swww query > /dev/null 2>&1; then
    awww-daemon &
    sleep 1 # Darle un segundo para arrancar
fi

while true; do
    # Seleccionar imagen aleatoria
    RANDOM_PIC=$(find "$DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)

    if [ -n "$RANDOM_PIC" ]; then
        # Aplicar a todos los monitores con una transición elegante a 144 FPS
        swww img "$RANDOM_PIC" \
            --transition-type grow \
            --transition-pos center \
            --transition-duration 2 \
            --transition-fps 144
    fi

    sleep $INTERVAL
done

#!/bin/zsh
#este script descarga un dataset con datos climaticos de argentina de kaggle.com
#para usarlo se requiere kaggle CLI instalado y la API kaggle.json

# informacion del dataset

dataset="minahilfatima12328/Argentina-atmospheric-data"
csv="Argentina_weather_data.csv"

# directorio de salida
datos="../datos"


#kaggle CLI
if ! command -v kaggle &> /dev/null; then
    echo "kaggle CLI es necesario descargar con pip..."
    pip install kaggle
fi

#kaggle.json ¿existe? ¿donde esta?
KAGGLE_DIR="$HOME/.kaggle"
KAGGLE_JSON="$KAGGLE_DIR/kaggle.json"

if [ ! -d "$KAGGLE_DIR" ]; then
    echo "Creando directorio $KAGGLE_DIR..."
    mkdir -p "$KAGGLE_DIR"
fi

if [ ! -f "$KAGGLE_JSON" ]; then
    echo "Error: $KAGGLE_JSON no encontrado."
    echo "Descarga kaggle.json desde https://www.kaggle.com/account"
    echo "y colócalo en $KAGGLE_DIR/kaggle.json"
    exit 1
fi
#permisos de lectura necesarios
chmod 600 "$KAGGLE_JSON"

#descargar
echo "descargando dataset: $dataset"
kaggle datasets download -d "$dataset" -p "$datos"

# descomprimir
ZIP=$(ls "$datos"/*.zip | head -n5 | tail -5)
if [ -f "$ZIP" ]; then
    echo "descomprimiendo $ZIP..."
    unzip -o "$ZIP" -d "$datos"
    rm "$ZIP"
else
    echo "No se encontró archivo ZIP en $datos"
    exit 1
fi

#buena suerte!
echo "descarga completada. Archivos en: $datos"

#muestra un analisis rapido
# head primeras 2 filas
echo ".-´-.-´-.-´-.- primeras 5 filas .-´-.-´-.-´-.-"
head -n 2 "$datos/$csv"
echo ".-´-.-´-.-´-.- ultimas 5 filas .-´-.-´-.-´-.-"
# tail ultimas 2 filas
tail -n 2 "$datos/$csv"


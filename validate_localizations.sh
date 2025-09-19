#!/bin/bash

# Script de validation de localisation pour BackupFlow
echo "🌍 Validation des fichiers de localisation BackupFlow"
echo "================================================="

RESOURCES_PATH="/Users/tamersavasci/Documents/BackupFlow/BackupFlow/Resources"
LANGUAGES=("en" "de" "fr" "zh" "ja")
REFERENCE_LANG="en"

# Extraire toutes les clés du fichier de référence (anglais)
echo "📋 Extraction des clés de référence (${REFERENCE_LANG})..."
reference_keys=$(grep '^"[^"]*"' "${RESOURCES_PATH}/${REFERENCE_LANG}.lproj/Localizable.strings" | sed 's/^"\([^"]*\)".*/\1/' | sort)
reference_count=$(echo "$reference_keys" | wc -l | tr -d ' ')

echo "   Nombre de clés trouvées: $reference_count"
echo ""

# Vérifier chaque langue
for lang in "${LANGUAGES[@]}"; do
    echo "🔍 Vérification de $lang..."
    
    file_path="${RESOURCES_PATH}/${lang}.lproj/Localizable.strings"
    
    if [ ! -f "$file_path" ]; then
        echo "   ❌ ERREUR: Fichier manquant pour $lang"
        continue
    fi
    
    # Extraire les clés pour cette langue
    lang_keys=$(grep '^"[^"]*"' "$file_path" | sed 's/^"\([^"]*\)".*/\1/' | sort)
    lang_count=$(echo "$lang_keys" | wc -l | tr -d ' ')
    
    echo "   📊 Nombre de clés: $lang_count"
    
    # Comparer avec la référence
    if [ "$lang_count" -eq "$reference_count" ]; then
        echo "   ✅ Nombre de clés correct"
        
        # Vérifier si toutes les clés sont présentes
        missing_keys=$(comm -23 <(echo "$reference_keys") <(echo "$lang_keys"))
        if [ -z "$missing_keys" ]; then
            echo "   ✅ Toutes les clés sont présentes"
        else
            echo "   ⚠️  Clés manquantes:"
            echo "$missing_keys" | sed 's/^/      - /'
        fi
    else
        echo "   ❌ Nombre de clés incorrect (attendu: $reference_count, trouvé: $lang_count)"
    fi
    
    echo ""
done

echo "🎉 Validation terminée !"
echo ""
echo "📋 Résumé des fichiers de localisation:"
for lang in "${LANGUAGES[@]}"; do
    file_path="${RESOURCES_PATH}/${lang}.lproj/Localizable.strings"
    if [ -f "$file_path" ]; then
        size=$(ls -lh "$file_path" | awk '{print $5}')
        echo "   $lang: $size"
    fi
done
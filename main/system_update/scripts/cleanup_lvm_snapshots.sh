#!/bin/bash
# cleanup_lvm_snapshots.sh
# Nettoie les snapshots LVM obsolètes (plus anciens que N jours)
# Utilisé par le playbook Ansible

set -e

# === CONFIGURATION ===
VG_NAME="${1:-rootvg}"           # Nom du volume group (par défaut : rootvg)
SNAPSHOT_PREFIX="${2:-snap_}"     # Préfixe des snapshots (ex. : snap_server01_)
RETENTION_DAYS="${3:-7}"         # Nombre de jours de rétention
DRY_RUN="${4:-false}"            # true = affiche les snapshots à supprimer, false = les supprime

# === FONCTIONS ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_snapshot_age() {
    local snapshot_name="$1"
    local creation_time
    creation_time=$(lvs --noheadings -o lv_time "$VG_NAME/$snapshot_name" 2>/dev/null | xargs)
    if [ -z "$creation_time" ]; then
        echo "0"
        return
    fi
    # Convertir en timestamp
    creation_timestamp=$(date -d "$creation_time" +%s 2>/dev/null)
    if [ -z "$creation_timestamp" ]; then
        echo "0"
        return
    fi
    current_timestamp=$(date +%s)
    echo $((current_timestamp - creation_timestamp))
}

# === MAIN ===
log "Nettoyage des snapshots LVM du VG '$VG_NAME' avec préfixe '$SNAPSHOT_PREFIX'"

# Lister tous les snapshots
snapshots=$(lvs --noheadings -o lv_name --select "lv_name=~^$SNAPSHOT_PREFIX" "$VG_NAME" 2>/dev/null | tr -d ' ' | grep -v "^$")

if [ -z "$snapshots" ]; then
    log "Aucun snapshot trouvé avec le préfixe '$SNAPSHOT_PREFIX'."
    exit 0
fi

log "Snapshots trouvés :"
for snap in $snapshots; do
    age_seconds=$(get_snapshot_age "$snap")
    age_days=$((age_seconds / 86400))
    log "  - $snap (âge : $age_days jours)"
done

# Nettoyer les snapshots obsolètes
for snap in $snapshots; do
    age_seconds=$(get_snapshot_age "$snap")
    age_days=$((age_seconds / 86400))
    if [ "$age_days" -ge "$RETENTION_DAYS" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            log "DRY-RUN : Suppression de $snap (âge : $age_days jours)"
        else
            log "Suppression de $snap (âge : $age_days jours)"
            lvremove -f "$VG_NAME/$snap" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "  ✅ Supprimé avec succès"
            else
                log "  ❌ Échec de suppression"
            fi
        fi
    fi
done

log "Nettoyage terminé."

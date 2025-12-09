#!/bin/bash
# check_lvm_snapshots.sh
# Retourne l'âge moyen des snapshots LVM (en jours) pour Zabbix

VG_NAME="${1:-rootvg}"
SNAPSHOT_PREFIX="${2:-snap_}"

# Lister les snapshots
snapshots=$(lvs --noheadings -o lv_name --select "lv_name=~^$SNAPSHOT_PREFIX" "$VG_NAME" 2>/dev/null | tr -d ' ' | grep -v "^$")

if [ -z "$snapshots" ]; then
    echo "0"
    exit 0
fi

total_age=0
count=0

for snap in $snapshots; do
    creation_time=$(lvs --noheadings -o lv_time "$VG_NAME/$snap" 2>/dev/null | xargs)
    if [ -z "$creation_time" ]; then
        continue
    fi
    creation_timestamp=$(date -d "$creation_time" +%s 2>/dev/null)
    if [ -z "$creation_timestamp" ]; then
        continue
    fi
    current_timestamp=$(date +%s)
    age_seconds=$((current_timestamp - creation_timestamp))
    age_days=$((age_seconds / 86400))
    total_age=$((total_age + age_days))
    count=$((count + 1))
done

if [ $count -eq 0 ]; then
    echo "0"
else
    avg_age=$((total_age / count))
    echo "$avg_age"
fi

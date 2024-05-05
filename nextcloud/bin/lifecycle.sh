#!/usr/bin/env bash

nextcloud_init() {
    sleep 60;
    while true; do
        nextcloud_status
        if [[ $rc == 0 ]]; then
            break
        fi
        sleep 5
    done

    NC_IS_INSTALLED=$(php occ status | grep "installed: true" -c)
    if [[ $NC_IS_INSTALLED != 0 ]]; then
        echo "nextcloud already installed, skipping init."
        exit 0
    fi

    echo "nextcloud init started"

    php occ maintenance:install \
        --admin-user    "admin" \
        --admin-pass    "$NC_ADMIN_PASSWORD" \
        --database      "mysql" \
        --database-host "nextcloud-db" \
        --database-port "3306" \
        --database-name "nextcloud" \
        --database-user "nextcloud" \
        --database-pass "$NC_DB_PASSWORD"

    NC_DOMAIN_IDX=0
    for DOMAIN in "${NC_TRUSTED_DOMAINS[@]}"; do
        DOMAIN=$(echo "$DOMAIN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        php occ config:system:set trusted_domains "$NC_DOMAIN_IDX" --value="$DOMAIN"
        if [[ $NC_DOMAIN_IDX == 0 ]]; then
                CLI_URL=${DOMAIN}
        fi
        NC_DOMAIN_IDX=$(($NC_DOMAIN_IDX+1))
    done

    NC_PROXY_IDX=0
    for PROXY in "${NC_TRUSTED_PROXIES[@]}"; do
        PROXY=$(echo "$PROXY" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        php occ config:system:set trusted_proxies "$NC_PROXY_IDX" --value="$PROXY"
        NC_PROXY_IDX=$(($NC_PROXY_IDX+1))
    done

    php occ config:system:set default_language --value="${NC_DEFAULT_LANGUAGE}"
    php occ config:system:set default_locale --value="${NC_DEFAULT_LOCALE}"
    php occ config:system:set default_phone_region --value="${NC_DEFAULT_PHONE_REGION}"
    php occ config:system:set default_timezone --value="${NC_DEFAULT_TIMEZONE}"

    php occ config:system:set overwriteprotocol --value="https"
    php occ config:system:set overwrite.cli.url --value="https://${CLI_URL}:8000"
    php occ config:system:set updatechecker --type=boolean --value="false"
    php occ config:system:set upgrade.disable-web --type=boolean --value="true"
    php occ config:system:set redis host --value="nextcloud-valkey"
    php occ config:system:set redis port --value="6379"
    php occ config:system:set memcache.local --value="\OC\Memcache\APCu"
    php occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
    php occ config:system:set memcache.locking --value="\OC\Memcache\Redis"

    php occ app:enable calendar
    php occ app:enable contacts
    php occ app:enable tasks
    php occ app:enable deck
    php occ app:enable notes
    php occ app:enable news -f
    php occ app:install maps
    php occ app:enable maps
    #php occ app:enable twofactor_totp
    #php occ app:install mail
    #php occ app:enable mail
    #php occ app:install user_oidc
    #php occ app:enable user_oidc

    php occ app:install richdocuments
    php occ app:enable richdocuments
    php occ config:system:set allow_local_remote_servers --value true --type bool
    php occ config:app:set richdocuments wopi_allowlist --value="192.168.27.0/24"
    # uncomment next line if using a self-signed certificate
    #php occ config:app:set richdocuments disable_certificate_verification --value "yes"
    php occ rich:setup -w "https://${CLI_URL}:9000" -c "https://${CLI_URL}:8000"

    php occ app:list
    php occ app:update --all

    echo "nextcloud init done"
}

nextcloud_upgrade() {
    php occ check
    php occ status -v
    php occ app:list

    UPGRADE_LOGFILE="/var/log/nextcloud-upgrade_"$(date +%y_%m_%d)".log"
    php occ upgrade 2>&1 >> "$UPGRADE_LOGFILE"
    DISABLED_APPS=( $(cat "$UPGRADE_LOGFILE" | grep "Disabled incompatible app:" | cut -d ":" -f 2 | egrep -o "[a-z]+[a-z0-9_]*[a-z0-9]+") )
    for APP_ID in "${DISABLED_APPS[@]}"; do
        php occ app:enable "$APP_ID" || php occ app:install "$APP_ID" || echo "Could not re-enable nextcloud app $APP_ID"
    done

    echo "nextcloud upgrade done. logs in $UPGRADE_LOGFILE"
}

nextcloud_periodic() {
    nextcloud_status
    if [[ $rc == 2 ]]; then
        echo "nextcloud needs upgrade. upgrading nextcloud.."
        nextcloud_upgrade
    elif [[ $rc == 1 ]]; then
        echo "nextcloud in maintenance mode. exiting"
        exit $rc
    elif [[ $rc != 0 ]]; then
        echo "nextcloud error $rc. exiting"
        exit $rc
    fi

    echo "nextcloud cron started"

    php -f /var/www/html/cron.php

    echo "nextcloud cron done"
}

nextcloud_status() {
    php occ status -e -v
    rc=$?
    echo "nextcloud status: $rc"
}

if [[ ! -n $1 ]];
then 
    echo "no command specified"
    exit 33;
fi

case "$1" in
    init)
        nextcloud_init
        ;;
    periodic)
        nextcloud_periodic
        ;;
    *)
        echo "supported commands are 'init' and 'periodic'"
        exit 34
esac

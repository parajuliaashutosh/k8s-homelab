#!/bin/sh
# Weekly postgres backup: pg_dumpall -> gzip -> openssl (AES-256) -> S3, then notify Discord.
# Mounted into the postgres-backup-weekly CronJob via the postgres-backup-script ConfigMap.

set -uo pipefail

TIMESTAMP=$(date -u +%Y%m%d_%H%M%SZ)
if pg_dumpall -h postgres.default.svc.cluster.local -U pgadmin | gzip |
  openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt -pass env:BACKUP_PASSPHRASE \
    >/tmp/backup_$TIMESTAMP.sql.gz.enc &&
  aws s3 cp /tmp/backup_$TIMESTAMP.sql.gz.enc \
    s3://$BUCKET_NAME/postgres/weekly/$TIMESTAMP.sql.gz.enc \
    --endpoint-url https://$S3_ENDPOINT; then
  curl -s -X POST $WEBHOOK_URL \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"✅ Postgres weekly backup succeeded: $TIMESTAMP\"}"
else
  curl -s -X POST $WEBHOOK_URL \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"❌ Postgres weekly backup failed!\"}"
  exit 1
fi

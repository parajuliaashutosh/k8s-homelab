#!/bin/sh
# Weekly postgres backup: pg_dumpall -> gzip -> S3, then notify Discord.
# Mounted into the postgres-backup-weekly CronJob via the postgres-backup-script ConfigMap.

TIMESTAMP=$(date -u +%Y%m%d_%H%M%SZ)
pg_dumpall -h postgres.default.svc.cluster.local -U pgadmin | gzip > /tmp/backup_$TIMESTAMP.sql.gz
if [ $? -eq 0 ]; then
  aws s3 cp /tmp/backup_$TIMESTAMP.sql.gz \
    s3://$BUCKET_NAME/postgres/weekly/$TIMESTAMP.sql.gz \
    --endpoint-url https://$S3_ENDPOINT
  curl -s -X POST $WEBHOOK_URL \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"✅ Postgres weekly backup succeeded: $TIMESTAMP\"}"
else
  curl -s -X POST $WEBHOOK_URL \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"❌ Postgres weekly backup failed!\"}"
fi
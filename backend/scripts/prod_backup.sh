#!/usr/bin/env bash
# 生产环境备份脚本：PostgreSQL 数据库 + 作业照片上传卷
#
# 用法：
#   ./prod_backup.sh [备份目录] [保留天数]
#   ./prod_backup.sh                      # 默认 /home/ubuntu/homework-app/backups，保留 7 天
#
# 建议以 cron 每日执行（见 DEPLOY.md）：
#   30 3 * * * /home/ubuntu/homework-app/src/backend/scripts/prod_backup.sh >> /home/ubuntu/homework-app/backups/backup.log 2>&1
#
# 恢复方法：
#   数据库   gunzip -c db-YYYY-MM-DD_HHMMSS.sql.gz | sudo docker exec -i homework-backend-db-1 psql -U homework -d homework
#   上传文件 sudo docker run --rm -i -v homework-backend_uploads:/data ubuntu tar xzf - -C /data < uploads-YYYY-MM-DD_HHMMSS.tar.gz

set -euo pipefail

BACKUP_DIR="${1:-/home/ubuntu/homework-app/backups}"
RETAIN_DAYS="${2:-7}"

# 容器与库名（与 docker-compose.prod.yml 的 project name 对应）
DB_CONTAINER="${DB_CONTAINER:-homework-backend-db-1}"
APP_IMAGE="${APP_IMAGE:-homework-backend-app}"
UPLOADS_VOLUME="${UPLOADS_VOLUME:-homework-backend_uploads}"
DB_NAME="${DB_NAME:-homework}"
DB_USER="${DB_USER:-homework}"

# cron 环境不继承 docker 组，统一用 sudo
DOCKER="${DOCKER:-sudo docker}"

STAMP="$(date +%F_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "[$(date '+%F %T')] ===== 备份开始 ====="

# ---------- 1. 数据库 ----------
DB_FILE="$BACKUP_DIR/db-$STAMP.sql.gz"
if $DOCKER exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$DB_FILE"; then
    if [ -s "$DB_FILE" ]; then
        echo "[OK] 数据库 -> $DB_FILE ($(du -h "$DB_FILE" | cut -f1))"
    else
        echo "[失败] 数据库备份为空：$DB_FILE" >&2
        rm -f "$DB_FILE"
        exit 1
    fi
else
    echo "[失败] pg_dump 执行失败（容器 $DB_CONTAINER 是否在运行？）" >&2
    rm -f "$DB_FILE"
    exit 1
fi

# ---------- 2. 上传文件卷 ----------
UPLOAD_FILE="$BACKUP_DIR/uploads-$STAMP.tar.gz"
# 复用应用镜像（避免额外拉取镜像），但要注意两点：
#   1) 应用镜像 ENTRYPOINT 是 java -jar，必须 --entrypoint tar 覆盖，否则 tar 会被当成 java 参数；
#   2) 该镜像没有 gzip，所以 tar 输出到 stdout，由宿主机 gzip 压缩。
if $DOCKER run --rm --entrypoint tar \
    -v "$UPLOADS_VOLUME":/data:ro \
    "$APP_IMAGE" cf - -C /data . | gzip > "$UPLOAD_FILE"; then
    if [ -s "$UPLOAD_FILE" ] && gzip -t "$UPLOAD_FILE"; then
        echo "[OK] 上传文件 -> $UPLOAD_FILE ($(du -h "$UPLOAD_FILE" | cut -f1))"
    else
        echo "[警告] 上传文件卷备份异常（文件为空或损坏）" >&2
        rm -f "$UPLOAD_FILE"
    fi
else
    echo "[警告] 上传文件卷备份失败（卷 $UPLOADS_VOLUME 可能不存在），数据库备份不受影响" >&2
    rm -f "$UPLOAD_FILE"
fi

# ---------- 3. 清理过期备份 ----------
DELETED=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.gz' -mtime +"$RETAIN_DAYS" -print -delete | wc -l)
echo "[清理] 删除超过 $RETAIN_DAYS 天的备份：$DELETED 个"

echo "[$(date '+%F %T')] ===== 备份完成 ====="
echo "当前备份文件："
ls -lh "$BACKUP_DIR"/*.gz 2>/dev/null | tail -10 || echo "（无）"

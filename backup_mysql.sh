#!/bin/bash

# 설정 변수들
ORIGIN_CONTAINER="originMysql"
NEW_CONTAINER="newMysql"
ORIGIN_DB="fisa"
NEW_DB="new_database"
MYSQL_USER="username"
MYSQL_PASSWORD="password"
DUMP_PATH="/tmp/origin_db_dump.sql"

# 1. originMysql 컨테이너에서 MySQL 덤프 생성
docker exec $ORIGIN_CONTAINER mysqldump -u $MYSQL_USER -p$MYSQL_PASSWORD $ORIGIN_DB > $DUMP_PATH

# 2. newMysql 컨테이너에 새로운 데이터베이스 생성 (이미 존재할 경우 무시)
docker exec $NEW_CONTAINER mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $NEW_DB;"

# 3. 덤프 파일을 newMysql 컨테이너에 복사
docker cp $DUMP_PATH $NEW_CONTAINER:/tmp/origin_db_dump.sql

# 4. newMysql 컨테이너에 덤프 파일 복원
docker exec -i $NEW_CONTAINER mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $NEW_DB < /tmp/origin_db_dump.sql

# 5. 덤프 파일 삭제 (선택 사항, 원하지 않으면 주석 처리)
rm $DUMP_PATH

echo "Backup and restore completed successfully."

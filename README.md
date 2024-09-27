# [ 🎩 MySQL Dump using Crontab ]

## 🧹 개요
> MySQL 백업을 위한 방법을 비교하고, **mysqldump와 Crontab**을 사용해 **Docker Container 간 데이터를 백업**하는 워크플로우를 구현합니다.

<br>

## 🕶 MySQL 덤프화 vs Docker 볼륨 백업
| 항목                    | Docker 볼륨 마운트 백업                              | MySQL 덤프 백업                                              |
|------------------------|----------------------------------------------------|------------------------------------------------------------|
| **백업 속도**           | 빠름                                               | 느림                                                       |
| **복원 속도**           | 빠름                                               | 느림                                                       |
| **무결성 보장**         | 낮음 (실행 중 백업 시 위험)                         | 높음 (옵션 사용 시 보장 가능)                               |
| **이식성**              | 낮음 (동일 환경에서만 보장)                         | 높음 (서로 다른 환경에서 복원 가능)                         |
| **세밀한 복원**         | 어려움                                              | 쉬움 (특정 테이블/DB만 복원 가능)                           |
| **설정 복원**           | 설정 파일까지 복원 가능                              | 설정 복원 어려움                                             |
| **장기적 유지보수**     | 비효율적 (호환성 문제 발생 가능)                    | 효율적 (다양한 환경에서 사용 가능)                          |

- **Docker 볼륨 마운트 백업**은 빠른 백업과 복구를 제공하지만, 이식성 문제와 데이터 무결성 문제가 있을 수 있습니다. 동일한 서버 환경에서 빠르게 복구해야 하거나, 큰 규모의 데이터를 효율적으로 관리해야 할 때 유리합니다.
- **MySQL 덤프 백업**은 이식성이 높고 데이터 무결성을 보장할 수 있으며, 특정 데이터만 선택적으로 복원할 수 있습니다. 복잡한 데이터 복구가 필요하거나 다른 환경으로 데이터를 이전해야 할 경우에 적합합니다.

<br>

> 이 레포지토리에서는 MySQL 덤프 백업을 진행합니다.

<br>


## 🚍 작업 Workflow
1. originMysql에서 MySQL 데이터를 덤프(mysqldump)하고 호스트 머신에 저장
2. newMysql에서 새로운 데이터베이스를 생성
3. 덤프된 파일을 newMysql 컨테이너로 복사한 후, mysql 명령을 사용해 복원
4. 데이터베이스 복원 여부 확인

<br>

## 👜 MySQL Dump와 Docker exec를 사용한 백업
### 1. Origin MySQL Container 생성 및 데이터베이스 설정

```
$ docker run --name originMysql -e MYSQL_ROOT_PASSWORD=root -d -p 3307:3306 mysql:latest

$ docker exec -it originMysql bash


bash-5.1# mysql -u root -p

# Mysql 컨테이너에 dept table 생성 및 데이터 저장
CREATE DATABASE fisa;
USE fisa;

GRANT ALL PRIVILEGES ON fisa.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
```

<br>

### 2. DBeaver 접속 후 더미 데이터 삽입

Docker Container에서 실행하는 MySQL DB에 접속하기 위한 DBeaver 설정
- `allowPublicKeyRetrieval` : true
- `useSSL` : false

<br><div align="center">
<img src="https://github.com/user-attachments/assets/2ec09915-ae7e-4623-855b-62ff42dbb69a" width="460">
</div>
<div align="center">
<img src="https://github.com/user-attachments/assets/cdcbc673-91ee-4c5c-99b8-171ac7e7f716" width="460">
</div><br>

```sql
-- 테이블 생성
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE,
    salary DECIMAL(10, 2)
);

-- 더미 데이터 삽입
INSERT INTO employees (first_name, last_name, email, hire_date, salary)
VALUES
('John', 'Doe', 'john.doe@example.com', '2020-01-15', 50000.00),
('Jane', 'Smith', 'jane.smith@example.com', '2019-03-22', 55000.00),
('Michael', 'Johnson', 'michael.johnson@example.com', '2018-07-11', 60000.00),
('Emily', 'Davis', 'emily.davis@example.com', '2021-09-30', 47000.00),
('David', 'Wilson', 'david.wilson@example.com', '2022-11-05', 52000.00);

-- 데이터 확인
SELECT * FROM employees;
```

<br><div align="center">
<img src="https://github.com/user-attachments/assets/6adb58ba-c01f-4e2b-8b41-71797998cc90" width="460">
</div><br>

### 3. 데이터 Dump 생성
호스트의 `/tmp` 경로에 덤프 파일 저장
```bash
$ docker exec originMysql mysqldump -u <username> -p<password> fisa > /tmp/origin_db_dump.sql

$ sudo ls /tmp | grep dump
origin_db_dump.sql
```

<br> 

### 4. New MySQL Container에 새로운 데이터베이스 생성
```bash
$ docker run --name newMysql -e MYSQL_ROOT_PASSWORD=root -d -p 3308:3306 mysql:latest

$ docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS          PORTS                                                    NAMES
06d35596f642   mysql:latest   "docker-entrypoint.s…"   2 minutes ago    Up 2 minutes    33060/tcp, 0.0.0.0:3308->3306/tcp, [::]:3308->3306/tcp   newMysql
f0fde8792bfa   mysql:latest   "docker-entrypoint.s…"   21 minutes ago   Up 21 minutes   33060/tcp, 0.0.0.0:3307->3306/tcp, [::]:3307->3306/tcp   originMysql

$ docker exec -it newMysql mysql -u <username> -p<password> -e "CREATE DATABASE new_database;"
```

<br>

### 5. Origin MySQL Container 덤프 파일을 New MySQL Container로 이관
```bash
$ docker cp /tmp/origin_db_dump.sql newMysql:/tmp/origin_db_dump.sql
Successfully copied 4.1kB to newMysql:/tmp/origin_db_dump.sql

$ docker exec -i newMysql mysql -u <username> -p<password> new_database < /tmp/origin_db_dump.sql

$ docker exec -it newMysql mysql -u <username> -p<password> -e "USE new_database; SHOW
 TABLES;"
+------------------------+
| Tables_in_new_database |
+------------------------+
| employees              |
+------------------------+
```

DBeaver에서 new_databse로 데이터가 이전된 것을 확인한 모습입니다.
<br><div align="center">
<img src="https://github.com/user-attachments/assets/cd2d0e6f-6574-445b-96e2-0e12676f802d" width="460">
</div><br>



## 🎐 Shell script로 작성해 Crontab으로 실행
### 1. 워크플로우 Shell script 작성 및 권한 부여

```bash
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
```
```bash
$ chmod +x backup_mysql.sh   # 실행 권한 부여
$ ls -l backup_mysql.sh 
-rwxrwxr-x 1 username username 980 Sep 27 15:21 backup_mysql.sh
```

<br>

### 2. Crontab 설정
```bash
$ crontab -e   # crontab 편집

# 다음 줄 추가 - 매일 오전 2시마다 실행되도록 설정
0 2 * * * /home/username/backup_mysql.sh >> /home/username/backup_mysql.log 2>&1   # 결과를 log 파일에 저장

$ crontab -l   # 설정 확인
```

5분 단위 백업(`*/5 * * * */home/username/backup_mysql.sh >> /home/username/backup_mysql.log 2>&1`)으로 테스트해본 결과

<br>

## 🎨 최종 실행 결과
Origin
<br><div align="center">
<img src="https://github.com/user-attachments/assets/1e1c58a0-7ca2-44d7-9302-45f14dce06b6" width="600">
</div><br>

Backup 전 New DB
<br><div align="center">
<img src="https://github.com/user-attachments/assets/753edea9-f50e-4450-a410-ed986ed7469a" width="600">
</div><br>

Backup 후 New DB
<br><div align="center">
<img src="https://github.com/user-attachments/assets/a84cfa0c-fdeb-456a-ac8f-cbd3928e665d" width="600">
</div><br>

## 🧵 결론 및 고찰
> Docker Container 상의 MySQL을 백업할 수 있는 다양한 방법에 대해 탐구해보았고, 백업을 진행하는 워크플로우를 구축했으며, DBeaver에서 Docker Container의 MySQL DB에 접근해 데이터가 이전된 것을 직접 확인했습니다.
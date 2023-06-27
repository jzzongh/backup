#!/usr/bin/env bash

source /etc/profile

# 当前时间
NOW=$(date +'%Y-%m-%d %H:%M:%S')
# 备份创建日期
BACKUP_DATE=$(date +%Y-%m-%d)
# 备份过期日期
EXPIRE_DATE=$(date -d '15 days ago' +%Y-%m-%d)
# 备份目录
BACKUP_DIR=/opt/backup
# 备份数据目录
BACKUP_DATA_DIR=${BACKUP_DIR}/data/mysql/${BACKUP_DATE}
# 过期备份数据目录
EXPIRE_DATA_DIR=${BACKUP_DIR}/data/mysql/${EXPIRE_DATE}
# 备份日志目录
BACKUP_LOG_DIR=${BACKUP_DIR}/logs/mysql/
# 备份日志文件
BACKUP_LOG_FILE=${BACKUP_LOG_DIR}/${BACKUP_DATE}.log

# 脚本使用说明
usage() {
cat <<EOF
Usage: sh $(basename "${BASH_SOURCE[0]}") 参数

请输入参数, 选项如下:

 [1] local 本机备份
 [2] remote 异机备份

EOF
exit 0
}

# 判断备份数据存储目录是否存在，不存在则创建
create_data_dir() {
  if [[ ! -d ${BACKUP_DATA_DIR} ]]; then
    mkdir -p ${BACKUP_DATA_DIR}
  fi
}

# 判断备份脚本日志目录文件是否存在，不存在则创建
create_log_file() {
  if [[ ! -d ${BACKUP_LOG_DIR} ]]; then
    mkdir -p ${BACKUP_LOG_DIR}
    touch ${BACKUP_LOG_FILE}
  else
    if [[ ! -e ${BACKUP_LOG_FILE} ]]; then
      touch ${BACKUP_LOG_FILE}
    fi
  fi
}

# 本机备份: 导出数据到本机备份数据存储目录
local_backup_data() {
  jq -c '.mysql[]' ${BACKUP_DIR}/.conf/.mysql.json | while read i; do

    user=$(echo $i | jq -r .user)
    passwd=$(echo $i | jq -r .passwd)
    dbs=$(echo $i | jq -r .dbs)

    for db in ${dbs[@]}; do
      echo "*- 正在备份数据库$db"
      mysqldump -u ${user} -p${passwd} ${db} > ${BACKUP_DATA_DIR}/${db}.sql
    done
  done
}

# 异机备份: 导出数据到备份机备份数据存储目录
remote_backup_data() {
  jq -c '.mysql[]' ${BACKUP_DIR}/.conf/.mysql.json | while read i; do

    name=$(echo $i | jq -r .name)
    host=$(echo $i | jq -r .host)
    port=$(echo $i | jq -r .port)
    user=$(echo $i | jq -r .user)
    passwd=$(echo $i | jq -r .passwd)
    dbs=$(echo $i | jq -r .dbs)

    mkdir -p ${BACKUP_DATA_DIR}/${name}

    for db in ${dbs[@]}; do
      echo "*- 正在备份数据库$db"
      mysqldump -h ${host} -P ${port} -u ${user} -p${passwd} ${db} > ${BACKUP_DATA_DIR}/${name}/${db}.sql
    done
  done
}

# 删除过期的备份
delete_expire_backup() {
  if [[ -d ${EXPIRE_DATA_DIR} ]]; then
    echo "*- 正在删除过期备份"
    rm -rf ${EXPIRE_DATA_DIR}
  fi
}

start_local(){
  create_data_dir
  create_log_file
  exec &> ${BACKUP_LOG_FILE}
  echo "*- ${NOW} -*"
  echo -e "*- - -   开始备份  - - -*\n"
  local_backup_data
  delete_expire_backup
  echo -e "\n*- - -   结束备份  - - -*"
  echo -e "*- - - - - - - - - - - -*\n"
}

start_remote(){
  create_data_dir
  create_log_file
  exec &> ${BACKUP_LOG_FILE}
  echo "*- 当前时间: ${NOW} -*"
  echo -e "*- - -   开始备份  - - -*\n"
  remote_backup_data
  delete_expire_backup
  echo -e "\n*- - -   结束备份  - - -*"
  echo -e "*- - - - - - - - - - - -*\n"
}

case $1 in
"local")
  start_local
;;
"remote")
  start_remote
;;
*)
  usage
;;
esac


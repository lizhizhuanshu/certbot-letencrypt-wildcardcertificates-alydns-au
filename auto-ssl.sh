#!/bin/bash


AU_FILE=$(pwd)/au.sh

# 查找并替换 TXY_KEY,TXY_TOKEN

# 提取字段值的函数
extract_value() {
    local key=$1
    local file=$2
    grep "^$key=" "$file" | cut -d '=' -f 2 | tr -d '"'
}

ensure_field() {
    local key=$1
    local file=$2
    if [ -z "$(extract_value $key $file)" ]; then
      read -p "Please input your $key:" DEFAULT_KEY
      if grep -q "^$key=" "$file"; then
          sed -i s/$key=\"\"/$key="\"$DEFAULT_KEY\""/ "$file"
      else
        echo "$key=\"$DEFAULT_KEY\"" >> "$file"
      fi
    else
      echo "$key 已经存在。"
    fi
}



init(){
  sudo apt install git
  #安装certbot
  sudo apt install certbot
  #安装python
  sudo apt install python-is-python3
}

install(){
  read -p "Please input your domain name:" DOMAIN_NAME
  CURRENT_DIR=$(pwd)
  #申请域名证书
  sudo certbot certonly  -d ${DOMAIN_NAME} -d *.${DOMAIN_NAME} --manual --preferred-challenges dns  --manual-auth-hook "${AU_FILE} python txy add" --manual-cleanup-hook "${AU_FILE} python txy clean"
  echo "证书申请成功 请查看 /etc/letsencrypt/live/${DOMAIN_NAME} 目录"
  echo "使用证书 cer /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem"
  echo "使用证书 key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem"
}

task_cmd(){
  if [ $USER != "root" ]; then
    HEADER=sudo
  else
    HEADER=""
  fi
  read -p "Please input your domain name:" DOMAIN_NAME
  TASK_CMD="${HEADER} certbot renew --cert-name ${DOMAIN_NAME} --deploy-hook  \"/bin/bash $USER $(pwd)/action.sh\" --manual-auth-hook \"${AU_FILE} python txy add\" --manual-cleanup-hook \"${AU_FILE} python txy clean\""
}

add_task(){
  task_cmd
  #设置定时
  CRON_TASK="0 0 */7 * * ${TASK_CMD}"
  # 检查任务是否已经存在
  (crontab -l | grep -Fx "$CRON_TASK") > /dev/null 2>&1

  if [ $? -eq 0 ]; then
      echo "任务已经存在，不需要添加。"
  else
      # 任务不存在，添加到 crontab
      (sudo crontab -l; echo "$CRON_TASK") | sudo crontab -
      echo "任务已成功添加到 crontab。"
  fi
}

renew(){
  task_cmd
  eval $TASK_CMD
}

case $1 in
  init)
    init $@
    ;;
  install)
    install $@
    ;;
  add_task)
    add_task $@
    ;;
  renew)
    renew $@
    ;;
  *)
    echo "Usage: $0 {init|install|add_task}"
    exit 1
esac




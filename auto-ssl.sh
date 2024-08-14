#!/bin/bash


AU_FILE=$(pwd)/au.sh
CONFIG_FILE=$(pwd)/config.sh

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


ensureContext(){
  read -p 'Please select your domain service provider,default is 1: 
  1.腾讯云 
  2.阿里云 
  3.华为云 
  4.GoDaddy
  ' PROVIDER

  if [ ! $PROVIDER ]; then
    PROVIDER=1
  fi

  if [ ! -f $CONFIG_FILE ]
  then
    echo "" > $CONFIG_FILE
  fi

  case $PROVIDER in
    1)PROVIDER_NAME="txy"
      ensure_field "TXY_KEY" $CONFIG_FILE
      ensure_field "TXY_TOKEN" $CONFIG_FILE
      ;;
    2)PROVIDER_NAME="aly" 
      ensure_field "ALY_KEY" $CONFIG_FILE
      ensure_field "ALY_TOKEN" $CONFIG_FILE
      ;;
    3)PROVIDER_NAME="hwy"
      ensure_field "HWY_KEY" $CONFIG_FILE
      ensure_field "HWY_TOKEN " $CONFIG_FILE
      ;;
    4)PROVIDER_NAME="godaddy"
      ensure_field "GODADDY_KEY" $CONFIG_FILE
      ensure_field "GODADDY_TOKEN " $CONFIG_FILE
      ;;
    *)
      echo "Not support this dns services"
      exit
  esac
}

install(){
  read -p "Please input your domain name:" DOMAIN_NAME

  ensureContext
  CURRENT_DIR=$(pwd)
  #申请域名证书
  sudo certbot certonly  -d ${DOMAIN_NAME} -d *.${DOMAIN_NAME} --manual --preferred-challenges dns  --manual-auth-hook "${AU_FILE} python ${PROVIDER_NAME} add" --manual-cleanup-hook "${AU_FILE} python ${PROVIDER_NAME} clean"
  echo "证书申请成功 请查看 /etc/letsencrypt/live/${DOMAIN_NAME} 目录"
  echo "使用证书 cer /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem"
  echo "使用证书 key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem"
}

task_cmd(){
  if [ $USER != "root" ]; then
    HEADER=sudo
  fi
  read -p "Please input your domain name:" DOMAIN_NAME
  ensureContext
  if [ -f "action.sh" ]; then
    DEPLAY_HOOK="--deploy-hook  \"/bin/bash $USER $(pwd)/action.sh\""
  fi
  TASK_CMD="${HEADER} certbot renew --cert-name ${DOMAIN_NAME} $DEPLAY_HOOK --manual-auth-hook \"${AU_FILE} python ${PROVIDER_NAME} add\" --manual-cleanup-hook \"${AU_FILE} python ${PROVIDER_NAME} clean\""
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




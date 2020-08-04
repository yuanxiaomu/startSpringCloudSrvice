#!/bin/bash

# 引入设置的变量
source setEnv.sh

# 引入自定义函数
source func.sh

#获取脚本当前的路径
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)

#获取jar包所在路径
SERVICE_FOLDER=$(cd $(dirname ${SCRIPT_DIR}); pwd)

PID_DIR="${SERVICE_FOLDER}/.pid"

killPid
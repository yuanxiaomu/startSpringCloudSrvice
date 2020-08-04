#!/bin/bash


# system version。spring boot版本为1的话则配置2，否则配置3。
SYSTEM_V=3
# 是否需要解密。0为不需要解密，1为需要解密
ENCRYPT=1
# 自定义临时文件夹路径。不允许使用系统默认的临时文件夹，会导致spring boot启动时创建的tomcat文件夹被删除而无法上传文件。如果没配置，则默认会在bin文件夹同级目录创建一个temp文件夹。
TMP_DIR=""
# 自定义java_home
MY_JAVA_HOME="D:\Program Files\Java\jdk1.8.0_121"
# 当前IP
CURRENT_IP=localhost
# eureka所在的IP
EUREKA_IP=localhost
# eureka的端口
EUREKA_PORT=8761
# 配置中心所在的IP
CONFIG_CENTER_IP=localhost
# 配置中心的端口
CONFIG_CENTER_PORT=8888
# 微服务使用的配置中心文件
SPRING_CLOUD_CONFIG_NAME=common


#固定代码，勿动
EUREKA_CLIENT_DEFAULTZONE=http://${EUREKA_IP}:${EUREKA_PORT}/eureka
SPRING_CLOUD_CONFIG_URI=http://${CONFIG_CENTER_IP}:${CONFIG_CENTER_PORT}

#固定代码，勿动
# 如果没有配置临时文件夹，则默认在文件夹下创建
if [ -z $TMP_DIR ]
then
	#获取脚本当前的路径
	SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)
	#获取jar包所在路径
	SERVICE_FOLDER=$(cd $(dirname ${SCRIPT_DIR}); pwd)
	TMP_DIR=${SERVICE_FOLDER}/temp
fi
# 如果不存在，则需要创建
if [[ ! -d "$TMP_DIR" ]]; then
	#echo "$TMP_DIR不存在，创建文件夹"
	cmdResult=`mkdir $TMP_DIR`
	if [ $? -ne 0 ];then
		echo ${cmdResult}
		exit
	fi
fi

# application name与jar包对应关系。必须要配置。配置方式：serviceMapping["eureka页面看到的微服务名称大写"]="不含版本与后缀的微服务jar包名称,端口号,java启动的系统属性,自定义的jar参数"
declare -A serviceMapping
serviceMapping["COMPMGR"]="compmgr,8088,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["CONFIG-CENTER"]="config-center,${CONFIG_CENTER_PORT},-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["DFSMGR"]="dfsmgr,8082,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["EUREKA-SERVER"]="eureka-server,${EUREKA_PORT},-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["FLOWENGINE"]="flowEngine,8085,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["GATEWAY"]="gateway,8000,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["HNLFMGR"]="hnlfmgr,8093,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["LOGMGR"]="logmgr,8099,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASCOMMON"]="sas-common,8086,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASDOWNLOAD"]="sas-cross-download,8016,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASINFOCFG"]="sas-infocfg,8199,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASPROCESSMGR"]="sas-processmgr,8017,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASCATALOG"]="sas-sz-catalog,8103,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASMEETINGMGR"]="sas-sz-meeting,8101,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASSZRULE"]="sas-sz-rule,8102,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SSOMGR"]="ssomgr,8098,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SYSMGR"]="sysmgr,8089,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["SASACISSUEMGR"]="szyd_sasac_issue,8096,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME} --sasacIssueTask.itemListTask.enable=true --sasacIssueTask.reportStatTask.enable=true"
serviceMapping["UPGRADEMGR"]="sas-upgrade,8076,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"
serviceMapping["TRANSFERMGR"]="transfermgr,8095,-Xms128m -Xmx256m -Djava.io.tmpdir=${TMP_DIR},--spring.cloud.config.name=${SPRING_CLOUD_CONFIG_NAME}"

#固定代码，勿动
EUREKA_APPLICATION_NAME=EUREKA-SERVER
CONFIG_APPLICATION_NAME=CONFIG-CENTER
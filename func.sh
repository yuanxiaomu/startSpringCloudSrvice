#!/bin/bash

# 判断文件是否存在
function isFileExist(){
	if [ -z "$1" ]; then
		echo "文件路径为空"
		return 1
	fi
	if [ ! -f "$1" ];then
		echo "文件$1不存在"
		return 2
	fi
}

# 判断文件夹是否存在
function isDirExist(){
	if [ -z "$1" ]; then
		echo "文件夹路径为空"
		return 1
	fi
	if [[ ! -d "$1" ]]; then
		if [[ "$2" == "1" ]]; then
			mkdir $1
			echo "文件夹$1存在"
			return 0
		else
			echo "文件夹不存在"
			return 2
		fi
	else
		#echo "文件夹$1存在"
		return 0	
	fi
}

# 验证命令是否存在
function isCmdExist(){
	if [ -z "$1" ]; then
		echo "命令为空"
		return 1
	fi
	type $1
	if [[ $? == 0 ]]; then
		echo "$1已安装"
		return 0
	else
		echo "$1未安装"
		return 2
	fi
}

# 获取java home
function getJavaHome(){
	if [ -n "$1" ]; then
		if [[ ! -d "$MY_JAVA_HOME" ]]; then
			echo "检测设置的MY_JAVA_HOME路径$1不存在"
			return 1
		else
			echo "$1"
			return 0
		fi
	else	
		if [ -n "${JAVA_HOME}" ]; then
			#echo "未自定义JAVA运行环境，将使用系统的JAVA运行环境${JAVA_HOME}"
			echo ${JAVA_HOME}
			return 0
		else
			echo "java运行环境未配置"
			return 1
		fi
	fi
}

# 查询微服务的jar包是否存在
function checkJarFileExist(){
	if [ -z "$1" ]; then
		echo "微服务名称为空"
		return 1
	fi
	result=${serviceMapping[$1]}
	if [ -z "${result}" ]; then
		echo "微服务$1未映射jar包"
		return 1
	fi

	oldIFS=$IFS
	IFS=,
	#serviceCofig=(${serviceCofig//,/ })
	array=(${result})	
	IFS=$oldIFS
	
	SERVICE_JAR_NAME_PRE=${array[0]}
	SERVICE_JAR_NAME=""
	SERVICE_JAR_LIST=`ls |grep ^${SERVICE_JAR_NAME_PRE}.*\.jar$`
	#echo $SERVICE_JAR_LIST
	#echo ${#SERVICE_JAR_LIST[@]}
	if [[ ${#SERVICE_JAR_LIST[@]} -gt 1 ]]; then
		echo "存在多个$1微服务可运行的jar包"
		return 2
	elif [[ ${#SERVICE_JAR_LIST[@]} -lt 1 ]]; then
		echo "不存在$1微服务可运行的jar包"
		return 1
	else
		#echo ${SERVICE_JAR_LIST[0]}
		#如果内容为空的话，则说明不存在
		if [ -z "${SERVICE_JAR_LIST[0]}" ]; then
			echo "不存在$1微服务可运行的jar包"
			return 1
		else
			#echo "存在唯一的$1微服务可运行的jar包"
			SERVICE_JAR_NAME=${SERVICE_JAR_LIST[0]%%.jar*}
			echo $SERVICE_JAR_NAME
			return 0
		fi
	fi
}

# 查询微服务jar包前缀
function getServiceJarNamePre(){
	if [ -z "$1" ]; then
		echo "微服务名称为空"
		return 1
	fi
	result=${serviceMapping[$1]}
	if [ -z "${result}" ]; then
		echo "微服务$1未映射jar包"
		return 1
	fi
	oldIFS=$IFS
	IFS=,
	#array=(${result//,/ })
	array=(${result})
	IFS=$oldIFS

	echo ${array[0]}
}

# 启动jar包。参数1：微服务名，参数2：jar包名称（不含后缀）
function startJar(){
	serviceCofig=${serviceMapping[${1}]}
	oldIFS=$IFS
	IFS=,
	#serviceCofig=(${serviceCofig//,/ })
	serviceCofig=(${serviceCofig})	
	IFS=$oldIFS
	
	if [[ $ENCRYPT == 1 ]]; then
		nohup "${MY_JAVA_HOME}/bin/java" ${serviceCofig[2]} -Djava.security.egd=file:/dev/./urandom -jar ${SERVICE_FOLDER}/$2.jar --server.port=${serviceCofig[1]} --eureka.client.service-url.defaultZone=${EUREKA_CLIENT_DEFAULTZONE} --spring.cloud.config.uri=${SPRING_CLOUD_CONFIG_URI} ${serviceCofig[3]} --xjar.keyfile=${KEY_DIR}/$2.key >> ${LOG_DIR}/${serviceCofig[0]}.log & echo "$!" > ${PID_DIR}/${serviceCofig[0]}.pid
	else
		nohup "${MY_JAVA_HOME}/bin/java" ${serviceCofig[2]} -Djava.security.egd=file:/dev/./urandom -jar ${SERVICE_FOLDER}/$2.jar --server.port=${serviceCofig[1]} --eureka.client.service-url.defaultZone=${EUREKA_CLIENT_DEFAULTZONE} --spring.cloud.config.uri=${SPRING_CLOUD_CONFIG_URI} ${serviceCofig[3]} >> ${LOG_DIR}/${serviceCofig[0]}.log & echo "$!" > ${PID_DIR}/${serviceCofig[0]}.pid
	fi
	
}

# 验证微服务是否启动 参数： 微服务名 ip 端口
function isServiceStarted(){
	echo "SYSTEM_V ${SYSTEM_V}"
	echo "${1} ${2} ${3}"
	if [[ ${SYSTEM_V} = 2 ]]; then
		echo "curl -s http://${2}:${3}/info"
		appInfo=`curl -s http://${2}:${3}/info`
		if [[ $appInfo =~ ${1} ]]
		then
			echo "微服务已启动"
			return 0
		else
			echo "微服务未启动"
			return 1
		fi
	else
		appInfo=`curl -s http://${2}:${3}/actuator/health`
		if [[ $appInfo =~ "UP" ]]
		then
			echo "微服务已启动"
			return 0
		else
			echo "微服务未启动"
			return 1
		fi
	fi
	
}


# 关闭进程。参数1：微服务名称
function killPid(){
	sysInfo=`uname`
	if [[ -n $1 ]];then
		#echo "关闭微服务${1}的进程"
		serviceCofig=${serviceMapping[${1}]}
		oldIFS=$IFS
		IFS=,
		#serviceCofig=(${serviceCofig//,/ })
		serviceCofig=(${serviceCofig})
		IFS=$oldIFS

		pidFile=`ls ${PID_DIR}|grep "${serviceCofig[0]}\.pid"|awk '$1'`
		#echo "pidFile $pidFile"
		
		result=`isFileExist ${PID_DIR}/${pidFile}`
		if [ $? = 0 ];then
			pid=`cat ${PID_DIR}/${pidFile}`
			#echo $pid
			kill -9 ${pid}
			rm -fr ${PID_DIR}/${pidFile}
		fi
		
		
		#if [[ ${sysInfo} != "Linux" ]];then
		#	# 查询端口的window进程号
		#	wpid=`netstat -ano|findstr :serviceCofig[1]|findstr -v TIME_WAIT|awk '{print $2,$5}'|grep :serviceCofig[1]|awk -F ':' '{print $2}'|awk '{print $2}'`
		#	#echo $pidInfoList
		#	#for pid in $pidInfoList; do
		#	#	echo "$pid"
		#	#done	
		#fi
		
	else
		#echo "关闭所有微服务的进程"
		for key in ${!serviceMapping[@]}
		do  
			serviceCofig=${serviceMapping[${key}]}
			oldIFS=$IFS
			IFS=,
			#serviceCofig=(${serviceCofig//,/ })
			serviceCofig=(${serviceCofig})
			IFS=$oldIFS
			pidFile=`ls ${PID_DIR}|grep "${serviceCofig[0]}\.pid"|awk '$1'`
			#echo "pidFile $pidFile"
			result=`isFileExist ${PID_DIR}/${pidFile}`
			if [ $? = 0 ];then
				pid=`cat ${PID_DIR}/${pidFile}`
				#echo $pid
				kill -9 ${pid}
				rm -fr ${PID_DIR}/${pidFile}
			fi
			
			
			#if [[ ${sysInfo} != "Linux" ]];then
			#	# 查询所有java的window进程
			#	wpid=`netstat -ano|findstr :serviceCofig[1]|findstr -v TIME_WAIT|awk '{print $2,$5}'|grep :serviceCofig[1]|awk -F ':' '{print $2}'|awk '{print $2}'`
			#	#echo "$javaAllPids"
			#fi
		done
	fi
}
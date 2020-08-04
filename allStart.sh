#!/bin/bash

# 引入设置的变量
source setEnv.sh

# 引入自定义函数
source func.sh

echo "---自定义变量"
echo "------CURRENT_IP=$CURRENT_IP"
echo "------MY_JAVA_HOME=$MY_JAVA_HOME"
echo "------TMP_DIR=$TMP_DIR"
echo "------EUREKA_IP=$EUREKA_IP"
echo "------EUREKA_PORT=$EUREKA_PORT"
echo "------CONFIG_CENTER_IP=$CONFIG_CENTER_IP"
echo "------CONFIG_CENTER_PORT=$CONFIG_CENTER_PORT"
echo "------SPRING_CLOUD_CONFIG_NAME=$SPRING_CLOUD_CONFIG_NAME"
echo "------需要解密：$ENCRYPT"
echo "------------"

#如果是单个微服务启动
SINGLE_SATART_SERVICE_NAME=$1


#获取脚本当前的路径
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)

#获取jar包所在路径
SERVICE_FOLDER=$(cd $(dirname ${SCRIPT_DIR}); pwd)

echo "---开始检测运行环境有效性"

#获取日志所在路径
LOG_DIR=${SERVICE_FOLDER}/logs
result=`isDirExist $LOG_DIR 1`


#获取进程ID在路径
PID_DIR="${SERVICE_FOLDER}/.pid"
result=`isDirExist $PID_DIR 1`


#判断key文件夹是否存在
KEY_DIR="${SERVICE_FOLDER}/key"
if [[ $ENCRYPT == 1 ]]; then
	result=`isDirExist $KEY_DIR`
	if [[ $? == 2 ]]; then
		echo "------key文件夹不存在，无法启动"
		exit
	fi
fi

#验证是否安装了curl
result=`isCmdExist curl`
if [[ $? == 0 ]]; then
	echo "------curl已安装"
else
	echo "------curl未安装，无法启动"
	exit
fi


#验证是否安装了netstat
#result=`isCmdExist netstat`
#if [[ $? == 0 ]]; then
#	echo "------netstat已安装"
#else
#	echo "------netstat未安装，无法启动"
#	exit
#fi


#获取java运行环境
result=`getJavaHome "$MY_JAVA_HOME"`
if [[ $? == 0 ]]; then
	MY_JAVA_HOME=$result
	echo "------使用的JAVA运行环境为$MY_JAVA_HOME"
else
	echo "------$result"
	exit
fi

echo "------运行环境有效性检测通过"

#是否在本服务器启动eureka
START_EUREKA_ON_THIS_SERVER=1
#是否在本服务器启动配置中心
START_CONFIG_ON_THIS_SERVER=1

cd ${SERVICE_FOLDER}
# 如果只启动单个微服务
if [ -n "$SINGLE_SATART_SERVICE_NAME" ]; then

	echo "---需要单独启动$SINGLE_SATART_SERVICE_NAME微服务"

	# 验证jar文件是否存在
	result=`checkJarFileExist $SINGLE_SATART_SERVICE_NAME`
	if [[ $? == 0 ]]; then
		#微服务JAR名称（全称且不包含后缀）
		SERVICE_JAR_NAME=$result
		#echo "jar包全名：$SERVICE_JAR_NAME"

		# 获取微服务配置信息
		serviceCofig=${serviceMapping[${SINGLE_SATART_SERVICE_NAME}]}
		#echo "微服务${SINGLE_SATART_SERVICE_NAME}的配置信息：$serviceCofig"
		oldIFS=$IFS
		IFS=,
		#serviceCofig=(${serviceCofig//,/ })
		serviceCofig=(${serviceCofig})
		IFS=$oldIFS


		if [[ $ENCRYPT == 1 ]]; then
			#验证key文件是否存在
			result=`isFileExist ${KEY_DIR}/${SERVICE_JAR_NAME}.key`
			if [ $? = 1 ];then
				echo "------微服务${SINGLE_SATART_SERVICE_NAME}的key文件不存在"
				exit
			fi
		fi

		# 如果是eureka微服务，直接启动
		if [[ "${SINGLE_SATART_SERVICE_NAME}" == "${EUREKA_APPLICATION_NAME}" ]]; then
			# 关闭原eureka微服务
			pidFile="${serviceCofig[0]}.pid"
			#echo $pidFile
			result=`isFileExist ${PID_DIR}/${pidFile}`
			if [ $? = 0 ];then
				echo "------关闭原${SINGLE_SATART_SERVICE_NAME}微服务"
				#kill -9 `cat ${PID_DIR}/${pidFile}`
				#rm -fr ${PID_DIR}/${pidFile}
				killPid ${SINGLE_SATART_SERVICE_NAME}
			fi

			# 启动eureka微服务
			echo "------执行命令，开始启动eureka"
			startJar ${SINGLE_SATART_SERVICE_NAME} ${SERVICE_JAR_NAME}

			echo "------判断eureka是否启动成功"
			result=`isServiceStarted ${serviceCofig[0]} ${EUREKA_IP} ${serviceCofig[1]}`
			resultCode=$?
			while [ $resultCode -ne 0 ]
			do
				echo "---------eureka未启动，等待5秒后再次验证"
				sleep 5
				result=`isServiceStarted ${serviceCofig[0]} ${EUREKA_IP} ${serviceCofig[1]}`
				resultCode=$?

			done
			echo "------eureka启动成功"

			exit
		fi

		# 如果是配置中心微服务，需要先验证eureka微服务是否启动，然后再启动配置中心微服务
		if [[ ${SINGLE_SATART_SERVICE_NAME} == ${CONFIG_APPLICATION_NAME} ]]; then
			# 先判断eureka是否已经启动成功
			eurekaServiceCofig=${serviceMapping[${EUREKA_APPLICATION_NAME}]}
			oldIFS=$IFS
			IFS=,
			#eurekaServiceCofig=(${eurekaServiceCofig//,/ })
			eurekaServiceCofig=(${eurekaServiceCofig})
			IFS=$oldIFS
			echo "------判断eureka是否已启动"
			result=`isServiceStarted ${eurekaServiceCofig[0]} ${EUREKA_IP} ${EUREKA_PORT}`
			resultCode=$?
			if [ $resultCode -ne 0 ]
			then
				echo "---------eureka未启动，请先启动eureka微服务"
				exit
			fi
			echo "---------eureka已启动"


			# 关闭原配置中心微服务
			pidFile="${serviceCofig[0]}.pid"
			#echo $pidFile
			result=`isFileExist ${PID_DIR}/${pidFile}`
			if [ $? = 0 ];then
				echo "------关闭原${SINGLE_SATART_SERVICE_NAME}微服务"
				#kill -9 `cat ${PID_DIR}/${pidFile}`
				#rm -fr ${PID_DIR}/${pidFile}
				killPid ${SINGLE_SATART_SERVICE_NAME}
			fi


			# 再启动配置中心微服务
			echo "------执行命令，开始启动配置中心"
			
			startJar ${SINGLE_SATART_SERVICE_NAME} ${SERVICE_JAR_NAME}
			result=`isServiceStarted ${serviceCofig[0]} ${CONFIG_CENTER_IP} ${serviceCofig[1]}`
			resultCode=$?
			while [ $resultCode -ne 0 ]
			do
				echo "---------配置中心未启动，等待5秒后再次验证"
				sleep 5
				result=`isServiceStarted ${serviceCofig[0]} ${CONFIG_CENTER_IP} ${serviceCofig[1]}`
				resultCode=$?
			done
			echo "---------配置中心启动成功"

			exit
		fi

		# 如果是其他微服务，先验证eureka是否启动，再验证配置中心是否启动，最后才启动此微服务
		# 先判断eureka是否已经启动
		echo "------判断eureka是否启动成功"
		eurekaServiceCofig=${serviceMapping[${EUREKA_APPLICATION_NAME}]}
		oldIFS=$IFS
		IFS=,
		#eurekaServiceCofig=(${eurekaServiceCofig//,/ })
		eurekaServiceCofig=(${eurekaServiceCofig})
		IFS=$oldIFS

		result=`isServiceStarted ${eurekaServiceCofig[0]} ${EUREKA_IP} ${EUREKA_PORT}`
		resultCode=$?
		if [ $resultCode -ne 0 ]
		then
			echo "---------eureka未启动，请先启动eureka微服务"
			exit
		fi
		echo "---------eureka已启动"

		# 再判断配置中心是否已经启动
		echo "------判断配置中心是否启动成功"
		configServiceCofig=${serviceMapping[${CONFIG_APPLICATION_NAME}]}
		oldIFS=$IFS
		IFS=,
		#configServiceCofig=(${configServiceCofig//,/ })
		configServiceCofig=(${configServiceCofig})
		IFS=$oldIFS

		result=`isServiceStarted ${configServiceCofig[0]} ${CONFIG_CENTER_IP} ${CONFIG_CENTER_PORT}`
		resultCode=$?
		if [ $resultCode -ne 0 ]
		then
			echo "---------配置中心未启动，请先启动配置中心微服务"
			exit
		fi
		echo "---------配置中心已启动"

		# 关闭原微服务
		pidFile="${serviceCofig[0]}.pid"
		#echo $pidFile
		result=`isFileExist ${PID_DIR}/${pidFile}`
		if [ $? = 0 ];then
			echo "------关闭原${SINGLE_SATART_SERVICE_NAME}微服务"
			#kill -9 `cat ${PID_DIR}/${pidFile}`
			#rm -fr ${PID_DIR}/${pidFile}
			killPid ${SINGLE_SATART_SERVICE_NAME}
		fi


		# 最后才启动此微服务		
		echo "------执行命令，开始启动微服务${SINGLE_SATART_SERVICE_NAME}"
		startJar ${SINGLE_SATART_SERVICE_NAME} ${SERVICE_JAR_NAME}
		result=`isServiceStarted ${serviceCofig[0]} ${CURRENT_IP} ${serviceCofig[1]}`
		resultCode=$?
		while [ $resultCode -ne 0 ]
		do
			echo "---------微服务${SINGLE_SATART_SERVICE_NAME}未启动。10秒后再次检测---"
			sleep 10
			result=`isServiceStarted ${serviceCofig[0]} ${CURRENT_IP} ${serviceCofig[1]}`
			resultCode=$?
		done
		echo "---------微服务${SINGLE_SATART_SERVICE_NAME}已启动"
			
		exit
		
	else
		echo "------$result"
		exit
	fi
	exit
else
	echo "---验证微服务可运行jar包的唯一性"
	#查找是否有eureka-server的jar包。如果没有，则结束此脚本执行。
	result=`checkJarFileExist $EUREKA_APPLICATION_NAME`
	#echo $result
	if [ $? = 0 ];then
		#echo "------微服务$EUREKA_APPLICATION_NAME存在唯一的运行jar包${result}.jar"
		EUREKA_JAR_NAME=${result}
	elif 	[ $? = 1 ];then
		#如果没有找到eureka的jar包，有可能是eureka服务在其他的服务器上。所以，需要去验证eureka是否启动，如果启动了，则继续后续的判断。如果没启动，则返回错误信息。
		
		# 判断eureka是否已经启动成功
		eurekaServiceCofig=${serviceMapping[${EUREKA_APPLICATION_NAME}]}
		oldIFS=$IFS
		IFS=,
		eurekaServiceCofig=(${eurekaServiceCofig})
		IFS=$oldIFS
		#echo "------未查找到eureka的jar包，判断eureka是否在其他服务器已启动"
		r=`isServiceStarted ${eurekaServiceCofig[0]} ${EUREKA_IP} ${EUREKA_PORT}`
		if [ $? -ne 0 ];then
			echo "------$result"
			exit
		else
			START_EUREKA_ON_THIS_SERVER=0
			#echo "------eureka已在${EUREKA_IP}启动"
		fi
	else
		echo "------$result"
		exit
	fi
	EUREKA_JAR_NAME_PRE=`getServiceJarNamePre $EUREKA_APPLICATION_NAME`


	#查找是否有config-center的jar包。如果没有，则结束此脚本执行。
	result=`checkJarFileExist $CONFIG_APPLICATION_NAME`
	if [ $? = 0 ];then
		#echo "------微服务$CONFIG_APPLICATION_NAME存在唯一的运行jar包${result}.jar"
		CONFIG_JAR_NAME=${result}
	#echo $result
	elif [ $? = 1 ];then
		#如果没有找到config的jar包，有可能是config服务在其他的服务器上。所以，需要去验证config是否启动，如果启动了，则继续后续的判断。如果没启动，则返回错误信息。
		# 判断config-center是否已经启动成功
		configServiceCofig=${serviceMapping[${CONFIG_APPLICATION_NAME}]}
		oldIFS=$IFS
		IFS=,
		configServiceCofig=(${configServiceCofig})
		IFS=$oldIFS
		#echo "------未查找到eureka的jar包，判断eureka是否在其他服务器已启动"
		r=`isServiceStarted ${configServiceCofig[0]} ${CONFIG_CENTER_IP} ${CONFIG_CENTER_PORT}`
		if [ $? -ne 0 ];then
			echo "------$result"
			exit
		else
			START_CONFIG_ON_THIS_SERVER=0
		#	echo "------config-center已在${CONFIG_CENTER_IP}启动"
		fi
	else
		echo "---$result"
		exit
	fi
	CONFIG_JAR_NAME_PRE=`getServiceJarNamePre $CONFIG_APPLICATION_NAME`


	#获取需要运行的jar包。排除eurake和config
	cd ${SERVICE_FOLDER}
	OTHER_JARS=`ls |grep '.*\.jar$'|grep -v ^${CONFIG_JAR_NAME_PRE}.*\.jar$|grep -v ^${EUREKA_JAR_NAME_PRE}.*\.jar$|awk '$1'`
	#echo $OTHER_JARS

	#获取微服务名和jar包全名的映射
	declare -A serviceAllJarNameMap
	JAR_NAMES=""
	for otherJar in $OTHER_JARS; do
	    	#echo $otherJar
		#echo ${otherJar%%.jar*}
		#echo $i 
		#echo ${otherJar%%.jar*}
		JAR_NAMES=${JAR_NAMES}" "${otherJar%%.jar*}
		for key in ${!serviceMapping[@]} 
		do
			#echo $key
			#echo ${otherJar%%.jar*}
			#echo ${serviceMapping[$key]}
			theServiceJarNamePre=`getServiceJarNamePre $key`
			if [[ ${otherJar%%.jar*} =~ ^${theServiceJarNamePre}.* ]]
			then
				if [[ -n ${serviceAllJarNameMap["$key"]} ]]; then
					echo "------微服务${key}存在多个jar包，无法启动"
					exit
				fi
				serviceAllJarNameMap["$key"]=${otherJar%%.jar*};
			fi
		done
	done
	echo "------微服务可运行jar包的唯一性验证通过"


	cd ${SERVICE_FOLDER}

	if [[ $ENCRYPT == 1 ]]; then
		echo "---验证微服务的key文件有效性"
		result=`isFileExist ${KEY_DIR}/${EUREKA_JAR_NAME}.key`
		if [ $? = 1 ];then
			echo "------微服务${EUREKA_APPLICATION_NAME}的key文件不存在"
			exit
		fi
		result=`isFileExist ${KEY_DIR}/${CONFIG_JAR_NAME}.key`
		if [ $? = 1 ];then
			echo "------微服务${CONFIG_APPLICATION_NAME}的key文件不存在"
			exit
		fi

		failKeyFileValidate=0
		for key in ${!serviceAllJarNameMap[@]}; do
			keyFile=${KEY_DIR}/${serviceAllJarNameMap[$key]}.key
			#echo $keyFile
			if [[ ! -f "$keyFile" ]];then
				echo "------${jarName}的key文件不存在"
				failKeyFileValidate=1
			fi
		done
		if [[ failKeyFileValidate -eq 1 ]]; then
			echo "------key文件验证失败，无法启动"
			exit
		else
			echo "------key文件验证通过"
		fi
	fi



	echo "---开始关闭原来的微服务"
	#source ${SCRIPT_DIR}/allStop.sh
	killPid
	echo "------已关闭原来的微服务"

	cd ${SERVICE_FOLDER}
	echo "---开始启动微服务"
	
	if [ $START_EUREKA_ON_THIS_SERVER = 1 ];then
		echo "------执行命令，开始启动eureka"
		serviceCofig=${serviceMapping[${EUREKA_APPLICATION_NAME}]}
		oldIFS=$IFS
		IFS=,
		#serviceCofig=(${serviceCofig//,/ })
		serviceCofig=(${serviceCofig})
		IFS=$oldIFS

		startJar ${EUREKA_APPLICATION_NAME} ${EUREKA_JAR_NAME}

		echo "------判断eureka是否启动成功"
		result=`isServiceStarted ${serviceCofig[0]} ${EUREKA_IP} ${serviceCofig[1]}`
		resultCode=$?
		while [ $resultCode -ne 0 ]
		do
			echo "---------eureka未启动，等待5秒后再次验证"
			sleep 5
			result=`isServiceStarted ${serviceCofig[0]} ${EUREKA_IP} ${serviceCofig[1]}`
			resultCode=$?

		done
		echo "------eureka启动成功"
	fi

	if [ $START_CONFIG_ON_THIS_SERVER = 1 ];then
		echo "------执行命令，开始启动配置中心"
		serviceCofig=${serviceMapping[${CONFIG_APPLICATION_NAME}]}
		oldIFS=$IFS
		IFS=,
		#serviceCofig=(${serviceCofig//,/ })
		serviceCofig=(${serviceCofig})
		IFS=$oldIFS
		startJar ${CONFIG_APPLICATION_NAME} ${CONFIG_JAR_NAME}

		result=`isServiceStarted ${serviceCofig[0]} ${CONFIG_CENTER_IP} ${serviceCofig[1]}`
		resultCode=$?
		while [ $resultCode -ne 0 ]
		do
			echo "---------配置中心未启动，等待5秒后再次验证"
			sleep 5
			result=`isServiceStarted ${serviceCofig[0]} ${CONFIG_CENTER_IP} ${serviceCofig[1]}`
			resultCode=$?
		done
		echo "------配置中心启动成功"
	fi

	for key in ${!serviceAllJarNameMap[@]}; do
		echo "------执行命令，开始启动微服务${key}"
		jarName=${serviceAllJarNameMap[$key]}
		startJar ${key} ${jarName}
	done

	#echo ${serviceAllJarNameMap[@]}
	#echo ${#serviceAllJarNameMap[@]}

	while [ ${#serviceAllJarNameMap[@]} -gt 0 ]
	do
		for key in ${!serviceAllJarNameMap[@]}  
		do  
			serviceCofig=${serviceMapping[${key}]}
			oldIFS=$IFS
			IFS=,
			#serviceCofig=(${serviceCofig//,/ })
			serviceCofig=(${serviceCofig})
			IFS=$oldIFS

			result=`isServiceStarted ${serviceCofig[0]} ${CURRENT_IP} ${serviceCofig[1]}`
			if [[ $? == 0 ]]; then
				echo "---------微服务${key}已启动"
				unset serviceAllJarNameMap[$key]
			else
				echo "---------微服务${key}未启动"
			fi
		done
		
		if [ ${#serviceAllJarNameMap[@]} -gt 0 ]
		then
			echo "---------剩余未启动微服务: ${!serviceAllJarNameMap[@]}。10秒后再次检测---"
			sleep 10
		fi
	done

	echo "------所有微服务启动成功"	
fi
#!/bin/bash
# 多账号并发,不定时
# 变量：要运行的脚本$SCRIPT
# 默认随机延迟5-12秒
# DD_BOT_SECRET_SPEC：特别推送
# DD_BOT_TOKEN_SPEC：特别推送
# 通过 `test.sh jd.js delay 2` 指定延迟时间
# `test.sh jd.js 00:00:12 2` 通过时间，指定脚本 运行时间 和 延迟时间（默认为0）
# `test.sh jd.js 12 2` 通过分钟（小于等于十分钟，需要设置定时在上一个小时触发），指定脚本 运行时间 和 延迟时间（默认为0）
# 版本：v3.13

# set -e

## 导入通用变量与函数
dir_shell=/ql/shell
. $dir_shell/share.sh
. $dir_shell/api.sh

SCRIPT="$1"

SKD="$2"
# 延迟时间设置
DELAY="$3"

# VIP人数，默认前面的账号
VIPS=${JD_SH_VIP:-0}
SCRIPT_NAME=`echo "${SCRIPT}" | awk -F "." '{print $1}'`
SHARECODE_ENV=${SCRIPT_NAME}_code

home="/ql"
# 助力码文件目录
SHCD_DIR="${home}/sharecode"

# 脚本文件初始目录
SCRIPT_DIR="${home}/scripts"

# 推送脚本
NOTIFY_SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}_run_sendNotify.js"
NOTIFY_SCRIPT_SPEC="${SCRIPT_DIR}/${SCRIPT_NAME}_run_sendNotify_spec.js"

LOG="${SHCD_DIR}/${SCRIPT_NAME}.log"
MSG_DIR="${home}/JDmsg"
NOTIFY_CONF="${MSG_DIR}/${SCRIPT_NAME}_dt.conf"

# 推送JS
NOTIFY_JS="${SCRIPT_DIR}/${SCRIPT_NAME}_sendNotify.js"
NOTIFY_JS_RETURN="${SCRIPT_DIR}/${SCRIPT_NAME}_return_sendNotify.js"

[ ! -d ${SHCD_DIR} ] && mkdir ${SHCD_DIR}
[ ! -d ${MSG_DIR} ] && mkdir ${MSG_DIR}

# 准点触发
act_by_min(){
    min=${1}
    if [ ! -n `echo $min | grep ":"` ]; then
	hour=`date +%H`
	if [ $min -le 10 ]; then
		hour=$((hour + 1))
		[ "$hour" = "24" ] && hour="00"
	fi
	timer="${hour}:${min}:00"
    fi
    [ "$timer" = "00:00:00" ] && nextdate=`date +%s%N -d "+1 day $timer"` || nextdate=`date +%s%N -d "$timer"`
    echo $nextdate
}

# 修改文件
modify_scripts(){
	cd ${SCRIPT_DIR}
	if [ -n "$SYNCURL" ]; then
    	echo "下载脚本"
	    curl "$SYNCURL" > ./${SCRIPT}
    	# 外链脚本替换
	    sed -i "s/indexOf('GITHUB')/indexOf('GOGOGOGO')/g" `ls -l | grep -v ^d | awk '{print $9}'`
    	sed -i 's/indexOf("GITHUB")/indexOf("GOGOGOGO")/g' `ls -l | grep -v ^d | awk '{print $9}'`
	fi
	[ ! -e "./$SCRIPT" ] && echo "脚本不存在" && exit 0
	
	echo "修改发送方式"

    # 备份
	cp -f ${SCRIPT_DIR}/${SCRIPT} ${SCRIPT_DIR}/${SCRIPT_NAME}_tmp.js

	if [ -n "$DD_BOT_TOKEN_SPEC" -a -n "$DD_BOT_SECRET_SPEC" ]; then
        #修改常规推送
	    cat > ${NOTIFY_SCRIPT} <<EOF
notify = require('${NOTIFY_JS}');
fs = require('fs');
var data = fs.readFileSync('${NOTIFY_CONF}');
var name = fs.readFileSync('${NOTIFY_CONF}name');
notify.sendNotify(name, data.toString());
EOF
        #修改特别推送
	    cat > ${NOTIFY_SCRIPT_SPEC} <<EOT
notify = require('${NOTIFY_JS}');
fs = require('fs');
var data = fs.readFileSync('${NOTIFY_CONF}spec');
var name = fs.readFileSync('${NOTIFY_CONF}name');
notify.sendNotify(name, data.toString());
EOT
    fi
    # 推送js复制
    cp -f ${SCRIPT_DIR}/sendNotify.js ${NOTIFY_JS}
    cp -f ${SCRIPT_DIR}/sendNotify.js ${NOTIFY_JS_RETURN}
    sed -i 's/text = text.match/\/\/text = text.match/g' ${NOTIFY_JS_RETURN}

    # 删除旧消息
    rm -f ${NOTIFY_CONF}*

    sed -i "s/desp += author/\/\/desp += author/g" ${NOTIFY_JS}
	  sed -i "/text = text.match/a   var fs = require('fs');fs.writeFile(\"${NOTIFY_CONF}name\", text + \"\\\n\", function(err) {if(err) {return console.log(err);}});fs.appendFile(\"${NOTIFY_CONF}\" + new Date().getTime(), desp + \"\\\n\", function(err) {if(err) {return console.log(err);}});\n  return" ${NOTIFY_JS_RETURN}
    sed -i "s#.\/sendNotify#${NOTIFY_JS_RETURN}#g" ${SCRIPT_DIR}/${SCRIPT_NAME}_tmp.js
    [ ! -e "./$SCRIPT" ] && echo "脚本不存在" && exit 0
}

# 格式化助力码到文本
format_sc2txt(){
# $1 助力码文件
# $2 助力码文本生成位置
    sc_file=$1
    fsr_file=$2
    #${SCRIPT_NAME}.conf
    [ ! -e "$sc_file" ] && return 0
    sc_list=(`cat "$sc_file" | while read LINE; do echo $LINE; done | awk -F "】" '{print $2}'`)
    sc_vip_list=(`echo ${sc_list[*]:0:VIPS}`)
    nums_of_user=`echo ${#sc_list[*]}`
    sc_normal_list=(`echo ${sc_list[*]:VIPS:nums_of_user}`)
    for e in `seq 1 ${#sc_list[*]}`
    do 
        if [ $((VIPS-0)) -ge $e ]; then
            sc_vip_list+=(${sc_vip_list[0]})
            unset sc_vip_list[0]
            sc_vip_list=(${sc_vip_list[*]})
        else
            sc_normal_list+=(${sc_normal_list[0]})
            unset sc_normal_list[0]
            sc_normal_list=(${sc_normal_list[*]})
        fi
        final_sc_list=(`echo ${sc_vip_list[*]} ${sc_normal_list[*]}`)
	
        if [ $e -eq 1 ]; then
            echo ${final_sc_list[*]:0} | awk '{for(i=1;i<=NF;i++) {if(i==NF) print $i;else printf $i"@"}}' > $fsr_file
        else
            echo ${final_sc_list[*]:0} | awk '{for(i=1;i<=NF;i++) {if(i==NF) print $i;else printf $i"@"}}' >> $fsr_file
        fi
    done
    if [ -n `echo "$JD_COOKIE" | grep "&"` ]; then
	    JK_LIST=(`echo "$JD_COOKIE" | awk -F "&" '{for(i=1;i<=NF;i++) print $i}'`)
    else
	    JK_LIST=(`echo "$JD_COOKIE" | awk -F "$" '{for(i=1;i<=NF;i++){{if(length($i)!=0) print $i}}'`)
    fi
    # 新账号第一次优先助力前面的账号
    if [ -n "$JK_LIST" ]; then
        diff=$((${#JK_LIST[*]}-${#sc_list[*]}))
        for e in `seq 1 $diff`
        do 
            sc_list+=(${sc_list[0]})
            unset sc_list[0]
            sc_list=(${sc_list[*]})
            echo ${sc_list[*]:0} | awk '{for(i=1;i<=NF;i++) {if(i==NF) print $i;else printf $i"@"}}' >> $fsr_file
        done
    fi
}

# 修改助力码环境变量
autoHelp_env(){
# $1 脚本文件
# $2 助力码文件所在
# $3 cookie顺序
    local sr_file=$1
    local sc_file=$2
    local jk_ordr=$3
    local f_shcode=""
    
    [ ! -e "$sc_file" ] && return 0
    f_shcode="$f_shcode""'""`cat $sc_file | head -n $jk_ordr | tail -n 1`""',""\n"
    
    export ${SHARECODE_ENV}="${f_shcode}"
}

autoHelp(){
# 添加助力码
# $1 脚本文件
    local sr_file=$1
    sed -i "s/let shareCodes = \[/let shareCodes = \[\n${SHARECODE_ENV}/g" "$sr_file"
    sed -i "s/const inviteCodes = \[/const inviteCodes = \[\n${SHARECODE_ENV}/g" "$sr_file"
    sed -i "s/let inviteCodes = \[/let inviteCodes = \[\n${SHARECODE_ENV}/g" "$sr_file"
    
    autoHelp_spec $sr_file "jd_plantBean" "PlantBeanShareCodes" "jdPlantBeanShareCodes"
    autoHelp_spec $sr_file "jd_pet" "PetShareCodes" "jdPetShareCodes"
    autoHelp_spec $sr_file "jd_fruit" "FruitShareCodes" "jdFruitShareCodes"
    autoHelp_spec $sr_file "jd_dreamFactory" "shareCodes" "jdDreamFactoryShareCodes"
    autoHelp_spec $sr_file "jd_jdfactory" "shareCodes" "jdFactoryShareCodes"
}

autoHelp_spec(){
# 修改助力码特别版
    if [ $(echo "$1" | grep $2)x != ""x ]; then
        cp -f "${SCRIPT_DIR}/${4}.js" "${SCRIPT_DIR}/${4}.sharebak_${SCRIPT_NAME}"
        sed -i "s/let $3 =/let ${3}_abandon =/g" "${SCRIPT_DIR}/${4}.js"
        sed -i "/let ${3}_abandon/i\let ${3} = \[\]" "${SCRIPT_DIR}/${4}.js"
    fi
}

# 收集助力码
collectSharecode(){
    log_file=${1}
    echo "${log_file}：收集新助力码"
    code=`sed -n '/'码】'.*/'p ${log_file}`
    ret=""
    if [ -z "$code" ]; then
        activity=`sed -n '/配置文件.*/'p "${log_file}" | awk -F "获取" '{print $2}' | awk -F "配置" '{print $1}'`
        name=(`sed -n '/'【京东账号'.*/'p "${log_file}" | grep "开始" | awk -F "开始" '{print $2}' |sed 's/】/（/g'| awk -v ac="$activity" -F "*" '{print $1"）" ac "好友助力码】"}'`)
        # 相邻重复去重
	code=(`sed -n '/'您的好友助力码为'.*/'p ${log_file} | awk '{print $2}' | uniq`)
        [ -z "$code" ] && code=(`sed -n '/'好友助力码'.*/'p ${log_file} | awk -F "：" '{print $2}' | uniq`)
        [ -z "$code" ] && return
	
        for i in `seq 0 $((${#name[*]}-1))`
        do 
            [ -n "${code[i]}" ] && ret+=`echo "${name[i]}""${code[i]}"` + "\n"
        done
    else
        ret=`echo $code | awk '{for(i=1;i<=NF;i++)print $i}'`
    fi
    echo $ret
    
}

# 任务函数
do_task(){
    local jk="$1"
    local num=$2
    
    autoHelp_env "${SCRIPT_DIR}/${SCRIPT_NAME}_tmp.js" "${SHCD_DIR}/${SCRIPT_NAME}.log" $num
    export JD_COOKIE="$jk"

    (node ${SCRIPT_DIR}/${SCRIPT_NAME}_tmp.js  | grep -Ev "pt_pin|pt_key") >&1 | tee "${log_path}${num}"

    # 随机延迟5-12秒
    random_time=$(($RANDOM%12+5))
    delay=${DELAY:-$random_time}
    echo "随机延迟${delay}秒"
    sleep ${delay}s
}

# 清除连续空行为一行和首尾空行
blank_lines2blank_line(){
	# $1: 文件名
    # 删除连续空行为一行
    cat -s $1 > $1.bk
    mv -f $1.bk $1
    #清除文首文末空行
    [ "$(cat $1 | head -n 1)"x = ""x ] && sed -i '1d' $1
    [ "$(cat $1 | tail -n 1)"x = ""x ] && sed -i '$d' $1
}

# 判断是否需要特别推送
specify_send(){
  ret=`cat $1 | grep "提醒\|已超时\|已可兑换\|已失效\|重新登录\|已可领取\|未选择商品\|兑换地址\|未继续领养"`
  [ -n "$ret" ] && echo 1 || echo 0
}

# 传入需要的环境变量
deliver_env(){
	env_var=(`cat $1 | grep process.env | awk -F "." '{print $3}' | awk '{print $1}' | awk -F ";|)" '{print $1}' | grep "_" | sort -u | uniq`)
	for var in ${env_var[*]}
	do
		val=`eval echo '$'{$var}`
		[ -n $val ] && sed -i "s/let $var = ''/let ${var} = '${val}'/g" $1
	done
}

# 主函数
main(){
	[ -z "$SCRIPT" ] && echo "参数错误，需指定要运行的脚本"
	
	log_time=$(date "+%Y-%m-%d-%H-%M-%S")
	log_dir_tmp="${SCRIPT_NAME##*/}"
	log_dir="$dir_log/${log_dir_tmp%%.*}"
	log_path="$log_dir/$log_time.log.tmp"
	make_dir "$log_dir"
	
	modify_scripts

	echo "开始多账号并发"
	IFS=$'\n'

	format_sc2txt "${SHCD_DIR}/${SCRIPT_NAME}.log" "${home}/${SCRIPT_NAME}.conf"
	autoHelp "${SCRIPT_DIR}/${SCRIPT_NAME}_tmp.js"
	
	# 兼容 换行 和 & 分割cookie
	if [ -n `echo "$JD_COOKIE" | grep "&"` ]; then
		JK_LIST=(`echo "$JD_COOKIE" | awk -F "&" '{for(i=1;i<=NF;i++) print $i}'`)
	else
		JK_LIST=(`echo "$JD_COOKIE" | awk -F "$" '{for(i=1;i<=NF;i++){{if(length($i)!=0) print $i}}'`)
	fi
  # 判断下载jd_dailybonus
	if [[ $SCRIPT == *jd_bean_sign.js ]]; then
      curl -k -s -o  ${SCRIPT_DIR}/JD_DailyBonus.js --connect-timeout 10 --retry 3 https://raw.githubusercontent.com/NobyDa/Script/master/JD-DailyBonus/JD_DailyBonus.js
  fi
  
	for jkl in `seq 1 ${#JK_LIST[*]}`
	do
		do_task ${JK_LIST[$((jkl-1))]} $jkl &
	done
	
	echo "有账号" ${#JK_LIST[*]}
	unset IFS

	wait
  
	# 助力码
	for num in `seq 1 ${#JK_LIST[*]}`
	do  
		local share_code=`collectSharecode "${log_path}${num}"`
		[ "${share_code}"x != ""x ] && echo ${share_code} | sed  "s/账号[0-9]/账号$n/g" | sed "s/京东号 [0-9]/京东号$n/g" >> ${LOG}
	done

	echo "推送消息"
	sed -i 's/text}\\n\\n/text}\\n/g' ${NOTIFY_JS}
	sed -i 's/\\n\\n本脚本/\\n本脚本/g' ${NOTIFY_JS}
	sed -i 's/text = text.match/\/\/text = text.match/g' ${NOTIFY_JS}
	
	# 传递变量
	deliver_env ${NOTIFY_JS}

	# 整合推送消息
	IFS=$'\n'
	for n in `ls ${MSG_DIR} | grep ${SCRIPT_NAME}_dt.conf | grep -v ${SCRIPT_NAME}_dt.confname`
	do
		echo "正在处理${MSG_DIR}/${n}文本"
		if [ $(specify_send ${MSG_DIR}/${n}) -eq 0 ];then
			cat ${MSG_DIR}/${n} >> ${NOTIFY_CONF}
		else
			cat ${MSG_DIR}/${n} >> ${NOTIFY_CONF}spec
		fi
		# 清空文件
		rm -f ${MSG_DIR}/${n}
	done
	unset IFS

	if [ -e ${NOTIFY_CONF} -a -n "$(cat ${NOTIFY_CONF} 2>&1 | sed '/^$/d')" ]; then
		blank_lines2blank_line  ${NOTIFY_CONF}
		blank_lines2blank_line  ${NOTIFY_CONF}name
		cat ${NOTIFY_CONF}
		node ${NOTIFY_SCRIPT}
	fi
	# 特殊推送
	if [ -e ${NOTIFY_CONF}spec -a -n "$(cat ${NOTIFY_CONF}spec 2>&1 | sed '/^$/d')" ]; then
		blank_lines2blank_line  ${NOTIFY_CONF}spec
		blank_lines2blank_line  ${NOTIFY_CONF}name
		cat ${NOTIFY_CONF}spec
		if [ -n "$DD_BOT_TOKEN_SPEC" -a -n "$DD_BOT_SECRET_SPEC" ]; then
        sed -i "s/DD_BOT_TOKEN/DD_BOT_TOKEN_SPEC/g" ${NOTIFY_JS}
        sed -i "s/DD_BOT_SECRET/DD_BOT_SECRET_SPEC/g" ${NOTIFY_JS}
        sed -i "s/let DD_BOT_TOKEN_SPEC/let DD_BOT_TOKEN_SPEC_OLD/g" ${NOTIFY_JS}
        sed -i "s/let DD_BOT_SECRET_SPEC/let DD_BOT_SECRET_SPEC_OLD/g" ${NOTIFY_JS}
        sed -i "/let DD_BOT_TOKEN_SPEC_OLD/a let DD_BOT_TOKEN_SPEC = '${DD_BOT_TOKEN_SPEC}'" ${NOTIFY_JS}
        sed -i "/let DD_BOT_SECRET_SPEC_OLD/a let DD_BOT_SECRET_SPEC = '${DD_BOT_SECRET_SPEC}'" ${NOTIFY_JS}
		fi
		node ${NOTIFY_SCRIPT_SPEC}
	fi
	
	echo "删除旧文件"
	rm -f ${SCRIPT_DIR}/${SCRIPT_NAME}_tmp.js
	rm -f ${NOTIFY_JS}
	rm -f ${NOTIFY_JS_RETURN}
	rm -f ${NOTIFY_SCRIPT}
	rm -f ${NOTIFY_SCRIPT_SPEC}
	rm -f ${log_path}
	share_code_file=`ls ${SCRIPT_DIR} | grep "\.sharebak" | grep "${SCRIPT_NAME}" | awk -F ".sharebak" '{print $1}'`
	bk_file_prefix="${SCRIPT_DIR}/${share_code_file}"
	[ -n "$share_code_file" ] && cp -f "${bk_file_prefix}.sharebak_${SCRIPT_NAME}" "${bk_file_prefix}.js" && rm -f "${bk_file_prefix}.sharebak_${SCRIPT_NAME}"
}


main 

#!/usr/bin/env bash

## 导入通用变量与函数
dir_shell=/ql/shell
. $dir_shell/share.sh
. $dir_shell/api.sh

## 选择python3还是node
define_program() {
    local first_param=$1
    if [[ $first_param == *.js ]]; then
        which_program="node"
    elif [[ $first_param == *.py ]]; then
        which_program="python3"
    elif [[ $first_param == *.sh ]]; then
        which_program="bash"
    elif [[ $first_param == *.ts ]]; then
        which_program="ts-node-transpile-only"
    else
        which_program=""
    fi
}

random_delay() {
    local random_delay_max=$RandomDelay
    if [[ $random_delay_max ]] && [[ $random_delay_max -gt 0 ]]; then
        local current_min=$(date "+%-M")
        if [[ $current_min -ne 0 ]] && [[ $current_min -ne 30 ]]; then
            delay_second=$(($(gen_random_num $random_delay_max) + 1))
            echo -e "\n命令未添加 \"now\"，随机延迟 $delay_second 秒后再执行任务，如需立即终止，请按 CTRL+C...\n"
            sleep $delay_second
        fi
    fi
}

## scripts目录下所有可运行脚本数组
gen_array_scripts() {
    local dir_current=$(pwd)
    local i="-1"
    cd $dir_scripts
    for file in $(ls); do
        if [ -f $file ] && [[ $file == *.js && $file != sendNotify.js ]]; then
            let i++
            array_scripts[i]=$(echo "$file" | perl -pe "s|$dir_scripts/||g")
            array_scripts_name[i]=$(grep "new Env" $file | awk -F "'|\"" '{print $2}' | head -1)
            [[ -z ${array_scripts_name[i]} ]] && array_scripts_name[i]="<未识别出活动名称>"
        fi
    done
    cd $dir_current
}

## 使用说明
usage() {
    define_cmd
    gen_array_scripts
    echo -e "task命令运行本程序自动添加进crontab的脚本，需要输入脚本的绝对路径或去掉 “$dir_scripts/” 目录后的相对路径（定时任务中请写作相对路径），用法为："
    echo -e "1.$cmd_task <file_name>                  # 依次执行，如果设置了随机延迟，将随机延迟一定秒数"
    echo -e "2.$cmd_task <file_name> now              # 依次执行，无论是否设置了随机延迟，均立即运行，前台会输出日志，同时记录在日志文件中"
    echo -e "3.$cmd_task <file_name> conc <环境变量名>  # 并发执行，无论是否设置了随机延迟，均立即运行，前台不产生日志，直接记录在日志文件中"
    if [[ ${#array_scripts[*]} -gt 0 ]]; then
        echo -e "\n当前有以下脚本可以运行:"
        for ((i = 0; i < ${#array_scripts[*]}; i++)); do
            echo -e "$(($i + 1)). ${array_scripts_name[i]}：${array_scripts[i]}"
        done
    else
        echo -e "\n暂无脚本可以执行"
    fi
}

## run nohup，$1：文件名，不含路径，带后缀
run_nohup() {
    local file_name=$1
    nohup node $file_name &>$log_path &
}

## 正常运行单个脚本，$1：传入参数
run_normal() {
    local first_param=$1
    cd $dir_scripts
    define_program "$first_param"
    if [[ $first_param == *.js ]]; then
        if [[ $# -eq 1 ]]; then
            random_delay
        fi
    fi
    log_time=$(date "+%Y-%m-%d-%H-%M-%S")
    log_dir_tmp="${first_param##*/}"
    log_dir="$dir_log/${log_dir_tmp%%.*}"
    log_path="$log_dir/$log_time.log"
    cmd=">> $log_path 2>&1"
    [[ "$show_log" == "true" ]] && cmd=""
    make_dir "$log_dir"

    local begin_time=$(date '+%Y-%m-%d %H:%M:%S')
    eval echo -e "\#\# 开始执行... $begin_time\\\n" $cmd
    [[ -f $task_error_log_path ]] && eval cat $task_error_log_path $cmd

    local id=$(cat $list_crontab_user | grep -E "$cmd_task $first_param" | perl -pe "s|.*ID=(.*) $cmd_task $first_param\.*|\1|" | head -1 | awk -F " " '{print $1}')
    [[ $id ]] && update_cron "\"$id\"" "0" "$$" "$log_path"

    eval . $file_task_before "$@" $cmd
    if [[ $first_param == *.js || $first_param == *.py ]]; then
        chmod 755 ${dir_shell}/run_scripts.sh
        eval timeout -k 10s $command_timeout_time ${dir_shell}/run_scripts.sh $first_param 2>&1 | tee $log_path
    else
        eval timeout -k 10s $command_timeout_time $which_program $first_param $cmd
    fi

    eval . $file_task_after "$@" $cmd
    [[ $id ]] && update_cron "\"$id\"" "1" "" "$log_path"
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local diff_time=$(($(date +%s -d "$end_time") - $(date +%s -d "$begin_time")))
    eval echo -e "\\\n\#\# 执行结束... $end_time  耗时 $diff_time 秒" $cmd
}

## 并发执行时，设定的 RandomDelay 不会生效，即所有任务立即执行
run_concurrent() {
    local first_param=$1
    local third_param=$3
    if [[ ! $third_param ]]; then
        echo -e "\n 缺少并发运行的环境变量参数"
        exit 1
    fi

    cd $dir_scripts
    define_program "$first_param"
    log_time=$(date "+%Y-%m-%d-%H-%M-%S")
    log_dir_tmp="${first_param##*/}"
    log_dir="$dir_log/${log_dir_tmp%%.*}"
    log_path="$log_dir/$log_time.log"
    cmd=">> $log_path 2>&1"
    [[ "$show_log" == "true" ]] && cmd=""
    make_dir $log_dir

    local begin_time=$(date '+%Y-%m-%d %H:%M:%S')
    eval echo -e "\#\# 开始执行... $begin_time\\\n" $cmd
    [[ -f $task_error_log_path ]] && eval cat $task_error_log_path $cmd

    local id=$(cat $list_crontab_user | grep -E "$cmd_task $first_param" | perl -pe "s|.*ID=(.*) $cmd_task $first_param\.*|\1|" | head -1 | awk -F " " '{print $1}')
    [[ $id ]] && update_cron "\"$id\"" "0" "$$" "$log_path"
    eval . $file_task_before "$@" $cmd

    local envs=$(eval echo "\$${third_param}")
    local array=($(echo $envs | sed 's/&/ /g'))
    single_log_time=$(date "+%Y-%m-%d-%H-%M-%S.%N")
    if [[ $first_param == *.js || $third_param == "JD_COOKIE" ]]; then
        chmod 755 ${dir_shell}/concurrency.sh
        eval timeout -k 10s $command_timeout_time ${dir_shell}/concurrency.sh $first_param 2>&1 | tee $log_path
    else
        for i in "${!array[@]}"; do
            export ${third_param}=${array[i]}
            single_log_path="$log_dir/${single_log_time}_$((i + 1)).log"
            timeout -k 10s $command_timeout_time $which_program $first_param &>$single_log_path &
        done

        wait
        for i in "${!array[@]}"; do
            single_log_path="$log_dir/${single_log_time}_$((i + 1)).log"
            eval cat $single_log_path $cmd
            [ -f $single_log_path ] && rm -f $single_log_path
        done
     fi

    eval . $file_task_after "$@" $cmd
    [[ $id ]] && update_cron "\"$id\"" "1" "" "$log_path"
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local diff_time=$(($(date +%s -d "$end_time") - $(date +%s -d "$begin_time")))
    eval echo -e "\\\n\#\# 执行结束... $end_time  耗时 $diff_time 秒" $cmd
}

## 运行其他命令
run_else() {
    local log_time=$(date "+%Y-%m-%d-%H-%M-%S")
    local log_dir_tmp="${1##*/}"
    local log_dir="$dir_log/${log_dir_tmp%%.*}"
    log_path="$log_dir/$log_time.log"
    cmd=">> $log_path 2>&1"
    [[ "$show_log" == "true" ]] && cmd=""
    make_dir "$log_dir"

    local begin_time=$(date '+%Y-%m-%d %H:%M:%S')
    eval echo -e "\#\# 开始执行... $begin_time\\\n" $cmd
    [[ -f $task_error_log_path ]] && eval cat $task_error_log_path $cmd

    local id=$(cat $list_crontab_user | grep -E "$cmd_task $first_param" | perl -pe "s|.*ID=(.*) $cmd_task $first_param\.*|\1|" | head -1 | awk -F " " '{print $1}')
    [[ $id ]] && update_cron "\"$id\"" "0" "$$" "$log_path"
    eval . $file_task_before "$@" $cmd

    eval timeout -k 10s $command_timeout_time "$@" $cmd

    eval . $file_task_after "$@" $cmd
    [[ $id ]] && update_cron "\"$id\"" "1" "" "$log_path"
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local diff_time=$(($(date +%s -d "$end_time") - $(date +%s -d "$begin_time")))
    eval echo -e "\\\n\#\# 执行结束... $end_time  耗时 $diff_time 秒" $cmd
}

## 命令检测
main() {
    show_log="false"
    while getopts ":l" opt
    do
        case $opt in
            l)
                show_log="true"
                ;;
        esac
    done
    [[ "$show_log" == "true" ]] && shift $(($OPTIND - 1))

    if [[ $1 == *.js ]] || [[ $1 == *.py ]] || [[ $1 == *.sh ]] || [[ $1 == *.ts ]]; then
        case $# in
        1)
            run_normal $1
            ;;
        2 | 3)
            case $2 in
            now)
                run_normal $1 $2
                ;;
            conc)
                run_concurrent $1 $2 $3
                ;;
            *)
                run_else "$@"
                ;;
            esac
            ;;
        *)
            run_else "$@"
            ;;
        esac
        [[ -f $log_path ]] && cat $log_path
    elif [[ $# -eq 0 ]]; then
        echo
        usage
    else
        run_else "$@"
    fi
}

main "$@"

exit 0

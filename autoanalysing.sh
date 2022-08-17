#!/bin/sh
# 脚本的目的是自动化解析ips，简化CrashSymbolicator.py和symbolicatecrash流程
# 
# 该脚本使用方法
# step 1. 在用户工作区目录新建文件夹，比如AutoAnalysing
# step 2. 文件下放置该脚本
# step 3. 终端cd到AutoAnalysing 执行 sh autoanalysing.sh
# step 4. 选择和确认不同选项....
# step 5. Success  🎉 🎉 🎉!


# ************************* 脚步可自定义配置 start 

# 配置Xcode名字(可选)，当本地有多个Xcode可以指定路径解析，需要是安装完毕的
__LOCAL_XCODE_NAME="Xcode"

# 配置输出日志
__LOCAL_CRASH_NAME="crash_log"

# 文件自定义名称
__IPS_NAME="PregnancyHelper"
__DSYM_NAME="PregnancyHelper"


# ************************* 路径配置 
__LOCAL_CRASH_PATH="${__LOCAL_CRASH_NAME}.ips"
__LOCAL_XCODE_PATH=""

# ************************* 公共部分 脚本样式
__TITLE_LEFT_COLOR="\033[36;1m==== "
__TITLE_RIGHT_COLOR=" ====\033[0m"

__OPTION_LEFT_COLOR="\033[33;1m"
__OPTION_RIGHT_COLOR="\033[0m"

__LINE_BREAK_LEFT="\033[32;1m"
__LINE_BREAK_RIGHT="\033[0m"

# 红底白字
__ERROR_MESSAGE_LEFT="\033[41m ! ! ! "
__ERROR_MESSAGE_RIGHT=" ! ! ! \033[0m"

# ************************* 脚本内容

# 询问当前的ips是什么系统产生的，大于等于iOS15的系统CrashSymbolicator 小于iOS15的系统symbolicatecrash

# 选择项输入方法 接收3个参数：1、选项标题 2、选项数组 3、选项数组的长度(0~256)
function READ_USER_INPUT() {
  title=$1
  options=$2
  maxValue=$3
  echo "${__TITLE_LEFT_COLOR}${title}${__TITLE_RIGHT_COLOR}"
  for option in ${options[*]}; do
    echo "${__OPTION_LEFT_COLOR}${option}${__OPTION_RIGHT_COLOR}"
  done
  read
  __INPUT=$REPLY
  expr $__INPUT "+" 10 &> /dev/null
  if [[ $? -eq 0 ]]; then
    if [[ $__INPUT -gt 0 && $__INPUT -le $maxValue ]]; then
      return $__INPUT
    else
      echo "${__ERROR_MESSAGE_LEFT}输入越界了，请重新输入${__ERROR_MESSAGE_RIGHT}"
      READ_USER_INPUT $title "${options[*]}" $maxValue
    fi
  else
    echo "${__ERROR_MESSAGE_LEFT}输入有误，请输入数字序号${__ERROR_MESSAGE_RIGHT}"
    READ_USER_INPUT $title "${options[*]}" $maxValue
  fi
}

__IS_IOS15_OPTIONS=("1.大于或等于iOS15系统选择" "2.小于iOS15系统选择")
__TIPS="当前的ips是什么系统产生的，输入按回车继续："
READ_USER_INPUT "${__TIPS}" "${__IS_IOS15_OPTIONS[*]}" ${#__IS_IOS15_OPTIONS[*]}
__IS_IOS15_OPTIONS=$?


if [[ $__IS_IOS15_OPTIONS -eq 1 ]]; then
  __LOCAL_XCODE_PATH="/Applications/${__LOCAL_XCODE_NAME}.app/Contents/SharedFrameworks/CoreSymbolicationDT.framework/Versions/A/Resources/"
else
 __LOCAL_XCODE_PATH="/Applications/${__LOCAL_XCODE_NAME}.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources/"
fi

XCODE_BUILD_VERSION=$(xcodebuild -version)
echo "-------------- Xcode版本: $XCODE_BUILD_VERSION -------------------"

function printMessage() {
  pMessage=$1
  echo "${__LINE_BREAK_LEFT}${pMessage}${__LINE_BREAK_RIGHT}"
}

# 检查当前文件夹内是否存在解析文件 ips dSYM 其中 dSYM 实际是一个文件夹的形式，真的坑爹，ips是文件
__PATHS=()
__PATHS_FILE=()
function check_dir_exist_files() {
  arr=("${__DSYM_NAME}.app.dSYM" "${__IPS_NAME}.ips")
  for path in `ls -a $1` 
  do
    # 判断存在需要的文件
    for i in ${!arr[@]}; do
        if [ ${path} = ${arr[$i]} ]; then
            unset arr[$i]
            __PATHS[$i]=$1/"${path}"
            
            #判断是否是文件夹
            if (test -d "$path"); then
              __PATHS_FILE[$i]="1"
            else
              __PATHS_FILE[$i]="0"
            fi
        fi
    done
    # 优化后缀匹配
    # if !(test -d "$path"); then
    #     # echo ${path}

    #     # name=${path%.*}   # 文件名
    #     # exte=${path##*.}  # 后缀
    #     # echo ${name}
    #     # echo ${exte}
    #     # 遍历包含就移除
    #     # for i in ${!arr[@]}
    #     # do
    #     #   item=${arr[$i]}
    #     #   if [ ${item} = exte ] 
    #     #   then
    #     #       echo ${arr[$i]}
    #     #       unset arr[$i]
    #     #   fi
    #     # done
    # fi
  done

  for i in ${!arr[@]}; 
  do
      printMessage "${arr[$i]} 文件未存在 😢 😢 😢"
      exit 1
  done
}

__PWD=`pwd`
check_dir_exist_files "${__PWD}"


#*********************************************************** 区别系统解析行为 >=15
if [[ $__IS_IOS15_OPTIONS -eq 1 ]]; then
  
  # 判断Xcode解析目录是否存在
  if !(test -d "${__LOCAL_XCODE_PATH}");
  then
    printMessage "Xcode解析目录异常，请适配目前安装的Xcode 😢 😢 😢"
    exit 1
  fi

  # 复制移动文件
  __TESTPATH=${__LOCAL_XCODE_PATH}
  # 拷贝到系统XCode指定目录下
  for i in ${!__PATHS[@]}; 
  do
    path="${__PATHS[$i]}"
    path_file="${__PATHS_FILE[$i]}"

    # 交互式 -i 强制性 -f
    if [[ ${path_file} = "0" ]]; then
      # 非文件夹
      sudo cp -f ${path} ${__TESTPATH}
    else
      # 文件夹
      sudo cp -R ${path} ${__TESTPATH}
    fi
  done

  # cd到 Xcode指定目录
  cd ${__LOCAL_XCODE_PATH}

  # 执行脚本前移除旧log
  if [[ -f "${__LOCAL_XCODE_PATH}""${__LOCAL_CRASH_PATH}" ]]; then
      echo "发现存在旧log，正常执行删除.."
      sudo rm -rf "${__LOCAL_XCODE_PATH}""${__LOCAL_CRASH_PATH}"
  fi

  printMessage "解析中.."

  # 执行脚本
  sudo python3 CrashSymbolicator.py -d "${__DSYM_NAME}.app.dSYM"  -o ${__LOCAL_CRASH_PATH} -p "${__IPS_NAME}.ips"

  # 判断 log是否生成
  if [[ -f "${__LOCAL_XCODE_PATH}""${__LOCAL_CRASH_PATH}" ]]; then
      printMessage "解析成功 🚀 🚀 🚀"
      open ${__LOCAL_XCODE_PATH}
      open "${__LOCAL_XCODE_PATH}""${__LOCAL_CRASH_PATH}"
    else
      printMessage "解析失败 😢 😢 😢"
  fi
else
  #*********************************************************** 区别系统解析行为 <15

  # 当前目录下
  __PWD=`pwd`
  cd ${__PWD}

  __LOCAL_CRASH_PATH="${__LOCAL_CRASH_NAME}.crash"

  # 把.ips 复制一份更名为 .crash
  cp -f "${__IPS_NAME}.ips" "${__IPS_NAME}.crash"

  # 拷贝一份解析文件出来
  if ! [[ -f "symbolicatecrash" ]]; then
      cp -f "${__LOCAL_XCODE_PATH}/symbolicatecrash" "symbolicatecrash"
  fi
  
  #执行一下选择当前的xcode路径
  export DEVELOPER_DIR=/Applications/${__LOCAL_XCODE_NAME}.app/Contents/Developer

  #移除旧log
  if [[ -f "${__LOCAL_CRASH_PATH}" ]]; then
      echo "发现存在旧log，正常执行删除.."
      sudo rm -rf "${__LOCAL_CRASH_PATH}"
  fi

  printMessage "解析中.."

  # 执行解析脚本
  ./symbolicatecrash  "${__IPS_NAME}.crash" "${__DSYM_NAME}.app.dSYM" > "${__LOCAL_CRASH_PATH}"

  # 判断 log是否生成
  if [[ -f "${__LOCAL_CRASH_PATH}" ]]; then
      printMessage "解析成功 🚀 🚀 🚀"
      open ${__PWD}
      open "${__LOCAL_CRASH_PATH}"
    else
      printMessage "解析失败 😢 😢 😢"
  fi

fi


# 输出总用时
printMessage "使用脚本总耗时: ${SECONDS}s"



#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script is based on projects below
# https://github.com/yixia/FFmpeg-Android
# http://git.videolan.org/?p=vlc-ports/android.git;a=summary

#----------
UNI_BUILD_ROOT=`pwd`
FF_TARGET=$1
FF_TARGET_EXTRA=$2
set -e
set +x

FF_ACT_ARCHS_32="armv5 armv7a x86"
FF_ACT_ARCHS_64="armv5 armv7a arm64 x86 x86_64"
FF_ACT_ARCHS_ALL=$FF_ACT_ARCHS_64

echo_archs() {
    echo "===================="
    echo "[*] check archs"
    echo "===================="
    echo "FF_ALL_ARCHS = $FF_ACT_ARCHS_ALL"
    # 在 Shell 脚本中，$* 是一个特殊变量，代表传递给脚本或函数的所有参数。 
    # +1
    # 核心功能
    # 当你运行一个脚本并传入多个参数时（例如 ./script.sh a b c），$* 会获取这些所有的参数。
    # $* 与 $@ 的关键区别
    # 虽然两者都代表所有参数，但在加双引号时行为完全不同： 
    # "$*"（加引号）：将所有参数看作一个单一的字符串。参数之间由环境变量 IFS（通常是空格）分隔。
    # 例："$1 $2 $3"
    # "$@"（加引号）：将每个参数看作独立的字符串。这是最常用的推荐方式，因为它能正确处理带空格的参数。
    # 例："$1" "$2" "$3"
    # 不加引号时：$* 和 $@ 的行为基本一致，都会按空格拆分参数。
    echo "FF_ACT_ARCHS = $*"
    echo ""
}

echo_usage() {
    echo "Usage:"
    echo "  compile-ffmpeg.sh armv5|armv7a|arm64|x86|x86_64"
    echo "  compile-ffmpeg.sh all|all32"
    echo "  compile-ffmpeg.sh all64"
    echo "  compile-ffmpeg.sh clean"
    echo "  compile-ffmpeg.sh check"
    exit 1
}

echo_nextstep_help() {
    echo ""
    echo "--------------------"
    echo "[*] Finished"
    echo "--------------------"
    echo "# to continue to build ijkplayer, run script below,"
    echo "sh compile-ijk.sh "
}

# 在 Shell 脚本中，switch 逻辑是通过 case 语句来实现的。它非常适合处理多分支选择，尤其是匹配字符串或模式。
# 1. 基本语法结构
# bash
# case "变量" in
#     模式1)
#         # 执行命令1
#         ;;
#     模式2)
#         # 执行命令2
#         ;;
#     *)
#         # 默认执行（相当于 default）
#         ;;
# esac

# 2. 核心规则
# )：每个模式以右括号结束。
# ;;：每个分支必须以双分号结尾（相当于 break），否则会报错。
# *：最后的星号代表通配符，用于匹配所有未命中的情况。
# esac：是 case 反过来写，表示结束。 
case "$FF_TARGET" in
    "")
        echo_archs armv7a
        sh tools/do-compile-ffmpeg.sh armv7a
    ;;
    armv5|armv7a|arm64|x86|x86_64)
        echo_archs $FF_TARGET $FF_TARGET_EXTRA
        sh tools/do-compile-ffmpeg.sh $FF_TARGET $FF_TARGET_EXTRA
        echo_nextstep_help
    ;;
    all32)
        echo_archs $FF_ACT_ARCHS_32
        # 在 Shell 脚本（如 Bash）中，for ... in 循环默认使用空格、制表符（Tab）和换行符作为分隔符。 
        # 如果你需要按逗号、分号或其他特定字符拆分字符串，主要有以下三种常用方法：
        # 1. 修改内部字段分隔符（IFS）
        # IFS（Internal Field Separator）是控制 Shell 如何拆分词语的环境变量。 
        # 实现方式：先将 IFS 设置为目标分隔符，再运行循环。
        # 最佳实践：建议在修改前备份 IFS，并在循环后恢复，以防影响后续脚本逻辑。 
        # #!/bin/bash
        # data="apple,banana,cherry,orange"

        # # 1. 备份旧的 IFS，设置新的 IFS 为逗号
        # OLD_IFS=$IFS
        # IFS=","

        # # 2. 执行循环（注意：$data 不能加双引号，否则会被视为一个整体）
        # for item in $data; do
        #     echo "水果: $item"
        # done

        # # 3. 恢复原始 IFS
        # IFS=$OLD_IFS

        # 在 Shell 脚本中，do 和 done 是循环结构的边界关键词。它们成对出现，用来包裹循环体内需要重复执行的代码块。
        # 无论是 for、while 还是 until 循环，都必须使用这对关键字。
        for ARCH in $FF_ACT_ARCHS_32
        do
            sh tools/do-compile-ffmpeg.sh $ARCH $FF_TARGET_EXTRA
        done
        echo_nextstep_help
    ;;
    all|all64)
        echo_archs $FF_ACT_ARCHS_64
        for ARCH in $FF_ACT_ARCHS_64
        do
            sh tools/do-compile-ffmpeg.sh $ARCH $FF_TARGET_EXTRA
        done
        echo_nextstep_help
    ;;
    clean)
        echo_archs FF_ACT_ARCHS_64
        # 在 Linux Shell 脚本（如 Bash）中，判断变量是否需要加 $ 符号，最简单的准则是：定义或修改变量时不加，引用（取值）变量时必须加
        for ARCH in $FF_ACT_ARCHS_ALL
        do
            if [ -d ffmpeg-$ARCH ]; then
                # 这是一个非常“暴力”的清理命令，执行前一定要确认清楚。它的作用是强制删除工作区中所有未被 Git 追踪的文件
                # 什么时候用它？
                # 项目环境乱套了，想彻底回到“刚拉取代码”的最干净状态。
                # 编译报错，怀疑是旧的中间文件干扰，需要清空所有构建产物。
                cd ffmpeg-$ARCH && git clean -xdf && cd -
            fi
        done
        rm -rf ./build/ffmpeg-*
    ;;
    check)
        echo_archs FF_ACT_ARCHS_ALL
    ;;
    *)
        echo_usage
        # 在 Linux Shell 中，exit 1 的核心作用是终止当前脚本并返回一个“失败”的状态码给操作系统。
        # 1. 状态码的含义
        # exit 0：表示程序成功执行（Success）。
        # exit 1（或 1-255 之间的任何非零值）：表示程序执行失败或出现异常（Failure/Error）。
        # 1 通常是通用的“一般错误”。
        # 特定的错误码（如 127 表示找不到命令，126 表示权限不足）。
        exit 1
    ;;
esac

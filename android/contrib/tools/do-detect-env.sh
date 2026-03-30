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

# 简单来说，set -e 关注的是单个命令的失败，而 set -o pipefail 专门负责揪出管道中隐瞒的错误。
# 它们通常是“黄金搭档”，为了弥补彼此的盲点。
# 1. 核心区别

# | 命令 | 关注对象 | 触发逻辑 |
# |---|---|---|
# | set -e | 普通命令 / 管道整体 | 只要命令或管道最后一个环节失败，脚本退出。 |
# | set -o pipefail | 管道内部各个环节 | 只要管道中任何一个环节失败，整个管道就视为失败。 |

# ------------------------------
# 2. 为什么需要配合使用？（核心痛点）
# 在默认情况下（只开 set -e），Shell 只看管道中最后一个命令的退出码。
# 场景 A：只开启 set -e

# set -e
# cat nonexistent_file | echo "Hello"
# echo "脚本继续运行了！"


# * 发生什么了？ cat 因为文件不存在报错了，但 echo "Hello" 执行成功了。
# * 结果：因为最后一个命令成功了，set -e 认为整个管道是成功的，脚本会继续往下跑。这可能导致后续处理空数据，引发隐蔽的 Bug。

# 场景 B：开启 set -e 和 set -o pipefail

# set -eset -o pipefail
# cat nonexistent_file | echo "Hello"
# echo "这条不会被打印"


# * 发生什么了？ 虽然 echo 成功了，但 pipefail 捕捉到了 cat 的失败状态。
# * 结果：整个管道被判定为失败（返回非零值），set -e 随即触发，脚本立即停止。

# ------------------------------
# 3. 最佳实践
# 在编写健壮的脚本（如你正在研究的环境检测或编译脚本）时，通常会在开头写上这一行“严谨模式”全家桶：

# set -euo pipefail


# * -e: 遇错即停。
# * -u: 变量未定义即停（防止 rm -rf $DIR/ 这种因变量空导致的误删）。
# * -o pipefail: 管道内任何环节报错即停。

# 4. 总结
# 如果你在处理像 grep ... | sed ... | cut ... 这样长串的管道：

# * 没有 pipefail，即便 grep 没找到文件，只要最后的 cut 成功了，脚本就会假装一切正常。
# * 有了 pipefail，任何一环掉链子，脚本都会及时“自杀”报警。

# 你现在是在优化你的脚本，还是在排查为什么管道报错了脚本却没停下来？


set -e
# uname -s 是一个常用的系统命令，用于打印当前操作系统的名称。
UNAME_S=$(uname -s)
# uname -s -m（通常简写为 uname -sm）会同时输出操作系统内核名称和硬件架构类型。
UNAME_SM=$(uname -sm)
echo "build on $UNAME_SM"
# 这行命令的作用是在终端打印出环境变量 ANDROID_NDK 的当前值。
echo "ANDROID_NDK=$ANDROID_NDK"

if [ -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK before starting."
    echo "They must point to your NDK directories."
    echo ""
    exit 1
fi



# try to detect NDK version
# 普通变量只能在当前脚本或 Shell 中使用，只有经过 export，子进程（如你调用的编译器、FFmpeg 编译脚本、NDK 工具链）才能读取到它。
# export VAR="val"	设置环境变量。当前 Shell 及其所有子进程都能访问。	设置 ANDROID_NDK 路径、编译器参数。
export IJK_GCC_VER=4.9
export IJK_GCC_64_VER=4.9
export IJK_MAKE_TOOLCHAIN_FLAGS=
export IJK_MAKE_FLAG=

# 命令替换（Command Substitution） 是 Shell 中极其强大的功能，它的作用是：执行一个命令，并将该命令的“标准输出”结果直接替换到当前命令行中。
# 简单来说，就是把命令的运行结果当成一个值来使用。
# 1. 两种语法格式
# 格式	示例	推荐程度
# $(command)	DIR=$(pwd)	推荐（支持嵌套，易读）
# `command` (反引号)	DIR=\pwd``	较老旧（不支持嵌套，易用性差）
# 2. 实际应用场景
# A. 将结果赋值给变量
# 这是你看到的 IJK_NDK_REL=$(...) 的用法：
# bash
# # 获取当前日期
# NOW=$(date +%Y%m%d)
# echo "备份文件名：backup_$NOW.tar.gz"
# 请谨慎使用此类代码。

# B. 直接作为命令参数
# bash
# # 统计当前目录下文件的数量
# echo "总共有 $(ls | wc -l) 个文件"

# # 杀死名为 "my_process" 的进程
# kill -9 $(pgrep my_process)
# 请谨慎使用此类代码。

# 3. 核心特性
# 自动修整：Shell 会自动删除输出结果末尾的所有换行符。
# 嵌套执行：使用 $() 格式可以轻松嵌套。
# bash
# # 先找到文件路径，再查看文件大小
# FILE_SIZE=$(du -sh $(which python3))
# 请谨慎使用此类代码。

# 子进程执行：命令替换会在一个子 Shell 中运行，这意味着它内部定义的临时变量不会影响到你的主脚本。
# 4. 避坑指南：空格与引号
# 如果命令的输出结果中包含空格，不加引号可能会导致后续命令解析出错。
# ❌ 错误示例（如果路径有空格会崩）：
# bash
# MY_PATH=$(pwd)
# ls $MY_PATH  # 如果路径是 "/My Docs"，ls 会去查 "/My" 和 "Docs" 两个目录
# 请谨慎使用此类代码。

# ✅ 正确做法：
# bash
# ls "$MY_PATH"  # 永远给包含命令替换结果的变量加上双引号
# 请谨慎使用此类代码。

# 结合你的上下文
# 在你之前的例子中：
# export IJK_NDK_REL=$(grep ... | sed ... | cut ...)
# 这里就是利用命令替换，把复杂的文本过滤结果（例如 10e）直接塞进 IJK_NDK_REL 这个变量里，从而实现了“自动化探测版本号”。

# 2>/dev/null
# 这是 Shell 中最常用的错误屏蔽手段，意思是：“如果这条命令报错，请静默处理，不要在屏幕上显示任何错误信息。”
# 1. 拆解分析
# 2：代表标准错误输出 (stderr)。在 Linux 中，文件描述符 1 是正常输出，2 是报错信息。
# >：重定向符号，表示将输出内容发送到某个地方。
# /dev/null：Linux 的“黑洞”设备。任何发送到这里的数据都会被直接丢弃，消失得无影无踪。
# 2. 为什么在你的脚本里使用它？
# 在你之前看到的命令中：
# grep ... $ANDROID_NDK/RELEASE.TXT 2>/dev/null
# 场景： 如果你的 $ANDROID_NDK 路径填错了，或者该目录下根本没有 RELEASE.TXT 这个文件。
# 不加 2>/dev/null：终端会弹出一行刺眼的报错：grep: /invalid/path/RELEASE.TXT: No such file or directory。
# 加上 2>/dev/null：报错被“黑洞”吞掉，终端干干净净。脚本会继续执行（返回一个空值），显得更加专业和健壮。

# 这行代码是典型的 Android NDK 版本自动检测 逻辑。它的目的是从 NDK 根目录下的 RELEASE.TXT 文件中提取出版本号（例如 10e、21 等），并存入变量 IJK_NDK_REL。
# 我们可以分层拆解这个“命令链”：
# 1. 整体结构

# * export: 将提取到的版本号设为环境变量，确保后续的编译进程（如 FFmpeg 的 configure）能读到它。
# * $( ... ): 命令替换，执行括号内的所有命令，并将最终结果赋值给变量。

# 2. 管道命令详解 (| 连接的步骤)

#    1. grep -o '^r[0-9]*.*' $ANDROID_NDK/RELEASE.TXT
#    * 读取 NDK 目录下的 RELEASE.TXT。
#       * ^r[0-9]*.*: 匹配以字母 r 开头，后面跟着数字的行（例如 r10e (64-bit)）。
#       * -o: 只输出匹配到的部分，忽略行内其他无关内容。
#       * 2>/dev/null: 如果文件不存在或读取失败，静默处理，不报错。
#    2. sed 's/[[:space:]]*//g'
#    * 使用流编辑器 sed 删除字符串中所有的空格、制表符。确保版本号是连续的字符串。
#    3. cut -b2-
#    * 关键动作：从第 2 个字节（Character）开始截取到末尾。
#       * 目的：去掉开头的字母 r。
#       * 示例：如果输入是 r21，执行后变成 21；如果输入是 r10e，执行后变成 10e。
   
# ------------------------------
# 3. 执行流程示例
# 假设你的 ANDROID_NDK/RELEASE.TXT 内容是：r10e (64-bit) 20140521

#    1. grep 抓取到：r10e (64-bit)
#    2. sed 处理后：r10e(64-bit)
#    3. cut 截取后：10e(64-bit) （注：实际 NDK 文件格式略有差异，通常最终会得到类似 10e 或 21 这样的纯版本号）。

# 4. 为什么要这么做？
# ijkplayer 等项目对 NDK 版本有严格要求（例如必须大于 r10e）。脚本通过这一行自动获取当前环境的 NDK 版本，然后后续可能会有类似这样的逻辑：

# if [ "$IJK_NDK_REL" != "10e" ]; then
#     echo "警告：建议使用 NDK r10e 以获得最佳兼容性"fi

# 💡 潜在风险

# * NDK 路径：如果你的 $ANDROID_NDK 变量没设置对，这行命令会得到一个空值。
# * 新版 NDK：较新版本的 NDK 可能不再提供 RELEASE.TXT（改用 source.properties），如果这行报错，你可能需要手动指定版本。

# 你现在的 IJK_NDK_REL 打印出来是什么？（可以用 echo $IJK_NDK_REL 确认一下）


export IJK_NDK_REL=$(grep -o '^r[0-9]*.*' $ANDROID_NDK/RELEASE.TXT 2>/dev/null | sed 's/[[:space:]]*//g' | cut -b2-)
case "$IJK_NDK_REL" in
    10e*)
        # we don't use 4.4.3 because it doesn't handle threads correctly.
        # 在 Shell 脚本中，test 和 [ 其实是同一个命令。
        # 1. 它们本质上是一样的
        # 在大多数 Linux 系统中，[ 是 test 命令的一个硬链接或内置别名。它们的逻辑完全一致，只是语法风格不同。

        # * test -d /data
        # * [ -d /data ]

        # 2. 为什么 [ 后面要有空格？
        # 因为 [ 是一个命令名称（就像 ls 或 mkdir 一样）。

        # * [-d 会报错，因为系统找不到名为 [-d 的命令。
        # * 你必须写成 [ -d ...，让 Shell 识别出 [ 是命令，-d 是它的第一个参数。

        # 3. 为什么末尾要有 ]？
        # 当命令以 [ 开头时，它要求最后一个参数必须是 ]，这纯粹是为了让代码看起来更像传统的编程语言（如 C 或 Java）的条件判断，增加可读性。
        # 4. 现代推荐：双括号 [[ ]]
        # 如果你使用的是 Bash 或 Zsh，通常建议使用 [[ ... ]]。它是 Shell 的关键字（不是外部命令），比 [ 更强大且安全：

        # * 不需要引号：即使变量为空或包含空格，也不会报错。
        # * 支持逻辑符：可以直接用 && 和 ||，而不需要用 -a 或 -o。
        # * 支持通配符：可以进行模式匹配（例如判断字符串是否以某字母开头）。

        # 你想了解如何在 if 语句中高效组合多个测试条件吗？

        if test -d ${ANDROID_NDK}/toolchains/arm-linux-androideabi-4.8
        # if gcc 4.8 is present, it's there for all the archs (x86, mips, arm)
        then
            echo "NDKr$IJK_NDK_REL detected"

            case "$UNAME_S" in
                Darwin)
                    export IJK_MAKE_TOOLCHAIN_FLAGS="$IJK_MAKE_TOOLCHAIN_FLAGS --system=darwin-x86_64"
                ;;
                # 你在提到的 CYGWIN_NT-*) 通常出现在 Shell 脚本的 case 语句中，用来匹配 Cygwin 环境（在 Windows 上模拟 Linux 的环境）。
                # 1. 核心含义
                # CYGWIN_NT-*：这是执行 uname -s 命令时返回的系统名称开头。NT 代表 Windows NT 内核，后面的数字（如 10.0）表示内核版本。
                # *)：这是通配符，表示匹配任何以 CYGWIN_NT- 开头的字符串。
                CYGWIN_NT-*)
                    export IJK_MAKE_TOOLCHAIN_FLAGS="$IJK_MAKE_TOOLCHAIN_FLAGS --system=windows-x86_64"
                ;;
            esac
        else
            echo "You need the NDKr10e or later"
            exit 1
        fi
    ;;
    *)
        # 这条命令的作用是提取等号（=）后面的内容。
        # 1. 参数拆解

        # * cut：文本裁剪工具。
        # * -d "="：指定分隔符（delimiter）为等号。它告诉系统把每一行按照 = 切开。
        # * -f 2：取切开后的第 2 个字段（field）。

        # 2. 实际效果
        # 假设你有一个配置文件 config.txt，内容如下：
        # user=admin
        # password=123456
        # 执行 cut -d "=" -f 2 config.txt 后，输出结果为：
        # admin
        # 123456
        # 3. 注意事项

        # * 如果一行里有多个等号：它只会取第一个和第二个等号中间的部分。
        # * 如果一行里没有等号：默认情况下，cut 会输出整行内容。如果你想忽略没有分隔符的行，可以加上 -s 参数：cut -sd "=" -f 2。
        # * 空格问题：如果等号两边有空格（例如 user = admin），输出结果会带上那个空格（ admin）。这种情况下，通常建议配合 tr -d ' ' 或 awk 来处理。

        # 你是在处理 环境变量、INI 配置文件，还是某个 Shell 脚本的输出结果？
        IJK_NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $ANDROID_NDK/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
        echo "IJK_NDK_REL=$IJK_NDK_REL"
        case "$IJK_NDK_REL" in
            11*|12*|13*|14*)
                if test -d ${ANDROID_NDK}/toolchains/arm-linux-androideabi-4.9
                then
                    echo "NDKr$IJK_NDK_REL detected"
                else
                    echo "You need the NDKr10e or later"
                    exit 1
                fi
            ;;
            *)
                echo "You need the NDKr10e or later"
                exit 1
            ;;
        esac
    ;;
esac


case "$UNAME_S" in
    Darwin)
        # `...` (反引号)  与  $()  区别
        # 它们在功能上完全相同，都是命令替换（执行命令并将输出结果放回原处）。但在现代 Shell 编程中，强烈建议优先使用 $()。
        # 以下是它们的具体区别：
        # 1. 可读性与嵌套（最大区别）

        # * $() 支持轻松嵌套：
        # 如果你想在一个命令的结果里再运行命令，$() 非常直观。

        # # 获取父目录的大小
        # dirname=$(basename $(dirname "/var/log/syslog"))

        # * 反引号嵌套很痛苦：
        # 必须使用大量的反斜杠 \ 来转义内部的反引号，极易出错。

        # dirname=`basename \`dirname "/var/log/syslog"\``


        # 2. 转义处理

        # * 反引号对反斜杠 \ 的处理比较特殊。在反引号内，\$、\、``` 等字符有时需要双重转义。
        # * $() 内部的处理逻辑更符合直觉，基本不需要为特殊字符头疼。

        # 3. 视觉辨识度

        # * 反引号（`）长得非常像单引号（'），在很多字体下难以分辨，容易导致低级语法错误。
        # * $() 结构清晰，一眼就能看出这是一个动态执行的模块。

        # 4. 兼容性

        # * 反引号：所有 POSIX 标准的 Shell（包括非常老的 sh）都支持。
        # * $()：绝大多数现代 Shell（Bash, Zsh, Dash, Ksh）都支持，但在极少数非常古老的 Unix 系统（如 80 年代的原始 sh）中可能不支持。

        # 总结：
        # 除非你必须编写兼容 40 年前古董系统的脚本，否则请永远使用 $()。
        # 你是在将旧脚本重构为更现代的格式，还是在处理复杂的多层命令嵌套？

        # 这段命令的作用是根据你电脑的 CPU 核心（线程）数，自动设置多线程编译参数。它通常出现在编译开源项目（如 IJKPlayer）的脚本中。
        # 1. 命令分解

        # * sysctl -n machdep.cpu.thread_level (或 thread_count)：这是 macOS 上的命令，用于获取 CPU 的逻辑线程总数（例如 8 或 16）。
        # * `...` (反引号)：执行括号内的命令，并将其输出结果替换到当前位置。
        # * -j：这是 make 命令的参数，代表 jobs（并行任务数）。
        # * export：将组合后的字符串赋值给环境变量 IJK_MAKE_FLAG，并导出给子进程使用。

        # 2. 最终效果
        # 如果你的 Mac 有 8 个线程，这条命令等同于执行：

        # export IJK_MAKE_FLAG=-j8

        # 当你后续运行 make $IJK_MAKE_FLAG 时，系统会火力全开，同时启动 8 个编译任务，显著加快编译速度。
        # 3. 注意事项

        # * 平台限制：sysctl machdep.cpu... 是 macOS 专用的。
        # * 如果你在 Linux 上，对应的命令通常是：nproc。
        # * 通用写法：export IJK_MAKE_FLAG="-j$(nproc 2>/dev/null || sysctl -n hw.ncpu)"。
        # * 负载建议：有时候为了防止电脑卡死，开发者会写成 -j$(($(nproc) + 1))，即线程数加 1。

        # 你是在编译 IJKPlayer 或者是某个 Android/iOS 的音视频库吗？
        export IJK_MAKE_FLAG=-j`sysctl -n machdep.cpu.thread_count`
    ;;
    CYGWIN_NT-*)
        IJK_WIN_TEMP="$(cygpath -am /tmp)"
        export TEMPDIR=$IJK_WIN_TEMP/

        echo "Cygwin temp prefix=$IJK_WIN_TEMP/"
    ;;
esac

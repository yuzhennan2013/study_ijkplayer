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

#--------------------
echo "===================="
echo "[*] check env $1"
echo "===================="
# 在 Linux Shell（如 Bash 或 Zsh）中，set -e 是一个内置命令，用于开启 "即时退出" (errexit) 模式。 
# 核心功能
# 它的作用是：一旦脚本中的任何命令执行失败（返回非零退出状态码），脚本将立即停止运行。 
# OneUptime
# OneUptime
# 在默认情况下，Shell 脚本即便中间某行命令报错，也会继续执行下一行。这可能会导致后续操作基于错误的前提进行（例如：进入目录失败后却执行了删除操作），使用 set -e 可以有效防止这种灾难性的连锁反应。
set -e


#--------------------
# common defines
FF_ARCH=$1
FF_BUILD_OPT=$2
echo "FF_ARCH=$FF_ARCH"
echo "FF_BUILD_OPT=$FF_BUILD_OPT"
# 在 if [ -z "$var" ] 这种结构中，-z 用于检查字符串的长度是否为零。
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm, armv7a, x86, ...'."
    echo ""
    exit 1
fi

# 在父脚本调用子脚本时，子脚本中 pwd 的返回值取决于你调用子脚本的方式：
# ## 1. 默认情况：返回“执行命令时所在的目录”
# 无论子脚本存放在哪里，pwd 返回的都是父脚本当前的工作目录。

# * 原理：子进程会继承父进程的“当前工作目录”（Working Directory）。
# * 例子：
# * 你在 /home/user/ 执行父脚本。
#    * 父脚本里写了 ./scripts/build.sh。
#    * 子脚本 build.sh 里的 pwd 返回的依然是 /home/user/。

# ## 2. 如果父脚本在调用前 cd 了
# 如果你在调用子脚本之前改变了目录，pwd 就会改变：

# cd /tmp
# sh /home/user/project/sub-script.sh  # 子脚本里的 pwd 会返回 /tmp

# ## 3. 如果你想在子脚本里获取“脚本文件所在的目录”
# 这在 FFmpeg 编译脚本中非常常见，因为你可能需要引用同目录下的其他配置文件。此时不能用 pwd，而要用：

# # 获取子脚本文件本身所在的绝对路径
# SCRIPT_DIR=$(cd $(dirname $0); pwd)

# 这样无论你在哪里运行，都能定位到脚本自己的位置。
# 总结：pwd 始终返回你当前“人”在哪个目录下（当前 shell 的工作路径），而不是脚本文件存放的路径。
# 你是因为子脚本找不到同级目录下的工具链或配置文件才遇到这个问题的吗？

# 这行代码是 Shell 脚本中的“金句”，它的核心作用是：无论你在哪里调用脚本，都能获取该脚本文件所在的绝对路径。
# 在 FFmpeg 编译脚本中，这通常用来定位 交叉编译工具链（Toolchain） 或 依赖库。
# ## 拆解分析：

#    1. $0: 获取当前执行的脚本文件名（可能包含相对路径，如 ./build.sh）。
#    2. dirname $0: 提取出脚本所在的目录部分。如果执行 ./scripts/build.sh，它会得到 ./scripts。
#    3. cd ...: 进入这个目录。
#    4. pwd: 在进入目录后，获取当前的绝对路径（如 /home/user/ffmpeg/scripts）。
#    5. $( ... ): 将整条命令的结果赋值给变量。

# ## 为什么要这么写？
# 如果你直接用 pwd，获取的是你执行命令时所在的目录（Working Directory）；
# 而用这一串代码，获取的是脚本文件实际存放的目录（Script Location）。
# 对比场景：
# 假设脚本在 /opt/ffmpeg/build.sh，而你在 /home/user/ 下执行 /opt/ffmpeg/build.sh：

# * 直接用 pwd：返回 /home/user （会导致找不到同目录下的配置文件）。
# * 用这行代码：返回 /opt/ffmpeg （能准确找到脚本旁边的资源）。

# ## 建议写法
# 为了处理路径中包含空格的情况，工业级的写法通常会加上双引号：

# SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)

# 你现在是打算用这个路径来指定交叉编译器的 PREBUILT 路径吗？

FF_BUILD_ROOT=`pwd`
FF_ANDROID_PLATFORM=android-9

# Shell中直接写变量名（不可以）
# 在 Shell 中，你不能只写一个变量名就结束：
# bash
# my_var      # 错误！系统会认为你在运行一个名为 "my_var" 的命令
# my_var=     # 正确。这定义了变量，值为空字符串
FF_BUILD_NAME=
FF_SOURCE=
FF_CROSS_PREFIX=
FF_DEP_OPENSSL_INC=
FF_DEP_OPENSSL_LIB=

FF_DEP_LIBSOXR_INC=
FF_DEP_LIBSOXR_LIB=

FF_CFG_FLAGS=

FF_EXTRA_CFLAGS=
FF_EXTRA_LDFLAGS=
FF_DEP_LIBS=

FF_MODULE_DIRS="compat libavcodec libavfilter libavformat libavutil libswresample libswscale"
FF_ASSEMBLER_SUB_DIRS=


#--------------------
echo ""
echo "--------------------"
echo "[*] make NDK standalone toolchain"
echo "--------------------"
# 在 Linux Shell 中，这行命令的意思是：在当前 Shell 环境中执行 do-detect-env.sh 脚本。
# 具体拆解如下：
# 1. 开头的 . (点号)
# 这里的第一个点号是 source 命令的缩写。
# 普通执行 (./script.sh)：会开启一个子 Shell（Subshell）来运行脚本。脚本运行完后，里面定义的变量、环境变量、别名（Alias）都会随之消失。
# Source 执行 (. ./script.sh)：是在当前 Shell 中直接运行。脚本里设置的任何变量或路径，在脚本执行完后依然有效。
# 2. 空格
# 第一个点号和路径之间必须有空格。
# 3. ./tools/do-detect-env.sh
# 这是脚本的相对路径，表示执行当前目录下 tools 文件夹里的 do-detect-env.sh。
. ./tools/do-detect-env.sh
FF_MAKE_TOOLCHAIN_FLAGS=$IJK_MAKE_TOOLCHAIN_FLAGS
FF_MAKE_FLAGS=$IJK_MAKE_FLAG
FF_GCC_VER=$IJK_GCC_VER
FF_GCC_64_VER=$IJK_GCC_64_VER


#----- armv7a begin -----
if [ "$FF_ARCH" = "armv7a" ]; then
    FF_BUILD_NAME=ffmpeg-armv7a
    FF_BUILD_NAME_OPENSSL=openssl-armv7a
    FF_BUILD_NAME_LIBSOXR=libsoxr-armv7a
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=arm-linux-androideabi
    FF_TOOLCHAIN_NAME=${FF_CROSS_PREFIX}-${FF_GCC_VER}

    # 这段代码是 FFmpeg 配置脚本 (configure) 的典型参数设置，专门针对 ARMv7-A 架构（特别是早期 Android 设备常用的 Cortex-A8 处理器）进行性能优化。
    # 以下是各行参数的具体含义：
    # ## 1. --arch=arm --cpu=cortex-a8

    # * 作用：明确告知 FFmpeg 目标硬件。
    # * 影响：编译器会针对 Cortex-A8 的流水线特性进行指令调度优化。
    # * 背景：Cortex-A8 是第一款支持 NEON 指令集的架构（如经典的 iPhone 4 或早期三星 Galaxy S 系列）。

    # ## 2. --enable-neon

    # * 作用：开启 NEON (SIMD) 指令集加速。
    # * 重要性：这是多媒体处理的“性能怪兽”。NEON 可以并行处理多个数据（单指令多数据），在视频编解码（如 H.264 解码）、颜色空间转换（YUV 转 RGB）时，性能提升通常可达 3-10 倍。

    # ## 3. --enable-thumb

    # * 作用：使用 Thumb-2 指令集。
    # * 优势：Thumb 指令比标准的 32 位 ARM 指令更短（混合 16/32 位），可以显著减小生成的二进制文件（.so）体积（通常能缩小 20%-30%），同时在现代处理器上保持接近 ARM 指令的执行效率。

    # ------------------------------
    # ## 与你之前提到的内容串联：

    # * 编译器：这些参数会传递给 arm-linux-androideabi-gcc（或 Clang）。
    # * 中间产物：开启 neon 后，生成的 .o 文件中会包含大量的向量化指令。
    # * 配置：这些选项最终会写入生成的 config.h 中（例如 #define HAVE_NEON 1），从而让 FFmpeg 源码内部的 C 代码切换到高效的汇编版本。

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=arm --cpu=cortex-a8"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-neon"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-thumb"

    # 这段代码是用于 ARMv7-A 架构（特别是针对 Cortex-A8 处理器）的编译和链接参数配置，常出现在 FFmpeg 等多媒体库的 Android 交叉编译脚本中。 [1, 2] 
    # 以下是各项参数的详细解释：
    # ## 1. CFLAGS (编译选项) [3] 
    # FF_EXTRA_CFLAGS 中添加的参数主要定义了目标硬件的指令集和浮点运算方式：

    # * -march=armv7-a: 指定目标架构为 ARMv7-A。
    # * -mcpu=cortex-a8: 针对 Cortex-A8 处理器进行优化。Cortex-A8 是第一款支持 NEON 技术并广泛用于早期 Android 设备（如 Nexus One）的处理器。
    # * -mfpu=vfpv3-d16: 指定使用 VFPv3 浮点单元，且限制为 16 个 64 位寄存器（d0-d15）。这是 ARMv7-A 的标准配置，具有最广泛的兼容性。
    # * -mfloat-abi=softfp: 使用软浮点调用约定，但允许生成硬件浮点指令。
    # * 这意味着函数参数仍通过通用寄存器传递（与 soft 兼容），但内部计算由硬件 FPU 完成。这在早期的 Android NDK 中是标准做法，以确保二进制兼容性。
    # * -mthumb: 生成 Thumb-2 指令集。相比于标准的 ARM 指令，Thumb 指令更紧凑，可以显著减小生成的可执行文件体积，且在 ARMv7 上性能损耗极小。 [1, 2, 4, 5, 6, 7] 

    # ## 2. LDFLAGS (链接选项)
    # FF_EXTRA_LDFLAGS 中添加的参数用于处理特定的硬件缺陷：

    # * -Wl,--fix-cortex-a8: 这是一个链接器指令，用于修复 Cortex-A8 处理器早期版本中的一个 CPU 勘误（Errata）。
    # * 该缺陷可能导致某些特定序列的指令在 4KB 边界附近执行时发生错误。开启此选项后，链接器会在受影响的代码段插入补丁或跳转，以避开该缺陷。 [8] 

    # ## 总结
    # 这组配置的主要目的是：在保证最大兼容性的前提下（兼容所有 ARMv7 设备），针对 Cortex-A8 进行优化，并修复其已知的硬件缺陷。
    # 注意：如果你正在使用较新的 Android NDK（如 r19 及以上版本），Cortex-A8 已逐渐被视为过时。现代 NDK 默认使用更高效的 hard 浮点 ABI 或已经移除了对 --fix-cortex-a8 的默认支持。 [8] 
    # 您是在进行 FFmpeg 的 Android 移植 还是其他 ARM 嵌入式开发？建议根据您的 NDK 版本 确认是否需要调整这些参数。

    # [1] [https://stackoverflow.com](https://stackoverflow.com/questions/27436589/c-compiler-error-build-ffmpeg-for-android)
    # [2] [https://stackoverflow.com](https://stackoverflow.com/questions/77373572/armeabi-v7a-executable-compiles-but-so-doesnt)
    # [3] [https://elixir.bootlin.com](https://elixir.bootlin.com/glibc/glibc-2.33/source/INSTALL#:~:text=Any%20compiler%20options%20required%20for%20all%20compilations%2C,optimization%20and%20debugging%2C%20should%20go%20in%20%27CFLAGS%27.)
    # [4] [https://gist.github.com](https://gist.github.com/sdwfrost/beedeb49f92aecd3070751ea6a1e1ac4)
    # [5] [https://stackoverflow.com](https://stackoverflow.com/questions/8888945/enable-neon-on-cortex-a8-with-fpu-set-to-either-softvfp-or-none)
    # [6] [https://groups.google.com](https://groups.google.com/g/android-ndk/c/rVpPljdMbGs)
    # [7] [https://github.com](https://github.com/ml-explore/mlx/issues/20)
    # [8] [https://github.com](https://github.com/android/ndk/issues/766)
    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -march=armv7-a -mcpu=cortex-a8 -mfpu=vfpv3-d16 -mfloat-abi=softfp -mthumb"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -Wl,--fix-cortex-a8"

    FF_ASSEMBLER_SUB_DIRS="arm"

elif [ "$FF_ARCH" = "armv5" ]; then
    FF_BUILD_NAME=ffmpeg-armv5
    FF_BUILD_NAME_OPENSSL=openssl-armv5
    FF_BUILD_NAME_LIBSOXR=libsoxr-armv5
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=arm-linux-androideabi
    FF_TOOLCHAIN_NAME=${FF_CROSS_PREFIX}-${FF_GCC_VER}

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=arm"

    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -march=armv5te -mtune=arm9tdmi -msoft-float"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

    FF_ASSEMBLER_SUB_DIRS="arm"

elif [ "$FF_ARCH" = "x86" ]; then
    FF_BUILD_NAME=ffmpeg-x86
    FF_BUILD_NAME_OPENSSL=openssl-x86
    FF_BUILD_NAME_LIBSOXR=libsoxr-x86
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=i686-linux-android
    FF_TOOLCHAIN_NAME=x86-${FF_GCC_VER}

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=x86 --cpu=i686 --enable-yasm"

    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -march=atom -msse3 -ffast-math -mfpmath=sse"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

    FF_ASSEMBLER_SUB_DIRS="x86"

elif [ "$FF_ARCH" = "x86_64" ]; then
    FF_ANDROID_PLATFORM=android-21

    FF_BUILD_NAME=ffmpeg-x86_64
    FF_BUILD_NAME_OPENSSL=openssl-x86_64
    FF_BUILD_NAME_LIBSOXR=libsoxr-x86_64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=x86_64-linux-android
    FF_TOOLCHAIN_NAME=${FF_CROSS_PREFIX}-${FF_GCC_64_VER}

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=x86_64 --enable-yasm"

    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

    FF_ASSEMBLER_SUB_DIRS="x86"

elif [ "$FF_ARCH" = "arm64" ]; then
    FF_ANDROID_PLATFORM=android-21

    FF_BUILD_NAME=ffmpeg-arm64
    FF_BUILD_NAME_OPENSSL=openssl-arm64
    FF_BUILD_NAME_LIBSOXR=libsoxr-arm64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CROSS_PREFIX=aarch64-linux-android
    FF_TOOLCHAIN_NAME=${FF_CROSS_PREFIX}-${FF_GCC_64_VER}

    FF_CFG_FLAGS="$FF_CFG_FLAGS --arch=aarch64 --enable-yasm"

    FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS"
    FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS"

    FF_ASSEMBLER_SUB_DIRS="aarch64 neon"

else
    echo "unknown architecture $FF_ARCH";
    exit 1
fi

if [ ! -d $FF_SOURCE ]; then
    echo ""
    echo "!! ERROR"
    echo "!! Can not find FFmpeg directory for $FF_BUILD_NAME"
    echo "!! Run 'sh init-android.sh' first"
    echo ""
    exit 1
fi

FF_TOOLCHAIN_PATH=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/toolchain
FF_MAKE_TOOLCHAIN_FLAGS="$FF_MAKE_TOOLCHAIN_FLAGS --install-dir=$FF_TOOLCHAIN_PATH"

FF_SYSROOT=$FF_TOOLCHAIN_PATH/sysroot
FF_PREFIX=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output
FF_DEP_OPENSSL_INC=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_OPENSSL/output/include
FF_DEP_OPENSSL_LIB=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_OPENSSL/output/lib
FF_DEP_LIBSOXR_INC=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_LIBSOXR/output/include
FF_DEP_LIBSOXR_LIB=$FF_BUILD_ROOT/build/$FF_BUILD_NAME_LIBSOXR/output/lib

case "$UNAME_S" in
    CYGWIN_NT-*)
        FF_SYSROOT="$(cygpath -am $FF_SYSROOT)"
        FF_PREFIX="$(cygpath -am $FF_PREFIX)"
    ;;
esac


mkdir -p $FF_PREFIX
# mkdir -p $FF_SYSROOT


FF_TOOLCHAIN_TOUCH="$FF_TOOLCHAIN_PATH/touch"
if [ ! -f "$FF_TOOLCHAIN_TOUCH" ]; then
    $ANDROID_NDK/build/tools/make-standalone-toolchain.sh \
        $FF_MAKE_TOOLCHAIN_FLAGS \
        --platform=$FF_ANDROID_PLATFORM \
        --toolchain=$FF_TOOLCHAIN_NAME
    touch $FF_TOOLCHAIN_TOUCH;
fi


#--------------------
echo ""
echo "--------------------"
echo "[*] check ffmpeg env"
echo "--------------------"
export PATH=$FF_TOOLCHAIN_PATH/bin/:$PATH
#export CC="ccache ${FF_CROSS_PREFIX}-gcc"
export CC="${FF_CROSS_PREFIX}-gcc"
export LD=${FF_CROSS_PREFIX}-ld
export AR=${FF_CROSS_PREFIX}-ar
export STRIP=${FF_CROSS_PREFIX}-strip

FF_CFLAGS="-O3 -Wall -pipe \
    -std=c99 \
    -ffast-math \
    -fstrict-aliasing -Werror=strict-aliasing \
    -Wno-psabi -Wa,--noexecstack \
    -DANDROID -DNDEBUG"

# cause av_strlcpy crash with gcc4.7, gcc4.8
# -fmodulo-sched -fmodulo-sched-allow-regmoves

# --enable-thumb is OK
#FF_CFLAGS="$FF_CFLAGS -mthumb"

# not necessary
#FF_CFLAGS="$FF_CFLAGS -finline-limit=300"

export COMMON_FF_CFG_FLAGS=
. $FF_BUILD_ROOT/../../config/module.sh


#--------------------
# with openssl
if [ -f "${FF_DEP_OPENSSL_LIB}/libssl.a" ]; then
    echo "OpenSSL detected"
# FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-nonfree"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-openssl"

    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_OPENSSL_INC}"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_OPENSSL_LIB} -lssl -lcrypto"
fi

if [ -f "${FF_DEP_LIBSOXR_LIB}/libsoxr.a" ]; then
    echo "libsoxr detected"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-libsoxr"

    FF_CFLAGS="$FF_CFLAGS -I${FF_DEP_LIBSOXR_INC}"
    FF_DEP_LIBS="$FF_DEP_LIBS -L${FF_DEP_LIBSOXR_LIB} -lsoxr"
fi

FF_CFG_FLAGS="$FF_CFG_FLAGS $COMMON_FF_CFG_FLAGS"

#--------------------
# Standard options:
FF_CFG_FLAGS="$FF_CFG_FLAGS --prefix=$FF_PREFIX"

# Advanced options (experts only):
FF_CFG_FLAGS="$FF_CFG_FLAGS --cross-prefix=${FF_CROSS_PREFIX}-"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-cross-compile"
FF_CFG_FLAGS="$FF_CFG_FLAGS --target-os=linux"
FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-pic"
# FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-symver"

if [ "$FF_ARCH" = "x86" ]; then
    FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-asm"
else
    # Optimization options (experts only):
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-asm"
    FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-inline-asm"
fi

case "$FF_BUILD_OPT" in
    debug)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-optimizations"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --disable-small"
    ;;
    *)
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-optimizations"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug"
        FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-small"
    ;;
esac

#--------------------
echo ""
echo "--------------------"
echo "[*] configurate ffmpeg"
echo "--------------------"
cd $FF_SOURCE
if [ -f "./config.h" ]; then
    echo 'reuse configure'
else
    which $CC
    ./configure $FF_CFG_FLAGS \
        --extra-cflags="$FF_CFLAGS $FF_EXTRA_CFLAGS" \
        --extra-ldflags="$FF_DEP_LIBS $FF_EXTRA_LDFLAGS"
    make clean
fi

#--------------------
echo ""
echo "--------------------"
echo "[*] compile ffmpeg"
echo "--------------------"
cp config.* $FF_PREFIX
make $FF_MAKE_FLAGS > /dev/null
make install
mkdir -p $FF_PREFIX/include/libffmpeg
cp -f config.h $FF_PREFIX/include/libffmpeg/config.h

#--------------------
echo ""
echo "--------------------"
echo "[*] link ffmpeg"
echo "--------------------"
echo $FF_EXTRA_LDFLAGS

FF_C_OBJ_FILES=
FF_ASM_OBJ_FILES=
for MODULE_DIR in $FF_MODULE_DIRS
do
    C_OBJ_FILES="$MODULE_DIR/*.o"
    if ls $C_OBJ_FILES 1> /dev/null 2>&1; then
        echo "link $MODULE_DIR/*.o"
        FF_C_OBJ_FILES="$FF_C_OBJ_FILES $C_OBJ_FILES"
    fi

    for ASM_SUB_DIR in $FF_ASSEMBLER_SUB_DIRS
    do
        ASM_OBJ_FILES="$MODULE_DIR/$ASM_SUB_DIR/*.o"
        if ls $ASM_OBJ_FILES 1> /dev/null 2>&1; then
            echo "link $MODULE_DIR/$ASM_SUB_DIR/*.o"
            FF_ASM_OBJ_FILES="$FF_ASM_OBJ_FILES $ASM_OBJ_FILES"
        fi
    done
done

$CC -lm -lz -shared --sysroot=$FF_SYSROOT -Wl,--no-undefined -Wl,-z,noexecstack $FF_EXTRA_LDFLAGS \
    -Wl,-soname,libijkffmpeg.so \
    $FF_C_OBJ_FILES \
    $FF_ASM_OBJ_FILES \
    $FF_DEP_LIBS \
    -o $FF_PREFIX/libijkffmpeg.so

mysedi() {
    f=$1
    exp=$2
    n=`basename $f`
    cp $f /tmp/$n
    sed $exp /tmp/$n > $f
    rm /tmp/$n
}

echo ""
echo "--------------------"
echo "[*] create files for shared ffmpeg"
echo "--------------------"
rm -rf $FF_PREFIX/shared
mkdir -p $FF_PREFIX/shared/lib/pkgconfig
ln -s $FF_PREFIX/include $FF_PREFIX/shared/include
ln -s $FF_PREFIX/libijkffmpeg.so $FF_PREFIX/shared/lib/libijkffmpeg.so
cp $FF_PREFIX/lib/pkgconfig/*.pc $FF_PREFIX/shared/lib/pkgconfig
for f in $FF_PREFIX/lib/pkgconfig/*.pc; do
    # in case empty dir
    if [ ! -f $f ]; then
        continue
    fi
    cp $f $FF_PREFIX/shared/lib/pkgconfig
    f=$FF_PREFIX/shared/lib/pkgconfig/`basename $f`
    # OSX sed doesn't have in-place(-i)
    mysedi $f 's/\/output/\/output\/shared/g'
    mysedi $f 's/-lavcodec/-lijkffmpeg/g'
    mysedi $f 's/-lavfilter/-lijkffmpeg/g'
    mysedi $f 's/-lavformat/-lijkffmpeg/g'
    mysedi $f 's/-lavutil/-lijkffmpeg/g'
    mysedi $f 's/-lswresample/-lijkffmpeg/g'
    mysedi $f 's/-lswscale/-lijkffmpeg/g'
done

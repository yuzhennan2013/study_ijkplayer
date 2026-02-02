#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
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

# IJK_FFMPEG_UPSTREAM=git://git.videolan.org/ffmpeg.git
IJK_FFMPEG_UPSTREAM=https://github.com/bilibili/FFmpeg.git
IJK_FFMPEG_FORK=https://github.com/bilibili/FFmpeg.git
IJK_FFMPEG_COMMIT=ff4.0--ijk0.8.8--20210426--001
IJK_FFMPEG_LOCAL_REPO=extra/ffmpeg

#-e 参数表示只要shell脚本中发生错误，即命令返回值不等于0，则停止执行并退出shell。https://zhuanlan.zhihu.com/p/400723887
set -e
TOOLS=tools

git --version

echo "== pull ffmpeg base =="
# Mac终端命令行中执行"./"、"sh"命令运行文件的区别:https://juejin.cn/post/7428157656257118234
# ./ 用于执行当前目录下的可执行文件，需要文件具有执行权限。
# sh 用于调用 sh 解释器来执行脚本文件，不要求文件具有执行权限，但文件必须是一个文本文件。
sh $TOOLS/pull-repo-base.sh $IJK_FFMPEG_UPSTREAM $IJK_FFMPEG_LOCAL_REPO

function pull_fork()
{
    echo "== pull ffmpeg fork $1 =="
    # 使用git clone reference技术，将前述clone下来的$IJK_FFMPEG_LOCAL_REPO作为base，以引用的方式克隆各CPU架构到本地独立文件夹，避免重复网络传输及本地拷贝，节省时间和空间。
    sh $TOOLS/pull-repo-ref.sh $IJK_FFMPEG_FORK android/contrib/ffmpeg-$1 ${IJK_FFMPEG_LOCAL_REPO}
    cd android/contrib/ffmpeg-$1
    git checkout ${IJK_FFMPEG_COMMIT} -B ijkplayer
    cd -
}

pull_fork "armv5"
pull_fork "armv7a"
pull_fork "arm64"
pull_fork "x86"
pull_fork "x86_64"

./init-config.sh
./init-android-libyuv.sh
./init-android-soundtouch.sh

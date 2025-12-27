#! /usr/bin/env bash

REMOTE_REPO=$1
LOCAL_WORKSPACE=$2

# -o　　: or
# -z string 测试指定字符是否为空，空着真，非空为假：https://www.cnblogs.com/pugang/p/13167714.html
# [ -d FILE ] 如果 FILE 存在且是一个目录则为真。
if [ -z $REMOTE_REPO -o -z $LOCAL_WORKSPACE ]; then
    echo "invalid call pull-repo.sh '$REMOTE_REPO' '$LOCAL_WORKSPACE'"
elif [ ! -d $LOCAL_WORKSPACE ]; then
    git clone $REMOTE_REPO $LOCAL_WORKSPACE
else
    cd $LOCAL_WORKSPACE
    git fetch --all --tags
    # 在 shell 中，cd - 命令是 change directory 的缩写，其功能是切换到上一个工作目录，即你执行 cd 命令之前所在的那个目录，它能快速地在两个目录之间来回跳转，非常方便。 
    cd -
fi

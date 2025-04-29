#!/bin/bash

# 使用方法: ./update_version.sh [版本号]
# 例如: ./update_version.sh 1.2.0

if [ $# -ne 1 ]; then
    echo "用法: $0 版本号"
    echo "例如: $0 1.2.0"
    exit 1
fi

VERSION=$1
# 移除版本号前的 'v'（如果有）
VERSION=${VERSION#v}

# 更新 Info.plist 中的版本号
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "./Kettle/Info.plist"

# 更新 Info.plist 中的构建号（可选，这里简化为和版本号相同）
BUILD=$(date +%Y%m%d)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "./Kettle/Info.plist"

echo "版本已更新到 $VERSION (构建: $BUILD)"
echo "现在您可以提交这些更改并创建新的 Git 标签:"
echo "git add ."
echo "git commit -m \"发布版本 $VERSION\""
echo "git tag -a v$VERSION -m \"版本 $VERSION\""
echo "git push origin main v$VERSION" 
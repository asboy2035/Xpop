#
//  create_dmg.sh
//  Xpop
//
//  Created by Dongqi Shen on 2025/1/13.
//

#!/bin/zsh

# 变量设置
APP_NAME="Xpop"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
APP_PATH="${APP_NAME}.app"
DMG_TEMP="temp.dmg"
DMG_FINAL="${APP_NAME}_Final.dmg"

# 创建临时DMG文件
hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200m "${DMG_TEMP}"

# 挂载DMG文件
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_PATH="/Volumes/${VOLUME_NAME}"

# 设置卷图标
# 使用 `touch` 更新目录的修改时间，这有助于强制刷新图标
touch "${MOUNT_PATH}"
# 使用 `SetFile -a C` 设置自定义图标属性
SetFile -a C "${MOUNT_PATH}"

# 卸载并重新挂载DMG文件以确保图标生效
hdiutil detach "${DEVICE}"
sleep 1 # 增加一个短暂的延迟
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | egrep '^/dev/' | sed 1q | awk '{print $1}')

# 创建Applications文件夹的快捷方式
ln -s /Applications "${MOUNT_PATH}/Applications"

# 设置DMG窗口布局
echo '
   tell application "Finder"
     tell disk "'${VOLUME_NAME}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 900, 400}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 72
           set position of item "Applications" of container window to {100, 100}
           set position of item "'${APP_PATH}'" of container window to {400, 100}
           update without registering applications
           delay 2
           eject
     end tell
   end tell
' | osascript

# 压缩DMG文件
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}"

# 清理临时文件
rm -f "${DMG_TEMP}"

echo "DMG文件已生成：${DMG_FINAL}"

<p align="center">
  <!-- 浅色模式图片 -->
  <source srcset="Xpop/Assets.xcassets/AppIcon.appiconset/solar--cursor-square-linear-256x256.png" media="(prefers-color-scheme: light)">
  <!-- 深色模式图片 -->
  <source srcset="Xpop/Assets.xcassets/AppIcon-White.appiconset/solar--cursor-square-linear-256x256.png" media="(prefers-color-scheme: dark)">
  <!-- 默认图片（显式回退） -->
  <source srcset="Xpop/Assets.xcassets/AppIcon.appiconset/solar--cursor-square-linear-256x256.png" media="all">
  <!-- 最终默认图片 -->
  <img src = "Xpop/Assets.xcassets/AppIcon.appiconset/solar--cursor-square-linear-256x256.png">
<h1 align="center">Xpop</h1>
<h4 align="center">An open-source text selection tool for macOS, a PopClip alternative.</h4>

<p align="center">
<a href="https://github.com/DongqiShen/Xpop/blob/main/LICENSE">
<img src="https://img.shields.io/github/license/dongqishen/xpop" alt="License"></a>          
<a href="https://img.shields.io/badge/-macOS-black?&logo=apple&logoColor=white">
<img src="https://img.shields.io/badge/-macOS-black?&logo=apple&logoColor=white" alt="macOS"></a>  

> [!IMPORTANT]
> This project is under active development and may have bugs. Inspired by PopClip, I’m building an open-source alternative with plans to fully support its plugin system (currently limited). As this is my first Swift project, the code will evolve as I learn and improve. Feedback is welcome!


## Popclip Extensions Compatibility
> [!IMPORTANT]
> PopClip's plugin system is highly sophisticated and powerful. Achieving full compatibility with it will be a lengthy process. My priority is to implement basic functionality first. Feedback is welcome, and I will prioritize feature requests for future development.


### Icons
1. Supports SF Symbols and the vast majority of modifiers.
2. Do not support iconify icons.
3. Do not support local icons.

### Actions
#### Open URL actions
1. Support URL scheme.
2. Only support `url` property, do not support `options` yet.

## Acknowledgement

This repo benefits from [Easydict](https://github.com/tisfeng/Easydict), [PopClip-Extensions](https://github.com/pilotmoon/PopClip-Extensions). Thanks for their wonderful works.

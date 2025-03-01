<p align="center">
  <picture>
    <!-- 深色模式图片 -->
    <source srcset="Xpop/Assets.xcassets/AppIcon-White.appiconset/solar--cursor-square-linear-256x256.png" media="(prefers-color-scheme: dark)">
    <!-- 浅色模式图片 -->
    <source srcset="Xpop/Assets.xcassets/AppIcon.appiconset/solar--cursor-square-linear-256x256.png" media="(prefers-color-scheme: light)">
    <!-- 默认图片 -->
    <img src="Xpop/Assets.xcassets/AppIcon.appiconset/solar--cursor-square-linear-256x256.png" alt="App Icon">
  </picture>
</p>
<h1 align="center">Xpop</h1>
<h4 align="center">An open-source text selection tool for macOS, a PopClip alternative.</h4>

<p align="center">
<a href="https://github.com/DongqiShen/Xpop/blob/main/LICENSE">
<img src="https://img.shields.io/github/license/dongqishen/xpop" alt="License"></a>          
<a href="https://img.shields.io/badge/-macOS-black?&logo=apple&logoColor=white">
<img src="https://img.shields.io/badge/-macOS-black?&logo=apple&logoColor=white" alt="macOS"></a>  

> [!IMPORTANT]
> This project is under active development and may have bugs. Inspired by PopClip, I’m building an open-source alternative with plans to fully support its plugin system (currently limited). As this is my first Swift project, the code will evolve as I learn and improve. Feedback is welcome!

## What is Xpop?

Xpop is a utility tool for Mac that pops up a menu with multiple actions when text is selected in **any application**.

The action features of Xpop are quite extensive, ranging from simple **copy-paste** and **web searches** to more complex operations. Xpop offers an easy-to-use **plugin system**, allowing developers to easily create and implement the functionalities they desire.

Xpop is a **free** and **open-source software**, and anyone can view and obtain its source code on GitHub. You can consider it as an alternative to PopClip, with **partial compatibility with its plugin system**. PopClip is an excellent software that I highly admire.

Xpop is exclusively designed for the **Mac platform** and is written in Swift. I hope that this native application will deliver an even better user experience.

<p align="center">
  <img src="assets/xpop-translate.gif">
</p>

## Getting Started

Download the latest version of Xpop from the [GitHub Releases page](https://github.com/DongqiShen/Xpop/releases).

For more details, please visit the official [website](https://xpop.oneapis.uk).
- [Installation](https://xpop.oneapis.uk/guide/installation)
- [Extensions](https://xpop.oneapis.uk/guide/extensions)

## Developer

### Package Extension
1. Add the extension .xpopext to the folder.
   ```
   move YOUR_EXTENSION_NAME YOUR_EXTENSION_NAME.xpopext
   ```
2. Set it to Package
   ```
   SetFile -a B YOUR_EXTENSION_NAME.xpopext
   ``` 
3. Double click the extension to install it.

## Popclip Extensions Compatibility
> [!IMPORTANT]
> PopClip's plugin system is highly sophisticated and powerful. Achieving full compatibility with it will be a lengthy process. My priority is to implement basic functionality first. Feedback is welcome, and I will prioritize feature requests for future development.


### Icons
1. Supports SF Symbols and the vast majority of modifiers.
2. Do not support iconify icons.
3. Do not support local icons.

### Actions

### Open URL actions

#### Google Search
```yaml
# xpop
name: Google
icon: symbol:magnifyingglass
url: https://www.google.com/search?q={xpop text}
```

#### Use of option parameter
```yaml
# xpop Wiktionary search with subdomain option
name: Wiktionary
url: https://{xpop option subdomain}.wiktionary.org/wiki/{xpop text}
options:
- type: string
  label: subdomain
  defaultValue: en
```

## Acknowledgement

This repo benefits from [Easydict](https://github.com/tisfeng/Easydict), [PopClip-Extensions](https://github.com/pilotmoon/PopClip-Extensions). Thanks for their wonderful works.

# FormatFlow · 格式工坊

原生 macOS 离线格式转换工具，支持图片、PDF、Office 文档和音频。使用 Swift + AppKit 编写，支持拖入文件和批量转换，保留原文件，同名输出自动编号。

**系统要求：Apple Silicon（M 系列芯片），macOS 13 或更新版本。** 本地构建版本尚未经过 Apple 开发者签名和公证。

## 下载与安装

在 [Releases](https://github.com/sl080/FormatFlow/releases) 下载 `FormatFlow-1.1.dmg`，打开后将 FormatFlow 拖入 Applications。

如果首次打开被系统阻止，请在系统设置 → 隐私与安全性中查看并允许打开你信任的此应用。

## 支持的转换

| 类型 | 输入 | 输出 |
| --- | --- | --- |
| 图片 | PNG、JPEG、HEIC、TIFF、BMP、GIF、WebP（依系统解码能力） | PDF、PNG、JPG、TIFF、BMP、HEIC |
| PDF | 未加密 PDF | PNG、JPG、TIFF、BMP、HEIC，每页输出一张 |
| 文档 | DOC/DOCX、XLS/XLSX、PPT/PPTX、ODF、RTF、TXT、CSV、HTML | PDF |
| 音频 | MP3、WAV、M4A、AAC、FLAC、AIFF、CAF 等系统支持的音频 | WAV、M4A、AAC、FLAC、AIFF、CAF |

MP3 当前仅支持导入。M4A/AAC 设置目标码率为 192 kbps；WAV/AIFF/CAF 使用 16 位 PCM。转换为无损格式不会恢复有损音频已经丢失的信息。不承诺保留全部音频标签、封面或歌词。

这不是任意格式转换器：当前不支持 OCR、PDF 转可编辑 Word、视频转换或受 DRM 保护的文件。Office 排版会受到字体和转换引擎影响。

## 使用

1. 添加文件，或将文件拖入窗口。
2. 选择目标格式。首次添加音频默认选择 M4A。
3. 选择保存位置，点击“开始转换”。
4. 在窗口查看各文件结果，点击“打开输出文件夹”。

所有转换在本机完成。详细说明见 [使用说明](使用说明.md)。

## 从源码构建

需要 macOS、Apple Command Line Tools（含 Swift）和完整的 LibreOffice.app。Office 引擎不存入源码仓库；构建时复制你指定的完整应用，保留其许可证文件。

在仓库目录执行：

```zsh
OFFICE_ENGINE_APP=/Applications/LibreOffice.app zsh build.sh
```

产物为 `dist/FormatFlow.app` 和 `FormatFlow-1.1.dmg`。脚本默认构建 Apple Silicon 版本，只进行本地临时签名；分发公证需自行配置 Apple Developer 证书。

- `main.swift`：界面、批量任务和转换逻辑。
- `Info.plist`、`AppIcon.icns`：应用元数据和图标。
- `icon.swift`：图标生成源文件。
- `build.sh`：构建与打包脚本。

## 验证与第三方组件

图片转 PDF、DOCX 转 PDF、PDF 转图片已完成本机验证。新增六种音频输出已检查时长，并回转解码核对有效样本、声道和采样率。没有穷举所有文件格式、复杂文档或全部系统版本；MP3 导入尚未做样本验证。

Office 转换由随安装包内置的 LibreOffice 提供；音频转换使用系统 `afconvert`。第三方版权和许可说明见 [THIRD_PARTY.md](THIRD_PARTY.md)。

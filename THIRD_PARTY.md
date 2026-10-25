# 第三方组件

## LibreOffice

Office 文档转 PDF 使用完整内置的 LibreOffice 引擎。源码仓库不包含引擎二进制；安装镜像中的引擎位于：

`FormatFlow.app/Contents/Resources/OfficeEngine.app`

保留的版权及许可说明：

- `Contents/Resources/LICENSE`
- `Contents/Resources/LICENSE.html`

LibreOffice 官网及源代码获取入口：

- https://www.libreoffice.org/
- https://www.libreoffice.org/about-us/licenses/
- https://www.libreoffice.org/download/download-libreoffice/

LibreOffice 及其依赖分别遵循各自的许可条款，以上保留声明为准。FormatFlow 不修改其引擎代码。

## Apple 系统框架

图像和 PDF 处理使用 macOS Cocoa、PDFKit、ImageIO；音频使用系统 afconvert 和 AVFoundation。这些系统组件不随源码仓库重新分发。

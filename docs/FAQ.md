# FAQ

## User Interface

### How can I export a picture?

There is an export button on the right side of the window, 
clicking on it will show the file export dialog box. 

![Export Button](export_button.png)

You can also drag drop the content of the window to the desktop or another application, or copy paste it into Preview.

## Rendering

### Is the rendering pixel accurate?

Generally, no. Vector drawing instructions are translated into Core Graphics instructions, which will result in different pixel rendering, in particular when you consider that modern Mac computers have much higher resolution. Pixmap rendering _should_ be accurate.

### How can I get pixel accurate rendering?

Your best bet for getting pixel correct rendering is to run a Mac emulator, like for instance the excellent [Infinite Mac](https://infinitemac.org), upload your file and convert it there, either in a modern bitmap format like PNG, or EPS, maybe by printing to an emulated printer. 

## QuickTime Images

### Could you export the embedded image files?

If the QuickTime container holds a single image in a format that is supported externally, like JPEG or TIFF, it would sense to export that content (extraction) and avoid all the possibly lossy conversions.
This is a feature I'm looking into implementing.

### Can you support codec `WXYZ`? 

Possibly. Generally, for me to add support for a Codec, I need some samples, and ideally some form of documentation or a pointer to some other code that supports said codec (say FFMPEG). 

## SVG 

### Can the program export SVG?

No.

### Is SVG support planed? 

No. If you feel like implementing it, you are most welcome, but this is not something I'm interested in doing. The SVG format is complex, and few programs except web-browers support it. My primary goal was making a simple program that would three things:

* Allow me hack around quickly with minimal back-end work.
* Display the pictures in the application.
* Exporting them in formats that are useful on a modern Mac.

SVG fullfill none of these goals. 

Rendering to SVG would require a different rendering back-end, with additional conversion logic, as SVG can only embed limited Bitmap formats (PNG and JPG), so while vector instructions could be dispatched directly, pixmap (including patterns) would need to be rendered and exported as PNG data.

This would be quite cumbersome for QuickTime rendering, as embedded TIFF or TARGA data would need to be converted into PNG. There are plenty of libraries that can do this, but this would increase the scope of the project. 

Some features like ICC colour profiles are _theoretically_ supported, but browswer support is limited.

## Linux

### Can the program be compiled for Linux?

No. Even though the Swift language is cross-platform, QuickDraw viewer relies on many frameworks like CoreGraphics, CoreText and CoreImage for back-end rendering. The parser probably compiles fine of most platforms, but the renderer won't. 

There is an open-source project to implement a [CoreGraphics alternative](https://github.com/OpenSwiftUIProject/OpenCoreGraphics), but that is only one component, as you would also need an equivalent to CoreText and CoreImage to get any basic rendering working. A more reasonable solution for Linux would be to render to SVG and use some SVG renderer, see above.



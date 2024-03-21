#  QuickDraw Viewer

![QuickDraw Viewer Icon](QuickDrawViewer/Assets.xcassets/AppIcon.appiconset/Icon128.png)

I wanted to teach myself Swift programming, and needed something a bit more involved than just _Hello World_, so I decided the write a program that would decode QuickDraw image files and display them. This was basically a rewrite of the [Java Quickdraw](https://github.com/wiesmann/JavaQuickDraw) code I wrote, many years back.
This program is far from finished, but I decided to release it for the 40th anniversary of the original Macintosh computer: QuickDraw was the graphical language of the original Macintosh, and the format used to store and exchange images on the computer. Support for these files has been slowly decaying with newer versions of Mac OS X, and on my M1 PowerBook, Preview can only open a small subset of the files I have.

## Philosophy

This program is not meant to be a pixel correct QuickDraw renderer,
instead it behaves more like a _printer driver_ did under the classic Mac OS,
and tries to render pictures as well as possible on a modern Mac OS X screen.

The screen of my 2021 14" laptop has a resolution of around 264 DPI, 
closer to the resolution of the LaserWriter printers (300DPI) than that of the screen
of a compact Macintosh (72 DPI) and well above the resolution of an ImageWriter dot matrix printer (144 DPI.)
The rendering engine of Mac OS X is also closer to a PostScript printer than the QuickDraw model.

So this program mostly translates QuickDraw instructions and delegates most of the actual rendering to Core Graphics.
Instructions meant for printers (QuickDraw _comments_) are also used in the translation.

## Original Pict Example

The decoder is mostly based on `Inside Macintosh - Imaging With QuickDraw` published in 1994.
The book contains the resource definition of very simple QuickDraw picture.
```
data 'PICT' (128) {
$"0078"     /* picture size; don't use this value for picture size */
$"0000 0000 006C 00A8"  /* bounding rectangle of picture at 72 dpi */
$"0011"     /* VersionOp opcode; always $0011 for extended version 2 */
$"02FF"     /* Version opcode; always $02FF for extended version 2 */
$"0C00"     /* HeaderOp opcode; always $0C00 for extended version 2 */
            /* next 24 bytes contain header information */
   $"FFFE"  /* version; always -2 for extended version 2 */
   $"0000"  /* reserved */
   $"0048 0000"         /* best horizontal resolution: 72 dpi */
   $"0048 0000"         /* best vertical resolution: 72 dpi */
   $"0002 0002 006E 00AA"  /* optimal source rectangle for 72 dpi horizontal
                              and 72 dpi vertical resolutions */
   $"0000"  /* reserved */
$"001E"     /* DefHilite opcode to use default hilite color */
$"0001"     /* Clip opcode to define clipping region for picture */
   $"000A"  /* region size */
   $"0002 0002 006E 00AA"  /* bounding rectangle for clipping region */
$"000A"     /* FillPat opcode; fill pattern specified in next 8 bytes */
   $"77DD 77DD 77DD 77DD"  /* fill pattern */
$"0034"     /* fillRect opcode; rectangle specified in next 8 bytes */
   $"0002 0002 006E 00AA"  /* rectangle to fill */
$"000A"     /* FillPat opcode; fill pattern specified in next 8 bytes */
   $"8822 8822 8822 8822"  /* fill pattern */
$"005C"
$"0008"
$"0008"
$"0071"
/* fillSameOval opcode */
/* PnMode opcode */
/* pen mode data */
/* paintPoly opcode */
   $"001A"  /* size of polygon */
   $"0002 0002 006E 00AA"  /* bounding rectangle for polygon */
   $"006E 0002 0002 0054 006E 00AA 006E 0002"   /* polygon points */
$"00FF"     /* OpEndPic opcode; end of picture */
}; 
```

You can [download the compiled Pict file](docs/inside_macintosh.pict).
he rendering in the book looks like this:

![Example Pict](docs/inside_macintosh_listing_A5.png)

This is how the Picture is rendered in Preview Version 11.0 on Mac OS X 14.4 (Sonoma).

![Example Pict (Broken)](docs/inside_macintosh_preview.png)

This is how it is rendered in QuickDraw Viewer:

![Example Pict (QuickDraw Viewer)](docs/inside_macintosh_pict.png)


## Supported File types

This application basically handles QuickDraw image files, but also two related (but distinct) image formats:

* QuickTime images (`QTIF`) 
* MacPaint images (`PNTG`)

These two formats are handled by converting them into QuickDraw at load time.
QuickTime images are supported so far as the underlying codec is supported.
MacPaint images are supported by virtue of being one of codecs that can be embedded inside QuickTime.

## Structure

This program has basically three parts:

* A library that parses QuickDraw files, which only depends on the `Foundation` framework.
* A Library that renders into a CoreGraphics context, which depends on CoreGraphics, CoreText and CoreImage.
* A minimalistic Swift-UI application that shows the pictures. 

This means the code could be used in other applications that want to handle QuickDraw files.

## Features

The library basically parses QuickDraw version 1 and version 2 files

* Lines
* Basic Shapes (Rectangles, Ovals, Round-Rectangles and Arcs)
* Regions
* Text
* Patterns (black & white)
* Colours
* Palette images
* Direct (RGB) images
* QuickTime embedded images with the following codecs:
  * External image formats: JPEG, TIFF, PNG, BMP, JPEG-2000, GIF 
    (these are handled natively by the renderer)
  * RAW (`raw `)
  * MacPaint
  * Apple Video (`RPZA`)
  * Apple Component Video (`YUV2`)
  * Apple Graphics (`smc `)
  * Apple Animation (`RLE `) with depths of 2,4,8,16, 24 and 32 bits/pixel
  * Planar Video (`8BPS`). 

Some basic comment parsing is used to improve images, in particular:

* Polygon annotations to connect the lines and close polygons
* Fractional pen width
* Text rotation

## Unsupported features

Currently, the following QuickDraw features don't work:

* Some exotic compositing modes (which are typically not supported by printers)
* Text alignement
* Polygon smoothing
* Color patterns
* Exotic QuickTime codecs, like for instance Photo-CD

## User Interface Application

The application is currently very simple, you can view pictures, copy-paste them to Preview. 
There is an export icon in the toolbar that allows you to export to PDF files. 
There is some primitive drag-drop that works when the target is Notes or Pages, but not when the target expects a file, like the Finder or Mail.

## License 

The code is distributed under the [Apache 2.0 License](License.txt).

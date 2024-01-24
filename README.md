#  QuickDraw Viewer

![](Icon128.png)

I wanted to teach myself Swift programming, and needed something a bit more involved than just _Hello World_, so I decided the write a program that would decode QuickDraw image files and display them. This was basically a rewrite of the [Java Quickdraw](https://github.com/wiesmann/JavaQuickDraw) code I wrote, many years back.

This program is far from finished, but I decided to release it for the 40th anniversary of the original Macintosh computer: QuickDraw was the graphical language of the original Macintosh, and the format used to store and exchange images on the computer. Support for these files has been slowly decaying with newer versions of Mac OS X, and on my M1 PowerBook, Preview can only open a small subset of the files I have.

## Structure

This program has basically three parts:

* A library that parses QuickDraw files, which only depends on the `Foundation` framework.
* A Library that renders into a CoreGraphics context, which depends on CoreGraphics, CoreText and CoreImage.
* A minimalistic Swift-UI application that shows the pictures. 

This means the code could be used in other applications that want to handle QuickDraw files.

## Features

The library basically parses QuickDraw version 1 and version 2 files, and supports the following features.

* Lines
* Basic Shapes (Rectangles, Ovals, Round-Rectangles and Arcs)
* Regions
* Text
* Patterns (black & white(
* Colours
* Palette images
* Direct (RGB) images
* QuickTime embedded images with the following codecs:
  * JPEG, TIFF, PNG, BMP
  * RAW

Some basic comment parsing is used to improve images, in particular:

* Polygon annotations to connect the lines and close polygons
* Fractional pen width

## Unsupported features

Currently, the following QuickDraw features don't work:

* All modes except `copy`
* Text rotation
* Exotic QuickTime codes, in particular:
  * Photo-CD
  * Apple Video (`RPZA`)
  
## Application

The application is currently very simple, you can view pictures, copy-paste them to Preview. There is some primitive drag-drop that works when the target is Notes or Pages, but not when the target expects a file, like the Finder or Mail.


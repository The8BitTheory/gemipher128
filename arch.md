# Architecture of Gemipher 128

As there's a given variety of C128 setups, I think it makes sense to design to approaches:
- classic mode:
    the current "reality" is currently on screen.
    pages from the history are fully re-loaded from the network, only addresses stay in memory
    swapping to disk might be an option
    if 64k VRAM are available, we can use it for display as if it was a 16k setup
        and use the remaining 48k as memory. adds up to about 108 kb of total usable memory for content.
- tabbed mode: 
    c128 RAM layout is same as in classic mode for displaying data
    gopher/text data is directly loaded into expanded memory, lookup tables are saved alongside history information
    pages from the history are loaded into ram from expanded memory
    multiple pages/views can be open at the same time (eg maximum 4)


## Load and persist data
Loading and persisting data is one common step, because the amount of data can be too much to keep as one single block in memory
* via WiC64
* via disk/sd-iec/other local device
* to C128 Bank 1,2,3
* to GeoRAM
* to REU
* maybe also to VDC, if no other expansion is available

The goal of this step is to have all data from the download available locally (if possible).
Data is loaded into expanded memory immediately, or at least in chunks of a couple (hundred) bytes.
After loading is complete, the first block is copied to Bank 1.

## Parse data
The goal of parsing is to have lookup tables with pointers to relevant data.
The formats to parse are:
* Gopher file format
* Plain text files
* future: Gemtext

For Gopher files, these are 9 bytes long and contain
pointers to every part of the gopher line (text, text-length, selector, host, port).

For plain text files, entries of the lookup table are 3 bytes long, as we only have
pointer to text line and length of textline.
For plain text files, this should probably just be done on-the-fly, but it's needed 
for Gopher files due to lines consisting of visible and invisible content.
Gopher files don't usually tend to become as long as plain text files.
For example: In the beginning was the command line has close to 4000 lines.
For a lookup table with 3 bytes per entry, that would be 12000 bytes.
12k is manageable, but the question is: where is the limit?
If a Gopher file becomes so long, ok. But if we can handle plain text files without that, it would make things easier.


## Display data
Right now, displaying data on screen is done in two steps:

First, part of the visible data is copied to a backbuffer in VRAM. Second,
the lines that are supposed to be visible are block copied to the frontbuffer.

Depending on the length of lines, at least 3 or 4 pages can be held in the vram backbuffer
right now. For listings of directories, usually even more.
Right now, we work with 6 kb of VRAM backbuffer. That fits a 16 kB VRAM configuration.
With 64 kB VRAM, we could either have a larger single backbuffer, or keep more pages in VRAM.
Especially when skipping back and forth in the browsing history, we might just skip over pages real quick.




## More thoughts

### Swapping to disk
Persisting to sd2iec or 1581 might be a reasonable thing to do, provided that it's fast enough.

Storing each line in a REL file might make sense for faster read access.

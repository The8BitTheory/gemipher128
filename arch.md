# Architecture of Gemipher 128

Three major pillars of dataflow: input, processing, output

## Input

### Load content into RAM
This can be done via Network interface (Wic64, Ultimate, X16, Mega) or be loaded from disk (IEC Kernal, Ultimate DMA)

### Userinput via Keyboard
Keyboard input should just be readable from kernal routines. Different addresses, but similar behavior.

## Processing

### Parse data
This builds a lookup table with pointers for type, text, length of text, host, port, and selector.
For plain text files, the processing is different.
Audio files will present a page that allows for playback via wic64-mex, for a start.

### Petscii to Ascii
C64 and Mega65 can very likely use similar conversion routines.
The X16 might need none at all, or different ones.

### Create Decimal output
for printing numbers

### Create Hexadecimal output
for printing numbers (addresses, mainly)

## Output

### Display on screen
This can be VDC, X16 Vera, Mega65 VIC-IV, maybe C64 Kawari.
Very likely we're not going to use standard chrout routines in all cases (eg the VDC),
but instead use direct access to videochip registers.
For Mega65 and X16 we might be better off using kernel routines, though.

### Write to disk
We can save the currently viewed resource to disk (gopher or text files),
or the media behind an information page (eg audio files, binaries, images, ...)



# Common Interfaces
## Input

### Load Content
Network interfaces will be the common device for loading.
But any sufficiently fast devicetype that allows for loading files should work. (that excludes tape drives)

#### High level API
Load from network: host:port/selector
Load from disk: dev:8/filename
More with proprietary APIs are possible (don't know how RAM-Link etc work)

Do we need a protocol/datatype definition like gopher:// ?
I don't think so... at least not until more (eg Gemini) are supported

#### loadFromDisk
- device nr
- filename (can include path for supported devicetypes)

#### loadFromNetwork
- host
- port
- path (selector)

### Keyboard and Mouse input

#### Keyboard
- get input. must also work for function keys and modifiers, etc.

#### Mouse
don't have a clue as of yet on how this needs to be implemented.
Behavior of the mouse should be dependent on the screen area.
Click in the address bar enables address entry mode.
Hover in the content area moves the cursor. Click is equivalent to hitting the Return key.
Hover in the bottom area does nothing.
Scrolling with the mouse might be better with a scroll bar.

## Output

### Printing
- makeItHex
- makeItDec

### UI-Related
- clearScreen
- createStatusBar
- createAddressBar
- createMenuBar (not in current version)

### Data
#### Screen
- displayGopher
- displayPlainText
- displaySound
- displayUnknownFiletype
- displayTimeout
- displayError

#### Disk
- downloadToDisk (eg binary file or image or audio file)
- saveToDisk    (eg currently displayed Gopher dir or plaintext file)

# Generic features

## Filetypes
We can display Gopher dirs or plaintext files.
Gopher dirs show a cursor and lines are shorter, to leave room for the cursor.
The screen scrolls below and above a certain cursor position.

Plaintext files scroll the full screen and lines are 80 cols long.

All other pages (unknown file type, etc) behave like Gopher files.
That allows us to display a cursor and offer choices to the user.

## History
When visiting a location that's manually entered, or picked from a Gopher dir,
it is added to the history at the current position. That means, if we are in the
middle of a history list, the subsequent entries are dropped.

When visiting a location from the history list, we just put the pointer to that
location and allow the user to navigate forward and backward in the history list.

When leaving a page, we store the current scrolling position and cursor position
of the page we're leaving.
The page we enter will be added to the history list. The entry contains
selector and gophertype.

# Program flow
We have dedicated binaries for each supported platform. C128, X16, Mega65, C64-Kawari.

## Startup
Upon startup, we detect present memory and hardware options.
C128: 2 or 4 banks, 16 or 64 kB VRAM, REU size, GeoRAM size, Ultimate-II, WiC64, disk drives
X16: 512 kB or 2048 kB RAM, Network interface, disk drives
Mega65: Attic-RAM size (0 or 8 MB), disk drives
C64-Kawari: REU size, GeoRAM size, Ultimate-II, WiC64, disk drives

## Start screen
The first screen is a Gopher dir that's loaded from disk.
That acts as a quickstart manual and offers some first options via cursor selection.
If program settings are ever supported, the user could configure a custom start screen (eg floodgap)

## User input
Once the start screen is displayed, the user can move the cursor or hit one of the hotkeys.


# Memory Organization
The following types of data exist in Gemipher:
- content: can be a gopher dir or plain text. has start- and end address, and a bank number
- linetable: pointers to each line of a gopher dir and each of the parts. one entry is about 10 bytes in size.
- vram-table: depending on videochip speed, we might want to have pre-warmed data in vram backbuffer (eg vdc)
- history: host:port/selector, scrollposition, cursorposition.
           consists of an entry-list and a pointer-list, due to the variable length of host:port/selector

## Memory expansions
Visible content is in the VRAM's frontbuffer.
There might be a backbuffer with pre-warmed data, or data could be made visible on-the-fly (mega65, for example).
The challenge is when a certain memory pool is full and data needs to be pulled in from another one.
Let's take a text file with 500 kb in size.

An example on the c128:
About 64 kb fit in main memory if we have 2 banks
About 192 kb, if we have 4 banks.
The rest 308 kb is stored in the REU, GeoRAM or a swap file (Ultimate-II DMA).
If 64 kB VRAM is available, we could also use a part of it as if it was RAM.

On the x16:
8 kb fit in main memory in one bank. the 500 kb are split across 8 kb chunks.
We can switch between banks and copy to VRAM accordingly.

On the Mega65:
Everything fits into Attic-RAM. Should be the simplest to implement.
We can directly DMA-copy from Attic-RAM into VRAM.

On the C64-Kawari:
RAM for single chunks is probably as limited as on the X16.
But instead of copying directly from different 8kB banks, we'll need to 
copy to RAM first (from GeoRAM, the REU or a swap-file) and then write to VRAM.
At least, the VIC-II memory area can be used for this, so we can REU-DMA-RAM-DMA-VRAM in 16 kB chunks.

# Memory
The program is written in assembly language. Usually, no Basic routines will be used.
On the C128, there might be some exceptions to this, like for disk I/O. Over time, all these should
be replaced with custom assembly code or just kernal routines.

## C128
Kernal ($E000-$FFFF) and I/O space ($Dxxx) are be enabled by default.
Reading and writing in Bank 0 should be restricted to the area below $D000. (about 45k available)
Reading and writing in Bank 1 is always done through far routines, so close to 63 kb are available.
Same goes for banks 2 and 3, if available.
I/O is needed for accessing the network interface and the VDC registers.

## X16
Kernal and I/O space is always active.
Program code (and lookup tables) has about 48 k available.

## Mega65
Program code is restricted to bank 0, just like on all the other machines.
Writing below I/O or Kernal space might be easier, but about 40 kb available RAM should be ok.
We might just use [],z to access higher banks.
Just relying on Attic-RAM would exclude all Nexys Boards

## C64 Kawari
With only Kernal and I/O space enabled, we should have the same 45 kb available as on the c128's bank 0.
Instead of using higher banks, we can only use GeoRAM or REU.
DMA communication with the VIC-II Kawari can be done via DMA from the VIC-II's accessible 16 kb bank,
or byte-by-byte from anywhere in C64 RAM.




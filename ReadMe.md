## Starbound Build Tools 

This vanilla-compatible starbound mod includes :

* Painting tool
 * A tool that provides a few advanced features for painting tiles.
 * Cycle modes by holding shift and clicking LMB/RMB
 * Toggle mask mode by doubletapping shift
 * Clear selection and mask by holding shift
 * Modes :
  * Paint - apply selected colour to front (LMB) or back (RMB) layer.
  * Select colour - cycle through colours with LMB/RMB
  * Select size - cycle through sizes (1x1 through 5x5) with LMB/RMB
  * Fill selection - turns the whole selection sans masked areas into selected colour, back or front layer.
  * Replace colour - replaces the colour clicked on with selected colour in the whole selection area sans the mask, back or front layer.
 * Mask modes :
  * Select rectangle - select lower left (RMB) or upper right (LMB) corner of the selection rectangle.
  * Paint mask - paints or erases mask with current brush size.
  * Colour to mask - adds the clicked on colour from front (RMB) or back (LMB) layer to the mask.
  * Colour from mask - substracts the clicked on colour from front (RMB) or back (LMB) layer to the mask.
  * Fill mask - fills or erases the selection from mask.
  * Invert mask - inverts mask in the selection.
  
* Copying tool
 * A tool that provides means to copy and paste painting patterns.
 * Cycle through modes by tapping shift
 * Hold shift to generate a preview of current data
 * Modes :
  * Select rectangle - select lower left (RMB) or upper right (LMB) corner of the selection rectangle.
  * Copy - copy front (RMB) or back (LMB) layer.
  * Paste - paste the copied data into front (RMB) or back (LMB) layer.
  * Flip - toggle horizontal (RMB) and vertical (LMB) flipping.

While this mod attempts to bypass using /debug to render it's UI, it does display current mode in debug info.
  
## Installation

1. Aquire the ShieldBars api mod from [here](https://github.com/GTG3000/shieldBars/releases) or [Steam](http://steamcommunity.com/sharedfiles/filedetails/?id=876362250)

2. Download the most recent release [here](https://github.com/GTG3000/Starbound-BuildTools/releases/tag/1) and unzip it into your /starbound/mods folder. Double-check that you have folders /recipes and /items in the resulting folder.

3. Craft the tools ingame.
# braille.el
Emacs minor mode for drawing with braille characters
using a mouse or drawing tablet

Work in progress

Implemented:
- [x] Add dot to braille character grid according to where in the character the click occurred
- [x] Mouse drag draw
- [x] Draw line
- [x] Linear interpolation: Don't skip when drawing quickly
- [x] Better(?) interpolation: Dot-space Bresenham
- [x] Minor mode
- [x] Option to use either real spaces or blank grid character '⠀' (helps with alignment when it can't be displayed in a monospace font)

TBD:
- [ ] Don't do the deletion/insertion if clicked outside of "canvas"
- [ ] Ctrl left mouse erase
- [ ] Shift left mouse drag adjust brush size (and message what it's set to)
- [ ] <kbd>C-c n</kbd> create canvas prompting for size
- [ ] <kbd>C-c C-n</kbd> create canvas with default size, and make the default adjustable (defcustom) (and message the size of the canvas created)
- [ ] Draw rectangle
- [ ] Draw ellipse

Maybe:
- [ ] Create a font where the braille dots are blocks for better visibility
- [ ] Draw speech bubble (ASCII)
- [ ] Animation

## Usage
- Turn on minor mode (<kbd>M-x</kbd> `braille-mode`); this will take over some of your keys, like left mouse
- Create "canvas" (adds a bunch of lines filled with spaces)
  + <kbd>M-x</kbd> `braille-create-canvas-at-point`
- Click and drag left mouse on the canvas (or any existing characters)

## Resources used
- [Emacs.SE: How to access mouse event coordinates? (conveniently)](https://emacs.stackexchange.com/questions/51596/how-to-access-mouse-event-coordinates-conveniently) 2019 question by ideasman42, answer by wasamasa
- [/r/emacs: elisp determine if mouse posn is within region?](https://www.reddit.com/r/emacs/comments/1coumhm/elisp_determine_if_mouse_posn_is_within_region/) 2024 question by AcmeLover, answer by Slow-Mammoth7380
- [Emacs.SE: Right-click to select one character under the mouse pointer?](https://emacs.stackexchange.com/questions/19580/right-click-to-select-one-character-under-the-mouse-pointer) 2016 question by stacko, answer by Drew
- [Wikipedia Bresenham plotLine reference implementation](https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm)
- [systemcrafters.net: Creating a Custom Minor Mode](https://systemcrafters.net/learning-emacs-lisp/creating-minor-modes/)
- [GNU Emacs Lisp Reference Manual: Defining Minor Modes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Defining-Minor-Modes.html)

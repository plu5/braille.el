# braille.el
Emacs minor mode for drawing with braille characters
using a mouse or drawing tablet

Work in progress

Implemented:
- [x] Add dot to braille character grid according to where in the character the click occurred
- [x] Mouse drag draw
- [x] Draw line

TBD:
- [ ] Interpolation / Don't skip when drawing quickly
- [ ] Don't do the deletion/insertion if clicked outside of "canvas"
- [ ] Right mouse erase
- [ ] Minor mode
- [ ] Draw rectangle
- [ ] Draw ellipse

Maybe:
- [ ] Create a font where the braille dots are blocks for better visibility
- [ ] Draw speech bubble (ASCII)
- [ ] Animation

## Usage
- Turn on minor mode; this will take over some of your keys, like left mouse
  + There is not a minor mode yet. For debugging I am currently doing:
    ```elisp
    (global-set-key [down-mouse-1] #'braille-mouse-draw)
    (global-unset-key [mouse-1])
    ```
- Create "canvas" (adds a bunch of lines filled with spaces)
  + <kbd>M-x</kbd> `braille-create-canvas-at-point`
- Click and drag left mouse

## Resources that helped me
- [Emacs.SE: How to access mouse event coordinates? (conveniently)](https://emacs.stackexchange.com/questions/51596/how-to-access-mouse-event-coordinates-conveniently) 2019 question by ideasman42, answer by wasamasa
- [/r/emacs: elisp determine if mouse posn is within region?](https://www.reddit.com/r/emacs/comments/1coumhm/elisp_determine_if_mouse_posn_is_within_region/) 2024 question by AcmeLover, answer by Slow-Mammoth7380
- [Emacs.SE: Right-click to select one character under the mouse pointer?](https://emacs.stackexchange.com/questions/19580/right-click-to-select-one-character-under-the-mouse-pointer) 2016 question by stacko, answer by Drew

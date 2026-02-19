;;; braille.el -- Braille drawing minor mode  -*- lexical-binding: t; -*-
;; 2026-02-10 07:04
;; Author: plu5
;; Keywords: mouse
;; URL: https://github.com/plu5/braille.el
;; This file is not part of GNU Emacs.

;;; Commentary:
;; M-x braille-mode
;; create canvas
;; left click to draw
;; hold ctrl while drawing to erase

;;; Code:

(defgroup braille nil
  "Braille drawing engine."
  :group 'mouse)

(defcustom braille-use-blank-grid nil
  "Whether to use the blank grid character '⠀' instead of space.
This can be useful if you intend to use your artwork in an environment that
is not going to display it a monospace font.
See `braille-convert-spacing-in-region' to convert existing canvases."
  :type 'boolean
  :group 'braille)

(defcustom braille-consider-text-out-of-bounds t
  "Avoid drawing on characters that are not either braille or space."
  :type 'boolean
  :group 'braille)

(defcustom braille-consider-space-out-of-bounds nil
  "Avoid drawing on space.
Expected to be used in combination with `braille-use-blank-grid' t."
  :type 'boolean
  :group 'braille)

(defcustom braille-default-canvas-size "50x20"
  "Canvas size in the format WxH to use as default dimensions.
Used in `braille-create-canvas-at-point-without-asking' and in
`braille-create-canvas-at-point' as the default value.
The unit of W and H is number of characters."
  :type 'string
  :group 'braille)

(defconst braille-base #x2800 "Start of unicode braille block")
(defconst braille-nrows 4 "Number of rows in the braille grid")
(defconst braille-ncols 2 "Number of columns in the braille grid")

(defun braille-empty-char ()
  "Return the character used for empty canvas in braille.
Either space or the blank grid character '⠀', according to the value of
`braille-use-blank-grid'."
  (if braille-use-blank-grid braille-base ?\s))

(defun braille-char-name-or-char (c)
  "Return description for space and blank braille grid if c is one of them.
Otherwise, return c as a string."
  (cond
   ((eq c ?\s) "space")
   ((eq c braille-base) "blank braille grid")
   (t (char-to-string c))))

(defun braille-create-canvas-at-point (size)
  "Create an area of whitespace with given dimensions."
  (interactive
   (list (split-string
          (read-string "Canvas size: " braille-default-canvas-size) "x")))
  (unless (= (length size) 2)
    (user-error "Expected canvas size format: WxH (ex. 40x10)"))
  (let ((h (string-to-number (cadr size)))
        (w (string-to-number (car size)))
        (c (braille-empty-char)))
    (dotimes (i h)
      (insert (make-string w c) "\n"))
    (message "Created %s canvas with %s character" size
             (braille-char-name-or-char c))))

(defun braille-create-canvas-at-point-without-asking ()
  "Create an area of whitespace with default dimensions.
As defined in `braille-default-canvas-size'."
  (interactive)
  (braille-create-canvas-at-point
   (split-string braille-default-canvas-size "x")))

(defun braille-convert-spacing-in-region (beg end)
  "Convert characters in region from braille blank grid to space or vice versa.
If a braille blank grid character is found in region, convert braille
blank grid characters to spaces, otherwise convert spaces to braille
blank grid characters."
  (interactive "*r")
  (save-restriction
    (narrow-to-region beg end)
    (let* ((grd (char-to-string braille-base))
           (spc " ")
           (old (if (save-excursion (search-forward grd nil t 1)) grd spc))
           (new (if (eq old grd) spc grd)))
      (goto-char (point-min))
      (while (search-forward old nil t 1)
        (replace-match new))
      (message "Converted [%s] (%s) to [%s] (%s) in region %s to %s"
               old (braille-char-name-or-char (string-to-char old))
               new (braille-char-name-or-char (string-to-char new)) beg end))))

(defun braille-colrow-from-posn (posn)
    "Calculate col and row of appropriate braille point from posn.
col = 0/1. row = 0/1/2/3."
  (let* ((rel-xy (posn-object-x-y posn))
         (rel-wh (posn-object-width-height posn))
         (col (min (1- braille-ncols)
                   ;; x / w / ncols
                   (/ (car rel-xy) (/ (car rel-wh) braille-ncols))))
         (row (min (1- braille-nrows)
                   ;; y / h / nrows
                   (/ (cdr rel-xy) (/ (cdr rel-wh) braille-nrows)))))
    (cons col row)))

(defun braille-bit-from-colrow (colrow)
  "Get braille dot bit at COLROW.
COLROW is (col . row) for the dot position in the 2x4 braille grid, 0-based."
  ;; unfortunately this can't be a simple data structure because
  ;; the order in braille is 1237 4568
  (let ((col (car colrow))
        (row (cdr colrow)))
    (cond
     ;; left
     ((and (= col 0) (= row 0)) #b00000001)
     ((and (= col 0) (= row 1)) #b00000010)
     ((and (= col 0) (= row 2)) #b00000100)
     ((and (= col 0) (= row 3)) #b01000000)
     ;; right
     ((and (= col 1) (= row 0)) #b00001000)
     ((and (= col 1) (= row 1)) #b00010000)
     ((and (= col 1) (= row 2)) #b00100000)
     ((and (= col 1) (= row 3)) #b10000000))))

(defun braille-posn-char-xy (posn)
  "Return char top left pixel coordinates (x . y) given POSN."
  (posn-x-y (posn-at-point (posn-point posn))))

(defun braille-in-bounds-p (posn)
  "If POSN is in bounds for braille drawing return t, nil otherwise."
  (let ((click-xy (posn-x-y posn))
        (char-xy (braille-posn-char-xy posn))
        (rel-wh (posn-object-width-height posn)))
    ;; (message "bounds calc %s %s %s" click-xy char-xy rel-wh)  ; debug
    (and (<= (car click-xy) (+ (car char-xy) (car rel-wh)))
         (<= (cdr click-xy) (+ (cdr char-xy) (cdr rel-wh))))))

(defun braille-click-debug (e)
  "Show information about the click position for debugging purposes.
E should be a mouse click event."
  (interactive "e")
  (let* ((posn (event-start e))
         (char-pos (posn-point posn))
         (rel-xy (posn-object-x-y posn))
         (click-xy (posn-x-y posn))
         (colrow (braille-colrow-from-posn posn))
         (bit (braille-bit-from-colrow colrow))
         (char-posn (posn-at-point char-pos)))
    (message
     "@@ char-pos:%d rel-xy:%s click-xy:%s colrow:%s bit:%s char-xy:%s
in-bounds:%s
p:%s s:%s"
     char-pos rel-xy click-xy colrow bit (posn-x-y char-posn)
     (braille-in-bounds-p posn)
     char-posn (braille-posn-debug posn))))

(defun braille-char-p (char)
  "If CHAR is a braille character return its delta, otherwise return nil."
  (let ((delta (- char braille-base)))
    (if (and (>= delta 0) (< delta 256))
        delta)))

(defun braille-bit-from-posn (posn)
  "Get bit for appropriate dot given POSN."
  (braille-bit-from-colrow
   (braille-colrow-from-posn posn)))

(defun braille-posn-at-xy (xy)
  "Return the posn at XY, where XY is a cons (x . y) of pixel coordinates."
  (posn-at-x-y (car xy) (cdr xy)))

(defun braille-insert-at-xy (xy &optional erase)
  "Place braille dot at appropriate position based on pixel coordinates XY.
Places the first dot or Adds it to the existing dots if character under
point is a braille character.
XY should be (x . y) where x and y are pixel coordinates.
If ERASE is t, erase the dot instead of placing it."
  (let* ((posn (braille-posn-at-xy xy))
         (char-pos (posn-point posn))
         (dot-bit (braille-bit-from-posn posn))
         (inhibit-modification-hooks t)) ; FIXME: potentially problematic
    (if (braille-in-bounds-p posn)
        (save-excursion
          ;; (message "in bounds %s" posn)  ; debug
          (goto-char char-pos)
          (let* ((char (char-after))
                 (d (braille-char-p char))
                 (new-dot-value
                  (if erase
                      (if d (logand d (lognot dot-bit)) 0)
                    (if d (logior d dot-bit) dot-bit)))
                 (c (if (and erase (= 0 new-dot-value))
                        (braille-empty-char)
                      (+ #x2800 new-dot-value))))
;;             (message
;;              "braille-insert-at-xy char:%s d:%s erase:%s
;; new-dot-value:%s c:%s" char d erase new-dot-value c)  ; debug
            (if (eq char ?\n)
                (message "braille: out of bounds (newline character)")
              (if (or (and braille-consider-text-out-of-bounds
                           (null d) (not (eq char ?\s)))
                      (and braille-consider-space-out-of-bounds
                           (eq char ?\s)))
                  (message "braille: out of bounds (text)")
                (delete-char 1)
                (insert c)))))
      (message "braille: out of bounds"))))

(defun braille-click (e)
  "Place braille dot at appropriate position based on mouse location.
E should be a mouse click event."
  (interactive "e")
  (braille-insert-at-xy (posn-x-y (event-start e))))

(defun braille-posn-debug (posn &optional text)
  "Show message with information from POSN.
POSN is the return from `event-start' or `event-end'."
  (let (char-pos click-xy char-posn)
    (setq char-pos (posn-point posn))
    (setq click-xy (posn-x-y posn))
    (setq char-posn (braille-posn-at-xy click-xy))
    (message "%s char-pos:%s | click-xy:%s |\
 char-pos-xy:%s | posn:%s | char-posn:%s"
             (or text "braille-posn-debug") char-pos click-xy
             (posn-x-y char-posn) char-posn posn)))

(defun braille-dot-wh ()
  "Calculate braille dot width and height"
  (let ((dot-w (/ (window-font-width) (float braille-ncols)))
        (dot-h (/ (window-font-height) (float braille-nrows))))
    (cons dot-w dot-h)))

(defun braille-posn-to-dot-xy (posn)
  "Convert posn to dotspace coordinates."
  (let* ((xyn (braille-posn-char-xy posn)) ; top left
         (dot-wh (braille-dot-wh))
         (colrow (braille-colrow-from-posn posn))
         (dot-x (+ (/ (car xyn) (car dot-wh)) (car colrow)))
         (dot-y (+ (/ (cdr xyn) (cdr dot-wh)) (cdr colrow))))
    (cons dot-x dot-y)))

(defun braille-insert-at-dot-xy (dot-xy &optional erase)
  "Insert braille dot at dotspace (x . y)
If ERASE is t, erase instead."
  (let* ((dot-wh (braille-dot-wh))
         (xy (cons (floor (* (car dot-xy) (car dot-wh)))
                   (floor (* (cdr dot-xy) (cdr dot-wh))))))
    (braille-insert-at-xy xy erase)))

(defun braille-dotspace-line (dot-xy0 dot-xy1 &optional erase)
  "Draw a line of braille points from XY0 to XY1 in dotspace.
XY0 and XY1 should each be a position in dotspace like (x . y)
(dots from the left and dots from the top)
If ERASE is t, erase instead."
  (let* ((dot-wh (braille-dot-wh))
         (x0 (car dot-xy0))
         (y0 (cdr dot-xy0))
         (x1 (car dot-xy1))
         (y1 (cdr dot-xy1))
         (dx (abs (- x1 x0)))
         (dy (abs (- y1 y0)))
         (sx (if (< x0 x1) 1 -1))
         (sy (if (< y0 y1) 1 -1))
         (err (- dx dy)))
    (while (not (and (= x0 x1) (= y0 y1)))
      (braille-insert-at-dot-xy (cons x0 y0) erase)
      (let ((e2 (* 2 err)))
        (when (> e2 (- dy))
          (setq err (- err dy))
          (setq x0 (+ x0 sx)))
        (when (< e2 dx)
          (setq err (+ err dx))
          (setq y0 (+ y0 sy)))))
    (braille-insert-at-dot-xy (cons x1 y1) erase)))

(defun braille-line (xy0 xy1)
  "Draw a line of braille points from XY0 to XY1.
XY0 and XY1 should each be a position in pixels like (x . y)"
  (let* ((dot-xy0 (braille-posn-to-dot-xy (braille-posn-at-xy xy0)))
         (dot-xy1 (braille-posn-to-dot-xy (braille-posn-at-xy xy1))))
    (braille-dotspace-line dot-xy0 dot-xy1)))

(defun braille-draw-line (e)
  "Draw a line of braille points.
Interpolates a line from position mouse is pressed to position it is let go.
E should be a mouse down event."
  (interactive "e")
  (undo-boundary)
  (track-mouse
    (let (xy0 xy1)
      (setq xy0 (posn-x-y (event-start e))) ; start xy
      (while (and (setq e (read-event)) (mouse-movement-p e)) ; drag
        (ignore))
      (setq xy1 (posn-x-y (event-end e))) ; end xy
      (braille-line xy0 xy1))))

(defun braille-mouse-draw (e &optional erase)
  "Draw braille while mouse is dragged, stopping when it is let go.
E should be a mouse down event.
If ERASE is t, erase instead."
  (interactive "e")
  (undo-boundary)
  (let* ((posn (event-start e))
         (dot-xy-prev (braille-posn-to-dot-xy posn))
         dot-xy-cur)
    ;; (message "braille-mouse-draw posn: %s" posn)  ; debug
    (braille-insert-at-dot-xy dot-xy-prev erase) ; first click
    (track-mouse
      (while (and (setq e (read-event)) (mouse-movement-p e)) ; drag
        (setq dot-xy-cur (braille-posn-to-dot-xy (event-start e)))
        (unless (eq dot-xy-cur dot-xy-prev)
          (braille-dotspace-line dot-xy-prev dot-xy-cur erase))
        ;; (message "movement %s" dot-xy-cur)  ; debug
        (setq dot-xy-prev dot-xy-cur)))))

(defun braille-mouse-erase (e)
  "Erase braille while mouse is dragged, stopping when it is let go.
E should be a mouse down event."
  (interactive "e")
  (braille-mouse-draw e t))

;; temp debug
;; (global-set-key [down-mouse-1] #'braille-mouse-draw)
;; (global-unset-key [mouse-1])
;; (global-set-key [mouse-8] #'braille-click-debug)
;; (global-set-key [mouse-8] #'braille-click)
;; (global-set-key [down-mouse-1] #'braille-draw-line)

(define-minor-mode braille-mode
  "Toggles global braille-mode.
Lets you draw in the buffer with braille dots using your mouse."
  :global t
  :lighter " ⣿"
  :keymap
  '(([down-mouse-1] . braille-mouse-draw)
    ([mouse-1] . ignore)
    ([C-down-mouse-1] . braille-mouse-erase)
    ([C-mouse-1] . ignore)
    ([M-mouse-1] . undo)
    ([M-down-mouse-1] . ignore)
    ([M-S-mouse-1] . redo)
    ([(control ?c) ?n] . braille-create-canvas-at-point)
    ([(control ?c) (control ?n)] . braille-create-canvas-at-point-without-asking)))

(provide 'braille)

;;; braille.el ends here

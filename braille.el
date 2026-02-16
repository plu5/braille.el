;;; braille.el Braille drawing mode
;; 2026-02-10 07:04
;; left click to draw
;; right click to erase (TBD)

(defcustom braille-use-blank-grid nil
  "Whether to use the blank grid character '⠀' instead of space.
This can be useful if you intend to use your artwork in an environment that
is not going to display it a monospace font.")

(defconst braille-base #x2800 "Start of unicode braille block")
(defconst braille-nrows 4 "Number of rows in the braille grid")
(defconst braille-ncols 2 "Number of columns in the braille grid")

(defun braille-create-canvas-at-point (size)
  "Create an area of whitespace with given dimensions."
  (interactive (list (split-string (read-string "Canvas size: " "40x10") "x")))
  (unless (= (length size) 2)
    (user-error "Expected canvas size format: WxH (ex. 40x10)"))
  (let ((h (string-to-number (cadr size)))
        (w (string-to-number (car size)))
        (c (if braille-use-blank-grid ?\u2800 ?\s)))
    (dotimes (i h)
      (insert (make-string w c) "\n"))))

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
p:%s s:%s"
     char-pos rel-xy click-xy colrow bit
     (posn-x-y char-posn)
     char-posn
     (braille-posn-debug posn))))

(defun braille-char-p (char)
  "If CHAR is a braille character return its delta, otherwise return nil."
  (let ((delta (- char braille-base)))
    (if (and (>= delta 0) (< delta 256))
        delta)))

(defun braille-bit-from-posn (posn)
  "Get bit for appropriate dot given mouse event event-start information."
  (braille-bit-from-colrow
   (braille-colrow-from-posn posn)))

(defun braille-insert-at-xy (xy)
  "Place braille dot at appropriate position based on pixel coordinates XY.
Places the first dot or Adds it to the existing dots if character under
point is a braille character.
XY should be (x . y) where x and y are pixel coordinates."
  (let* ((posn (posn-at-x-y (car xy) (cdr xy)))
         (char-pos (posn-point posn))
         (dot-bit (braille-bit-from-posn posn))
         (inhibit-modification-hooks t)) ; FIXME: potentially problematic
    (unless (>= char-pos (point-max))
      (save-excursion
        (goto-char char-pos)
        (let* ((char (char-after))
               (d (braille-char-p char))
               (new-dot-value
                (if d (logior d dot-bit) dot-bit)))
          (delete-char 1)
          (insert (+ #x2800 new-dot-value)))))))

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
    (setq char-posn (posn-at-x-y (car click-xy) (cdr click-xy)))
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
  (let* ((xyn (posn-x-y (posn-at-point (posn-point posn)))) ; top left
         (dot-wh (braille-dot-wh))
         (colrow (braille-colrow-from-posn posn))
         (dot-x (+ (/ (car xyn) (car dot-wh)) (car colrow)))
         (dot-y (+ (/ (cdr xyn) (cdr dot-wh)) (cdr colrow))))
    (cons dot-x dot-y)))

(defun braille-insert-at-dot-xy (dot-xy)
  "Insert braille dot at dotspace (x . y)"
  (let* ((dot-wh (braille-dot-wh))
         (xy (cons (floor (* (car dot-xy) (car dot-wh)))
                   (floor (* (cdr dot-xy) (cdr dot-wh))))))
    (braille-insert-at-xy xy)))

(defun braille-dotspace-line (dot-xy0 dot-xy1)
  "Draw a line of braille points from XY0 to XY1 in dotspace.
XY0 and XY1 should each be a position in dotspace like (x . y)
(dots from the left and dots from the top)"
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
      (braille-insert-at-dot-xy (cons x0 y0))
      (let ((e2 (* 2 err)))
        (when (> e2 (- dy))
          (setq err (- err dy))
          (setq x0 (+ x0 sx)))
        (when (< e2 dx)
          (setq err (+ err dx))
          (setq y0 (+ y0 sy)))))
    (braille-insert-at-dot-xy (cons x1 y1))))

(defun braille-line (xy0 xy1)
  "Draw a line of braille points from XY0 to XY1.
XY0 and XY1 should each be a position in pixels like (x . y)"
  (let* ((dot-xy0 (braille-posn-to-dot-xy (posn-at-x-y (car xy0) (cdr xy0))))
         (dot-xy1 (braille-posn-to-dot-xy (posn-at-x-y (car xy1) (cdr xy1)))))
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

(defun braille-mouse-draw (e)
  "Draw braille after click while mouse is dragged, stopping when it is let go.
E should be a mouse down event."
  (interactive "e")
  (undo-boundary)
  (let* ((posn (event-start e))
         (dot-xy-prev (braille-posn-to-dot-xy posn))
         dot-xy-cur)
    (braille-insert-at-dot-xy dot-xy-prev) ; first click
    (track-mouse
      (while (and (setq e (read-event)) (mouse-movement-p e)) ; drag
        (setq dot-xy-cur (braille-posn-to-dot-xy (event-start e)))
        (unless (eq dot-xy-cur dot-xy-prev)
          (braille-dotspace-line dot-xy-prev dot-xy-cur))
        ;; (message "movement %s" dot-xy-cur)  ; debug
        (setq dot-xy-prev dot-xy-cur)))))

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
  '(([down-mouse-1] . braille-mouse-draw)))

(provide 'braille)

;;; braille.el ends here

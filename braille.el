;;; braille.el Braille drawing mode
;; 2026-02-10 07:04
;; left click to draw
;; right click to erase (TBD)

(defconst braille-base #x2800 "Start of unicode braille block")
(defconst braille-nrows 4 "Number of rows in the braille grid")

(defun braille-create-canvas-at-point (size)
  "Create an area of whitespace with given dimensions."
  (interactive (list (split-string (read-string "Canvas size: " "40x10") "x")))
  (unless (= (length size) 2)
    (user-error "Expected canvas size format: WxH (ex. 40x10)"))
  (let ((h (string-to-number (cadr size)))
        (w (string-to-number (car size))))
    (dotimes (i h)
      (insert (concat (make-string w ? ) "\n")))))

(defun braille-colrow-from-rel-xy (rel-xy)
  "Calculate col and row of appropriate braille point from relative position.
col = 0/1. row = 0/1/2/3."
  (let* ((rel-x (car rel-xy))
         (rel-y (cdr rel-xy))
         (char-w (frame-char-width))
         (char-h (frame-char-height))
         (col (if (< rel-x (/ char-w 2)) 0 1))
         (row (floor (* braille-nrows (/ (float rel-y) char-h)))))
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
  (let* ((pos-info (event-start e))
         (char-pos (posn-point pos-info))
         (rel-xy (posn-object-x-y pos-info))
         (click-xy (posn-x-y pos-info))
         (colrow (braille-colrow-from-rel-xy rel-xy))
         (bit (braille-bit-from-colrow colrow)))
    (message "pos-info:%s char-pos:%d rel-xy:%s click-xy:%s colrow:%s bit:%s"
             pos-info char-pos rel-xy click-xy colrow bit)))

(defun braille-char-p (char)
  "If CHAR is a braille character return its delta, otherwise return nil."
  (let ((delta (- char braille-base)))
    ;; empty braille character (delta==0) intentionally omitted
    ;; (i prefer to just have space but maybe it could be configurable)
    (if (and (> delta 0) (< delta 256))
        delta)))

(defun braille-bit-from-pos-info (pos-info)
  "Get bit for appropriate dot given mouse event event-start information."
  (braille-bit-from-colrow
   (braille-colrow-from-rel-xy (posn-object-x-y pos-info))))

(defun braille-insert-at-xy (xy)
  "Place braille dot at appropriate position based on pixel coordinates XY.
Places the first dot or Adds it to the existing dots if character under
point is a braille character.
XY should be (x . y) where x and y are pixel coordinates."
  (message "xy:%s" xy)
  (let* ((pos-info (posn-at-x-y (car xy) (cdr xy)))
         (char-pos (posn-point pos-info))
         (dot-bit (braille-bit-from-pos-info pos-info))
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

(defun braille-mouse-draw (e)
  "Draw braille after click while mouse is dragged, stopping when it is let go.
E should be a mouse down event."
  (interactive "e")
  (track-mouse
    (braille-click e)                   ; first click
    ;; (message "out %S" event)
    (while (and (setq e (read-event)) (mouse-movement-p e)) ; drag
      ;; (message "in %S" e)
      (braille-click e))))

(defun braille-pos-info-debug (pos-info &optional text)
  "Show message with information from POS-INFO.
POS-INFO is the return from `event-start' or `event-end'."
  (let (char-pos click-xy char-pos-info)
    (setq char-pos (posn-point pos-info))
    (setq click-xy (posn-x-y pos-info))
    (setq char-pos-info (posn-at-x-y (car click-xy) (cdr click-xy)))
    (message "%s char-pos:%s | click-xy:%s |\
 char-pos-xy:%s | pos-info:%s | char-pos-info:%s"
             (or text "braille-pos-info-debug") char-pos click-xy
             (posn-x-y char-pos-info) char-pos-info pos-info)))

(defun braille-line (e)
  "Draw a line of braille points.
Interpolates a line from position mouse is pressed to position it is let go.
E should be a mouse down event."
  (interactive "e")
  (track-mouse
    (let (pos-info xy0 xy1 dx dy steps)
      (setq pos-info (event-start e))
      (setq xy0 (posn-x-y pos-info))    ; start xy
      (while (and (setq e (read-event)) (mouse-movement-p e)) ; drag
        (ignore))
      (setq pos-info (event-end e))
      (setq xy1 (posn-x-y pos-info))    ; end xy
      (setq dx (- (car xy1) (car xy0)))
      (setq dy (- (cdr xy1) (cdr xy0)))
      ;; abs because dx and dy can be negative. maybe should also
      ;; divide by something as it results in more steps than
      ;; necessary
      (setq steps (max (abs dx) (abs dy)))
      ;; (message "dx:%s dy:%s steps:%s" dx dy steps)
      (dotimes (i (1+ steps))
        ;; x0 + dx * i/steps. and must change one to float to avoid
        ;; rounding the i/steps, then round final result because
        ;; posn-point must be whole number
        (let* ((x (round (+ (car xy0) (* dx (/ (float i) steps)))))
               (y (round (+ (cdr xy0) (* dy (/ (float i) steps)))))
               (xy (cons x y)))
          ;; (message "i:%s x:%s y:%s" i x y)
          (braille-insert-at-xy xy))))))

;; temp debug
;; (global-set-key [down-mouse-1] #'braille-mouse-draw)
;; (global-unset-key [mouse-1])
;; (global-set-key [mouse-8] #'braille-click-debug)
;; (global-set-key [mouse-8] #'braille-click)
;; (global-set-key [down-mouse-1] #'braille-line)

;; (define-key braille-mode-map [down-mouse-1] #'braille-mouse-draw)

(provide 'braille)

;;; braille.el ends here

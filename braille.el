;;; braille.el Braille drawing mode
;; 2026-02-10 07:04
;; left click to draw
;; right click to erase (TBD)

(defconst braille-base #x2800)
(defconst braille-nrows 4)

(defun braille-create-canvas-at-point (size)
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
  (braille-bit-from-colrow
   (braille-colrow-from-rel-xy (posn-object-x-y pos-info))))

(defun braille-click (e)
  "E should be a mouse click event."
  (interactive "e")
  (let* ((pos-info (event-start e))
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

(defun braille-mouse-draw (e)
  "E should be a mouse down event."
  (interactive "e")
  (track-mouse
    (braille-click e)                   ; first click
    ;; (message "out %S" event)
    (while (and (setq e (read-event)) (mouse-movement-p e)) ; drag
      ;; (message "in %S" e)
      (braille-click e))))

;; temp debug
;; (global-set-key [down-mouse-1] 'braille-mouse-draw)
;; (global-unset-key [mouse-1])

;; (define-key braille-mode-map [down-mouse-1] #'braille-mouse-draw)

(provide 'braille)

;;; braille.el ends here

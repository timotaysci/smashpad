;;; smashpad.el --- A locked-down key-mashing notepad for toddlers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Timothy Johnson

;; Author: Timothy Johnson
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: games
;; URL: https://github.com/timotaysci/smashpad

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `smashpad-mode' turns Emacs into a toddler-proof notepad.  It opens
;; a fullscreen frame with huge, centred, rainbow-coloured text and
;; grabs *every* key and mouse event before the rest of Emacs sees it.
;; Printable keys type a letter, RET/TAB/DEL do the obvious thing,
;; and everything else (C-x C-c, M-x, C-g, C-z, mouse clicks, the
;; window close button...) is silently swallowed.
;;
;; To get out, press the exit key (default C-S-p, i.e. Ctrl+Shift+p)
;; three times in a row.  Anything else pressed in between resets the
;; count, so random mashing won't do it.
;;
;; Emergency hatch: from another terminal, run
;;   emacsclient -e '(smashpad-mode -1)'
;;
;; Usage:
;;   M-x smashpad

;;; Code:

(defgroup smashpad nil
  "A locked-down key-mashing notepad for toddlers."
  :group 'games
  :prefix "smashpad-")

(defcustom smashpad-exit-key "C-S-p"
  "Key that exits `smashpad-mode' when pressed enough times in a row.
A string in `kbd' format that must describe a single event.  On a
text terminal Ctrl+Shift+letter cannot be told apart from
Ctrl+letter, so use a graphical frame or choose another key."
  :type 'string)

(defcustom smashpad-exit-presses 3
  "How many consecutive presses of `smashpad-exit-key' exit the mode."
  :type 'natnum)

(defcustom smashpad-text-height 4.0
  "Text height in the smashpad buffer, relative to the default face."
  :type 'number)

(defcustom smashpad-margin-fraction 0.15
  "Fraction of the window width given to each side margin."
  :type 'number)

(defcustom smashpad-buffer-name "*smashpad*"
  "Name of the buffer the toddler types into.
Set this to \"*scratch*\" if you really want them in your scratch buffer."
  :type 'string)

(defcustom smashpad-new-frame t
  "Non-nil means open smashpad in a new fullscreen frame.
Only applies on graphical displays."
  :type 'boolean)

(defcustom smashpad-allow-backspace t
  "Non-nil means DEL/Backspace deletes the previous character."
  :type 'boolean)

(defcustom smashpad-colors
  '("#ff595e" "#ff924c" "#ffca3a" "#8ac926" "#1982c4" "#4267ac" "#6a4c93")
  "Colours picked at random for each typed character.
Set to nil for plain text."
  :type '(repeat color))

(defvar smashpad-lock-map
  (let ((map (make-sparse-keymap)))
    ;; A default binding: matches every event not otherwise bound in
    ;; this map, which is all of them.
    (define-key map [t] #'smashpad-handle-key)
    map)
  "Keymap that swallows every key while `smashpad-mode' is on.
It is installed as `overriding-terminal-local-map', which takes
precedence over every other keymap, including minor modes, Evil and
the minibuffer.")

(defconst smashpad--blocked-special-events '(delete-frame iconify-frame)
  "Events in `special-event-map' that are ignored while smashing.
These bypass ordinary keymaps, e.g. clicking the window close button.")

(defvar smashpad--frame nil "Frame created by smashpad, if any.")
(defvar smashpad--exit-count 0 "Consecutive presses of the exit key so far.")
(defvar smashpad--saved-overriding-map nil)
(defvar smashpad--saved-special-events nil)
(defvar smashpad--saved-window-config nil)

;;;; Key handling

(defun smashpad--exit-key-vector ()
  "Return `smashpad-exit-key' as a one-event vector, or signal an error."
  (let ((keys (kbd smashpad-exit-key)))
    (unless (= (length keys) 1)
      (user-error "`smashpad-exit-key' must be a single key, got %S"
                  smashpad-exit-key))
    (vconcat keys)))

(defun smashpad--normalize-event (event)
  "Translate EVENT through `local-function-key-map' when possible.
This turns symbols like `return', `backspace', `tab' and `kp-1' into
the characters they normally stand for."
  (let ((tr (and (symbolp event)
                 (lookup-key local-function-key-map (vector event)))))
    (if (and (arrayp tr) (= (length tr) 1) (characterp (aref tr 0)))
        (aref tr 0)
      event)))

(defun smashpad--buffer ()
  "Return the smashpad buffer, creating it if needed."
  (or (get-buffer smashpad-buffer-name)
      (smashpad--setup-buffer)))

(defun smashpad--insert (string)
  "Insert STRING at the end of the smashpad buffer, in a random colour."
  (goto-char (point-max))
  (insert (if smashpad-colors
              (propertize string 'face
                          (list :foreground
                                (nth (random (length smashpad-colors))
                                     smashpad-colors)))
            string)))

(defun smashpad-handle-key ()
  "Handle any key while `smashpad-mode' is on.
Printable characters are inserted; the exit key counts towards
leaving; everything else is ignored."
  (interactive)
  (if (equal (this-single-command-keys) (smashpad--exit-key-vector))
      (progn
        (setq smashpad--exit-count (1+ smashpad--exit-count))
        (when (>= smashpad--exit-count smashpad-exit-presses)
          (smashpad-mode -1)
          (message "Smashpad closed.  Bye!")))
    (setq smashpad--exit-count 0)
    (let ((buf (smashpad--buffer))
          (ev (smashpad--normalize-event last-input-event)))
      ;; Keep focus on the smashpad window, wherever the click went.
      (let ((win (get-buffer-window buf t)))
        (when win
          (unless (eq (window-frame win) (selected-frame))
            (select-frame-set-input-focus (window-frame win)))
          (select-window win)))
      (with-current-buffer buf
        (cond
         ((not (characterp ev)) nil)    ; mouse, f-keys, M-x, ...
         ((memq ev '(?\r ?\n)) (smashpad--insert "\n"))
         ((eq ev ?\t) (smashpad--insert " "))
         ((eq ev ?\d)
          (when (and smashpad-allow-backspace (> (point-max) (point-min)))
            (goto-char (point-max))
            (delete-char -1)))
         ((< ev 32) nil)                ; other control characters
         (t (smashpad--insert (string ev))))))))

;;;; Display

(defun smashpad--update-margins (&optional _frame)
  "Centre the text in every window showing the smashpad buffer."
  (let ((buf (get-buffer smashpad-buffer-name)))
    (when buf
      (dolist (win (get-buffer-window-list buf nil t))
        (let ((m (floor (* (window-total-width win) smashpad-margin-fraction))))
          (set-window-fringes win 0 0)
          (set-window-margins win m m))))))

(defun smashpad--setup-buffer ()
  "Create and configure the smashpad buffer and return it."
  (let ((buf (get-buffer-create smashpad-buffer-name)))
    (with-current-buffer buf
      (font-lock-mode -1)               ; would strip our colours
      (setq-local buffer-undo-list t)
      (setq-local mode-line-format nil)
      (setq-local header-line-format nil)
      (setq-local cursor-type 'box)
      (setq-local truncate-lines nil)
      (setq-local word-wrap t)
      (when (boundp 'display-line-numbers)
        (setq-local display-line-numbers nil))
      (face-remap-add-relative 'default :height smashpad-text-height))
    buf))

(defun smashpad--show-buffer (buf)
  "Display BUF, in a fresh fullscreen frame if possible."
  (setq smashpad--saved-window-config (current-window-configuration))
  (when (and smashpad-new-frame (display-graphic-p))
    (setq smashpad--frame
          (make-frame '((name . "smashpad")
                        (fullscreen . fullboth)
                        (menu-bar-lines . 0)
                        (tool-bar-lines . 0)
                        (tab-bar-lines . 0)
                        (vertical-scroll-bars . nil)
                        (horizontal-scroll-bars . nil))))
    (select-frame-set-input-focus smashpad--frame))
  (switch-to-buffer buf)
  (delete-other-windows)
  (goto-char (point-max))
  (smashpad--update-margins))

;;;; Mode

(defun smashpad--block-special-events ()
  (setq smashpad--saved-special-events
        (mapcar (lambda (ev) (cons ev (lookup-key special-event-map (vector ev))))
                smashpad--blocked-special-events))
  (dolist (ev smashpad--blocked-special-events)
    (define-key special-event-map (vector ev) #'ignore)))

(defun smashpad--restore-special-events ()
  (dolist (pair smashpad--saved-special-events)
    (define-key special-event-map (vector (car pair)) (cdr pair)))
  (setq smashpad--saved-special-events nil))

(defun smashpad--reassert-lock ()
  "Put our keymap back if something else replaced it."
  (unless (eq overriding-terminal-local-map smashpad-lock-map)
    (setq overriding-terminal-local-map smashpad-lock-map)))

(defun smashpad--enable ()
  (smashpad--exit-key-vector)           ; validate before locking anything
  (setq smashpad--exit-count 0)
  (smashpad--show-buffer (smashpad--buffer))
  (smashpad--block-special-events)
  (setq smashpad--saved-overriding-map overriding-terminal-local-map)
  (setq overriding-terminal-local-map smashpad-lock-map)
  (add-hook 'post-command-hook #'smashpad--reassert-lock)
  (add-hook 'window-size-change-functions #'smashpad--update-margins))

(defun smashpad--disable ()
  (remove-hook 'post-command-hook #'smashpad--reassert-lock)
  (remove-hook 'window-size-change-functions #'smashpad--update-margins)
  (when (eq overriding-terminal-local-map smashpad-lock-map)
    (setq overriding-terminal-local-map smashpad--saved-overriding-map))
  (setq smashpad--saved-overriding-map nil)
  (smashpad--restore-special-events)
  (if (frame-live-p smashpad--frame)
      (ignore-errors (delete-frame smashpad--frame))
    (when smashpad--saved-window-config
      (set-window-configuration smashpad--saved-window-config)))
  (setq smashpad--frame nil
        smashpad--saved-window-config nil))

;;;###autoload
(define-minor-mode smashpad-mode
  "Global minor mode that turns Emacs into a toddler-proof notepad.
While on, every key and mouse event goes to `smashpad-handle-key'.
Press `smashpad-exit-key' `smashpad-exit-presses' times in a row
to leave."
  :global t
  :lighter " Smash"
  (if smashpad-mode (smashpad--enable) (smashpad--disable)))

;;;###autoload
(defun smashpad ()
  "Start smashing.  See `smashpad-mode'."
  (interactive)
  (smashpad-mode 1)
  (message "Smashpad on.  Press %s %d times in a row to exit."
           smashpad-exit-key smashpad-exit-presses))

(provide 'smashpad)
;;; smashpad.el ends here

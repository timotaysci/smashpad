;;; screenshot.el --- Regenerate README screenshots -*- lexical-binding: t; -*-

;; Run from the repo root (needs a graphical, Cairo-enabled Emacs):
;;   emacs -Q -g 110x32 -l tools/screenshot.el
;; Writes screenshots/smashpad-dark.png and screenshots/smashpad-light.png.

(add-to-list 'load-path default-directory)
(require 'smashpad)

(setq inhibit-startup-screen t)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode -1)
(set-face-attribute 'default nil :height 140)
(setq smashpad-new-frame nil)

(defconst screenshot--mash
  "MAMA!!! hhhiiii\nppppPPPP 12345\nbanana gggghjk???")

(defun screenshot--take (theme file)
  "Show smashpad in THEME and save the frame to FILE."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t)
  (when (get-buffer smashpad-buffer-name) (kill-buffer smashpad-buffer-name))
  (random "smashpad")                   ; same colours every run
  (smashpad-mode 1)
  (with-current-buffer smashpad-buffer-name
    (mapc (lambda (c) (smashpad--insert (string c))) screenshot--mash))
  (set-window-start (get-buffer-window smashpad-buffer-name) 1)
  (message nil)
  (redisplay t)
  (sit-for 0.5)
  (redisplay t)
  (with-temp-file file
    (set-buffer-multibyte nil)
    (insert (x-export-frames nil 'png)))
  (smashpad-mode -1))

(defun screenshot--run ()
  (sit-for 1)
  (make-directory "screenshots" t)
  (screenshot--take 'modus-vivendi "screenshots/smashpad-dark.png")
  (screenshot--take 'modus-operandi "screenshots/smashpad-light.png")
  (kill-emacs 0))

(run-with-timer 1 nil #'screenshot--run)

;;; screenshot.el ends here

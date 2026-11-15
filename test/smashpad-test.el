;;; smashpad-test.el --- Tests for smashpad -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with: make test

;;; Code:

(require 'ert)
(require 'smashpad)

(defmacro smashpad-test--with-mode (&rest body)
  "Run BODY with `smashpad-mode' on in a fresh buffer, always cleaning up."
  (declare (indent 0))
  `(let ((smashpad-buffer-name "*smashpad-test*")
         (smashpad-colors nil)
         (smashpad-new-frame nil))
     (when (get-buffer smashpad-buffer-name)
       (kill-buffer smashpad-buffer-name))
     (unwind-protect
         (progn (smashpad-mode 1) ,@body)
       (when smashpad-mode (smashpad-mode -1))
       (kill-buffer smashpad-buffer-name))))

(defun smashpad-test--type (keys)
  "Feed KEYS (a `kbd' string) through the real command loop."
  (execute-kbd-macro (kbd keys)))

(defun smashpad-test--text ()
  (with-current-buffer smashpad-buffer-name
    (buffer-substring-no-properties (point-min) (point-max))))

(ert-deftest smashpad-test-printable-keys-insert ()
  (smashpad-test--with-mode
    (smashpad-test--type "h i SPC A RET !")
    (should (equal (smashpad-test--text) "hi A\n!"))))

(ert-deftest smashpad-test-function-key-symbols-translated ()
  (smashpad-test--with-mode
    (smashpad-test--type "a <return> <tab> <kp-1>")
    (should (equal (smashpad-test--text) "a\n 1"))))

(ert-deftest smashpad-test-backspace ()
  (smashpad-test--with-mode
    (smashpad-test--type "a b DEL <backspace> DEL")
    (should (equal (smashpad-test--text) ""))))

(ert-deftest smashpad-test-dangerous-keys-swallowed ()
  (smashpad-test--with-mode
    (dolist (k '("C-x" "M-x" "C-g" "C-z" "C-h" "<f1>" "ESC" "C-c"
                 "<mouse-1>" "<down-mouse-1>" "s-q" "C-M-<delete>"))
      (should (eq (key-binding (kbd k) t) #'smashpad-handle-key)))
    (smashpad-test--type "C-x b C-x k M-x C-x 0 C-a C-e C-z q")
    (should smashpad-mode)
    (should (equal (smashpad-test--text) "bk0q"))))

(ert-deftest smashpad-test-lock-beats-minor-mode-maps ()
  (let ((map (make-sparse-keymap)))
    (define-key map "a" #'ignore)
    (let ((minor-mode-overriding-map-alist `((t . ,map))))
      (smashpad-test--with-mode
        (should (eq (key-binding "a" t) #'smashpad-handle-key))))))

(ert-deftest smashpad-test-exit-needs-consecutive-presses ()
  (smashpad-test--with-mode
    (smashpad-test--type "C-S-p C-S-p a C-S-p C-S-p")
    (should smashpad-mode)
    (smashpad-test--type "C-S-p")
    (should-not smashpad-mode)))

(ert-deftest smashpad-test-plain-ctrl-p-does-not-exit ()
  (smashpad-test--with-mode
    (smashpad-test--type "C-p C-p C-p C-p")
    (should smashpad-mode)))

(ert-deftest smashpad-test-disable-restores-state ()
  (let ((before-map overriding-terminal-local-map)
        (before-delete (lookup-key special-event-map [delete-frame])))
    (smashpad-test--with-mode
      (should (eq overriding-terminal-local-map smashpad-lock-map))
      (should (eq (lookup-key special-event-map [delete-frame]) #'ignore))
      (smashpad-mode -1))
    (should (eq overriding-terminal-local-map before-map))
    (should (eq (lookup-key special-event-map [delete-frame]) before-delete))
    (should-not (memq #'smashpad--reassert-lock post-command-hook))))

(ert-deftest smashpad-test-lock-reasserted-after-command ()
  (smashpad-test--with-mode
    (setq overriding-terminal-local-map nil)
    (smashpad--reassert-lock)
    (should (eq overriding-terminal-local-map smashpad-lock-map))))

(ert-deftest smashpad-test-rainbow-colours ()
  (smashpad-test--with-mode
    (let ((smashpad-colors '("#123456")))
      (smashpad-test--type "x")
      (with-current-buffer smashpad-buffer-name
        (should (equal (get-text-property (point-min) 'face)
                       '(:foreground "#123456")))))))

(ert-deftest smashpad-test-bad-exit-key-refuses-to-lock ()
  (let ((smashpad-exit-key "C-x C-c")
        (smashpad-new-frame nil))
    (should-error (smashpad-mode 1) :type 'user-error)
    (should-not (eq overriding-terminal-local-map smashpad-lock-map))
    (when smashpad-mode (smashpad-mode -1))))

(provide 'smashpad-test)
;;; smashpad-test.el ends here

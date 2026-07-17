;;; pre-early-init.el --- Configuration before interface loads -*- no-byte-compile: t; lexical-binding: t; -*-

;; Reducing clutter in ~/.emacs.d by redirecting files to ~/emacs.d/var/
(setq minimal-emacs-var-dir (expand-file-name "var/" minimal-emacs-user-directory))
(setq package-user-dir (expand-file-name "elpa" minimal-emacs-var-dir))
(setq user-emacs-directory minimal-emacs-var-dir)

;; Debug startup - set to non-nil to enable
(setq minimal-emacs-debug nil)

;; Hide the title bar
(add-to-list 'default-frame-alist '(undecorated . t))

;;; pre-early-init.el ends here

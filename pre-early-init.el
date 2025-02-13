;;; pre-early-init.el --- Configuration before interface loads -*- no-byte-compile: t; lexical-binding: t; -*-

;; Reducing clutter in ~/.emacs.d by redirecting files to ~/emacs.d/var/
(setq minimal-emacs-var-dir (expand-file-name "var/" minimal-emacs-user-directory))
(setq package-user-dir (expand-file-name "elpa" minimal-emacs-var-dir))
(setq user-emacs-directory minimal-emacs-var-dir)

;; Hide the title bar
(add-to-list 'default-frame-alist '(undecorated . t))

(provide 'pre-early-init)

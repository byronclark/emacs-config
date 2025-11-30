;;; post-early-init.el --- Configuration before interface loads -*- no-byte-compile: t; lexical-binding: t; -*-

(push '("melpa-stable" . "https://stable.melpa.org/packages/") package-archives)
(setq package-archive-priorities '(("gnu"          . 99)
                                   ("melpa"        . 80)
                                   ("nongnu"       . 70)
                                   ("melpa-stable" . 0)))

(defvar byronc/emacs-local-dir (expand-file-name "~/.emacs.local/"))

(defvar byronc/emacs-local-early-dir (expand-file-name "early-init" byronc/emacs-local-dir))

(when (file-exists-p byronc/emacs-local-early-dir)
  (mapc 'load (directory-files byronc/emacs-local-early-dir 't "^[^#\.].*\\.el$")))

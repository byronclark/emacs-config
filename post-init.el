;;; post-init.el --- Configuration after interface loads -*- no-byte-compile: t; lexical-binding: t; -*-

(use-package compile-angel
  :demand t
  :ensure t
  :custom
  (compile-angel-verbose t)

  :config
  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)
  (push "/pre-init.el" compile-angel-excluded-files)
  (push "/post-init.el" compile-angel-excluded-files)
  (push "/pre-early-init.el" compile-angel-excluded-files)
  (push "/post-early-init.el" compile-angel-excluded-files)

  (compile-angel-on-load-mode 1))

(use-package exec-path-from-shell
  :ensure t
  :if (memq window-system '(mac ns x pgtk))
  :custom
  (exec-path-from-shell-arguments '("-l"))
  :config
  (dolist (env-var '("JAVA_HOME"))
    (add-to-list 'exec-path-from-shell-variables env-var))
  (exec-path-from-shell-initialize))

;; *** Allow use-package to install system packages ***
(use-package system-packages
  :ensure t)

(use-package use-package-ensure-system-package
  :ensure nil)

(defvar byronc/emacs-local-init-dir (expand-file-name "init" byronc/emacs-local-dir))

(use-package auth-source
  :ensure nil
  :demand t
  :custom
  (auth-sources (list (expand-file-name "secrets/.authinfo.gpg" byronc/emacs-local-dir)))
  :config
  (require 'epa-file)
  (epa-file-enable))

(when (file-exists-p byronc/emacs-local-init-dir)
  (mapc 'load (directory-files byronc/emacs-local-init-dir 't "^[^#\.].*\\.el$")))

;; *** Newer versions of built-in packages ***
(use-package transient
  :ensure t
  :pin melpa-stable
  :demand t)

;; *** Appearance ***
(use-package modus-themes
  :ensure t
  :custom
  (modus-themes-headings '((1 . (semibold 1.5))
                           (2 . (semibold 1.3))
                           (3 . (semibold 1.1))
                           (t . (semibold))))
  (modus-themes-mixed-fonts t)
  (modus-themes-italic-constructs t)
  :config
  (modus-themes-include-derivatives-mode))

(use-package ef-themes
  :ensure t
  :custom
  (modus-themes-to-toggle '(ef-frost ef-owl))
  :config
  ;; (modus-themes-select 'ef-owl)
  )

(use-package batppuccin
  :ensure t)

(use-package auto-dark
  :ensure t
  :custom
  (custom-safe-themes t)
  (auto-dark-themes '((batppuccin-macchiato) (batppuccin-latte)))
  :init
  (auto-dark-mode))

(use-package spacious-padding
  :ensure t
  :if (display-graphic-p)
  :custom
  ;; (spacious-padding-subtle-frame-lines t)
  (spacious-padding-widths '(:internal-border-width 15
                             :header-line-width 4
                             :mode-line-width 6
                             :tab-width 4
                             :right-divider-width 1
                             :scroll-bar-width 8
                             :fringe-width 8))
  :config
  (spacious-padding-mode 1))

(use-package fontaine
  :ensure t
  :if (display-graphic-p)
  :init
  (setopt fontaine-presets
          '((regular
             :default-family "Maple Mono"
             :default-height 140
             :fixed-pitch-family "Maple Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (regular-berkeley
             :default-family "Berkeley Mono"
             :default-height 140
             :fixed-pitch-family "Berkeley Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (regular-0xProto
             :default-family "0xProto"
             :default-height 140
             :fixed-pitch-family "0xProto"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (regular-inconsolata
             :default-family "Inconsolata"
             :default-height 160
             :fixed-pitch-family "Inconsolata"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.0
             :italic-slant italic)
            (regular-shared
             :inherit regular
             :default-height 170)
            (macbook
             :default-family "Maple Mono"
             :default-height 150
             :fixed-pitch-family "Maple Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (macbook-0xProto
             :default-family "0xProto"
             :default-height 140
             :fixed-pitch-family "0xProto"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (macbook-external
             :default-family "Maple Mono"
             :default-height 140
             :fixed-pitch-family "Maple Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (macbook-berkeley
             :default-family "Berkeley Mono"
             :default-height 150
             :fixed-pitch-family "Berkeley Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (macbook-inconsolata
             :default-family "Inconsolata"
             :default-height 180
             :fixed-pitch-family "Inconsolata"
             :variable-pitch-family "Source Sans 3"
             :italic-slant italic)
            (macbook-shared
             :inherit macbook
             :default-height 210)))

  :config
  (fontaine-set-preset (or (fontaine-restore-latest-preset)
                           'regular))
  (fontaine-mode 1))

(use-package mood-line
  :ensure t
  :config
  (mood-line-mode))

(use-package pulsar
  :ensure t
  :bind (:map global-map
              ("C-x l" . pulsar-pulse-line))
  :init
  (pulsar-global-mode 1)
  :hook (next-error . pulsar-pulse-line))

(use-package hl-line
  :ensure nil
  :init
  (global-hl-line-mode 1))

(setq-default truncate-lines nil)

;; *** Behavior ***
(setopt scroll-margin 10)
(use-package easy-kill
  :ensure t
  :bind (([remap kill-ring-save] . easy-kill)
         ([remap mark-sexp] . easy-mark)))

(use-package zop-to-char
  :ensure t
  :bind ([remap zap-to-char] . zop-up-to-char))

(use-package crux
  :ensure t
  :defer t
  :bind (("C-M-z" . crux-indent-defun)
         ("C-^" . crux-top-join-line)
         ("C-c d" . crux-duplicate-current-line-or-region)
         ([remap move-beginning-of-line] . crux-move-beginning-of-line)
         ([remap keyboard-quit] . crux-keyboard-quit-dwim)))

(use-package avy
  :ensure t
  :defer t
  :config
  (setq avy-background t)
  :bind (("s-," . avy-goto-char-timer)
         ("M-g l" . avy-goto-line)))

(use-package ace-window
  :ensure t
  :bind ([remap other-window] . ace-window)
  :custom
  (aw-scope 'frame))

(use-package expand-region
  :ensure t
  :bind ("C-=" . er/expand-region))

(use-package yasnippet-snippets
  :after yasnippet
  :ensure t)

(use-package yasnippet
  :ensure t
  :commands (yas-minor-mode
             yas-global-mode)
  :hook
  (after-init . yas-global-mode)
  :custom
  (yas-also-auto-indent-first-line t)  ; Indent first line of snippet
  (yas-also-indent-empty-lines t)
  (yas-snippet-revival nil)  ; Setting this to t causes issues with undo
  (yas-wrap-around-region nil) ; Do not wrap region when expanding snippets
  :init
  (setq yas-verbosity 0))

(use-package jinx
  :ensure t
  :hook
  (emacs-startup . global-jinx-mode)
  :bind (("M-$" . jinx-correct)
         ("C-M-$" . jinx-languages)))

(global-set-key (kbd "C-c *") 'isearch-forward-thing-at-point)

(use-package super-save
  :ensure t
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-idle-duration 60)

  :config
  ;; Disable super-save in situations where it doesn't work well:
  ;; - org-mode: spaces removed after every org-roam-node-insert
  ;; - hexl-mode: saves the hexl format of the file
  (add-to-list 'super-save-predicates (lambda ()
                                        (not (memq major-mode '(org-mode hexl-mode)))))
  :hook (after-init . super-save-mode))

;; **** Miscellaneous ****
(setq warning-minimum-level :error)

(use-package which-key
  :ensure t
  :commands which-key-mode
  :hook (after-init . which-key-mode)
  :custom
  (which-key-idle-delay 1.5)
  (which-key-idle-secondary-delay 0.25)
  (which-key-add-column-padding 1)
  (which-key-max-description-length 40))

(use-package editorconfig
  :ensure nil
  :config
  (editorconfig-mode 1))

(add-hook 'after-init-hook #'show-paren-mode)
(add-hook 'after-init-hook #'winner-mode)
(delete-selection-mode 1)
(setq save-interprogram-paste-before-kill t)

(setq confirm-kill-emacs 'y-or-n-p)

(use-package uniquify
  :ensure nil
  :custom
  (uniquify-buffer-name-style 'reverse)
  (uniquify-separator "•")
  (uniquify-after-kill-buffer-p t))

;; **** History ****
(use-package autorevert
  :ensure nil
  :commands (auto-revert-mode global-auto-revert-mode)
  :hook
  (after-init . global-auto-revert-mode)
  :custom
  (auto-revert-interval 3)
  (auto-revert-remote-files nil)
  (auto-revert-use-notify t)
  (auto-revert-avoid-polling nil)
  (auto-revert-verbose t))

(use-package recentf
  :ensure nil
  :commands (recentf-mode recentf-cleanup)
  :hook
  (after-init . recentf-mode)
  :custom
  (recentf-auto-cleanup (if (daemonp) 300 'never))
  (recentf-exclude
   (list "\\.tar$" "\\.tbz2$" "\\.tbz$" "\\.tgz$" "\\.bz2$"
         "\\.bz$" "\\.gz$" "\\.gzip$" "\\.xz$" "\\.zip$"
         "\\.7z$" "\\.rar$"
         "COMMIT_EDITMSG\\'"
         "\\.\\(?:gz\\|gif\\|svg\\|png\\|jpe?g\\|bmp\\|xpm\\)$"
         "-autoloads\\.el$" "autoload\\.el$"))

  :config
  ;; A cleanup depth of -90 ensures that `recentf-cleanup' runs before
  ;; `recentf-save-list', allowing stale entries to be removed before the list
  ;; is saved by `recentf-save-list', which is automatically added to
  ;; `kill-emacs-hook' by `recentf-mode'.
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90))

(use-package savehist
  :ensure nil
  :commands (savehist-mode savehist-save)
  :hook
  (after-init . savehist-mode)
  :custom
  (savehist-autosave-interval 600)
  (savehist-additional-variables
   '(kill-ring                        ; clipboard
     register-alist                   ; macros
     mark-ring global-mark-ring       ; marks
     search-ring regexp-search-ring)))

(use-package saveplace
  :ensure nil
  :commands (save-place-mode save-place-local-mode)
  :hook
  (after-init . save-place-mode)
  :custom
  (save-place-limit 400))

;; **** Window Management ****
(require 'windmove)
(windmove-default-keybindings)

(use-package perspective
  :ensure t
  :demand t
  :after consult
  :custom
  (persp-mode-prefix-key (kbd "C-x x"))
  (persp-modestring-short t)
  (persp-initial-frame-name "plan")
  :config
  (consult-customize consult-source-buffer :hidden t :default nil)
  (add-to-list 'consult-buffer-sources persp-consult-source)
  (persp-mode))

(use-package dired
  :ensure nil
  :hook
  (dired-mode . dired-hide-details-mode))

(use-package dired-preview
  :ensure t
  :hook
  (dired-mode . dired-preview-mode))

(use-package casual
  :ensure t
  :pin melpa-stable)

(use-package casual-dired
  :ensure nil
  :after dired
  :bind (:map dired-mode-map
         ("C-o" . casual-dired-tmenu)
         ("s" . casual-dired-sort-by-tmenu)))

(use-package casual-agenda
  :ensure nil
  :after org-agenda
  :bind (:map org-agenda-mode-map
         ("C-o" . casual-agenda-tmenu)))

(use-package casual-calc
  :ensure nil
  :after calc
  :bind (:map calc-mode-map
         ("C-o" . casual-calc-tmenu)
         :map calc-alg-map
         ("C-o" . casual-calc-tmenu)))

;; **** vertico stack ****
(use-package vertico
  :ensure t
  :config
  (vertico-mode))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless partial-completion basic))
  (completion-category-defaults nil)
  (completion-category-overrides nil))

(use-package marginalia
  :ensure t
  :commands (marginalia-mode marginalia-cycle)
  :hook (after-init . marginalia-mode))

(use-package embark
  :ensure t
  :commands (embark-act
             embark-dwim
             embark-export
             embark-collect
             embark-bindings
             embark-prefix-help-command)
  :bind
  (("C-." . embark-act)         ;; pick some comfortable binding
   ("C-;" . embark-dwim)        ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'

  :init
  (setq prefix-help-command #'embark-prefix-help-command)

  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package wgrep
  :ensure t)

(use-package embark-consult
  :ensure t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package consult
  :ensure t
  :demand t
  :bind (;; C-c bindings in `mode-specific-map'
         ("C-c M-x" . consult-mode-command)
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ("C-c m" . consult-man)
         ("C-c i" . consult-info)
         ([remap Info-search] . consult-info)
         ;; C-x bindings in `ctl-x-map'
         ("C-x M-:" . consult-complex-command)
         ("C-x b" . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x 5 b" . consult-buffer-other-frame)
         ("C-x t b" . consult-buffer-other-tab)
         ("C-x r b" . consult-bookmark)
         ("C-x p b" . consult-project-buffer)
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load)
         ("M-'" . consult-register-store)
         ("C-M-#" . consult-register)
         ;; Other custom bindings
         ("M-y" . consult-yank-pop)
         ;; M-g bindings in `goto-map'
         ("M-g e" . consult-compile-error)
         ("M-g f" . consult-flymake)
         ("M-g g" . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g o" . consult-outline)
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings in `search-map'
         ("M-s d" . consult-find)
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)
         ("M-s e" . consult-isearch-history)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history)
         ("M-r" . consult-history)
         ;; project.el replacements
         :map project-prefix-map
         ("g" . consult-ripgrep))

  ;; Enable automatic preview at point in the *Completions* buffer.
  :hook (completion-list-mode . consult-preview-at-point-mode)

  :init
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format)
  (advice-add #'register-preview :override #'consult-register-window)
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  :config
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   consult-source-bookmark consult-source-file-register
   consult-source-recent-file consult-source-project-recent-file
   :preview-key '(:debounce 0.4 any))
  (setq consult-narrow-key "<"))

;; **** Completions ****
(use-package corfu
  :ensure t
  :commands (corfu-mode global-corfu-mode)

  :hook ((prog-mode . corfu-mode)
         (shell-mode . corfu-mode)
         (eshell-mode . corfu-mode)
         (agent-shell-mode . corfu-mode))

  :custom
  (read-extended-command-predicate #'command-completion-default-include-p)
  (text-mode-ispell-word-completion nil)
  (tab-always-indent 'complete)

  :config
  (global-corfu-mode))

(use-package cape
  :ensure t
  :commands (cape-dabbrev cape-file cape-elisp-block)
  :bind ("C-c p" . cape-prefix-map)
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-elisp-block))

;; *** Content ***
(use-package elfeed
  :ensure t
  :init
  (setq-default elfeed-search-filter "@2-months-ago +unread ")
  (setopt elfeed-sort-order 'ascending)

  :hook (kill-emacs . elfeed-db-compact)
  :bind ("C-x w" . elfeed))

(use-package elfeed-tube
  :ensure t
  :after elfeed
  :demand t
  :config
  (elfeed-tube-setup)
  :bind (:map elfeed-show-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)
         :map elfeed-search-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)))

(use-package shr
  :ensure nil
  :demand t
  :config
  (setq shr-width 100
        shr-max-width 120
        shr-indentation 4
        shr-use-fonts nil
        shr-max-image-size '(800 . 600)
        shr-image-animate t))

(use-package eww
  :ensure nil
  :demand t
  :init
  (defun byronc/browse-url-pdf (url &rest _args)
    (let ((tmp (make-temp-file "emacs-pdf-" nil ".pdf")))
      (url-copy-file url tmp t)
      (find-file-other-window tmp)
      (pdf-view-mode)))
  :config
  (setq browse-url-handlers
        '(("\\.pdf$" . byronc/browse-url-pdf)
          ("github\\.com\\|gitlab\\.com\\|melpa.org\\|youtube.com" . browse-url-default-browser)
          ("." . eww-browse-url)))
  (setq browse-url-secondary-browser-function 'browse-url-default-browser))

;; **** Information Management ****
(use-package org
  :ensure t
  :demand t
  :mode ("\\.org\\'" . org-mode)
  :bind (("C-c a" . org-agenda)
         ("C-c b" . org-switchb)
         ("C-c l" . org-switch-link)
         ("C-c c" . org-capture))
  :hook (org-mode . (lambda ()
                      (auto-fill-mode -1)
                      (whitespace-mode -1)))
  :config
  (setq
   ;; Edit settings
   org-log-done t
   org-log-into-drawer t
   org-auto-align-tags nil
   org-tags-column 0
   org-catch-invisible-edits 'show-and-error
   org-special-ctrl-a/e t
   org-insert-heading-respect-content t

   ;; Babel settings
   org-src-preserve-indentation t
   org-src-window-setup 'current-window

   ;; Org styling, hide markup etc.
   org-hide-emphasis-markers t
   org-pretty-entities t
   org-ellipsis "…"

   ;; Agenda styling
   org-agenda-tags-column 0
   org-agenda-block-separator ?─

   ;; And everything else...
   org-directory "~/org"
   org-agenda-files (list "inbox.org"
                          "gtd.org"
                          "tickler.org"
                          "habits.org")
   org-refile-targets '(("gtd.org" :maxlevel . 2)
                        ("someday.org" :level . 1)
                        ("tickler.org" :maxlevel . 2))
   org-capture-templates '(("t" "Todo [inbox]" entry
                            (file+headline "inbox.org" "Tasks")
                            "* TODO %i%?")
                           ("T" "Tickler" entry
                            (file+headline "tickler.org" "Tickler")
                            "* %i%? \n %U"))

   org-todo-keywords '((sequence "TODO(t)" "WAITING(w@/!)" "|" "DONE(d!)" "CANCELLED(c@)"))

   org-agenda-window-setup 'current-window)
  (require 'org-habit))

(use-package verb
  :ensure t
  :pin melpa-stable
  :after org
  :custom
  (verb-auto-kill-response-buffers t)
  :config
  (define-key org-mode-map (kbd "C-c C-r") verb-command-map))

(use-package org-roam
  :ensure t
  :after org
  :commands (org-roam-node-find
             org-roam-node-search)
  :bind (("C-c n j" . org-roam-dailies-capture-today)
         ("C-c n d" . org-roam-dailies-goto-today)
         :map org-mode-map
         ("C-c n i" . org-roam-node-insert)
         ("C-c n t" . org-roam-tag-add)
         ("C-c n a" . org-roam-alias-add)
         ("C-c n l" . org-roam-buffer-toggle)
         ("C-c n r" . org-roam-refile))
  :config
  (setq
   org-roam-directory "~/org/notes"
   org-roam-capture-templates '(("d" "default" plain "%?"
                                 :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}
")
                                 :unnarrowed t)
                                ("b" "book notes" plain
                                 "\n\n- tags :: \n- author :: \n- series :: \n\n* Summary\n\n%?"
                                 :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}
")
                                 :unnarrowed t))

   org-roam-dailies-directory "daily/"
   org-roam-dailies-capture-templates '(("d" "default" entry
                                         "* %?"
                                         :target (file+head "%<%Y-%m-%d>.org"
                                                            "#+title: %<%Y-%m-%d>\n"))))
  (org-roam-db-autosync-enable))

(use-package consult-org-roam
  :ensure t
  :after consult
  :bind (("C-c n f" . consult-org-roam-file-find)
         ("C-c n s" . consult-org-roam-search))
  :config
  (setq consult-org-roam-grep-func #'consult-ripgrep)
  (consult-org-roam-mode 1))

(use-package ob-mermaid
  :ensure t)

(use-package markdown-mode
  :commands (gfm-mode
             gfm-view-mode
             markdown-mode
             markdown-view-mode)
  :mode (("\\.markdown\\'" . markdown-mode)
         ("\\.md\\'" . markdown-mode)
         ("README\\.md\\'" . gfm-mode))
  :bind
  (:map markdown-mode-map
        ("C-c C-e" . markdown-do)))

(use-package markdown-mermaid
  :ensure t
  :after markdown-mode
  :commands (markdown-mermaid-preview)
  :bind (:map markdown-mode-map
         ("C-c m" . markdown-mermaid-preview)))

;; *** Development ***
(use-package eldoc
  :ensure nil
  :config
  (setq eldoc-echo-area-use-multiline-p nil))

(use-package flymake
  :ensure nil
  :hook (prog-mode . flymake-mode))

(use-package project
  :ensure nil
  :custom
  (project-switch-commands
   '((project-find-file "Find file")
     (consult-ripgrep "Find regexp")
     (project-find-dir "Find directory")
     (project-vterm "Terminal")
     (magit-project-status "Magit")))
  (project-vc-extra-root-markers
   '(".projectile" ; carry over from projectile
     "deps.edn"
     "nbb.edn"
     "shadow-cljs.edn"))
  :config
  (defun byronc/project-kill-relative-path ()
    "Kill the project relative path of the file visited in the current buffer."
    (interactive)
    (if-let* ((file (buffer-file-name))
              (project (project-current))
              (root (project-root project))
              (rel-path (file-relative-name file root)))
        (progn
          (kill-new rel-path)
          (message "Copied: %s" rel-path))
      (message "Not in a project or buffer has no file"))))

(use-package envrc
  :hook (after-init . envrc-global-mode))

(use-package mise
  :ensure t
  :hook (prog-mode . mise-mode))

;; **** Terminal ****
(use-package vterm
  :ensure t
  :defer t
  :preface
  (defun project-vterm (&optional arg)
    "Start a vterm session in the current project's root directory.
Like `project-shell' but using vterm instead.

With prefix ARG, create a new vterm buffer even if one already exists."
    (interactive "P")
    (let* ((default-directory (project-root (project-current t)))
           (default-project-vterm-name (project-prefixed-buffer-name "vterm"))
           (vterm-buffer (get-buffer default-project-vterm-name)))
      (if (and vterm-buffer (not arg))
          (pop-to-buffer vterm-buffer)
        (vterm (generate-new-buffer-name default-project-vterm-name)))))
  :custom
  (vterm-always-compile-module t)
  (vterm-min-window-width 40)
  :commands (vterm
             project-vterm)
  :bind (("C-c t" . project-vterm)
         :map project-prefix-map
         ("t" . project-vterm))
  :hook
  (vterm-mode . (lambda () (setq-local global-hl-line-mode nil)))
  (vterm-copy-mode . (lambda () (call-interactively 'hl-line-mode))))

;; **** Machine intelligence ****
(use-package gptel
  :ensure t
  :after auth-source
  :bind ("C-c M" . gptel-menu)
  :commands (gptel gptel-send gptel-org-set-topic)
  :custom
  (gptel-default-mode #'org-mode)
  :config
  (require 'gptel-org)
  (setq gptel-backend (gptel-make-openai
                       "OpenRouter"
                       :host "openrouter.ai"
                       :endpoint "/api/v1/chat/completions"
                       :stream t
                       :key (auth-source-pick-first-password :host "openrouter.ai")
                       :models '(anthropic/claude-sonnet-4.5
                                 google/gemini-3-flash-preview
                                 google/gemini-3-pro-preview
                                 openai/gpt-5.2))))

(use-package agent-shell
  :ensure t
  :after auth-source
  :custom
  (agent-shell-prefer-viewport-interaction t)
  (agent-shell-context-sources '(files region error))
  (agent-shell-agent-configs (list (agent-shell-anthropic-make-claude-code-config)))
  (agent-shell-busy-indicator-frames 'dots-block)
  (agent-shell-session-strategy 'new)   ;Change this when agents start working better as a continuous single session.
  ;; Configure global mcp servers in ~/.emacs.local.
  ;; Claude Code
  (agent-shell-anthropic-authentication (agent-shell-anthropic-make-authentication :login t))
  ;;(agent-shell-anthropic-default-session-mode-id "plan")
  :config
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables
         ;; 1m token context window is not really a win in most cases.
         ;; Artificially limit the window until we have a better option.
         "CLAUDE_CODE_AUTO_COMPACT_WINDOW" "400000"
         :inherit-env t))
  :commands (agent-shell))

;; **** Source Control ****
(use-package magit
  :ensure t
  :pin melpa-stable
  :demand t
  :after project
  :custom
  (magit-define-global-key-bindings 'recommended)
  (magit-list-refs-sortby "-creatordate")
  :bind (:map project-prefix-map
         ("m" . magit-project-status)))

(use-package forge
  :ensure t
  :pin melpa-stable
  :defer t
  :after magit)

(use-package diff-hl
  :ensure t
  :after magit
  :hook
  ((dired-mode . diff-hl-dired-mode)
   (magit-post-refresh . diff-hl-magit-post-refresh))
  :config
  (global-diff-hl-mode))

(use-package git-timemachine
  :ensure t
  :commands (git-timemachine))

;; **** Structural Editing ****
(use-package smartparens
  :ensure t
  :hook
  ((prog-mode . smartparens-mode)
   (emacs-lisp-mode . smartparens-strict-mode))
  :config
  (require 'smartparens-config)
  (setq sp-base-key-bindings 'paredit
        sp-autoskip-closing-pair 'always
        sp-hybrid-kill-entire-symbol nil)
  (sp-use-paredit-bindings)
  ;; Switch sp-splice-sexp so consult and friends can have the binding.
  (define-key smartparens-mode-map (kbd "M-s") nil)
  (define-key smartparens-mode-map (kbd "M-D") #'sp-splice-sexp)
  ;; Unbind sp-convolute-sexp so xref can use it
  (define-key smartparens-mode-map (kbd "M-?") nil)
  (show-smartparens-global-mode 1))

(use-package rainbow-delimiters
  :ensure t
  :hook prog-mode)

;; **** White space ****
(use-package whitespace
  :ensure nil
  :config
  (defun enable-whitespace ()
    ;; cleanup whitespace in this buffer
    (add-hook 'before-save-hook 'whitespace-cleanup nil t)
    (whitespace-mode))
  (setq whitespace-line-column 120
        whitespace-style '(face tabs empty trailing lines-char))
  :hook ((text-mode . enable-whitespace)
         (prog-mode . enable-whitespace)))

;; **** Code understanding and navigation ****
(setq-default display-line-numbers-type 'absolute)
(dolist (hook '(prog-mode-hook conf-mode-hook))
  (add-hook hook #'display-line-numbers-mode))

(use-package outline
  :ensure nil
  :commands outline-minor-mode
  :hook
  ((emacs-lisp-mode . outline-minor-mode)
   (clojure-mode . outline-minor-mode)
   ;; Use " ▼" instead of the default ellipsis "..." for folded text to make
   ;; folds more visually distinctive and readable.
   (outline-minor-mode
    .
    (lambda()
      (let* ((display-table (or buffer-display-table (make-display-table)))
             (face-offset (* (face-id 'shadow) (ash 1 22)))
             (value (vconcat (mapcar (lambda (c) (+ face-offset c)) " ▼"))))
        (set-display-table-slot display-table 'selective-display value)
        (setq buffer-display-table display-table))))))

(use-package eglot
  :ensure t
  :commands (eglot-ensure
             eglot-rename
             eglot-format-buffer)
  :bind (:map eglot-mode-map
         ("C-c e a" . eglot-code-actions)
         ("C-c e r" . eglot-rename)
         ("C-c e f" . eglot-format)
         ("C-c e i" . eglot-find-implementation)
         ("C-c e d" . eglot-find-declaration))
  :custom
  (eglot-connect-timeout 300)
  (eglot-ignored-server-capabilites '(:inlayHintProvider))
  (eglot-extend-to-xref nil)
  (eglot-confirm-server-initiated-edits nil)
  (eglot-code-action-indicator "α")
  :config
  (defun byronc/eglot-maybe-format-region (orig-fun beg end &optional arg)
    (if (and (bound-and-true-p eglot--managed-mode)
             (eglot--server-capable :documentRangeFormattingProvider))
        (eglot-format beg end)
      (funcall orig-fun beg end arg)))
  (advice-add 'indent-region :around #'byronc/eglot-maybe-format-region))

(use-package eglot-multi-preset
  :ensure t
  :vc (:url "https://github.com/kn66/eglot-multi-preset.git" :rev :newest)
  :config
  (eglot-multi-preset-mode 1))

(use-package treesit-auto
  :custom
  (treesit-auto-install 'prompt)
  (treesit-auto-langs '(typescript tsx python javascript))
  :config
  (treesit-auto-add-to-auto-mode-alist '(typescript tsx javascript))
  (global-treesit-auto-mode))

;; Allow eglot to navigate into jar archives pointed to by clojure-lsp
(use-package jarchive
  :ensure t
  :after eglot
  :config
  (jarchive-setup))

;; **** Languages ****
;; ***** Clojure *****
(use-package clojure-mode
  :ensure t
  :pin melpa-stable
  :after smartparens
  :mode "\\.fiddle\\'" ;Calva fiddle
  :config
  (setq clojure-toplevel-inside-comment-form t)
  :hook ((clojure-mode . smartparens-strict-mode)
         (clojure-mode . subword-mode)
         (clojure-mode . eglot-ensure)))

(use-package cider
  :ensure t
  :pin melpa-stable
  :after clojure-mode
  :custom
  (nrepl-log-messages t)
  (cider-use-xref nil) ;Prefer lsp provided xref backend.
  (cider-offer-to-open-cljs-app-in-browser nil)
  (cider-repl-display-help-banner nil)
  (cider-repl-display-in-current-window t)
  (cider-eldoc-display-for-symbol-at-point nil)
  (cider-nbb-command "npx nbb") ;Prefer project version of nbb.
  :config
  ;; cider portal integration (see https://cljdoc.org/d/djblue/portal/0.58.5/doc/editors/emacs)
  (defun portal.api/open ()
    (interactive)
    (cider-nrepl-sync-request:eval
     "(do (ns dev) (def portal ((requiring-resolve 'portal.api/open) {:launcher :emacs})) (add-tap (requiring-resolve 'portal.api/submit)))"))
  (defun portal.api/clear ()
    (interactive)
    (cider-nrepl-sync-request:eval "(portal.api/clear)"))
  (defun portal.api/close ()
    (interactive)
    (cider-nrepl-sync-request:eval "(portal.api/close)"))
  :hook ((cider-repl-mode . smartparens-strict-mode)
         (cider-repl-mode . subword-mode)
         (cider-mode . (lambda ()
                         (remove-hook 'completion-at-point-functions 'cider-complete-at-point)))))

;; **** Docker ****
(use-package dockerfile-mode
  :ensure t)

;; **** GraphQL ****
(use-package graphql-mode
  :ensure t)

(use-package graphviz-dot-mode
  :ensure t
  :custom
  (graphviz-dot-indent-width 4))

;; **** JavaScript ****
(use-package js-ts-mode
  :ensure nil
  :mode "\\.[mc]js\\'" ;Modules
  :hook ((js-ts-mode . subword-mode)
         (js-ts-mode . eglot-ensure)))

;; **** TypeScript ****
(use-package typescript-ts-mode
  :ensure nil
  :hook ((typescript-ts-mode . eglot-ensure)
         (typescript-ts-mode . subword-mode)
         (tsx-ts-mode . eglot-ensure)
         (tsx-ts-mode . subword-mode)))

;; **** Python ****
(use-package python
  :ensure nil
  :hook
  (python-mode . eglot-ensure)
  (python-ts-mode . eglot-ensure))

(use-package pyvenv-auto
  :ensure t
  :hook ((python-mode . pyvenv-auto-run)))

;; **** Swift ****
(use-package swift-mode
  :ensure t)

;; **** Terraform ****
(use-package terraform-mode
  :ensure t)

;; **** YAML ****
(use-package yaml-mode
  :ensure t)

;; **** Zig ****
(use-package zig-mode
  :ensure t
  :hook
  (zig-mode . (lambda ()
                (smartparens-mode -1)
                (electric-pair-local-mode)
                (eglot-ensure))))

(use-package emacs
  :ensure nil
  :demand t
  :bind
  ("s-u" . revert-buffer)
  :hook
  (compilation-filter . ansi-color-compilation-filter)
  (text-mode . visual-line-mode)
  (text-mode . visual-wrap-prefix-mode)
  (after-save . executable-make-buffer-file-executable-if-script-p)
  :custom
  (isearch-lazy-count t)
  (lazy-count-prefix-format "(%s/%s) ")
  (window-combination-resize t)
  (set-mark-command-repeat-pop t)
  :config
  ;; macOS specifics
  (when (eq system-type 'darwin)
    (setq mac-option-modifier 'meta)
    (setq mac-command-modifier 'super)

    ;; Use GNU coreutils where needed on macOS
    (setopt insert-directory-program "gls")
    (setopt Man-sed-command "gsed")

    ;; Some macOS builds of emacs have a strict limit of 1024 files that can be
    ;; _watched_ before they start spewing errors about too many open files.
    ;; lsp-mode is especially good at watching lots of files.
    (setopt lsp-enable-file-watchers nil)))

(use-package server
  :ensure nil
  :commands server-start
  :hook (after-init . server-start))

;;; post-init.el ends here

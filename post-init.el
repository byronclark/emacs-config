;;; post-init.el --- Configuration after interface loads -*- no-byte-compile: t; lexical-binding: t; -*-

(use-package compile-angel
  :demand t
  :ensure t
  :config
  (setq compile-angel-verbose t)

  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)
  (push "/pre-init.el" compile-angel-excluded-files)
  (push "/post-init.el" compile-angel-excluded-files)
  (push "/pre-early-init.el" compile-angel-excluded-files)
  (push "/post-early-init.el" compile-angel-excluded-files)

  (compile-angel-on-load-mode 1))

(use-package exec-path-from-shell
  :ensure t
  :if (or (display-graphic-p) (daemonp))
  :demand t
  :functions exec-path-from-shell-initialize
  :config
  (dolist (env-var '("TMPDIR" "SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO" "LANG" "LC_CTYPE" "JAVA_HOME"))
    (add-to-list 'exec-path-from-shell-variables env-var))
  (exec-path-from-shell-initialize))

;; *** Allow use-package to install system packages ***
(use-package system-packages
  :ensure t)

(use-package use-package-ensure-system-package
  :ensure nil)

(defvar byronc/emacs-local-init-dir (expand-file-name "init" byronc/emacs-local-dir))

(defvar byronc/agent-shell-configure-hook nil
  "Hook for machine-local agent-shell configuration.

Functions run after agent-shell and its agent integrations have loaded.")

(defvar byronc/browse-url-default-browser-domains
  '("github\\.com"
    "gitlab\\.com"
    "melpa.org"
    "youtube.com"
    "google.com")
  "Regexps of domains to open in the system browser instead of eww. Defined early so local init files can add to the list.")

(use-package epa-file
  :ensure nil
  :custom
  (epg-pinentry-mode nil)
  :hook
  (after-init . epa-file-enable))

(use-package auth-source
  :ensure nil
  :custom
  (auth-sources (list (expand-file-name "secrets/.authinfo.gpg" byronc/emacs-local-dir))))

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
             :default-height 160
             :fixed-pitch-family "Maple Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (macbook-external
             :default-family "Maple Mono"
             :default-height 150
             :fixed-pitch-family "Maple Mono"
             :variable-pitch-family "Source Sans 3"
             :variable-pitch-height 1.1
             :italic-slant italic)
            (macbook-berkeley
             :default-family "Berkeley Mono"
             :default-height 160
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

(use-package anzu
  :ensure t
  :pin melpa-stable
  :bind
  (([remap query-replace] . anzu-query-replace)
   ([remap query-replace-regexp] . anzu-query-replace-regexp))
  :config
  (global-anzu-mode +1))

(use-package expand-region
  :ensure t
  :bind ("C-=" . er/expand-region))

(use-package yasnippet-snippets
  :ensure t)

(use-package yasnippet
  :ensure t
  :after yasnippet-snippets
  :custom
  (yas-also-auto-indent-first-line t)  ; Indent first line of snippet
  (yas-also-indent-empty-lines t)
  (yas-snippet-revival nil)  ; Setting this to t causes issues with undo
  (yas-wrap-around-region nil) ; Do not wrap region when expanding snippets
  (yas-indent-line 'fixed)
  :init
  (setq yas-verbosity 0)
  (yas-global-mode 1))

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
  :custom
  (auto-revert-interval 3)
  (auto-revert-remote-files nil)
  (auto-revert-use-notify t)
  (auto-revert-avoid-polling nil)
  (auto-revert-verbose t)
  :init
  (global-auto-revert-mode 1))

(use-package recentf
  :ensure nil
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
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90)
  :init
  (recentf-mode 1))

(use-package savehist
  :ensure nil
  :custom
  (history-length 300)
  (savehist-autosave-interval 600)
  :init
  (savehist-mode 1))

(use-package saveplace
  :ensure nil
  :custom
  (save-place-limit 400)
  :init
  (save-place-mode 1))

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
  :pin melpa-stable
  :hook (after-init . casual-init))

;; **** vertico stack ****
(use-package vertico
  :ensure t
  :init
  (vertico-mode 1))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  ;; Emacs 31: partial-completion behaves like substring
  (completion-pcm-leading-wildcard t))

(use-package marginalia
  :ensure t
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle))
  :init
  (marginalia-mode 1))

(use-package embark
  :ensure t
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
  :ensure t)

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
  (setq register-preview-delay 0.5)
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
  :custom
  (read-extended-command-predicate #'command-completion-default-include-p)
  (text-mode-ispell-word-completion nil)
  (tab-always-indent 'complete)

  :init
  (global-corfu-mode 1))

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
  :pin melpa-stable
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
  (setq shr-width nil
        shr-max-width 100
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
        `(("\\.pdf$" . byronc/browse-url-pdf)
          (,(mapconcat #'identity byronc/browse-url-default-browser-domains "\\|") . browse-url-default-browser)))
  ;; Starting Emacs 31, `eww-browse-with-external-browser' routes through
  ;; `browse-url' which means a catch-all in `browse-url-handlers' keeps the
  ;; secondary browser function from being called.
  (setq browse-url-browser-function 'eww-browse-url)
  (setq browse-url-secondary-browser-function 'browse-url-default-browser))

;; **** Information Management ****
(use-package org
  :ensure t
  :demand t
  :mode ("\\.org\\'" . org-mode)
  :preface
  (defun byronc/org-capture-web-link-template ()
    "Build a capture entry from the last stored link. Currently handles:
- elfeed (use external-link)
- eww, org-protocol (or any other generic entry with a :link)"
    (let* ((type  (plist-get org-store-link-plist :type))
           (desc  (plist-get org-store-link-plist :description))
           ;; Escape % in page-supplied text so it isn't expanded as a capture escape.
           (title (if desc (string-replace "%" "%%" desc) "%^{Title}"))
           (url   (string-replace "%" "%%"
                                  (pcase type
                                    ("elfeed" (plist-get org-store-link-plist :external-link))
                                    (_        (plist-get org-store-link-plist :link))))))
      (format "* %s\n%s\n%%U\n%%i%%?" title url)))

  :bind (("C-c a" . org-agenda)
         ("C-c b" . org-switchb)
         ("C-c l" . org-store-link)
         ("C-c c" . org-capture))
  :hook (org-mode . (lambda ()
                      (auto-fill-mode -1)))
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
                            (file "inbox.org")
                            "* TODO %i%?")
                           ("T" "Tickler" entry
                            (file "tickler.org")
                            "* %i%? \n %U")
                           ("r" "Read later" entry
                            (file "inbox.org")
                            (function byronc/org-capture-web-link-template)))

   org-todo-keywords '((sequence "TODO(t)" "WAITING(w@/!)" "|" "DONE(d!)" "CANCELLED(c@)"))

   org-agenda-window-setup 'current-window)

  ;; Add rather than set to allow contributions from ~/.emacs.local
  (add-to-list 'org-link-abbrev-alist '("github" . "https://github.com/%s"))

  (require 'org-habit)
  (require 'org-protocol))

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
  :preface
  (defun byronc/org-roam-node-link (node)
    "Return an Org link to NODE.
Uses an id: link when NODE already exists, and a roam: link otherwise;
org-roam rewrites roam: links to id: links on save once the node does
exist.  Returns the empty string for an empty title."
    (let ((title (org-roam-node-title node)))
      (cond ((string= title "") "")
            ((org-roam-node-id node)
             (org-link-make-string (concat "id:" (org-roam-node-id node)) title))
            (t (org-link-make-string (concat "roam:" title) title)))))

  (defun byronc/org-roam-read-link (prompt)
    "Read a node with PROMPT and return an Org link to it."
    (byronc/org-roam-node-link (org-roam-node-read nil nil nil nil prompt)))

  (defun byronc/org-roam-title-link (title)
    "Return an Org link to the node named TITLE.
Looked up by title so the id stays out of this file and each machine
resolves to its own node."
    (byronc/org-roam-node-link
     (or (org-roam-node-from-title-or-alias title)
         (org-roam-node-create :title title))))

  (defun byronc/org-roam-book-template ()
    "Body for the book note capture template.
Skipped prompts drop their line rather than leaving it empty."
    (let ((genre (byronc/org-roam-read-link "Genre (RET to skip): "))
          (author (byronc/org-roam-read-link "Author: "))
          (series (byronc/org-roam-read-link "Series (RET to skip): ")))
      (concat "\n- tags :: "
              (mapconcat #'identity
                         (delete "" (list (byronc/org-roam-title-link "Book") genre))
                         ", ")
              "\n"
              (unless (string= author "") (concat "- author :: " author "\n"))
              (unless (string= series "") (concat "- series :: " series "\n"))
              "- read :: [%<%Y-%m-%d %a>]\n"
              "\n* Summary\n\n%?")))

  (defun byronc/org-roam-dailies-goto-today ()
    "Go to today's daily note without prompting for a template."
    (interactive)
    (org-roam-dailies-goto-today "d"))
  :bind (("C-c n j" . org-roam-dailies-capture-today)
         ("C-c n d" . byronc/org-roam-dailies-goto-today)
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
                                 (function byronc/org-roam-book-template)
                                 :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}
")
                                 :unnarrowed t))

   org-roam-dailies-directory "daily/"
   org-roam-dailies-capture-templates '(("d" "default" entry
                                         "* %?"
                                         :target (file+head "%<%Y-%m-%d>.org"
                                                            "#+title: %<%Y-%m-%d>\n"))
                                        ("j" "journal" entry
                                         "* %?"
                                         :target (file+head+olp "%<%Y-%m-%d>.org"
                                                                "#+title: %<%Y-%m-%d>\n"
                                                                ("Journal")))))
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
     (ghostel-project "Terminal")
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
(use-package ghostel
  :ensure t
  :pin melpa-stable ; matching binary is only available for released versions
  :preface
  (defun byronc/ghostel-dwim ()
    (interactive)
    (if (project-current)
        (call-interactively #'ghostel-project)
      (call-interactively #'ghostel)))
  :custom
  (ghostel-module-auto-install 'download)
  :bind (("C-c t" . byronc/ghostel-dwim)
         :map project-prefix-map
         ("t" . ghostel-project))
  :commands (ghostel
             ghostel-project))

(use-package ghostel-compile
  :ensure nil
  :hook (after-init . ghostel-compile-global-mode))

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
                       :models '(anthropic/claude-opus-latest
                                 anthropic/claude-sonnet-latest
                                 google/gemini-flash-latest
                                 openai/gpt-chat-latest))))

;; agent-shell and its dependencies have regular stable releases
(dolist (pkg '(acp shell-maker agent-shell))
  (add-to-list 'package-pinned-packages (cons pkg "melpa-stable")))

(use-package agent-shell
  :ensure t
  :after auth-source
  :custom
  (agent-shell-prefer-viewport-interaction t)
  (agent-shell-context-sources '(files region error))
  (agent-shell-busy-indicator-frames 'dots-block)

  (agent-shell-session-strategy 'prompt)
  (agent-shell-session-choices-function
   (lambda (choices)
     (seq-remove (lambda (choice)
                   (eq (cdr choice) :downloads-shell))
                 choices)))
  (agent-shell-agent-configs (list (agent-shell-anthropic-make-claude-code-config)
                                   (agent-shell-opencode-make-agent-config)
                                   (agent-shell-pi-make-agent-config)))
  (agent-shell-preferred-agent-config '(preselect . claude-code))

  ;; Claude Code
  (agent-shell-anthropic-authentication (agent-shell-anthropic-make-authentication :login t))
  (agent-shell-anthropic-default-session-mode-id "auto")
  :config
  (setq agent-shell-activity-group-header-label-function #'agent-shell-activity-group-tally-label)
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables
         ;; 1m token context window is not really a win in most cases.
         ;; Artificially limit the window until we have a better option.
         "CLAUDE_CODE_AUTO_COMPACT_WINDOW" "400000"
         :inherit-env t))

  ;; The header SVG is already sized in pixels, but `create-image' scales
  ;; it again, resulting in text that's ~10% larger than my font.
  ;;
  ;; We can drop this if agent-shell starts passing :scale when creating the
  ;; header SVG.
  (defun byronc/agent-shell-unscale-header (header)
    "Render the SVG image in HEADER at its intrinsic pixel size."
    (when-let* (((stringp header))
                (pos (text-property-not-all 0 (length header) 'display nil header))
                (image (get-text-property pos 'display header))
                ((imagep image)))
      (setf (image-property image :scale) 1))
    header)
  (unless (fboundp 'agent-shell--render-header-model-uncached)
    (warn "agent-shell header advice is stale"))
  (advice-add 'agent-shell--render-header-model-uncached :filter-return
              #'byronc/agent-shell-unscale-header)

  (run-hooks 'byronc/agent-shell-configure-hook)
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
  (cider-enable-nrepl-jvmti-agent t)
  (cider-nbb-command "npx nbb") ;Prefer project version of nbb.
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
  :if (not (daemonp))
  :preface
  (defun byronc/server-start ()
    (unless (server-running-p)
      (server-start)))
  :init
  (add-hook 'emacs-startup-hook #'byronc/server-start))

;;; post-init.el ends here

;;; agent-shell-sessions.el --- Cross-perspective view of agent-shell sessions -*- lexical-binding: t; -*-

;; Author: Byron Clark
;; Keywords: tools, processes
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; A live view of every `agent-shell' session and the perspective it lives in,
;; so finding out what each one is doing doesn't mean cycling perspectives.
;;
;; - `agent-shell-sessions' opens a self-refreshing list.
;; - `agent-shell-sessions-consult-source' adds the same sessions to
;;   `consult-buffer' under the `a' narrowing key.
;;
;; Both jump to the perspective owning a session rather than importing it into
;; the current one.  `agent-shell' and `perspective' are soft dependencies.

;;; Code:

(require 'cl-lib)
(require 'comint)
(require 'ring)
(require 'seq)
(require 'subr-x)
(require 'tabulated-list)

(declare-function agent-shell-buffers "agent-shell")
(declare-function agent-shell-status "agent-shell" (&key shell-buffer))
(declare-function agent-shell-cwd "agent-shell-project")
(declare-function consult--buffer-preview "consult")
(declare-function consult--state-with-return "consult")
(declare-function persp-buffers "perspective")
(declare-function persp-switch-to-buffer "perspective" (buffer-or-name &optional norecord))
(declare-function perspectives-hash "perspective" (&optional frame))

(defgroup agent-shell-sessions nil
  "Cross-perspective view of `agent-shell' sessions."
  :group 'tools
  :prefix "agent-shell-sessions-")

(defcustom agent-shell-sessions-refresh-interval 1.0
  "Seconds between refreshes of the session list.
The timer only does work while the list is on screen."
  :type 'number)

(defcustom agent-shell-sessions-prompt-width 70
  "Maximum width of the last-prompt column in `consult-buffer' annotations."
  :type 'integer)

(defconst agent-shell-sessions-buffer-name "*Agent Sessions*"
  "Name of the buffer holding the session list.")

(defconst agent-shell-sessions--status-rank
  '((blocked . 0) (ready . 1) (busy . 2) (unknown . 3) (dead . 4))
  "Sort order for session statuses: what is owed you floats to the top.")

;;;; Data layer

(defun agent-shell-sessions--status (buffer)
  "Return `blocked', `busy', `ready', `dead' or `unknown' for BUFFER."
  (cond
   ((not (buffer-live-p buffer)) 'dead)
   ((not (fboundp 'agent-shell-status)) 'unknown)
   (t (or (ignore-errors (agent-shell-status :shell-buffer buffer)) 'unknown))))

(defun agent-shell-sessions--perspectives (buffer)
  "Return the sorted names of every perspective holding BUFFER.
Perspectives are frame-local, so this looks across all frames."
  (when (and (bound-and-true-p persp-mode)
             (fboundp 'perspectives-hash))
    (let (names)
      (dolist (frame (frame-list))
        (maphash (lambda (name persp)
                   (when (memq buffer (persp-buffers persp))
                     (cl-pushnew name names :test #'equal)))
                 (perspectives-hash frame)))
      (sort names #'string<))))

(defun agent-shell-sessions--project (buffer)
  "Return a short project label for BUFFER, or nil."
  (when (and (buffer-live-p buffer) (fboundp 'agent-shell-cwd))
    (with-current-buffer buffer
      (when-let* ((cwd (ignore-errors (agent-shell-cwd))))
        (file-name-nondirectory (directory-file-name cwd))))))

(defun agent-shell-sessions--last-prompt (buffer)
  "Return the most recent prompt sent in BUFFER as one line, or nil.
`shell-maker' maintains a comint input ring per shell buffer."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and (ring-p comint-input-ring)
                 (not (ring-empty-p comint-input-ring)))
        (let ((prompt (ring-ref comint-input-ring 0)))
          (when (and (stringp prompt) (not (string-blank-p prompt)))
            (string-join (split-string prompt) " ")))))))

(defun agent-shell-sessions--rank (status)
  "Return the sort rank of STATUS."
  (or (alist-get status agent-shell-sessions--status-rank) 99))

(defun agent-shell-sessions-list ()
  "Return a plist per live `agent-shell' session.

Each plist carries :buffer, :name, :status, :perspectives, :project and
:prompt.  Sorted by status so blocked sessions come first, then by
recency of access within a status."
  (when (fboundp 'agent-shell-buffers)
    (let ((sessions nil)
          (index 0))
      (dolist (buffer (agent-shell-buffers))
        (when (buffer-live-p buffer)
          (push (list :buffer buffer
                      :name (buffer-name buffer)
                      :status (agent-shell-sessions--status buffer)
                      :perspectives (agent-shell-sessions--perspectives buffer)
                      :project (agent-shell-sessions--project buffer)
                      :prompt (agent-shell-sessions--last-prompt buffer)
                      :order index)
                sessions))
        (setq index (1+ index)))
      (sort (nreverse sessions)
            (lambda (a b)
              (let ((ra (agent-shell-sessions--rank (plist-get a :status)))
                    (rb (agent-shell-sessions--rank (plist-get b :status))))
                (if (= ra rb)
                    (< (plist-get a :order) (plist-get b :order))
                  (< ra rb))))))))

;;;; Shared presentation

(defun agent-shell-sessions--status-label (status)
  "Return a propertized label for STATUS."
  (pcase status
    ('blocked (propertize "blocked" 'face 'error))
    ('busy    (propertize "busy"    'face 'warning))
    ('ready   (propertize "ready"   'face 'success))
    ('dead    (propertize "dead"    'face 'shadow))
    (_        (propertize "unknown" 'face 'shadow))))

(defun agent-shell-sessions--display (buffer)
  "Show BUFFER in the perspective that owns it.
Plain `switch-to-buffer' would drag BUFFER into the current perspective
instead."
  (if (and (bound-and-true-p persp-mode)
           (fboundp 'persp-switch-to-buffer))
      (persp-switch-to-buffer buffer)
    (pop-to-buffer buffer)))

;;;; Live view

(defun agent-shell-sessions--entries ()
  "Return `tabulated-list-entries' for the current sessions."
  (mapcar
   (lambda (session)
     (list (plist-get session :buffer)
           (vector (agent-shell-sessions--status-label (plist-get session :status))
                   (or (string-join (plist-get session :perspectives) ",") "—")
                   (or (plist-get session :project) "—")
                   (or (plist-get session :prompt) ""))))
   (agent-shell-sessions-list)))

(defun agent-shell-sessions--revert (&rest _)
  "Recompute the session list for the current buffer."
  (setq tabulated-list-entries (agent-shell-sessions--entries)))

(defun agent-shell-sessions-refresh ()
  "Refresh the session list, keeping point on the same session."
  (interactive)
  (when-let* ((buffer (get-buffer agent-shell-sessions-buffer-name)))
    (with-current-buffer buffer
      (let ((session (tabulated-list-get-id))
            (column (current-column)))
        (revert-buffer)
        (when session
          (goto-char (point-min))
          (let ((found nil))
            (while (and (not found) (not (eobp)))
              (if (eq (tabulated-list-get-id) session)
                  (setq found t)
                (forward-line 1)))
            (unless found (goto-char (point-min)))))
        (move-to-column column)))))

(defvar agent-shell-sessions--timer nil
  "Repeating timer refreshing the session view while it is on screen.")

(defun agent-shell-sessions--cancel-timer ()
  "Stop the refresh timer."
  (when (timerp agent-shell-sessions--timer)
    (cancel-timer agent-shell-sessions--timer))
  (setq agent-shell-sessions--timer nil))

(defun agent-shell-sessions--tick ()
  "Refresh the session view if it is visible; stop the timer once it is gone."
  (let ((buffer (get-buffer agent-shell-sessions-buffer-name)))
    (cond
     ((not (buffer-live-p buffer)) (agent-shell-sessions--cancel-timer))
     ((get-buffer-window buffer 'visible) (agent-shell-sessions-refresh)))))

(defun agent-shell-sessions--ensure-timer ()
  "Start the refresh timer unless it is already running."
  (unless (timerp agent-shell-sessions--timer)
    (setq agent-shell-sessions--timer
          (run-with-timer agent-shell-sessions-refresh-interval
                          agent-shell-sessions-refresh-interval
                          #'agent-shell-sessions--tick))))

(defun agent-shell-sessions--session-at-point ()
  "Return the session buffer on the current row, or signal an error."
  (let ((buffer (tabulated-list-get-id)))
    (cond
     ((null buffer) (user-error "Point is not on a session"))
     ((not (buffer-live-p buffer))
      (user-error "That session is gone; press g to refresh"))
     (t buffer))))

(defun agent-shell-sessions-visit ()
  "Switch to the session at point, in the perspective that owns it."
  (interactive)
  (agent-shell-sessions--display (agent-shell-sessions--session-at-point)))

(defun agent-shell-sessions-visit-other-window ()
  "Show the session at point in another window, without leaving this view."
  (interactive)
  (switch-to-buffer-other-window (agent-shell-sessions--session-at-point)))

(defun agent-shell-sessions-kill ()
  "Kill the session at point, after confirmation."
  (interactive)
  (let ((buffer (agent-shell-sessions--session-at-point)))
    (when (yes-or-no-p (format "Kill session %s? " (buffer-name buffer)))
      (kill-buffer buffer)
      (agent-shell-sessions-refresh))))

(defvar-keymap agent-shell-sessions-mode-map
  :doc "Keymap for `agent-shell-sessions-mode'."
  "RET" #'agent-shell-sessions-visit
  "o"   #'agent-shell-sessions-visit-other-window
  "g"   #'agent-shell-sessions-refresh
  "k"   #'agent-shell-sessions-kill)

(define-derived-mode agent-shell-sessions-mode tabulated-list-mode "Agent Sessions"
  "Major mode listing every `agent-shell' session across perspectives."
  (setq tabulated-list-format
        [("Status" 8 t) ("Perspective" 16 t) ("Project" 20 t) ("Last prompt" 0 nil)])
  (setq tabulated-list-padding 1)
  (setq tabulated-list-sort-key nil)
  (add-hook 'tabulated-list-revert-hook #'agent-shell-sessions--revert nil t)
  (add-hook 'kill-buffer-hook #'agent-shell-sessions--cancel-timer nil t)
  (tabulated-list-init-header))

;;;###autoload
(defun agent-shell-sessions ()
  "Show a live list of every `agent-shell' session across perspectives."
  (interactive)
  (let ((buffer (get-buffer-create agent-shell-sessions-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'agent-shell-sessions-mode)
        (agent-shell-sessions-mode))
      (revert-buffer))
    ;; `perspective' associates displayed buffers with the current
    ;; perspective, so the view is reachable from wherever it is opened.
    (agent-shell-sessions--ensure-timer)
    (pop-to-buffer buffer)))

;;;; consult-buffer source

(defvar agent-shell-sessions--consult-cache nil
  "Sessions from the last `consult-buffer' items call, for reuse by annotation.")

(defun agent-shell-sessions--consult-items ()
  "Return session buffer names for `consult-buffer'."
  (setq agent-shell-sessions--consult-cache (agent-shell-sessions-list))
  (mapcar (lambda (session) (plist-get session :name))
          agent-shell-sessions--consult-cache))

(defun agent-shell-sessions--consult-annotate (candidate)
  "Return the annotation for CANDIDATE: status, perspective, last prompt."
  (when-let* ((session (seq-find (lambda (s) (equal (plist-get s :name) candidate))
                                 agent-shell-sessions--consult-cache)))
    (concat " "
            (agent-shell-sessions--status-label (plist-get session :status))
            (when-let* ((perspectives (plist-get session :perspectives)))
              (concat "  " (propertize (string-join perspectives ",")
                                       'face 'font-lock-keyword-face)))
            (when-let* ((prompt (plist-get session :prompt)))
              (concat "  " (propertize (truncate-string-to-width
                                        prompt agent-shell-sessions-prompt-width
                                        nil nil t)
                                       'face 'completions-annotations))))))

(defun agent-shell-sessions--consult-action (candidate)
  "Switch to CANDIDATE in the perspective that owns it."
  (when-let* ((buffer (and candidate (get-buffer candidate))))
    (agent-shell-sessions--display buffer)))

(defun agent-shell-sessions--consult-state ()
  "Pair consult's buffer preview with a perspective-aware jump.
Consult previews with a non-nil NORECORD, which `perspective' reads as a
signal not to associate the buffer, so browsing does not pull sessions in."
  (consult--state-with-return (consult--buffer-preview)
                              #'agent-shell-sessions--consult-action))

(defvar agent-shell-sessions-consult-source
  ;; `marginalia' annotates the `buffer' category and its annotation wins over
  ;; `:annotate', so use a category it has no annotator for.  Candidates are
  ;; still buffer names, so `embark-keymap-alist' can map this to
  ;; `embark-buffer-map'.
  `( :name     "Agent Session"
     :narrow   ?a
     :category agent-shell-session
     :face     consult-buffer
     :history  buffer-name-history
     :annotate ,#'agent-shell-sessions--consult-annotate
     :state    ,#'agent-shell-sessions--consult-state
     :items    ,#'agent-shell-sessions--consult-items)
  "`consult-buffer' source listing `agent-shell' sessions.
Add to `consult-buffer-sources' to make it available under `a'.")

(provide 'agent-shell-sessions)
;;; agent-shell-sessions.el ends here

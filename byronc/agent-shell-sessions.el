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
;; the current one, landing on its viewport when it has one.  `agent-shell' and
;; `perspective' are soft dependencies.
;;
;; Blocked sessions sort longest-waiting first, ready ones most recently
;; active first.  `agent-shell' events drive refreshes and titles; the timer
;; only keeps idle ages current.

;;; Code:

(require 'cl-lib)
(require 'comint)
(require 'ring)
(require 'seq)
(require 'subr-x)
(require 'tabulated-list)

(declare-function agent-shell-buffers "agent-shell")
(declare-function agent-shell-status "agent-shell" (&key shell-buffer))
(declare-function agent-shell-last-activity-time "agent-shell" (&key shell-buffer))
(declare-function agent-shell-subscribe-to "agent-shell" (&key shell-buffer event on-event))
(declare-function agent-shell-cwd "agent-shell-project")
(declare-function agent-shell-viewport--buffer "agent-shell-viewport"
                  (&key shell-buffer existing-only))
(declare-function consult--buffer-preview "consult")
(declare-function consult--state-with-return "consult")
(declare-function persp-buffers "perspective")
(declare-function persp-switch-to-buffer "perspective" (buffer-or-name &optional norecord))
(declare-function perspectives-hash "perspective" (&optional frame))

;; Set by `agent-shell-viewport' when it loads.
(defvar agent-shell-prefer-viewport-interaction)

(defgroup agent-shell-sessions nil
  "Cross-perspective view of `agent-shell' sessions."
  :group 'tools
  :prefix "agent-shell-sessions-")

(defcustom agent-shell-sessions-refresh-interval 15.0
  "Seconds between refreshes of the session list.
Status and title changes refresh the list as they happen, so this only
keeps the idle ages current.  The timer only does work while the list is
on screen."
  :type 'number)

(defcustom agent-shell-sessions-title-width 70
  "Maximum width of the title in `consult-buffer' annotations."
  :type 'integer)

(defcustom agent-shell-sessions-stall-threshold 300
  "Seconds a busy session can go quiet before its idle age is highlighted."
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

(defun agent-shell-sessions--perspective-index ()
  "Return a hash mapping each buffer to the names of perspectives holding it.
Perspectives are frame-local, so this looks across all frames."
  (let ((index (make-hash-table :test #'eq)))
    (when (and (bound-and-true-p persp-mode)
               (fboundp 'perspectives-hash))
      (dolist (frame (frame-list))
        (maphash (lambda (name persp)
                   (dolist (buffer (persp-buffers persp))
                     (cl-pushnew name (gethash buffer index) :test #'equal)))
                 (perspectives-hash frame))))
    index))

(defun agent-shell-sessions--perspectives (buffers &optional index)
  "Return the sorted names of every perspective holding any of BUFFERS.
BUFFERS is a buffer or a list of buffers; nil entries are ignored.  INDEX
defaults to a freshly built `agent-shell-sessions--perspective-index'."
  (let ((index (or index (agent-shell-sessions--perspective-index)))
        names)
    (dolist (buffer (delq nil (ensure-list buffers)))
      (dolist (name (gethash buffer index))
        (cl-pushnew name names :test #'equal)))
    (sort names #'string<)))

(defun agent-shell-sessions--project (buffer)
  "Return a short project label for BUFFER, or nil."
  (when (and (buffer-live-p buffer) (fboundp 'agent-shell-cwd))
    (with-current-buffer buffer
      (when-let* ((cwd (ignore-errors (agent-shell-cwd))))
        (file-name-nondirectory (directory-file-name cwd))))))

(defun agent-shell-sessions--one-line (text)
  "Return TEXT with its whitespace collapsed to single spaces, or nil if blank."
  (when (and (stringp text) (not (string-blank-p text)))
    (string-join (split-string (substring-no-properties text)) " ")))

(defun agent-shell-sessions--last-prompt (buffer)
  "Return the most recent prompt sent in BUFFER as one line, or nil.
`shell-maker' maintains a comint input ring per shell buffer."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and (ring-p comint-input-ring)
                 (not (ring-empty-p comint-input-ring)))
        (agent-shell-sessions--one-line (ring-ref comint-input-ring 0))))))

(defvar-local agent-shell-sessions--title nil
  "The shell's session title, as last reported by `session-title-changed'.
`agent-shell' has no public accessor for the title, only the event.")

(defun agent-shell-sessions--session-title (buffer)
  "Return BUFFER's session title as one line, falling back to its last prompt."
  (when (buffer-live-p buffer)
    (or (agent-shell-sessions--one-line
         (buffer-local-value 'agent-shell-sessions--title buffer))
        (agent-shell-sessions--last-prompt buffer))))

(defun agent-shell-sessions--activity (buffer)
  "Return the time of BUFFER's latest prompt or agent notification, or nil."
  (when (and (buffer-live-p buffer)
             (fboundp 'agent-shell-last-activity-time))
    (ignore-errors (agent-shell-last-activity-time :shell-buffer buffer))))

(defun agent-shell-sessions--rank (status)
  "Return the sort rank of STATUS."
  (or (alist-get status agent-shell-sessions--status-rank) 99))

(defun agent-shell-sessions--before-p (a b)
  "Return non-nil when session A sorts before session B.
Status first, then blocked longest waiting first, ready most recently
active first, no activity last.  Busy sessions keep access order, since
streaming updates their activity constantly.  Ties keep access order."
  (let ((ra (agent-shell-sessions--rank (plist-get a :status)))
        (rb (agent-shell-sessions--rank (plist-get b :status)))
        (ta (plist-get a :activity))
        (tb (plist-get b :activity)))
    (cond
     ((/= ra rb) (< ra rb))
     ((or (not (memq (plist-get a :status) '(blocked ready)))
          (and (null ta) (null tb))
          (and ta tb (time-equal-p ta tb)))
      (< (plist-get a :order) (plist-get b :order)))
     ((null tb) t)
     ((null ta) nil)
     ((eq (plist-get a :status) 'blocked) (time-less-p ta tb))
     (t (time-less-p tb ta)))))

(defun agent-shell-sessions-list ()
  "Return a plist per live `agent-shell' session.

Each plist carries :buffer, :viewport, :name, :status, :activity,
:perspectives, :project and :title.  :buffer and :name stay the shell:
the viewport is killed and recreated as you work, so it is not a stable
identity.  Sorted by `agent-shell-sessions--before-p'."
  (when (fboundp 'agent-shell-buffers)
    (let ((sessions nil)
          (index 0)
          (perspectives (agent-shell-sessions--perspective-index)))
      (dolist (buffer (agent-shell-buffers))
        (when (buffer-live-p buffer)
          (let ((viewport (agent-shell-sessions--viewport buffer)))
            (push (list :buffer buffer
                        :viewport viewport
                        :name (buffer-name buffer)
                        :status (agent-shell-sessions--status buffer)
                        :activity (agent-shell-sessions--activity buffer)
                        :perspectives (agent-shell-sessions--perspectives
                                       (list buffer viewport) perspectives)
                        :project (agent-shell-sessions--project buffer)
                        :title (agent-shell-sessions--session-title buffer)
                        :order index)
                  sessions)))
        (setq index (1+ index)))
      (sort (nreverse sessions) #'agent-shell-sessions--before-p))))

;;;; Interaction surface

(defun agent-shell-sessions--viewport (shell)
  "Return the existing viewport buffer for SHELL, or nil.
A nil SHELL would make `agent-shell-viewport--buffer' prompt for one,
from a one-second timer."
  (when (and (buffer-live-p shell)
             (fboundp 'agent-shell-viewport--buffer))
    (ignore-errors
      (agent-shell-viewport--buffer :shell-buffer shell :existing-only t))))

(defun agent-shell-sessions--on-screen-p (buffer)
  "Return non-nil when BUFFER is displayed on a visible frame."
  (get-buffer-window buffer 'visible))

(defun agent-shell-sessions--interaction-buffer (shell)
  "Return the buffer to land on for the session whose shell is SHELL.
That is the viewport when one exists and either
`agent-shell-prefer-viewport-interaction' is on or it is already on
screen; otherwise SHELL."
  (or (when-let* ((viewport (agent-shell-sessions--viewport shell)))
        (and (or (bound-and-true-p agent-shell-prefer-viewport-interaction)
                 (agent-shell-sessions--on-screen-p viewport))
             viewport))
      shell))

;;;; Shared presentation

(defun agent-shell-sessions--status-label (status)
  "Return a propertized label for STATUS."
  (pcase status
    ('blocked (propertize "blocked" 'face 'error))
    ('busy    (propertize "busy"    'face 'warning))
    ('ready   (propertize "ready"   'face 'success))
    ('dead    (propertize "dead"    'face 'shadow))
    (_        (propertize "unknown" 'face 'shadow))))

(defun agent-shell-sessions--age-label (session)
  "Return how long SESSION has been idle, e.g. \"12s\" or \"4m\".
A busy session idle past `agent-shell-sessions-stall-threshold' is
highlighted, since it has probably stalled."
  (if-let* ((time (plist-get session :activity)))
      (let* ((seconds (max 0 (floor (float-time (time-subtract nil time)))))
             (label (cond ((< seconds 60) (format "%ds" seconds))
                          ((< seconds 3600) (format "%dm" (/ seconds 60)))
                          ((< seconds 86400) (format "%dh" (/ seconds 3600)))
                          (t (format "%dd" (/ seconds 86400))))))
        (if (and (eq (plist-get session :status) 'busy)
                 (>= seconds agent-shell-sessions-stall-threshold))
            (propertize label 'face 'warning)
          label))
    (propertize "—" 'face 'shadow)))

(defun agent-shell-sessions--display (buffer &optional other-window)
  "Show the session whose shell is BUFFER, in the perspective that owns it.
Plain `switch-to-buffer' would drag the session into the current
perspective instead.  With OTHER-WINDOW, show it here without leaving,
which imports it into the current perspective, unlike RET."
  (let ((target (agent-shell-sessions--interaction-buffer buffer)))
    (cond
     (other-window (switch-to-buffer-other-window target))
     ((and (bound-and-true-p persp-mode)
           (fboundp 'persp-switch-to-buffer))
      (persp-switch-to-buffer target))
     (t (pop-to-buffer target)))))

;;;; Live view

(defun agent-shell-sessions--entries ()
  "Return `tabulated-list-entries' for the current sessions."
  (mapcar
   (lambda (session)
     (list (plist-get session :buffer)
           (vector (agent-shell-sessions--status-label (plist-get session :status))
                   (agent-shell-sessions--age-label session)
                   (or (string-join (plist-get session :perspectives) ",") "—")
                   (or (plist-get session :project) "—")
                   (or (plist-get session :title) ""))))
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
  (agent-shell-sessions--display (agent-shell-sessions--session-at-point) t))

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
        [("Status" 8 t) ("Idle" 6 nil) ("Perspective" 16 t) ("Project" 20 t)
         ("Title" 0 nil)])
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

;;;; Event subscription

(defconst agent-shell-sessions--refresh-events
  '(permission-request permission-response turn-complete input-submitted
    session-title-changed clean-up)
  "`agent-shell' events that change what the session list shows.")

(defvar-local agent-shell-sessions--subscribed nil
  "Non-nil once this shell has been subscribed to.")

(defvar agent-shell-sessions--pending-refresh nil
  "One-shot timer for a batched refresh, or nil.")

(defun agent-shell-sessions--run-pending-refresh ()
  "Run the batched refresh."
  (setq agent-shell-sessions--pending-refresh nil)
  (agent-shell-sessions--tick))

(defun agent-shell-sessions--schedule-refresh ()
  "Refresh the view shortly, folding a burst of events into one refresh.
The delay also lets a shell that sent `clean-up' finish dying first."
  (unless (timerp agent-shell-sessions--pending-refresh)
    (setq agent-shell-sessions--pending-refresh
          (run-with-timer 0.1 nil #'agent-shell-sessions--run-pending-refresh))))

(defun agent-shell-sessions--on-event (event)
  "Cache the title and schedule a refresh for EVENT from the current shell.
Every event arrives here, streamed chunks included, so bail out early."
  (let ((kind (alist-get :event event)))
    (when (memq kind agent-shell-sessions--refresh-events)
      (when (eq kind 'session-title-changed)
        (setq agent-shell-sessions--title
              (alist-get :title (alist-get :data event))))
      (agent-shell-sessions--schedule-refresh))))

(defun agent-shell-sessions--subscribe (&optional shell)
  "Subscribe to the events of SHELL, defaulting to the current buffer.
Safe to call more than once per shell.  Subscriptions live in the shell's
state, so they go away with it."
  (let ((shell (or shell (current-buffer))))
    (when (and (fboundp 'agent-shell-subscribe-to)
               (buffer-live-p shell)
               (not (buffer-local-value 'agent-shell-sessions--subscribed shell)))
      (agent-shell-subscribe-to :shell-buffer shell
                                :on-event #'agent-shell-sessions--on-event)
      (with-current-buffer shell
        (setq agent-shell-sessions--subscribed t)))))

;; The hook runs once the shell's state exists.  Shells opened before this
;; file loaded are picked up once `agent-shell' is around.
(add-hook 'agent-shell-mode-hook #'agent-shell-sessions--subscribe)
(with-eval-after-load 'agent-shell
  (mapc #'agent-shell-sessions--subscribe (agent-shell-buffers)))

;;;; consult-buffer source

(defvar agent-shell-sessions--consult-cache nil
  "Sessions from the last `consult-buffer' items call, for reuse by annotation.")

(defun agent-shell-sessions--consult-items ()
  "Return session buffer names for `consult-buffer'."
  (setq agent-shell-sessions--consult-cache (agent-shell-sessions-list))
  (mapcar (lambda (session) (plist-get session :name))
          agent-shell-sessions--consult-cache))

(defun agent-shell-sessions--consult-annotate (candidate)
  "Return the annotation for CANDIDATE: status, idle age, perspective, title."
  (when-let* ((session (seq-find (lambda (s) (equal (plist-get s :name) candidate))
                                 agent-shell-sessions--consult-cache)))
    (concat " "
            (agent-shell-sessions--status-label (plist-get session :status))
            "  " (agent-shell-sessions--age-label session)
            (when-let* ((perspectives (plist-get session :perspectives)))
              (concat "  " (propertize (string-join perspectives ",")
                                       'face 'font-lock-keyword-face)))
            (when-let* ((title (plist-get session :title)))
              (concat "  " (propertize (truncate-string-to-width
                                        title agent-shell-sessions-title-width
                                        nil nil t)
                                       'face 'completions-annotations))))))

(defun agent-shell-sessions--consult-action (candidate)
  "Switch to CANDIDATE in the perspective that owns it."
  (when-let* ((buffer (and candidate (get-buffer candidate))))
    (agent-shell-sessions--display buffer)))

(defun agent-shell-sessions--consult-preview-candidate (candidate)
  "Return what preview should show for session CANDIDATE.
The viewport when that is where RET would land, CANDIDATE itself
otherwise."
  (or (when-let* ((shell (and candidate (get-buffer candidate)))
                  (target (agent-shell-sessions--interaction-buffer shell)))
        (and (not (eq target shell)) target))
      candidate))

(defun agent-shell-sessions--consult-state ()
  "Pair consult's buffer preview with a perspective-aware jump.
Preview resolves the same surface the jump lands on.  Consult previews
with a non-nil NORECORD, which `perspective' reads as a signal not to
associate the buffer, so browsing does not pull sessions in."
  (let ((preview (consult--buffer-preview)))
    (consult--state-with-return
     (lambda (action candidate)
       (funcall preview action
                (if (eq action 'preview)
                    (agent-shell-sessions--consult-preview-candidate candidate)
                  candidate)))
     #'agent-shell-sessions--consult-action)))

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

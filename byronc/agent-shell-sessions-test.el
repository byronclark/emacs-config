;;; agent-shell-sessions-test.el --- Tests for agent-shell-sessions -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT coverage of the data layer.  The view and the consult source are
;; verified by hand.
;;
;; Run with:
;;   emacs -Q --batch -L . -l agent-shell-sessions-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'comint)
(require 'ring)
(require 'agent-shell-sessions)

;; Not loaded in batch, so `let' would bind them lexically rather than dynamically.
(defvar persp-mode)
(defvar agent-shell-prefer-viewport-interaction)

;;;; Helpers

(defmacro agent-shell-sessions-test--with-buffers (names &rest body)
  "Create a temp buffer per symbol in NAMES, bound to that symbol, around BODY."
  (declare (indent 1))
  `(let ,(mapcar (lambda (name)
                   `(,name (generate-new-buffer ,(format " *test-%s*" name))))
                 names)
     (unwind-protect (progn ,@body)
       ,@(mapcar (lambda (name) `(when (buffer-live-p ,name) (kill-buffer ,name)))
                 names))))

(defun agent-shell-sessions-test--set-prompts (buffer &rest prompts)
  "Populate BUFFER's comint input ring with PROMPTS, oldest first."
  (with-current-buffer buffer
    (setq-local comint-input-ring (make-ring (max 1 (length prompts))))
    (dolist (prompt prompts)
      (ring-insert comint-input-ring prompt))))

(defmacro agent-shell-sessions-test--with-sessions (spec &rest body)
  "Run BODY with `agent-shell' stubbed from SPEC.

SPEC is a list of (BUFFER STATUS SECONDS-AGO), in access order.  A nil
SECONDS-AGO means no activity yet."
  (declare (indent 1))
  `(let* ((spec ,spec)
          (now (current-time)))
     (cl-letf (((symbol-function 'agent-shell-buffers)
                (lambda () (mapcar #'car spec)))
               ((symbol-function 'agent-shell-status)
                (lambda (&rest args)
                  (nth 1 (assq (plist-get args :shell-buffer) spec))))
               ((symbol-function 'agent-shell-last-activity-time)
                (lambda (&rest args)
                  (when-let* ((ago (nth 2 (assq (plist-get args :shell-buffer) spec))))
                    (time-subtract now ago))))
               ((symbol-function 'agent-shell-cwd) (lambda () "/tmp/proj/")))
       ,@body)))

(defun agent-shell-sessions-test--order ()
  "Return the buffers of `agent-shell-sessions-list', in order."
  (mapcar (lambda (s) (plist-get s :buffer)) (agent-shell-sessions-list)))

(defun agent-shell-sessions-test--make-persp (name buffers)
  "Return a perspective named NAME holding BUFFERS.
A real struct when `perspective' is loaded: a `cl-letf' stub for the
`persp-buffers' accessor does not reach code running in a live Emacs."
  (if (fboundp 'make-persp-internal)
      (let ((persp (make-persp-internal :name name)))
        (setf (persp-buffers persp) buffers)
        persp)
    (cons name buffers)))

(defmacro agent-shell-sessions-test--with-perspectives (spec &rest body)
  "Run BODY with `perspectives-hash' stubbed from SPEC.

SPEC is an alist of (PERSPECTIVE-NAME . BUFFERS)."
  (declare (indent 1))
  `(let ((persp-mode t)
         (table (make-hash-table :test #'equal)))
     (dolist (entry ,spec)
       (puthash (car entry)
                (agent-shell-sessions-test--make-persp (car entry) (cdr entry))
                table))
     (cl-letf (((symbol-function 'perspectives-hash) (lambda (&optional _frame) table))
               ((symbol-function 'persp-buffers)
                (if (fboundp 'make-persp-internal)
                    (symbol-function 'persp-buffers)
                  (lambda (persp) (cdr persp)))))
       ,@body)))

(defmacro agent-shell-sessions-test--with-viewport (spec &rest body)
  "Run BODY with `agent-shell-viewport--buffer' stubbed from SPEC.

SPEC is an alist of (SHELL-BUFFER . VIEWPORT-BUFFER)."
  (declare (indent 1))
  `(let ((pairs ,spec))
     (cl-letf (((symbol-function 'agent-shell-viewport--buffer)
                (lambda (&rest args)
                  (alist-get (plist-get args :shell-buffer) pairs))))
       ,@body)))

;;;; Last prompt

(ert-deftest agent-shell-sessions-test-last-prompt-returns-most-recent ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "first prompt" "second prompt")
    (should (equal (agent-shell-sessions--last-prompt shell) "second prompt"))))

(ert-deftest agent-shell-sessions-test-last-prompt-collapses-to-one-line ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "fix the\n  broken\ttest")
    (should (equal (agent-shell-sessions--last-prompt shell) "fix the broken test"))))

(ert-deftest agent-shell-sessions-test-last-prompt-nil-when-ring-empty ()
  (agent-shell-sessions-test--with-buffers (shell)
    (with-current-buffer shell
      (setq-local comint-input-ring (make-ring 10)))
    (should-not (agent-shell-sessions--last-prompt shell))))

(ert-deftest agent-shell-sessions-test-last-prompt-nil-when-blank ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "   \n  ")
    (should-not (agent-shell-sessions--last-prompt shell))))

(ert-deftest agent-shell-sessions-test-last-prompt-nil-for-dead-buffer ()
  (let ((shell (generate-new-buffer " *test-dead*")))
    (kill-buffer shell)
    (should-not (agent-shell-sessions--last-prompt shell))))

;;;; Status

(ert-deftest agent-shell-sessions-test-status-passes-through-agent-shell ()
  (agent-shell-sessions-test--with-buffers (shell)
    (cl-letf (((symbol-function 'agent-shell-status)
               (lambda (&rest _) 'blocked)))
      (should (eq (agent-shell-sessions--status shell) 'blocked)))))

(ert-deftest agent-shell-sessions-test-status-dead-for-killed-buffer ()
  (let ((shell (generate-new-buffer " *test-dead*")))
    (kill-buffer shell)
    (should (eq (agent-shell-sessions--status shell) 'dead))))

(ert-deftest agent-shell-sessions-test-status-unknown-when-agent-shell-errors ()
  (agent-shell-sessions-test--with-buffers (shell)
    (cl-letf (((symbol-function 'agent-shell-status)
               (lambda (&rest _) (error "No session"))))
      (should (eq (agent-shell-sessions--status shell) 'unknown)))))

;;;; Perspectives

(ert-deftest agent-shell-sessions-test-perspectives-finds-owning-perspective ()
  (agent-shell-sessions-test--with-buffers (shell other)
    (agent-shell-sessions-test--with-perspectives
        (list (cons "work" (list shell)) (cons "plan" (list other)))
      (should (equal (agent-shell-sessions--perspectives shell) '("work"))))))

(ert-deftest agent-shell-sessions-test-perspectives-reports-every-owner ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--with-perspectives
        (list (cons "work" (list shell)) (cons "plan" (list shell)))
      (should (equal (agent-shell-sessions--perspectives shell) '("plan" "work"))))))

(ert-deftest agent-shell-sessions-test-perspectives-empty-when-unowned ()
  (agent-shell-sessions-test--with-buffers (shell other)
    (agent-shell-sessions-test--with-perspectives (list (cons "work" (list other)))
      (should-not (agent-shell-sessions--perspectives shell)))))

(ert-deftest agent-shell-sessions-test-perspectives-nil-without-persp-mode ()
  (agent-shell-sessions-test--with-buffers (shell)
    (let ((persp-mode nil))
      (should-not (agent-shell-sessions--perspectives shell)))))

(ert-deftest agent-shell-sessions-test-perspectives-unions-shell-and-viewport ()
  (agent-shell-sessions-test--with-buffers (shell viewport)
    (agent-shell-sessions-test--with-perspectives
        (list (cons "work" (list viewport)) (cons "plan" (list shell)))
      (should (equal (agent-shell-sessions--perspectives (list shell viewport))
                     '("plan" "work"))))))

(ert-deftest agent-shell-sessions-test-perspectives-de-dups-and-ignores-nil ()
  (agent-shell-sessions-test--with-buffers (shell viewport)
    (agent-shell-sessions-test--with-perspectives
        (list (cons "work" (list shell viewport)))
      (should (equal (agent-shell-sessions--perspectives (list shell nil viewport))
                     '("work"))))))

;;;; Interaction surface

(ert-deftest agent-shell-sessions-test-interaction-prefers-viewport ()
  (agent-shell-sessions-test--with-buffers (shell viewport)
    (agent-shell-sessions-test--with-viewport (list (cons shell viewport))
      (let ((agent-shell-prefer-viewport-interaction t))
        (should (eq (agent-shell-sessions--interaction-buffer shell) viewport))))))

(ert-deftest agent-shell-sessions-test-interaction-shell-without-viewport ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--with-viewport nil
      (let ((agent-shell-prefer-viewport-interaction t))
        (should (eq (agent-shell-sessions--interaction-buffer shell) shell))))))

(ert-deftest agent-shell-sessions-test-interaction-shell-when-preference-off ()
  (agent-shell-sessions-test--with-buffers (shell viewport)
    (agent-shell-sessions-test--with-viewport (list (cons shell viewport))
      (cl-letf (((symbol-function 'agent-shell-sessions--on-screen-p)
                 (lambda (_buffer) nil)))
        (let ((agent-shell-prefer-viewport-interaction nil))
          (should (eq (agent-shell-sessions--interaction-buffer shell) shell)))))))

(ert-deftest agent-shell-sessions-test-interaction-viewport-when-on-screen ()
  (agent-shell-sessions-test--with-buffers (shell viewport)
    (agent-shell-sessions-test--with-viewport (list (cons shell viewport))
      (cl-letf (((symbol-function 'agent-shell-sessions--on-screen-p)
                 (lambda (buffer) (eq buffer viewport))))
        (let ((agent-shell-prefer-viewport-interaction nil))
          (should (eq (agent-shell-sessions--interaction-buffer shell) viewport)))))))

(ert-deftest agent-shell-sessions-test-interaction-never-asks-about-dead-shell ()
  ;; `agent-shell-viewport--buffer' signals on a dead shell, so the guard has
  ;; to come before the call.
  (let ((shell (generate-new-buffer " *test-dead*"))
        (asked nil))
    (kill-buffer shell)
    (cl-letf (((symbol-function 'agent-shell-viewport--buffer)
               (lambda (&rest _) (setq asked t) nil)))
      (let ((agent-shell-prefer-viewport-interaction t))
        (should (eq (agent-shell-sessions--interaction-buffer shell) shell))
        (should-not asked)))))

(ert-deftest agent-shell-sessions-test-interaction-shell-without-viewport-support ()
  (agent-shell-sessions-test--with-buffers (shell)
    (cl-letf (((symbol-function 'agent-shell-viewport--buffer) nil))
      (fmakunbound 'agent-shell-viewport--buffer)
      (let ((agent-shell-prefer-viewport-interaction t))
        (should (eq (agent-shell-sessions--interaction-buffer shell) shell))))))

;;;; Session list

(ert-deftest agent-shell-sessions-test-list-empty-without-agent-shell ()
  (cl-letf (((symbol-function 'agent-shell-buffers) nil))
    (fmakunbound 'agent-shell-buffers)
    (should-not (agent-shell-sessions-list))))

(ert-deftest agent-shell-sessions-test-list-sorts-blocked-before-ready-before-busy ()
  (agent-shell-sessions-test--with-buffers (busy ready blocked)
    (let ((statuses (list (cons busy 'busy)
                          (cons ready 'ready)
                          (cons blocked 'blocked))))
      (cl-letf (((symbol-function 'agent-shell-buffers)
                 (lambda () (list busy ready blocked)))
                ((symbol-function 'agent-shell-status)
                 (lambda (&rest args)
                   (alist-get (plist-get args :shell-buffer) statuses)))
                ((symbol-function 'agent-shell-cwd) (lambda () "/tmp/proj/")))
        (should (equal (mapcar (lambda (s) (plist-get s :status))
                               (agent-shell-sessions-list))
                       '(blocked ready busy)))))))

(ert-deftest agent-shell-sessions-test-list-keeps-recency-within-a-status ()
  (agent-shell-sessions-test--with-buffers (recent older)
    (cl-letf (((symbol-function 'agent-shell-buffers)
               ;; `agent-shell-buffers' is ordered most-recently-accessed first.
               (lambda () (list recent older)))
              ((symbol-function 'agent-shell-status) (lambda (&rest _) 'ready))
              ((symbol-function 'agent-shell-cwd) (lambda () "/tmp/proj/")))
      (should (equal (mapcar (lambda (s) (plist-get s :buffer))
                             (agent-shell-sessions-list))
                     (list recent older))))))

(ert-deftest agent-shell-sessions-test-list-skips-killed-buffers ()
  (agent-shell-sessions-test--with-buffers (live)
    (let ((dead (generate-new-buffer " *test-dead*")))
      (kill-buffer dead)
      (cl-letf (((symbol-function 'agent-shell-buffers) (lambda () (list live dead)))
                ((symbol-function 'agent-shell-status) (lambda (&rest _) 'ready))
                ((symbol-function 'agent-shell-cwd) (lambda () "/tmp/proj/")))
        (should (equal (mapcar (lambda (s) (plist-get s :buffer))
                               (agent-shell-sessions-list))
                       (list live)))))))

(ert-deftest agent-shell-sessions-test-list-carries-project-and-title ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "make the tests pass")
    (cl-letf (((symbol-function 'agent-shell-buffers) (lambda () (list shell)))
              ((symbol-function 'agent-shell-status) (lambda (&rest _) 'ready))
              ((symbol-function 'agent-shell-cwd) (lambda () "/Users/byron/src/videra/")))
      (let ((session (car (agent-shell-sessions-list))))
        (should (equal (plist-get session :project) "videra"))
        (should (equal (plist-get session :title) "make the tests pass"))))))

(ert-deftest agent-shell-sessions-test-list-blocked-longest-waiting-first ()
  (agent-shell-sessions-test--with-buffers (recent older)
    (agent-shell-sessions-test--with-sessions
        (list (list recent 'blocked 10) (list older 'blocked 600))
      (should (equal (agent-shell-sessions-test--order) (list older recent))))))

(ert-deftest agent-shell-sessions-test-list-ready-most-recent-first ()
  (agent-shell-sessions-test--with-buffers (visited finished)
    (agent-shell-sessions-test--with-sessions
        (list (list visited 'ready 600) (list finished 'ready 10))
      (should (equal (agent-shell-sessions-test--order) (list finished visited))))))

(ert-deftest agent-shell-sessions-test-list-inactive-sessions-go-last ()
  (agent-shell-sessions-test--with-buffers (fresh used)
    (agent-shell-sessions-test--with-sessions
        (list (list fresh 'ready nil) (list used 'ready 600))
      (should (equal (agent-shell-sessions-test--order) (list used fresh))))))

(ert-deftest agent-shell-sessions-test-list-busy-keeps-access-order ()
  (agent-shell-sessions-test--with-buffers (visited streaming)
    (agent-shell-sessions-test--with-sessions
        (list (list visited 'busy 30) (list streaming 'busy 1))
      (should (equal (agent-shell-sessions-test--order) (list visited streaming))))))

(ert-deftest agent-shell-sessions-test-list-status-outranks-activity ()
  (agent-shell-sessions-test--with-buffers (ready blocked)
    (agent-shell-sessions-test--with-sessions
        (list (list ready 'ready 1) (list blocked 'blocked 600))
      (should (equal (agent-shell-sessions-test--order) (list blocked ready))))))

(ert-deftest agent-shell-sessions-test-list-carries-viewport-but-keys-on-shell ()
  (agent-shell-sessions-test--with-buffers (shell viewport)
    (agent-shell-sessions-test--with-viewport (list (cons shell viewport))
      (cl-letf (((symbol-function 'agent-shell-buffers) (lambda () (list shell)))
                ((symbol-function 'agent-shell-status) (lambda (&rest _) 'ready))
                ((symbol-function 'agent-shell-cwd) (lambda () "/tmp/proj/")))
        (let ((session (car (agent-shell-sessions-list))))
          (should (eq (plist-get session :buffer) shell))
          (should (eq (plist-get session :viewport) viewport))
          (should (equal (plist-get session :name) (buffer-name shell))))))))

;;;; Title

(ert-deftest agent-shell-sessions-test-title-prefers-reported-title ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "yes")
    (with-current-buffer shell
      (setq agent-shell-sessions--title "Fix the\n  flaky test"))
    (should (equal (agent-shell-sessions--session-title shell) "Fix the flaky test"))))

(ert-deftest agent-shell-sessions-test-title-falls-back-to-last-prompt ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "make the tests pass")
    (should (equal (agent-shell-sessions--session-title shell) "make the tests pass"))))

;;;; Idle age

(defun agent-shell-sessions-test--age (status seconds-ago)
  "Return the age label for a STATUS session active SECONDS-AGO."
  (agent-shell-sessions--age-label
   (list :status status
         :activity (and seconds-ago (time-subtract nil seconds-ago)))))

(ert-deftest agent-shell-sessions-test-age-formats-units ()
  (should (equal (agent-shell-sessions-test--age 'ready 12) "12s"))
  (should (equal (agent-shell-sessions-test--age 'ready 240) "4m"))
  (should (equal (agent-shell-sessions-test--age 'ready 7300) "2h"))
  (should (equal (agent-shell-sessions-test--age 'ready 200000) "2d")))

(ert-deftest agent-shell-sessions-test-age-dash-without-activity ()
  (should (equal (agent-shell-sessions-test--age 'ready nil) "—")))

(ert-deftest agent-shell-sessions-test-age-flags-stalled-busy-session ()
  (let ((agent-shell-sessions-stall-threshold 300))
    (should (eq (get-text-property 0 'face (agent-shell-sessions-test--age 'busy 400))
                'warning))
    (should-not (get-text-property 0 'face (agent-shell-sessions-test--age 'busy 100)))
    (should-not (get-text-property 0 'face (agent-shell-sessions-test--age 'ready 400)))))

;;;; Events

(defmacro agent-shell-sessions-test--capturing-refreshes (&rest body)
  "Run BODY counting scheduled refreshes in `refreshes'."
  (declare (indent 0))
  `(let ((refreshes 0))
     (cl-letf (((symbol-function 'agent-shell-sessions--schedule-refresh)
                (lambda () (cl-incf refreshes))))
       ,@body)))

(ert-deftest agent-shell-sessions-test-event-caches-title ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--capturing-refreshes
      (with-current-buffer shell
        (agent-shell-sessions--on-event
         (list (cons :data (list (cons :title "Refactor the loader")))
               (cons :event 'session-title-changed))))
      (should (equal (agent-shell-sessions--session-title shell) "Refactor the loader"))
      (should (= refreshes 1)))))

(ert-deftest agent-shell-sessions-test-event-refreshes-on-status-change ()
  (agent-shell-sessions-test--capturing-refreshes
    (dolist (kind '(permission-request permission-response turn-complete
                    input-submitted clean-up))
      (agent-shell-sessions--on-event (list (cons :event kind))))
    (should (= refreshes 5))))

(ert-deftest agent-shell-sessions-test-event-ignores-streaming ()
  (agent-shell-sessions-test--capturing-refreshes
    (agent-shell-sessions--on-event (list (cons :event 'agent-message-chunk)))
    (agent-shell-sessions--on-event (list (cons :event 'tool-call-update)))
    (should (= refreshes 0))))

(ert-deftest agent-shell-sessions-test-subscribe-once-per-shell ()
  (agent-shell-sessions-test--with-buffers (shell)
    (let ((calls nil))
      (cl-letf (((symbol-function 'agent-shell-subscribe-to)
                 (lambda (&rest args) (push (plist-get args :shell-buffer) calls) 1)))
        (agent-shell-sessions--subscribe shell)
        (with-current-buffer shell (agent-shell-sessions--subscribe))
        (should (equal calls (list shell)))))))

;;;; Project label

(ert-deftest agent-shell-sessions-test-project-strips-trailing-slash ()
  (agent-shell-sessions-test--with-buffers (shell)
    (cl-letf (((symbol-function 'agent-shell-cwd) (lambda () "/a/b/myproject/")))
      (should (equal (agent-shell-sessions--project shell) "myproject")))))

(ert-deftest agent-shell-sessions-test-project-nil-when-cwd-errors ()
  (agent-shell-sessions-test--with-buffers (shell)
    (cl-letf (((symbol-function 'agent-shell-cwd) (lambda () (error "No CWD"))))
      (should-not (agent-shell-sessions--project shell)))))

(provide 'agent-shell-sessions-test)
;;; agent-shell-sessions-test.el ends here

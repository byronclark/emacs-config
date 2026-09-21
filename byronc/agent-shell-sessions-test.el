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

(ert-deftest agent-shell-sessions-test-list-carries-project-and-prompt ()
  (agent-shell-sessions-test--with-buffers (shell)
    (agent-shell-sessions-test--set-prompts shell "make the tests pass")
    (cl-letf (((symbol-function 'agent-shell-buffers) (lambda () (list shell)))
              ((symbol-function 'agent-shell-status) (lambda (&rest _) 'ready))
              ((symbol-function 'agent-shell-cwd) (lambda () "/Users/byron/src/videra/")))
      (let ((session (car (agent-shell-sessions-list))))
        (should (equal (plist-get session :project) "videra"))
        (should (equal (plist-get session :prompt) "make the tests pass"))))))

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

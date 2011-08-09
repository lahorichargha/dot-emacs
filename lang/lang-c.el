;;;_ * cc-mode

(autoload 'c-mode "cc-mode" nil t)
(autoload 'c++-mode "cc-mode" nil t)
(autoload 'gtags-mode "gtags" "" t)
(autoload 'company-mode "company" "" t)

(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.m\\'" . c-mode))
(add-to-list 'auto-mode-alist '("\\.mm\\'" . c++-mode))

(defun gtags-update-hook ()
  (call-process "global" nil nil nil "-u" "-q"))

(defun my-c-indent-or-complete ()
  (interactive)
  (let ((class (syntax-class (syntax-after (1- (point))))))
   (if (or (bolp) (and (/= 2 class)
                       (/= 3 class)))
       (call-interactively 'indent-according-to-mode)
     (call-interactively 'company-complete-common))))

(defun my-c-mode-common-hook ()
  (doxymacs-mode 1)
  (gtags-mode 1)
  (company-mode 1)
  (which-function-mode 1)
  (define-key c-mode-base-map [(meta ?.)] 'my-gtags-find-tag)
  (define-key c-mode-base-map [return] 'newline-and-indent)
  (make-variable-buffer-local 'yas/fallback-behavior)
  (setq yas/fallback-behavior '(apply my-c-indent-or-complete . nil))
  (define-key c-mode-base-map [tab] 'yas/expand-from-trigger-key)
  (define-key c-mode-base-map [(alt tab)] 'company-complete-common)
  (define-key c-mode-base-map [(meta ?j)] 'delete-indentation-forward)
  (define-key c-mode-base-map [(control ?c) (control ?i)]
    'c-includes-current-file)
  (set (make-local-variable 'parens-require-spaces) nil)
  (setq indicate-empty-lines t)
  (setq fill-column 72)
  (column-marker-3 80)

  (add-hook 'after-save-hook 'gtags-update-hook t t)

  (let ((bufname (buffer-file-name)))
    (when bufname
      (cond
       ((string-match "/ledger/" bufname)
        (c-set-style "ledger"))
       ((string-match "/ANSI/" bufname)
        (c-set-style "edg")
        (substitute-key-definition 'fill-paragraph 'ti-refill-comment
                                   c-mode-base-map global-map)
        (define-key c-mode-base-map [(meta ?q)] 'ti-refill-comment)))))

  (font-lock-add-keywords
   'c++-mode '(("\\<\\(assert\\|DEBUG\\)(" 1 font-lock-warning-face t))))

(defun ti-refill-comment ()
  (interactive)
  (let ((here (point)))
    (goto-char (line-beginning-position))
    (let ((begin (point)) end
          (marker ?-) (marker-re "\\(-----\\|\\*\\*\\*\\*\\*\\)")
          (leader-width 0))
      (unless (looking-at "[ \t]*/\\*[-* ]")
        (search-backward "/*")
        (goto-char (line-beginning-position)))
      (unless (looking-at "[ \t]*/\\*[-* ]")
        (error "Not in a comment"))
      (while (and (looking-at "\\([ \t]*\\)/\\* ")
                  (setq leader-width (length (match-string 1)))
                  (not (looking-at (concat "[ \t]*/\\*" marker-re))))
        (forward-line -1)
        (setq begin (point)))
      (when (looking-at (concat "[^\n]+?" marker-re "\\*/[ \t]*$"))
        (setq marker (if (string= (match-string 1) "-----") ?- ?*))
        (forward-line))
      (while (and (looking-at "[^\n]+?\\*/[ \t]*$")
                  (not (looking-at (concat "[^\n]+?" marker-re
                                           "\\*/[ \t]*$"))))
        (forward-line))
      (when (looking-at (concat "[^\n]+?" marker-re "\\*/[ \t]*$"))
        (forward-line))
      (setq end (point))
      (let ((comment (buffer-substring-no-properties begin end)))
        (with-temp-buffer
          (insert comment)
          (goto-char (point-min))
          (flush-lines (concat "^[ \t]*/\\*" marker-re "[-*]+\\*/[ \t]*$"))
          (goto-char (point-min))
          (while (re-search-forward "^[ \t]*/\\* ?" nil t)
            (goto-char (match-beginning 0))
            (delete-region (match-beginning 0) (match-end 0)))
          (goto-char (point-min))
          (while (re-search-forward "[ \t]*\\*/[ \t]*$" nil t)
            (goto-char (match-beginning 0))
            (delete-region (match-beginning 0) (match-end 0)))
          (goto-char (point-min)) (delete-trailing-whitespace)
          (goto-char (point-min)) (flush-lines "^$")
          (set-fill-column (- 80   ; width of the text
                              6    ; width of "/*  */"
                              leader-width))
          (goto-char (point-min)) (fill-paragraph)
          (goto-char (point-min))
          (while (not (eobp))
            (insert (make-string leader-width ? ) "/* ")
            (goto-char (line-end-position))
            (insert (make-string (- 80 3 (current-column)) ? ) " */")
            (forward-line))
          (goto-char (point-min))
          (insert (make-string leader-width ? )
                  "/*" (make-string (- 80 4 leader-width) marker) "*/\n")
          (goto-char (point-max))
          (insert (make-string leader-width ? )
                  "/*" (make-string (- 80 4 leader-width) marker) "*/\n")
          (setq comment (buffer-string)))
        (goto-char begin)
        (delete-region begin end)
        (insert comment)))
    (goto-char here)))

(defun keep-mine ()
  (interactive)
  (beginning-of-line)
  (assert (or (looking-at "<<<<<<")
              (re-search-backward "^<<<<<<" nil t)
              (re-search-forward "^<<<<<<" nil t)))
  (goto-char (match-beginning 0))
  (let ((beg (point)))
    (forward-line)
    (delete-region beg (point))
    ;; (re-search-forward "^=======")
    (re-search-forward "^>>>>>>>")
    (setq beg (match-beginning 0))
    ;; (re-search-forward "^>>>>>>>")
    (re-search-forward "^=======")
    (forward-line)
    (delete-region beg (point))))

(defun keep-theirs ()
  (interactive)
  (beginning-of-line)
  (assert (or (looking-at "<<<<<<")
              (re-search-backward "^<<<<<<" nil t)
              (re-search-forward "^<<<<<<" nil t)))
  (goto-char (match-beginning 0))
  (let ((beg (point)))
    ;; (re-search-forward "^=======")
    (re-search-forward "^>>>>>>>")
    (forward-line)
    (delete-region beg (point))
    ;; (re-search-forward "^>>>>>>>")
    (re-search-forward "^#######")
    (beginning-of-line)
    (setq beg (point))
    (re-search-forward "^=======")
    (beginning-of-line)
    (forward-line)
    (delete-region beg (point))))

(defun keep-both ()
  (interactive)
  (beginning-of-line)
  (assert (or (looking-at "<<<<<<")
              (re-search-backward "^<<<<<<" nil t)
              (re-search-forward "^<<<<<<" nil t)))
  (beginning-of-line)
  (let ((beg (point)))
    (forward-line)
    (delete-region beg (point))
    (re-search-forward "^>>>>>>>")
    (beginning-of-line)
    (setq beg (point))
    (forward-line)
    (delete-region beg (point))
    (re-search-forward "^#######")
    (beginning-of-line)
    (setq beg (point))
    (re-search-forward "^=======")
    (beginning-of-line)
    (forward-line)
    (delete-region beg (point))))

(eval-after-load "cc-mode"
  '(progn
     (setq c-syntactic-indentation nil)

     (define-key c-mode-base-map "#" 'self-insert-command)
     (define-key c-mode-base-map "{" 'self-insert-command)
     (define-key c-mode-base-map "}" 'self-insert-command)
     (define-key c-mode-base-map "/" 'self-insert-command)
     (define-key c-mode-base-map "*" 'self-insert-command)
     (define-key c-mode-base-map ";" 'self-insert-command)
     (define-key c-mode-base-map "," 'self-insert-command)
     (define-key c-mode-base-map ":" 'self-insert-command)
     (define-key c-mode-base-map "(" 'self-insert-command)
     (define-key c-mode-base-map ")" 'self-insert-command)
     (define-key c++-mode-map "<"    'self-insert-command)
     (define-key c++-mode-map ">"    'self-insert-command)

     (define-key c-mode-base-map [(meta ?p)] 'keep-mine)
     (define-key c-mode-base-map [(meta ?n)] 'keep-theirs)
     (define-key c-mode-base-map [(alt ?b)] 'keep-both)

     (add-hook 'c-mode-common-hook 'my-c-mode-common-hook)))

(eval-after-load "cc-styles"
  '(progn
     (add-to-list
      'c-style-alist
      '("ceg"
        (c-basic-offset . 3)
        (c-comment-only-line-offset . (0 . 0))
        (c-hanging-braces-alist
         . ((substatement-open before after)
            (arglist-cont-nonempty)))
        (c-offsets-alist
         . ((statement-block-intro . +)
            (knr-argdecl-intro . 5)
            (substatement-open . 0)
            (substatement-label . 0)
            (label . 0)
            (statement-case-open . 0)
            (statement-cont . +)
            (arglist-intro . c-lineup-arglist-intro-after-paren)
            (arglist-close . c-lineup-arglist)
            (inline-open . 0)
            (brace-list-open . 0)
            (topmost-intro-cont
             . (first c-lineup-topmost-intro-cont
                      c-lineup-gnu-DEFUN-intro-cont))))
        (c-special-indent-hook . c-gnu-impose-minimum)
        (c-block-comment-prefix . "")))
     (add-to-list
      'c-style-alist
      '("edg"
        (indent-tabs-mode . nil)
        (c-basic-offset . 3)
        (c-comment-only-line-offset . (0 . 0))
        (c-hanging-braces-alist
         . ((substatement-open before after)
            (arglist-cont-nonempty)))
        (c-offsets-alist
         . ((statement-block-intro . +)
            (knr-argdecl-intro . 5)
            (substatement-open . 0)
            (substatement-label . 0)
            (label . 0)
            (case-label . +)
            (statement-case-open . 0)
            (statement-cont . +)
            (arglist-intro . c-lineup-arglist-intro-after-paren)
            (arglist-close . c-lineup-arglist)
            (inline-open . 0)
            (brace-list-open . 0)
            (topmost-intro-cont
             . (first c-lineup-topmost-intro-cont
                      c-lineup-gnu-DEFUN-intro-cont))))
        (c-special-indent-hook . c-gnu-impose-minimum)
        (c-block-comment-prefix . "")))
     (add-to-list
      'c-style-alist
      '("ledger"
        (indent-tabs-mode . nil)
        (c-basic-offset . 2)
        (c-comment-only-line-offset . (0 . 0))
        (c-hanging-braces-alist
         . ((substatement-open before after)
            (arglist-cont-nonempty)))
        (c-offsets-alist
         . ((statement-block-intro . +)
            (knr-argdecl-intro . 5)
            (substatement-open . 0)
            (substatement-label . 0)
            (label . 0)
            (case-label . 0)
            (statement-case-open . 0)
            (statement-cont . +)
            (arglist-intro . c-lineup-arglist-intro-after-paren)
            (arglist-close . c-lineup-arglist)
            (inline-open . 0)
            (brace-list-open . 0)
            (topmost-intro-cont
             . (first c-lineup-topmost-intro-cont
                      c-lineup-gnu-DEFUN-intro-cont))))
        (c-special-indent-hook . c-gnu-impose-minimum)
        (c-block-comment-prefix . "")))))

;;_ * cmake-mode

(autoload 'cmake-mode "cmake-mode" nil t)

(setq auto-mode-alist
      (append '(("CMakeLists\\.txt\\'" . cmake-mode)
                ("\\.cmake\\'" . cmake-mode))
              auto-mode-alist))

;;_ * doxymacs

(autoload 'doxymacs-mode "doxymacs" nil t)
(autoload 'doxymacs-font-lock "doxymacs")

(defun my-doxymacs-font-lock-hook ()
  (if (or (eq major-mode 'c-mode) (eq major-mode 'c++-mode))
      (doxymacs-font-lock)))

(add-hook 'font-lock-mode-hook 'my-doxymacs-font-lock-hook)

;;;_ * ulp

(defun ulp ()
  (interactive)
  (find-file "~/src/ansi/ulp.c")
  (find-file-noselect "~/Contracts/TI/test/ulp_suite/invoke.sh")
  (find-file-noselect "~/Contracts/TI/test/ulp_suite")
  ;;(visit-tags-table "~/src/ansi/TAGS")
  (magit-status "~/src/ansi")
  (gdb "gdb --annotate=3 ~/Contracts/TI/bin/acpia470"))

;;; lang-c.el ends here

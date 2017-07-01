;;; suggest.el --- suggest elisp functions that give the output requested  -*- lexical-binding: t; -*-

;; Copyright (C) 2016

;; Author: Wilfred Hughes <me@wilfred.me.uk>
;; Version: 0.3
;; Keywords: convenience
;; Package-Requires: ((emacs "24.4") (loop "1.3") (dash "2.13.0") (s "1.11.0") (f "0.18.2"))
;; URL: https://github.com/Wilfred/suggest.el

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Suggest.el will find functions that give the output requested. It's
;; a great way of exploring list, string and arithmetic functions.

;;; Code:

(require 'dash)
(require 'loop)
(require 's)
(require 'f)
(require 'subr-x)
(eval-when-compile
  (require 'cl-lib)) ;; cl-incf

;; TODO: add #'read, but don't prompt for input when the example is nil.
;;
;; See also `cl--simple-funcs' and `cl--safe-funcs'.
(defvar suggest-functions
  (list
   ;; TODO: add funcall, apply and map?
   ;; Built-in functions that access or examine lists.
   #'car
   #'cdr
   #'cadr
   #'cdar
   #'last
   #'cons
   #'nth
   #'list
   #'length
   #'safe-length
   #'reverse
   #'remove
   #'remq
   #'append
   #'butlast
   ;; Built-in functions that create lists.
   #'make-list
   #'number-sequence
   ;; Sequence functions
   #'elt
   #'aref
   ;; CL list functions.
   #'cl-first
   #'cl-second
   #'cl-third
   ;; dash.el list functions.
   #'-non-nil
   #'-slice
   #'-take
   #'-take-last
   #'-drop
   #'-drop-last
   #'-select-by-indices
   #'-select-column
   #'-concat
   #'-flatten
   #'-replace
   #'-replace-first
   #'-insert-at
   #'-replace-at
   #'-remove-at
   #'-remove-at-indices
   #'-sum
   #'-product
   #'-min
   #'-max
   #'-is-prefix-p
   #'-is-suffix-p
   #'-is-infix-p
   #'-split-at
   #'-split-on
   #'-partition
   #'-partition-all
   #'-elem-index
   #'-elem-indices
   #'-union
   #'-difference
   #'-intersection
   #'-distinct
   #'-rotate
   #'-repeat
   #'-cons*
   #'-snoc
   #'-interpose
   #'-interleave
   #'-zip
   #'-first-item
   #'-last-item
   #'-butlast
   ;; alist functions
   #'assoc
   #'alist-get
   ;; plist functions
   #'plist-get
   #'lax-plist-get
   #'plist-member
   ;; hash tables
   #'gethash
   #'hash-table-keys
   #'hash-table-values
   ;; vectors
   ;; TODO: there must be more worth using
   #'vconcat
   ;; Arithmetic
   #'+
   #'-
   #'*
   #'/
   #'%
   #'mod
   #'max
   #'min
   #'ash
   #'lsh
   #'log
   #'expt
   #'sqrt
   #'abs
   #'float
   #'round
   #'truncate
   #'ceiling
   #'fceiling
   #'ffloor
   #'fround
   #'ftruncate
   #'1+
   #'1-
   ;; Strings
   #'string
   #'make-string
   #'upcase
   #'downcase
   #'substring
   #'concat
   #'split-string
   #'capitalize
   #'replace-regexp-in-string
   ;; Quoting strings
   #'shell-quote-argument
   #'regexp-quote
   ;; s.el string functions
   #'s-trim
   #'s-trim-left
   #'s-trim-right
   #'s-pad-left
   #'s-pad-right
   #'s-chomp
   #'s-collapse-whitespace
   #'s-word-wrap
   #'s-left
   #'s-right
   #'s-chop-suffix
   #'s-chop-suffixes
   #'s-chop-prefix
   #'s-chop-prefixes
   #'s-shared-start
   #'s-shared-end
   #'s-repeat
   #'s-concat
   #'s-prepend
   #'s-append
   #'s-lines
   #'s-split
   #'s-join
   #'s-ends-with-p
   #'s-starts-with-p
   #'s-contains-p
   #'s-replace
   #'s-capitalize
   #'s-index-of
   #'s-reverse
   #'s-count-matches
   #'s-split-words
   ;; Symbols
   #'symbol-name
   #'symbol-value
   #'symbol-file
   #'intern
   ;; Converting between types
   #'string-to-list
   #'string-to-number
   #'string-to-char
   #'number-to-string
   #'char-to-string
   ;; Paths
   #'file-name-as-directory
   #'file-name-base
   #'file-name-directory
   #'file-name-nondirectory
   #'file-name-extension
   #'expand-file-name
   #'abbreviate-file-name
   #'directory-file-name
   ;; Paths with f.el
   #'f-join
   #'f-split
   #'f-filename
   #'f-parent
   #'f-common-parent
   #'f-ext
   #'f-no-ext
   #'f-base
   #'f-short
   #'f-long
   #'f-canonical
   #'f-slash
   #'f-depth
   #'f-relative
   ;; These are not pure, but still safe:
   #'f-files
   #'f-directories
   #'f-entries
   ;; Keyboard codes
   #'kbd
   #'key-description
   ;; Generic functions
   #'identity
   #'ignore
   )
  "Functions that suggest will consider.
These functions must not produce side effects.

The best functions for examples generally take a small number of
arguments, and no arguments are functions. For other functions,
the likelihood of users discovering them is too low.

Likewise, we avoid predicates of one argument, as those generally
need multiple examples to ensure they do what the user wants.")

(defsubst suggest--safe (fn args)
  "Is FN safe to call with ARGS?
Due to Emacs bug #25684, some string functions cause Emacs to segfault
when given negative integers."
  (not
   ;; These functions call caseify_object in casefiddle.c.
   (and (memq fn '(upcase downcase capitalize upcase-initials))
        (eq (length args) 1)
        (integerp (car args))
        (< (car args) 0))))

(defface suggest-heading
  '((((class color) (background light)) :foreground "DarkGoldenrod4" :weight bold)
    (((class color) (background dark)) :foreground "LightGoldenrod2" :weight bold))
  "Face for headings."
  :group 'suggest)

(defvar suggest--inputs-heading ";; Inputs (one per line):")
(defvar suggest--outputs-heading ";; Desired output:")
(defvar suggest--results-heading ";; Suggestions:")

(defun suggest--insert-heading (text)
  "Highlight TEXT as a heading and insert in the current buffer."
  ;; Make a note of where the heading starts.
  (let ((excluding-last (substring text 0 (1- (length text))))
        (last-char (substring text (1- (length text))))
        (start (point))
        end)
    ;; Insert the heading, ensuring it's not editable,
    (insert (propertize excluding-last
                        'read-only t))
    ;; but allow users to type immediately after the heading.
    (insert (propertize last-char
                        'read-only t
                        'rear-nonsticky t))
    ;; Point is now at the end of the heading, save that position.
    (setq end (point))
    ;; Start the overlay after the ";; " bit.
    (let ((overlay (make-overlay (+ 3 start) end)))
      ;; Highlight the text in the heading.
      (overlay-put overlay 'face 'suggest-heading))))

(defun suggest--on-heading-p ()
  "Return t if point is on a heading."
  (get-char-property (point) 'read-only))

(defun suggest--raw-inputs ()
  "Read the input lines in the current suggestion buffer."
  (let ((headings-seen 0)
        (raw-inputs nil))
    (loop-for-each-line
      ;; Make a note of when we've passed the inputs heading.
      (when (and (suggest--on-heading-p))
        (cl-incf headings-seen)
        (if (equal headings-seen 2)
            ;; Stop once we reach the outputs.
            (loop-return (nreverse raw-inputs))
          (loop-continue)))
      ;; Skip over empty lines.
      (when (equal it "")
        (loop-continue))
      (push (substring-no-properties it) raw-inputs))))

;; TODO: check that there's only one line of output, or prevent
;; multiple lines being entered.
(defun suggest--raw-output ()
  "Read the output line in the current suggestion buffer."
  (save-excursion
    ;; Move past the 'desired output' heading.
    (suggest--nth-heading 2)
    (forward-line 1)
    ;; Skip blank lines.
    (while (looking-at "\n")
      (forward-line 1))
    ;; Return the current line.
    (buffer-substring (point)
                      (progn (move-end-of-line nil) (point)))))

(defun suggest--keybinding (command keymap)
  "Find the keybinding for COMMAND in KEYMAP."
  (car (where-is-internal command keymap)))

;;;###autoload
(defun suggest ()
  "Open a Suggest buffer that provides suggestions for the inputs
and outputs given."
  (interactive)
  (let ((buf (get-buffer-create "*suggest*")))
    (switch-to-buffer buf)
    (erase-buffer)
    (suggest-mode)
    (let ((inhibit-read-only t))
      (suggest--insert-heading suggest--inputs-heading)
      (insert "\n1\n2\n\n")
      (suggest--insert-heading suggest--outputs-heading)
      (insert "\n3\n\n")
      (suggest--insert-heading suggest--results-heading)
      (insert "\n"))
    ;; Populate the suggestions for 1, 2 => 3
    (suggest-update)
    ;; Put point on the first input.
    (suggest--nth-heading 1)
    (forward-line 1))
  (add-hook 'first-change-hook
            (lambda () (suggest--update-needed t))
            nil t))

(defun suggest--nth-heading (n)
  "Move point to Nth heading in the current *suggest* buffer.
N counts from 1."
  (goto-char (point-min))
  (let ((headings-seen 0))
    (loop-while (< headings-seen n)
      (when (suggest--on-heading-p)
        (cl-incf headings-seen))
      (forward-line 1)))
  (forward-line -1))

(defun suggest--write-suggestions-string (text)
  "Write TEXT to the suggestion section."
  (let ((inhibit-read-only t))
    (save-excursion
      ;; Move to the first line of the results.
      (suggest--nth-heading 3)
      (forward-line 1)
      ;; Remove the current suggestions text.
      (delete-region (point) (point-max))
      ;; Insert the text, ensuring it can't be edited.
      (insert (propertize text 'read-only t)))))

(defun suggest--format-output (value)
  "Format VALUE as the output to a function."
  (let* ((lines (s-lines (suggest--pretty-format value)))
         (prefixed-lines
          (--map-indexed
           (if (zerop it-index) (concat ";=> " it) (concat ";   " it))
           lines)))
    (s-join "\n" prefixed-lines)))

(defun suggest--format-suggestion (suggestion output)
  "Format SUGGESTION as a lisp expression returning OUTPUT."
  (let ((formatted-call ""))
    ;; Build up a string "(func1 (func2 ... literal-inputs))"
    (let ((funcs (plist-get suggestion :funcs))
          (literals (plist-get suggestion :literals)))
      (dolist (func funcs)
        (let ((func-sym (plist-get func :sym))
              (variadic-p (plist-get func :variadic-p)))
          (if variadic-p
              (setq formatted-call
                    (format "%s(apply #'%s " formatted-call func-sym))
            (setq formatted-call
                  (format "%s(%s " formatted-call func-sym)))))
      (setq formatted-call
            (format "%s%s" formatted-call
                    (s-join " " literals)))
      (setq formatted-call
            (concat formatted-call (s-repeat (length funcs) ")"))))
    (let* (;; A string of spaces the same length as the suggestion.
           (matching-spaces (s-repeat (length formatted-call) " "))
           (formatted-output (suggest--format-output output))
           ;; Append the output to the formatted suggestion. If the
           ;; output runs over multiple lines, indent appropriately.
           (formatted-lines
            (--map-indexed
             (if (zerop it-index)
                 (format "%s %s" formatted-call it)
               (format "%s %s" matching-spaces it))
             (s-lines formatted-output))))
      (s-join "\n" formatted-lines))))

(defun suggest--write-suggestions (suggestions output)
  "Write SUGGESTIONS to the current *suggest* buffer.
SUGGESTIONS is a list of forms."
  (->> suggestions
       (--map (suggest--format-suggestion it output))
       (s-join "\n")
       (suggest--write-suggestions-string)))

;; TODO: this is largely duplicated with refine.el and should be
;; factored out somewhere.
(defun suggest--pretty-format (value)
  "Return a pretty-printed version of VALUE."
  (let ((cl-formatted (with-temp-buffer
                        (cl-prettyprint value)
                        (s-trim (buffer-string)))))
    (cond ((stringp value)
           ;; TODO: we should format newlines as \n
           (format "\"%s\"" value))
          ;; Print nil and t as-is.'
          ((or (eq t value) (eq nil value))
           (format "%s" value))
          ;; Display other symbols, and lists, with a quote, so we
          ;; show usable syntax.
          ((or (symbolp value) (consp value))
           (format "'%s" cl-formatted))
          (t
           cl-formatted))))

(defun suggest--read-eval (form)
  "Read and eval FORM, but don't open a debugger on errors."
  (condition-case err
      (eval (read form))
    (error (user-error
            "Could not eval %s: %s" form err))))

;; TODO: this would be a good match for dash.el.
(defun suggest--permutations (lst)
  "Return a list of all possible orderings of list LST."
  (cl-case (length lst)
    (0 nil)
    (1 (list lst))
    (t
     ;; TODO: this is ugly.
     ;; TODO: extract an accumulate macro?
     (let ((permutations nil))
       (--each-indexed lst
         (let* ((element it)
                (remainder (-remove-at it-index lst))
                (remainder-perms (suggest--permutations remainder)))
           (--each remainder-perms (push (cons element it) permutations))))
       (nreverse permutations)))))

;; test cases: cdr cdr
;; 1+ 1+
;; butlast butlast, butlast -butlast, -butlast butlast, -butlast butlast
;; (2 3) => 9 using expt
;; (2 3) => 7 using expt, 1-
;; funcall with nesting
;; 0 => 3 using 1+ 1+ 1+

(defconst suggest--search-depth 4
  "The maximum number of nested function calls to try.
This tends to impact performance for values where many functions
could work, especially numbers.")

(defconst suggest--max-possibilities 20
  "The maximum number of possibilities to return.
This has a major impact on performance, and later possibilities
tend to be progressively more silly.")

(defconst suggest--max-intermediates 10000)

(defsubst suggest--classify-output (inputs func-output target-output)
  "Classify FUNC-OUTPUT so we can decide whether we should keep it."
  (cond
   ((equal func-output target-output)
    'match)
   ;; If the function gave us nil, we're not going to
   ;; find any interesting values by further exploring
   ;; this value.
   ((null func-output)
    'ignore)
   ;; If the function gave us the same target-output as our
   ;; input, don't bother exploring further. Too many
   ;; functions return the input if they can't do
   ;; anything with it.
   ((and (equal (length inputs) 1)
         (equal (-first-item inputs) func-output))
    'ignore)
   ;; The function returned a different result to what
   ;; we wanted, but might be worth exploring further.
   (t
    'different)))

(defun suggest--possibilities (input-literals input-values output)
  "Return a list of possibilities for these INPUTS-VALUES and OUTPUT.
Each possbility form uses INPUT-LITERALS so we show variables rather
than their values."
  (let (possibilities
        (possibilities-count 0)
        this-iteration
        intermediates
        (intermediates-count 0))
    ;; Setup: no function calls, all permutations of our inputs.
    (setq this-iteration
          (-map (-lambda ((values . literals))
                  (list :funcs nil :values values :literals literals))
                (-zip-pair (suggest--permutations input-values)
                           (suggest--permutations input-literals))))
    (catch 'done
      (dotimes (iteration suggest--search-depth)
        (catch 'done-iteration
          (dolist (variadic-p '(nil t))
            (dolist (func suggest-functions)
              (loop-for-each item this-iteration
                (let ((literals (plist-get item :literals))
                      (values (plist-get item :values))
                      (funcs (plist-get item :funcs))
                      func-output func-success)
                  ;; Try to evaluate the function.
                  (when (suggest--safe func values)
                    (if variadic-p
                        ;; See if (apply func values) gives us a value.
                        (when (and (eq (length values) 1) (listp (car values)))
                          (ignore-errors
                            (setq func-output (apply func (car values)))
                            (setq func-success t)))
                      ;; See if (func value1 value2...) gives us a value.
                      (ignore-errors
                        (setq func-output (apply func values))
                        (setq func-success t))))

                  (when func-success
                    (cl-case (suggest--classify-output values func-output output)
                      ;; The function gave us the output we wanted, just save it.
                      ('match
                       (push
                        (list :funcs (cons (list :sym func :variadic-p variadic-p)
                                           funcs)
                              :literals literals :values values)
                        possibilities)
                       (cl-incf possibilities-count)
                       (when (>= possibilities-count suggest--max-possibilities)
                         (throw 'done nil))
                       
                       ;; If we're on the first iteration, we're just
                       ;; searching all input permutations. Don't try any
                       ;; other permutations, or we end up showing e.g. both
                       ;; (+ 2 3) and (+ 3 2).
                       (when (zerop iteration)
                         ;; TODO: (throw 'done-func nil)
                         (loop-break)))
                      ;; The function returned a different result to what
                      ;; we wanted. Build a list of these values so we
                      ;; can explore them.
                      ('different
                       (if (< intermediates-count suggest--max-intermediates)
                           (progn
                             (push
                              (list :funcs (cons (list :sym func :variadic-p variadic-p)
                                                 funcs)
                                    :literals literals :values (list func-output))
                              intermediates)
                             (cl-incf intermediates-count))
                         ;; Avoid building up too big a list of
                         ;; intermediates. This is especially problematic
                         ;; when we have many functions that produce the
                         ;; same result (e.g. small numbers).
                         ;; TODO deduplicate instead.
                         (throw 'done-iteration nil))))))))))

        (setq this-iteration intermediates)
        (setq intermediates nil)
        (setq intermediates-count 0)))
    ;; Return a plist of just :funcs and :literals, as :values is just
    ;; an internal implementation detail.
    (-map (lambda (res)
            (list :funcs (plist-get res :funcs)
                  :literals (plist-get res :literals)))
          possibilities)))

(defun suggest--cmp-relevance (pos1 pos2)
  "Compare two possibilities such that the more relevant result
  is smaller."
  ;; We prefer fewer functions, and we prefer simpler functions. We
  ;; use a dumb but effective heuristic: concatenate the function
  ;; names and take the shortest.
  (let* ((get-names (lambda (pos)
                      (--map (symbol-name (plist-get it :sym))
                             (plist-get pos :funcs))))
         (func-names-1 (funcall get-names pos1))
         (func-names-2 (funcall get-names pos2))
         (length-1 (length (apply #'concat func-names-1)))
         (length-2 (length (apply #'concat func-names-2))))
    ;; Prefer fewer functions first, then concatenat symbol names as a
    ;; tie breaker.
    (if (= (length func-names-1)
           (length func-names-2))
        (< length-1 length-2)
      (< (length func-names-1)
         (length func-names-2)))))

;;;###autoload
(defun suggest-update ()
  "Update the suggestions according to the latest inputs/output given."
  (interactive)
  ;; TODO: error on multiple inputs on one line.
  (let* ((raw-inputs (suggest--raw-inputs))
         (inputs (--map (suggest--read-eval it) raw-inputs))
         (raw-output (suggest--raw-output))
         (desired-output (suggest--read-eval raw-output))
         (possibilities
          (suggest--possibilities raw-inputs inputs desired-output)))
    ;; Sort, and take the top 5 most relevant results.
    (setq possibilities
          (-take 5
                 (-sort #'suggest--cmp-relevance possibilities)))
    
    (if possibilities
        (suggest--write-suggestions
         possibilities
         ;; We show the evalled output, not the raw input, so if
         ;; users use variables, we show the value of that variable.
         desired-output)
      (suggest--write-suggestions-string ";; No matches found.")))
  (suggest--update-needed nil)
  (set-buffer-modified-p nil))

(define-derived-mode suggest-mode emacs-lisp-mode "Suggest"
  "A major mode for finding functions that provide the output requested.")

(define-key suggest-mode-map (kbd "C-c C-c") #'suggest-update)

(defun suggest--update-needed (update-needed)
  "Update the suggestions heading to say whether we need
the user to call `suggest-update'."
  (save-excursion
    (goto-char (point-min))
    (suggest--nth-heading 3)
    (let ((inhibit-read-only t))
      (delete-region (point) (progn (move-end-of-line nil) (point)))
      (if update-needed
          (suggest--insert-heading
           (format ";; Suggestions (press %s to update):"
                   (key-description
                    (suggest--keybinding #'suggest-update suggest-mode-map))))
        (suggest--insert-heading suggest--results-heading)))))

(provide 'suggest)
;;; suggest.el ends here

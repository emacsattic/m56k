;;; m56k.el --- major mode for editing Motorola's DSP56300 assembly code

;;; Copyright (c) 1995-2000 Richard Y. Kim

;; Author: Richard Y. Kim, <ryk@coho.com>
;; Maintainer: Richard Y. Kim, <ryk@coho.com>
;; Created: 1994 or 1995
;; Version: $Id: m56k.el,v 1.20 2000/05/26 01:40:23 ryk Exp ryk $

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
;; PURPOSE.  See the GNU General Public License for more details.

;; You should have received a copy of the GNU General Public
;; License along with this program; if not, write to the Free
;; Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
;; MA 02111-1307 USA

;;; Commentary:
;;
;; This provides a major mode called m56k-mode to aid those who
;; edit assembly language files using Motorola's 56300 (and 56000)
;; family of Digitial Signal Processors' instruction set.
;;
;; Features:
;;
;;   o Font-lock based color highlighting.
;;
;;   o On-demand color highlighting of regular expression, e.g.,
;;     (m56k-highlight-regexp "x0") highlights "\bx0\b" regular
;;     expression, i.e., only the x0 register. Each time this is
;;     called, a different color from the m56k-face-list variable are
;;     cycled. This aids one in reading code, because any register can
;;     be made to stand out so that you can quickly figure out where
;;     and how it is used.  This feature is one reason why I normally
;;     do not have font-lock-mode enabled.
;;     m56k-highlight-regexp is actually a general purpose function
;;     applicable to all modes.
;;
;;   o `beginning-of-defun' and `end-of-defun' are *advised* for
;;     convenient cursor movement.  This also makes reposition-window
;;     work nicely.
;;
;;   o You can swap two R/M/N register sets with a single command.
;;     For example, (m56k-swap-registers 0 4) swaps r0/n0/m0 registers
;;     with r4/n4/m4 registers in the current region.  This is a very
;;     handy tool to reorganize your register usage.
;;
;;   o Symbol values can be looked up from linker map file.
;;     This mode knows how to parse Motorola's linker map files.
;;     For example (m56k-lookup-mapfile "symbol") causes emacs
;;     to lookup the value of the "symbol" in the linker map file
;;     and report the value in the minibuffer.  However there is a catch.
;;     The linker map file keeps only the first 16 characters of a symbol.
;;     Hence any symbol that has more than 16 characters may not work
;;     correctly.
;;
;;   o An assembly code line may consist of of upto six different
;;     fields: label, opcode, operand, x parallel move field, y
;;     parallel move field, and comment.
;;     (m56k-indent-line) parses each field of the current line and
;;     then lines up each field starting at a fixed column number.
;;     For example, here is a really badly indented code.
;;
;;        do #1,_end0 ;comment a
;;        asl     a x:(r0)+,x0   y:(r4)+,y0
;;          nop ; comment b
;;        do      #2,_end1
;;        mac   x0,x1,a   a,b
;;          asl   a         x:(r0)+,x0   y:(r4)+,y0
;;        do    #3,_end2
;;          nop
;;        _end2:
;;        nop
;;        _end1:
;;       nop
;;        _end0:
;;
;;     Hitting TAB key in each line in turn changes this into
;;
;;        do        #1,_end0                             ;comment a
;;          asl     a         x:(r0)+,x0   y:(r4)+,y0
;;          nop                                          ;comment b
;;          do      #2,_end1
;;            mac   x0,x1,a   a,b
;;            asl   a         x:(r0)+,x0   y:(r4)+,y0
;;            do    #3,_end2
;;              nop
;;            _end2:
;;            nop
;;          _end1:
;;          nop
;;        _end0:
;;
;;     By setting the m56k-indentations user option, you can specify
;;     the column numbers for the opcode, operand, x-move field,
;;     y-move field, and the comment field.
;;
;; Background:
;;
;;   The starting point of this file was asm-mode.el distributed along
;;   with GNU Emacs 19.XX in 1994 or 1995.  Over the years, I added
;;   new features.  I stopped adding any new features in 1998 or
;;   1999. This has been used by myself and one or two others only on
;;   Windows platforms.  I never had the chance to use Motorola
;;   assembler on any UNIX platforms.
;;
;;   Around 1995, I had ambitious plan for this mode.  One of the
;;   things I wanted to do was to make TAB key be bound to super smart
;;   completer function based on context.  For example, hitting the
;;   TAB key after typing "mpy " would present the user with possible
;;   addressing modes for that particular instruction.  However, I
;;   never finished the work mainly because I already memorized the
;;   M56k instruction set sufficiently that any further work would not
;;   help me that much. That is why you will find code that looks very
;;   fancy for what it current does.  An example is the use of
;;   m56k-obarray hash table.
;;
;;   Another idea that would make this mode really useful is to
;;   integrate Motorola's documentation.  For example, (find-tag
;;   "mpy") should bring up the documentation on the "mpy"
;;   instruction.  Unfortunately, all of Motorola's documantation is in
;;   PDF format which is rather cumbersome to integrate into emacs. I
;;   know that the text can be extracted using acroread or ghostview,
;;   but the result is too ugly. For me, the ideal format would be
;;   texinfo, XML, latex, or HTML in that order with HTML a very
;;   reluctant last option.  If Motorola makes public their
;;   documenation in one of these formats, then I think I may be
;;   motivated enough to integrate it into this mode.

;; Future plans:
;;
;;   Bugs will be fixed as I become aware of them.
;;
;;   Any glaring error or omissions in documentation will be fixed.
;;
;;   Code will be reorganized for better readability.
;;
;;   All the color highlighting code was written when I knew nothing
;;   about emacs features that were added after emacs 18.  I learned
;;   the font-lock feature just barely enough to hack up the code that
;;   I have. I welcome suggestions in this and any other parts of this
;;   mode.

;;; Changelog:
;;;
;;; 1.20 - first public release on 5/25/2000 to comp.dsp and ntemacs
;;;        mailing list.

;;; Code:

;;;****************************************************************************
;;;@ Prerequisites
;;;****************************************************************************

;; Need advice.el in order to *advise* beginning-of-defun and
;; end-of-defun so that things like beginning-of-defun, end-of-defun
;; and reposition-window work.
(require 'advice)

;; Need cl.el for defstruct.
(require 'cl)

;; make-extent function is used below.
(cond
 ((string-match "XEmacs" emacs-version))
 (t (require 'lucid))
 )

;;;****************************************************************************
;;;@ User Options
;;;****************************************************************************

(defvar m56k-indentations '(4 14 24 37 50 80)
  "*A list of 6 integers for indentations of instruction, operands,
first parallel move, second parallel move, comment start, and end of comment.
See \\[m56k-indent-line] for usage.")

(defvar m56k-face-list
  '(font-lock-function-name-face
    font-lock-comment-face
    font-lock-special-keyword-face
    ;;font-lock-string-face ;; hard to see
    font-lock-label-face
    font-lock-cyan-face
    )
  "*List of faces to cycle each time \\[m56k-highlight-regexp] is called.")

;;;****************************************************************************
;;;@ Major Mode
;;;****************************************************************************

(defvar m56k-mode-syntax-table nil
  "Syntax table used while in m56k-mode.")

(if m56k-mode-syntax-table
    nil
  (setq m56k-mode-syntax-table (make-syntax-table (standard-syntax-table)))
  (modify-syntax-entry ?\; "<"  m56k-mode-syntax-table)      ;; open comment
  (modify-syntax-entry ?\n ">"  m56k-mode-syntax-table)      ;; close comment
  (modify-syntax-entry ?\' "\"" m56k-mode-syntax-table)      ;; string quote

  ;;Treat "_" character the same as a letter.  For example, "\bfoo\b"
  ;;regexp will not match "foo_1".
  (modify-syntax-entry ?\_ "w"  m56k-mode-syntax-table)      ;; word
  )

(defvar m56k-mode-abbrev-table nil
  "Abbrev table used while in m56k-mode.")

(define-abbrev-table 'm56k-mode-abbrev-table ())

(defvar m56k-mode-map nil
  "Keymap for m56k mode.")

(if m56k-mode-map
    nil
  (setq m56k-mode-map (make-sparse-keymap))
  (define-key m56k-mode-map ";"         'm56k-comment)
  (define-key m56k-mode-map "\C-i"      'm56k-indent-line)    ;TAB
  (define-key m56k-mode-map "\C-j"      'm56k-newline)                ;LF
  (define-key m56k-mode-map "\C-m"      'm56k-newline)                ;CR
  (define-key m56k-mode-map "\C-c\C-c"  'm56k-comment-region)
  (define-key m56k-mode-map "\C-c\C-u"  'm56k-uncomment-region)
  (define-key m56k-mode-map "\C-c\C-i"  'm56k-indent-file)
  (define-key m56k-mode-map "\C-c\C-m"  'm56k-lookup-mapfile)
  (define-key m56k-mode-map "\C-c\C-s"  'm56k-swap-registers)
  (define-key m56k-mode-map "\C-c\C-r"  'm56k-change-registers)
  (define-key m56k-mode-map "\C-c\C-h"  'm56k-highlight-regexp)
  (define-key m56k-mode-map "\C-c\C-f"  'm56k-fontify-buffer)
  (define-key m56k-mode-map "\e\t"      'lisp-complete-symbol)
  )

;;;###autoload
(defun m56k-mode ()
  "Major mode for editing Motorola M56k assembler code.

\\[beginning-of-defun] and \\[end-of-defun]  commands are advised to be
more sensible for this mode.

Turning on m56k-mode runs the hook `m56k-mode-hook' at the end of initialization.

Special commands:

\\{m56k-mode-map}
"
  (interactive)
  (kill-all-local-variables)
  (use-local-map m56k-mode-map)
  (setq mode-name "M56K")
  (setq major-mode 'm56k-mode)
  (setq local-abbrev-table m56k-mode-abbrev-table)
  ;;(make-local-variable 'm56k-mode-syntax-table)
  ;;(setq m56k-mode-syntax-table (make-syntax-table))
  (set-syntax-table m56k-mode-syntax-table)
  (run-hooks 'm56k-mode-set-comment-hook)
  ;;(modify-syntax-entry        ?;  "<" m56k-mode-syntax-table)
  ;;(modify-syntax-entry        ?\n ">" m56k-mode-syntax-table)
  (let ((cs ";"))
    (make-local-variable 'comment-start)
    (setq comment-start (concat cs " "))
    (make-local-variable 'comment-start-skip)
    (setq comment-start-skip (concat cs "+[ \t]*"))
    )
  (make-local-variable 'comment-end)
  (setq comment-end "")
  (make-local-variable 'comment-column)
  (setq comment-column 32)
  (setq fill-prefix "\t")
  (setq outline-regexp ";+@+")
  (setq tab-width 4)
  (setq indent-tabs-mode nil)
  (run-hooks 'm56k-mode-hook))

;;;****************************************************************************
;;;@ Cursor Movement Commands
;;;****************************************************************************

(defadvice beginning-of-defun
  (around m56k-support activate compile)
  "If in m56k-mode, move to symbol at column 0."
  (if (eq major-mode 'm56k-mode)
      (let ((opoint (point))
            (cnt (ad-get-arg 0)))
        (cond ((< cnt 0)
               (end-of-defun (- cnt))
               (setq cnt 1)))
        (while (> cnt 0)
          (forward-line -1)
          (while (and (not (bobp))
                      (not (looking-at "[a-zA-Z]")))
            (forward-line -1))
          (setq cnt (1- cnt))))
    ad-do-it
    ))

(defadvice end-of-defun
  (around m56k-support activate compile)
  "If in m56k-mode, move to symbol or comment at column 0."
  (if (eq major-mode 'm56k-mode)
      (let ((cnt (ad-get-arg 0)))
        (cond ((< cnt 0)
               (beginning-of-defun (- cnt))
               (setq cnt 1)))
        (while (> cnt 0)
          ;; skip over comment lines and symbols
          (while (and (not (eobp))
                      (looking-at "[a-zA-Z;]"))
            (forward-line 1))
          ;; goto next comment or symbol lines
          (while (and (not (eobp))
                      (looking-at "[ \t\n_]"))
            (forward-line 1))
          (setq cnt (1- cnt))))
    ad-do-it
    ))

;;;****************************************************************************
;;;@ Indenting
;;;****************************************************************************

(defun m56k-indent-file ( beg end )
  "Re-indent all lines in the current buffer.  With prefix argument,
reindent only the current region."
  (interactive
   (cond (current-prefix-arg
          (list (region-beginning) (region-end)))
         (t (list (point-min) (point-max)))))
  (save-excursion
    (save-restriction
      (widen)
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (< (point) (point-max))
        (m56k-indent-line)
        (forward-line 1)))))

(defun m56k-indent-line ()
  "Parse the current line and indent according to the following rules.

On lines starting with \";;;\", the leading white spaces if any are deleted.

On lines starting with \";;\" or blank lines, indent to proper column dictated
by context.

Lines starting with \";\" indent to comment field column specified
by m56k-indentations.

For all other lines, indent each field to the columns specified
by m56k-indentations.  The column number of the instruction is adjusted
by the number in @N@ if any."
  (interactive)
  (let ((col (m56k-indent-column))
        parsed-line field)
    (beginning-of-line)
    (cond

     ;; comment with starting with ;;;
     ((looking-at "[ \t]*;;;")
      (delete-region (point) (- (match-end 0) 3)))

     ;; empty line or comment line starting with ;; : indent to COL.
     ((or (looking-at "[ \t]*\n")
          (looking-at "[ \t]*;;"))
      (delete-horizontal-space)
      (cond ((and col
                  (setq field (m56k-line-comment (m56k-parse-line)))
                  (string-match "@\\(-?[0-9]+\\)@" field))
             (setq col (+ col
                          (read
                           (substring
                            field
                            (match-beginning 1) (match-end 1)))))))
      (indent-to col))

     ;; comment line starting with ; : indent to comment field column.
     ((looking-at "[ \t]*;")
      (delete-horizontal-space)
      (indent-to (nth 4 m56k-indentations) 1))

     (t
      (setq parsed-line (m56k-parse-line))

      ;; Set COL to indent-fixed property value if non-nil.
      (let ((i (m56k-line-instruction parsed-line))
            c)
        (cond ((and i (setq c (m56k-get i 'indent-fixed)))
               (setq col c))))

      ;; Add the number between two @ in the comment to COL
      (cond ((and col
                  (setq field (m56k-line-comment parsed-line))
                  (string-match "@\\(-?[0-9]+\\)@" field))
             (setq col (+ col
                          (read
                           (substring
                            field
                            (match-beginning 1) (match-end 1)))))))
      ;; Add indent-self property value if any.
      (let ((i (m56k-line-instruction parsed-line)))
        (and i
             (setq i (m56k-get i 'indent-self))
             (setq col (+ col i))))
      ;; Delete current line
      (delete-region (point) (progn (end-of-line) (point)))
      ;; insert label
      (cond ((setq field (m56k-line-label-column parsed-line))
             ;; If indented label, then indent it to COL-2
             (cond ((> field 0)
                    (indent-to (- col 2))))
             (insert (m56k-line-label parsed-line))
             (cond ((> field 0)
                    (insert ":")))))
      ;; insert inst
      (cond ((setq field (m56k-line-instruction parsed-line))
             (indent-to (or col (car m56k-indentations)) 1)
             (insert
              (cond ((or (m56k-directive-p field)
                         (m56k-macro-p field))
                     (upcase field))
                    (t field)))))
      ;; insert args
      (cond ((setq field (m56k-line-args parsed-line))
             (indent-to (nth 1 m56k-indentations) 1)
             (insert field)))
      ;; insert first parallel move
      (cond ((setq field (m56k-line-pmove1 parsed-line))
             (indent-to (nth 2 m56k-indentations) 1)
             (insert field)))
      ;; insert 2nd parallel move
      (cond ((setq field (m56k-line-pmove2 parsed-line))
             (indent-to (nth 3 m56k-indentations) 1)
             (insert field)))
      ;; insert comment
      (cond ((setq field (m56k-line-comment parsed-line))
             (delete-horizontal-space)
             (indent-to (max (min (- (nth 5 m56k-indentations)
                                     (length field))
                                  (nth 4 m56k-indentations))
                             0)
                        1)
             (insert field)))))))

;;;****************************************************************************
;;;@ Editing Commands
;;;****************************************************************************

(defun m56k-newline ()
  "Insert newline and indent according to context."
  (interactive)
  (if (eolp) (delete-horizontal-space))
  (insert "\n")
  (m56k-indent-line))

(defun m56k-match-line (regexp)
  (save-excursion
    (beginning-of-line)
    (looking-at regexp)))

(defun m56k-comment ()
  "Insert or remove `;' depending on context.  The best way to
learn this is to experiment with this on a blank line as well as
lines with valid opcode."
  (interactive)
  (cond

   ;; blank line - insert `;;' at the instruction column
   ((m56k-match-line "[ \t]*$")
    (delete-horizontal-space)
    (m56k-indent-line)
    (insert ";; "))

   ;; comment line starting with ; - make it ;; and indent to inst column
   ((m56k-match-line "[ \t]*;[^;]")
    (beginning-of-line)
    (delete-horizontal-space)
    (insert ";")
    (m56k-indent-line)
    )

   ;; comment line starting with ;; - make it ;;; and flush to left
   ((m56k-match-line "[ \t]*;;[^;]")
    (beginning-of-line)
    (delete-horizontal-space)
    (insert ";")
    (end-of-line))

   ;; comment line starting with ;;; - remove it
   ((m56k-match-line "[ \t]*;;;")
    (goto-char (match-end 0))
    (cond ((looking-at "[ \t]*$")
           (beginning-of-line)
           (delete-region (point) (progn (end-of-line) (point))))
          (t
           (delete-backward-char 3)
           (if (looking-at "[ \t]")
               (delete-char 1)))))

   ;; Nonblank line that is not all comments
   (t
    (let (b e comment)
      (cond
       ((looking-at ";")
        (setq b (point))
        (end-of-line)
        (setq e (point))
        (setq comment (buffer-substring b e))
        (delete-region b e)
        (beginning-of-line)
        (insert ";" comment "\n")
        (forward-line -1))

       ((progn (skip-chars-backward " \t")
               (bolp))
        (skip-chars-forward " \t")
        (let ((end (point)))
          (insert ";; ")
          (end-of-line)
          (while (re-search-backward "[ \t][ \t]+" end t)
            (replace-match " ")
            (forward-char 1))
          (beginning-of-line)))

       ((progn
          (beginning-of-line)
          (looking-at ".*;"))
        (goto-char (1- (match-end 0))))

       (t
        (end-of-line)
        (delete-horizontal-space)
        (indent-to (nth 4 m56k-indentations) 1)
        (insert ";"))

       )))))

;; @ Comment Insert/Delete

(defun m56k-comment-region ( rbeg rend &optional comment-string )
  "Insert \";\" character at the beginning of each line in the current region."
  (interactive "r")
  (cond
   ((null comment-string)
    (setq comment-string ";"))
   ((integerp comment-string)
    (setq comment-string (format ";%s" (make-string (1- comment-start) ?*))))
   ((stringp comment-start))
   (t
    (error "Invalid comment-string %s" comment-string)))
  (m56k-mapline '(lambda () (insert comment-string))
                rbeg rend))

(defun m56k-uncomment-region ( rbeg rend )
  "Delete leading \";\" in each line (if any) in the current region."
  (interactive "r")
  (m56k-mapline
   '(lambda ()
      ;; Delete the first non-white character if it is a semi-colon.
      (skip-chars-forward " \t")
      (and (looking-at ";")
           (delete-char 1)))
   rbeg rend))

(defun m56k-swap-registers ( from to &optional beg end )
  "Swap R/M/N registers in the current region.  This asks for two numbers.
If you specify, 0 and 4 for example, then all R0, M0, and N0 registers in
the region are changed to be R4, M4, and N4, and vice versa."
  (interactive
   (list (read-string "Reg to swap #1: ")
         (read-string "Reg to swap #2: ")
         (if current-prefix-arg
             (point-min)
           (region-beginning))
         (if current-prefix-arg
             (point-max)
           (region-end))))
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char beg)
      (replace-regexp (format "\\([rmn]\\)%s" from)  "\\1999" t)
      (goto-char beg)
      (replace-regexp (format "\\([rmn]\\)%s" to)    (format "\\1%s" from) t)
      (goto-char beg)
      (replace-regexp (format "\\([rmn]\\)%s" "999") (format "\\1%s" to) t))))

(defun m56k-change-registers ( from to &optional beg end )
  "Replace R/M/N register set from FROM to TO."
  (interactive
   (list (read-string "From: ")
         (read-string "To: ")
         (if current-prefix-arg
             (point-min)
           (region-beginning))
         (if current-prefix-arg
             (point-max)
           (region-end))))
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char beg)
      (replace-regexp (format "\\([rmn]\\)%s" from)  (format "\\1%s" to) t))))

;;;****************************************************************************
;;;@ Color Highlighting
;;;****************************************************************************

(setq m56k-face-list-index 0)

;;;###autoload
(defun m56k-highlight-regexp ( re &optional beg end unhilit )
  "Highlight all occurances of the given REGEXP.
With prefix argument, un-highlight all."
  (interactive
   (let ((ibeg (point-min))
         (iend (point-max))
         ire iunhilit)
     (cond
      ((and current-prefix-arg (= (car current-prefix-arg) 4))
       (setq iunhilit t))
      (current-prefix-arg
       (setq iunhilit (y-or-n-p "Unhilit? "))
       (if (y-or-n-p "Region only (rather than whole buffer) ? ")
           (setq ibeg (region-beginning)
                 iend (region-end))))
      (t (setq ire (read-string "Enter regexp to hilit: " (m56k-symbol-at-point)))
         (setq ire (format "\\b%s\\b" ire))))
     (list ire ibeg iend iunhilit)))

  (if unhilit
      ;;(cl-map-extents '(lambda (extent maparg) (delete-extent extent)))
      (mapcar 'delete-overlay (overlays-in (point-min) (point-max)))
    (if (>= m56k-face-list-index (length m56k-face-list))
        (setq m56k-face-list-index 0))
    (let ((face (nth m56k-face-list-index m56k-face-list)))
      (m56k-add-extent-regexp re 0 face beg end))
    ;; update m56k-face-list-index
    (setq m56k-face-list-index (1+ m56k-face-list-index))
    ))

(defun m56k-fontify-buffer ( &optional unfontify )
  (interactive "P")
  (cond
   (unfontify
    ;;(cl-map-extents '(lambda (extent maparg) (delete-extent extent)))
    (mapcar 'delete-overlay (overlays-in (point-min) (point-max)))
    (font-lock-mode -1))
   (t
    (font-lock-mode 1)
    (setq font-lock-keywords-case-fold-search t)
    (setq font-lock-keywords
          (list
           (cons
            (format "%s\\|%s"
                    "jset\\|jclr\\|[bj]cc\\|jcs\\|jec\\|jeq\\|jes\\|jge\\|jgt"
                    "jlc\\|jle\\|jls\\|jlt\\|jmi\\|jne\\|jnr\\|jpl\\|jnn")
            'font-lock-keyword-face)

           '("[ \t]\\(section\\|endsec\\|include\\|if\\|endif\\|else\\)[ \n]"
             1
             font-lock-special-keyword-face
             ;;font-lock-string-face
             )

           '("[ \t]\\(jmp\\)[ \n]"          1
             font-lock-cyan-face
             )

           '("^[a-z_][a-z0-9_]*" 0 font-lock-label-face t)
           ;;'("^ +\\([a-z_][a-z0-9_]*\\):"   1 font-lock-label-face)
           '("[ \t]\\(jsr\\|js[a-z][a-z]\\)[ ]"
             1 font-lock-string-face)
           ))
    (font-lock-fontify-buffer))))

(defun m56k-add-extent-regexp ( re match-number face beg end )
  (let (extent)
    (save-excursion
      (goto-char beg)
      (while (re-search-forward re nil end)
        (setq extent (make-extent (match-beginning match-number)
                                  (match-end match-number)))
        (set-extent-face extent face)))))

;;;****************************************************************************
;;;@ Linker Map File Interface
;;;****************************************************************************

(defvar m56k-last-mapfile nil)

(defun m56k-map-filename ()
  "Return the fullpath of a linker map file.  If a *.map file exists in the
current directory, then it is returned, else use m56k-last-mapfile is it exists."
  (let* ((fnnd (file-name-nondirectory
                (directory-file-name
                 default-directory)))
         (candidates
          (append (directory-files "." t "\\.map$")
                  (directory-files (format "../../build/%s" fnnd) t "\\.map$")
                  (list m56k-last-mapfile))))
    (catch 'done
      (mapcar '(lambda (f) (if (file-exists-p f) (throw 'done f)))
              candidates))))

(defun m56k-lookup-mapfile ( sym )
  "Report the value of the SYM by looking up the map file.
The map file is assumed to be same as current directory name with .map suffix."
  (interactive
   (cond ((or current-prefix-arg
              (not (m56k-symbol-at-point)))
          (let ((default (find-tag-default))
                (buffer-tag-table-list (buffer-tag-table-symbol-list))
                tag-symbol-tables tag-name)
            (list
             (completing-read
              "Symbol to lookup: "
              tag-completion-table 'tag-completion-predicate nil nil
              'find-tag-history))))
         (t (list (m56k-symbol-at-point)))))
  (if (> (length sym) 16)
      (setq sym (substring sym 0 16)))
  (let* ((case-fold-search t)
         (mapfile (m56k-map-filename))
         (mapfile-fnnd (file-name-nondirectory mapfile))
         (re (format "^%s\\.+\\(int\\|fpt\\) +\\([XYLP]:\\)?\\([0-9A-F.+]+\\) +"
                     (regexp-quote sym)))
         space value)
    (save-excursion
      (let ((buf (get-buffer mapfile-fnnd)))
        ;;Delete mapfile buffer if disk copy is newer.
        (if (and buf
                 (not (verify-visited-file-modtime buf)))
            (kill-buffer mapfile-fnnd))
        (cond
         ((file-exists-p mapfile)
          (setq buf (find-file-noselect mapfile t))
          (setq m56k-last-mapfile (expand-file-name mapfile)))
         ((setq buf (find-file-noselect m56k-last-mapfile t)))
         (t (error "Can't find the map file."))
         )
        (set-buffer buf))
      (goto-char (point-min))
      (re-search-forward "^ +Symbol Listing by Name")
      (if (re-search-forward re nil t)
          (setq space (if (match-beginning 2)
                          (buffer-substring (match-beginning 2) (match-end 2))
                        "")
                value (buffer-substring (match-beginning 3) (match-end 3)))))
    (cond (value
           (message "%s -> %s%s" sym space value)
           value)
          (t (error "Can't find \"%s\" in %s" sym mapfile)))
    ))

;;;****************************************************************************
;;;@ m56k-obarray
;;;****************************************************************************

(defvar m56k-obarray (make-vector 63 nil)
  "Rather than using the default obarray, this dedicated obarray is used by
the m56k-mode.  This table is meant to be a repository of data regarding
M56k instruction set, macros, etc. Each symbol may have one or more of
these properties:

  instruction   - t if instruction
  directive     - t if assembler directive
  function      - t if assembler @-function
  macro         - t if user defined assembler macro
  argc          - number of operands
  parallel-move - t if normal parallel move, list for other parallel moves
  indent-next   - number of spaces to indent for next instruction
  indent-self   - number of to add to the current line's indentation
  indent-fixed  - fixed indentation
")

(defmacro m56k-intern (s)
  (` (intern (, s) m56k-obarray)))

(defmacro m56k-put (s property value)
  (` (put (m56k-intern (, s)) (, property) (, value))))

(defmacro m56k-get (s property)
  (` (get (m56k-intern (, s)) (, property))))

(defmacro m56k-directive-p (s)
  (` (m56k-get (, s) 'directive)))

(defmacro m56k-instruction-p (s)
  (` (m56k-get (, s) 'instruction)))

(defmacro m56k-function-p (s)
  (` (m56k-get (, s) 'function)))

(defmacro m56k-macro-p (s)
  (` (m56k-get (, s) 'macro)))

(defvar m56k-condition-codes
  '(
    ("cc" "C=0, carry clear")
    ("cs" "C=1, carry set")
    ("ec" "E=0, extension clear")
    ("eq" "Z=1, equal")
    ("es" "E=1, extension set")
    ("ge" "NxV=0, greater than or equal")
    ("gt" "Z+NxV=0, greater than")
    ("lc" "L=0, limit clear")
    ("le" "Z+NxV=1, less than or equal")
    ("ls" "L=1, limit set")
    ("lt" "NxV=1, less than")
    ("mi" "N=1, minus")
    ("ne" "Z=0, not equal")
    ("nr" "Z+(U/ * E/)=1, normalized")
    ("pl" "N=0, plus")
    ("nn" "Z+(U/ * E/)=0, not normalized")
    )
  "An alist of all the condition codes.")

;; intern normal instructions
(mapcar '(lambda (x) (m56k-put x 'instruction t))
        (append
         ;; 56002 instructions
         '("abs" "adc" "add" "addl" "addr" "and" "andi" "asl" "asr"
           "bchg" "bclr" "bset" "btst"
           "clr" "cmp" "cmpm"
           "debug" "dec" "div" "do"
           "enddo" "eor" "illegal" "inc" "jclr" "jmp"
           "jsclr" "jset" "jsr" "jsset" "lsl" "lsr" "lua"
           "mac" "macr" "move" "movec" "movem" "movep" "mpy" "mpyr"
           "neg" "nop" "norm" "not"
           "or" "ori" "rep" "reset" "rnd" "rol" "ror" "rti" "rts"
           "sbc" "stop" "sub" "subl" "subr" "swi"
           "tfr" "tst" "wait")
         ;; 56300 instructions
         '("cmpu" "dmacss" "dmacsu" "dmacuu"
           "macsu" "macuu" "maci" "macri" "max" "maxm" "mpysu"
           "mpyuu" "mpyi" "mpyri" "normf"
           "clb"
           "extract"
           "extractu"
           "insert"
           "merge"
           "dor"
           "bra" "brclr" "brset" "bsr" "bsclr" "bsset"
           "plock" "punlock" "plockr" "punlockr" "pfree" "pflush" "pflushun"
           )
         ))

;; intern instructions ending with "cc"
(mapcar '(lambda (x)
           (mapcar '(lambda (z) (m56k-put z 'instruction t))
                   (mapcar '(lambda (y) (concat (substring x 0 -2) (car y)))
                           m56k-condition-codes)))
        '("debugcc" "bcc" "brkcc" "bscc" "jcc" "jscc" "tcc"))

(mapcar
 '(lambda (x)
    (m56k-put (nth 0 x) 'argc            (nth 1 x))
    (m56k-put (nth 0 x) 'parallel-move   (nth 2 x))
    (m56k-put (nth 0 x) 'addressing-mode (nth 3 x))
    (m56k-put (nth 0 x) 'indent-next     (nth 4 x)))
 '(
   ("abs"      1 t   '(regs-ab))
   ("adc"      2 t   '(regs-xy regs-ab))
   ("add"      2 t   '((regs-xy01 regs-xy regs-ab) regs-ab))
   ("addl"     2 t   '(regs-ab regs-ab))
   ("addr"     2 t   '(regs-ab regs-ab))
   ("and"      2 t   '(regs-xy01 regs-ab))
   ("andi"     2 t   '(imm-8 regs-c8))
   ("asl"      1 t   'regs-ab)
   ("asr"      1 t   'regs-ab)
   ("bchg"     2 t   '(imm-5 ea-abs))
   ("bclr"     2 t   '(imm-5 ea-abs))
   ("brclr"    3 nil '(imm-5 (ea-regs ea-aa ea-pp regs-all) abs-16) 2)
   ("brset"    3 nil '(imm-5 (ea-regs ea-aa ea-pp regs-all) abs-16) 2)
   ("bset"     2 t   '(imm-5 ea-abs))
   ("btst"     2 t   '(imm-5 ea-abs))
   ("clr"      1 t   'regs-ab)
   ("cmp"      2 t   '((regs-xy01 regs-xy regs-ab) regs-ab))
   ("cmpm"     2 t   '((regs-xy01 regs-xy regs-ab) regs-ab))
   ("debug"    0)
   ("dec"      2 t   '((regs-xy01 regs-xy regs-ab) regs-ab))
   ("div"      2 t   '(regs-xy01 regs-ab))
   ("do"       2 nil '((ea-regs imm-12 regs-par) abs-16) 2)
   ("enddo"    0)
   ("endif"    0 nil nil 2)
   ("eor"      2 t   '(regs-xy01 regs-ab))
   ("illegal"  0)
   ("inc"      1 t   'regs-ab)
   ("jclr"     3 nil '(imm-5 (ea-regs ea-aa ea-pp regs-all) abs-16) 2)
   ("jmp"      1 nil '(imm-12 ea-abs))
   ("jsclr"    3 nil '(imm-5 (ea-regs ea-aa ea-pp regs-all) abs-16))
   ("jset"     3 nil '(imm-5 (ea-regs ea-aa ea-pp regs-all) abs-16) 2)
   ("jsr"      1 nil '(imm-12 ea-abs))
   ("jsset"    3 nil '(imm-5 (ea-regs ea-aa ea-pp regs-all) abs-16))
   ("lsl"      1 t   '(regs-ab0))
   ("lsr"      1 t   '(regs-ab))
   ("lua"      2 nil '(regs-lua  (regs-r regs-n)))
   ("mac"      3 t   '(regs-xy01 (regs-xy01 imm-5) regs-ab))
   ("macr"     3 t   '(regs-xy01 (regs-xy01 imm-5) regs-ab))
   ("move"     0 t)
   ("movec"    2 nil '((ea-imm ea-aa regs-all imm-8) (regs-c (ea-imm ea-aa regs-all))))
   ("movem"    2 nil '((p:ea-abs p:ea-aa) (regs-all (p:ea-abs p:ea-aa))))
   ("movep"    2 nil '((x/y:ea-pp) ((x/y/p:ea-imm regs-all) x/y:ea-pp)))
   ("mpy"      3 t   '(regs-xy01 (regs-xy01 imm-5) regs-ab))
   ("mpyr"     3 t   '(regs-xy01 (regs-xy01 imm-5) regs-ab))
   ("neg"      1 t   '(regs-ab))
   ("nop"      0)
   ("norm"     1 nil '(regs-ab))
   ("not"      1 t   '(regs-ab))
   ("or"       2 t   '(regs-xy01 regs-ab))
   ("ori"      2 t   '(imm-8 regs-c8))
   ("rep"      1 nil '(x/y:ea-regs imm-12 x/y:aa))
   ("reset"    0)
   ("rnd"      1 t   '(regs-ab))
   ("rol"      1 nil '(regs-ab))
   ("ror"      1 nil '(regs-ab))
   ("rti"      0)
   ("rts"      0)
   ("sbc"      2 t   '(regs-xy regs-ab))
   ("stop"     0)
   ("sub"      2 t   '((regs-xy regs-xy01 regs-ab) regs-ab))
   ("subl"     2 t   '(regs-ab regs-ab))
   ("subr"     2 t   '(regs-ab regs-ab))
   ("swi"      0)
   ("tfr"      2 t   '((regs-xy01 regs-ab) regs-ab))
   ("tst"      1 t   '(regs-ab))
   ("wait"     0)))

(mapcar '(lambda (x)
           (mapcar '(lambda(z)
                      (let ((sym (m56k-intern z)))
                        (put sym 'argc  (nth 1 x))
                        (put sym 'parallel-move (nth 2 x))
                        (put sym 'addressing-mode (nth 3 x))))
                   (mapcar '(lambda (y)
                              (concat (substring (car x) 0 -2) (car y)))
                           m56k-condition-codes)))
        '(("debugcc"  0)
          ("jcc"      1 nil 'imm-12)
          ("bcc"      1 nil 'imm-12)
          ("jscc"     1 nil '(imm-12 ea-abs))
          ("tcc"      2 '(regs-r regs-r) '((regs-xy01 regs-ab) regs-ab)e)))

(mapcar '(lambda (z) (m56k-put z 'indent-next 2))
        (mapcar '(lambda (y) (concat "j" (car y)))
                m56k-condition-codes))

(mapcar '(lambda (z) (m56k-put z 'indent-next 2))
        (mapcar '(lambda (y) (concat "b" (car y)))
                m56k-condition-codes))

;; @@ Directives

(mapcar '(lambda (x) (m56k-put x 'directive t))
        '(".break" ".continue" ".else" ".endf" ".endi" ".endl" ".endw"
          ".for" ".if" ".lop" ".repeat" ".until" ".while"
          "baddr" "bsb" "bsc" "bsm" "buffer" "cobj" "comment" "dc"
          "dcb" "define" "ds" "dsm" "dsr" "dup" "dupa" "dupc" "dupf"
          "else" "end" "endbuf" "endif" "endm" "endsec" "equ" "exitm" "fail"
          "force" "global" "gset" "himem" "ident" "if" "include" "list"
          "local" "lomem" "lstcol" "maclib" "macro" "mode" "msg" "nolist"
          "opt" "org" "page" "pmacro" "prctl" "radix" "rdirect" "scsjmp"
          "scsreg" "section" "set" "stitle" "symobj" "tabs" "title"
          "undef" "warn" "xdef" "xref"))

(mapcar '(lambda (z) (m56k-put z 'indent-next 2))
        '("if" "else"))

(mapcar '(lambda (z) (m56k-put z 'indent-self -2))
        '("else" "endif"))

(mapcar '(lambda (z) (m56k-put z 'indent-fixed (nth 0 m56k-indentations)))
        '(
          "section"
          "endsec"
          "global"
          "nolist"
          "list"
          "macro"
          ))

(mapcar '(lambda (z) (m56k-put z 'indent-fixed (nth 1 m56k-indentations)))
        '(
          "bsm"
          "dsm"
          "equ"
          "set"
          "dc"
          "ds"
          ))

;; @@ Functions

(mapcar '(lambda (x) (m56k-put x 'function t))
        '("@abs" "@acs" "@arg" "@asn" "@at2" "@atn" "@ccc" "@cel" "@chk"
          "@cnt" "@coh" "@cos" "@ctr" "@cvf" "@cvi" "@cvs" "@def" "@exp"
          "@fld" "@flr" "@frc" "@int" "@l10" "@lcv" "@len" "@lfr" "@lng"
          "@log" "@lst" "@lun" "@mac" "@max" "@min" "@msp" "@mxp" "@pos"
          "@pow" "@rel" "@rnd" "@rvb" "@scp" "@sgn" "@sin" "@snh" "@sqt"
          "@tan" "@tnh" "@unf" "@xpn"))

;; @ M56k Addressing Modes

;; regs-xy   ("x" "y")
;; regs-xy01 ("x0" "x1" "y0" "y1")
;; regs-ab   ("a" "b")
;; regs-ac   (regs-ab     "a0"  "a1"  "a2"  "b0"  "b1"  "b2" )
;; regs-r    ("r0"  "r1"  "r2"  "r3"  "r4"  "r5"  "r6"  "r7" )
;; regs-m    ("m0"  "m1"  "m2"  "m3"  "m4"  "m5"  "m6"  "m7" )
;; regs-n    ("n0"  "n1"  "n2"  "n3"  "n4"  "n5"  "n6"  "n7" )
;; regs-c    (regs-m "la"  "lc"  "ssh" "ssl" "sp"  "omr" "sr")
;; regs-l    ("a10" "b10" "x"   "y"   "a"   "b"   "ab"  "ba")
;; regs-par  (regs-ac regs-xy01 regs-r regs-n)
;; regs-all  (regs-par regs-c)
;; regs-c8   ("mr" "ccr" "omr")
;;
;; imm-5     ("#bx")
;; imm-8     ("#xx")
;; imm-12    ("#xxx")
;; imm-24    ("#xxxxxx")
;;
;; abs-6     ("x:bbx"  "y:bbx")
;; abs-16    ("x:xxxx" "y:xxxx")
;;           ("x:xxxx"  "y:xxxx")
;;
;; ea-lua    ("(Rn)+Nn" "(Rn)-Nn" "(Rn)+" "(Rn)-")
;; ea-reg    (ea-lua    "(Rn+Nn)" "-(Rn)" "(Rn)")
;; ea-abs    (ea-reg    "absolute")
;; ea-imm    (ea-abs    imm-24)
;; ea-par    ("(Rn)"    "(Rn)+Nn" "(Rn)+" "(Rn)-")
;; ea-aa     (abs-6)
;; ea-pp     (x/y:<<bbx)
;;
;; bit
;; pmove-i   (regs-par)
;; pmove-r   (regs-par)
;; pmove-u   (ea-lua)
;; pmove-x   ((ea-abs <-> regs-par) (ea-aa <-> regs-par) ("immediate" -> regs-par))
;; pmove-xr  ((ea-abs <-> x0 x1 a b) (a,b -> y0,y1))
;;           ((a -> ea-reg) (x0->a))
;;           ((b -> ea-reg) (x0->b))
;; pmove-y   ((ea-abs <-> regs-par) (ea-aa <-> regs-par) ("immediate" -> regs-par))
;; pmove-yr  ((a,b -> x0,x1) (ea-abs <-> y0 y1 a b))
;;           ((y0->a) (a -> ea-reg))
;;           ((y0->b) (b -> ea-reg))
;; pmove-l   ((regs-l <-> ea-abs))
;; pmove-xy  ((x:ea-par <-> x0 x1 a b) (y:ea-par <-> y0 y1 a b))
;; movec     ((ea-imm <-> regs-c))
;;           ((regs-all <-> regs-c))
;; movem     ((ea-abs <-> regs-all))
;;           ((ea-aa     <-> regs-all))
;; movep     ((x/y/p:ea-imm <-> x/y:pp))
;;           ((regs-all     <-> x/y:pp))

;;;****************************************************************************
;;;@ Utils
;;;****************************************************************************

(defun m56k-symbol-at-point ( &optional re )
  "Return the symbol at point."
  (or re (setq re "a-zA-Z0-9_"))
  (let ((case-fold-search t)
        (re "\\(\\sw\\|_\\)")
        b e s)
    (save-excursion
      (if
          ;;(looking-at "\\(\\sw\\|\\s_\\)+")
          (looking-at (concat re "+"))
          (goto-char (match-end 0)))
      (setq e (point))
      (backward-char 1)
      (while
          ;;(looking-at "\\sw\\|\\s_")
          (looking-at re)
        (backward-char 1))
      (forward-char 1)
      (setq b (point))
      (setq s (buffer-substring b e))
      (if (equal s "")
          nil
        s))))

(defun m56k-mapline ( func rbeg rend &rest args )
  "Apply FUNC to each line between RBEG and REND.
The line containing RBEG is included whereas the line including
REND is excluded."
  (save-excursion
    (save-restriction
      (narrow-to-region
       (progn (goto-char rbeg)
              (beginning-of-line)
              (point))
       (progn (goto-char rend)
              (beginning-of-line)
              (point)))
      (goto-char (point-min))
      (while (not (eobp))
        (apply func args)
        (forward-line 1)))))

(defun m56k-indent-column ()
  "Return the column to which the current line should be indented
based on the previous line."
  (let ((result 0)
        offset pline field)
    (save-excursion
      (catch 'foo
        (forward-line -1)
        (while (not (bobp))
          (setq pline (m56k-parse-line))
          (cond

           ;; If fixed indentation instruction, then retun 4
           ((and (setq field  (m56k-line-instruction pline))
                 (m56k-get field 'indent-fixed))
            (setq result (car m56k-indentations))
            (setq offset (m56k-get (m56k-line-instruction pline) 'indent-next))
            (throw 'foo nil))

           ;; If instruction, then retun its column plus indent-next prop.
           ((setq field  (m56k-line-instruction-column pline))
            (setq result field)
            (setq offset (m56k-get (m56k-line-instruction pline) 'indent-next))
            (throw 'foo nil))

           ;; If indented label, then return its column.
           ((setq field (m56k-line-label-column pline))
            (setq result (if (= 0 field) 4 field))
            (throw 'foo nil))

           ;; If comment line starting with ;; then return its column
           ((and (setq field (m56k-line-comment-column pline))
                 (string-match "^;;[^;]" (m56k-line-comment pline)))
            (setq result field)
            (throw 'foo nil))

           )
          (forward-line -1))
        (setq result (car m56k-indentations)))
      (or offset (setq offset 0))
      (+ result offset))))

(defstruct m56k-line label label-column instruction instruction-column
  args args-column pmove1 pmove1-column pmove2 pmove2-column
  comment comment-column)

(defun m56k-parse-line ()
  "Parse the current line and return `m56k-line' structure filled
with the parsed values."
  (save-excursion
    (let ((line (make-m56k-line))
          col orig-inst instruction args )
      (beginning-of-line)
      (cond     ;; handle labels first
       ((or (looking-at "\\([a-zA-Z_][a-zA-Z0-9_]*\\)")
            (looking-at "[ \t]*\\([a-zA-Z_][a-zA-Z0-9_]*\\):"))
        (goto-char (match-beginning 1))
        (setf (m56k-line-label line)
              (buffer-substring (match-beginning 1) (match-end 1)))
        (setf (m56k-line-label-column line)
              (current-column))
        (goto-char (match-end 0))))

      (skip-chars-forward " \t")
      (cond
       ((looking-at "$"))         ;; no instruction or comment
       ((looking-at ";")          ;; no instruction with comment
        (setf (m56k-line-comment-column line) (current-column))
        (setf (m56k-line-comment line)
              (buffer-substring (point) (progn (end-of-line) (point)))))
       ;; parse instruction with optional args, pmoves, and comment
       (t
        ;; inst
        (setf (m56k-line-instruction-column line) (current-column))
        (setq orig-inst
              (buffer-substring
               (point) (progn (skip-chars-forward "a-zA-Z0-9_\\.") (point))))
        (setq instruction (downcase orig-inst))
        (cond ((or (m56k-instruction-p instruction)
                   (m56k-directive-p instruction)
                   (m56k-macro-p instruction))
               (setf (m56k-line-instruction line) instruction))
              ((y-or-n-p (format "Is \"%s\" a macro? " orig-inst))
               (m56k-put instruction 'macro t)
               (setf (m56k-line-instruction line) instruction))
              (t (error "Can't parse current M56k line.")))
        ;; args
        (skip-chars-forward " \t")
        (cond ((looking-at "[^ \t\n;]")
               (let ((b (point))
                     (col (current-column))
                     e)
                 ;; skip over one operand at a time
                 (while (looking-at "[^ \t\n;]")
                   (cond ((looking-at "'")
                          (forward-char 1)
                          (skip-chars-forward "^'\n")
                          (forward-char 1))
                         (t
                          (skip-chars-forward "^ \t\n;,")))
                   (cond ((looking-at ",") (forward-char 1))
                         (t (setq e (point))))
                   )
               (setf (m56k-line-args line) (buffer-substring b e))
               (setf (m56k-line-args-column line) col))))
        ;; pmove1
        (skip-chars-forward " \t")
        (cond ((looking-at "[^ \t\n;]+")
               (setf (m56k-line-pmove1 line)
                     (buffer-substring (match-beginning 0) (match-end 0)))
               (setf (m56k-line-pmove1-column line)
                     (current-column))
               (goto-char (match-end 0))))
        ;; pmove2
        (skip-chars-forward " \t")
        (cond ((looking-at "[^ \t\n;]+")
               (setf (m56k-line-pmove2 line)
                     (buffer-substring (match-beginning 0) (match-end 0)))
               (setf (m56k-line-pmove2-column line)
                     (current-column))
               (goto-char (match-end 0))))
        ;; comment
        (skip-chars-forward " \t")
        (cond
         ((looking-at ";.* *$")                ;; comment line
          (setf (m56k-line-comment line)
                (buffer-substring
                 (point)
                 (progn (end-of-line) (skip-chars-backward " ") (point))))
          (setf (m56k-line-comment-column line)
                (current-column))))))
      (m56k-order-args line))))

(defun m56k-order-args ( line )
  "Order pmove1 and pmove2."

  ;; 'move' instruction only has parallel moves
  (cond
   ((equal (m56k-line-instruction line) "move")
    (setf  (m56k-line-pmove2 line)        (m56k-line-pmove1 line))
    (setf  (m56k-line-pmove2-column line) (m56k-line-pmove1-column line))
    (setf  (m56k-line-pmove1 line)        (m56k-line-args line))
    (setf  (m56k-line-pmove1-column line) (m56k-line-args-column line))
    (setf  (m56k-line-args line)          nil)
    (setf  (m56k-line-args-column line)   nil)))

  (let ((arg (m56k-line-args line))
        (pmove1 (m56k-line-pmove1 line))
        (pmove2 (m56k-line-pmove2 line))
        (col1   (m56k-line-pmove1-column line))
        (col2   (m56k-line-pmove2-column line)))
    (cond
     ;; swap pmoves if pmove1 is y memory or pmove2 is x memory
     ((or (and pmove1 (string-match "y:" pmove1))
          (and pmove2 (string-match "x:" pmove2)))
      (psetq pmove1 pmove2 pmove2 pmove1
             col1   col2   col2   col1)))
    (setf (m56k-line-pmove1        line) pmove1)
    (setf (m56k-line-pmove1-column line) col1  )
    (setf (m56k-line-pmove2        line) pmove2)
    (setf (m56k-line-pmove2-column line) col2  )
    line))

;;;****************************************************************************
;;;@ Epilog
;;;****************************************************************************

(provide 'm56k)

;;Is m56k-load-hook redundant with eval-after-load?
(run-hooks 'm56k-load-hook)

;;; Local Variables: ***
;;; outline-regexp: ";;;@+ " ***
;;; End: ***

;;; m56k.el ends here

;;; yoficator.el -- Interactively yoficate Russian texts

;; Copyright (C) 2003 Eugene Minkovskii
;; Copyright (C) 2017 Alexander Krotov

;; Author: Eugene Minkovskii <emin@mccme.ru>
;;         Alexander Krotov <ilabdsf@gmail.com>
;; Version: 0.9
;; URL: https://gitlab.com/link2xt/yoficator

;;; This file is NOT part of GNU Emacs

;;; License

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a command to replace «е» letters with «ё» letters
;; according to built-in dictionary.  In ambiguous cases it asks user to
;; select the correct variant.
;;
;; Use M-x run-yoficator to run yoficator.

;;; Code:

(defvar yoficator-database-file
  (expand-file-name "yo.txt" (file-name-directory load-file-name))
  "Yoficator dictionary filename")

(defvar yoficator-database-codingsystem 'utf-8
  "Yoficator dictionary encoding")

(defvar yoficator-cutting-strings (list "\\-" "\"=" "\"~")
  "Words in the text may be splitting by some strings:
for example: hy\\-phe\\-na\\-ti\\-on in TeX")

(defun read-yoficator-database (file-name &optional encoding)
  "Reading yo database from FILENAME and return cons:
\(only-yo-hash . may-be-yo-hash) where hash mapping word whithout yo
to corresponding yoficator-form"
  (let ((only-yo (make-hash-table :test 'equal :size 60000))
        (may-be-yo (make-hash-table :test 'equal :size 2000))
        current-word)
    (switch-to-buffer (generate-new-buffer "yo"))
    (let ((coding-system-for-read encoding))
      (insert-file-contents file-name))
    (while (re-search-forward "^\\w+" nil t)
      (setq current-word (match-string 0))
      (puthash (replace-regexp-in-string "ё" "е" current-word)
               current-word only-yo))
    (beginning-of-buffer)
    (while (re-search-forward "^\\*[ \t]*\\(\\w+\\)" nil t)
      (setq current-word (match-string 1))
      (puthash (replace-regexp-in-string "ё" "е" current-word)
               current-word may-be-yo))
    (kill-buffer (current-buffer))
    (cons only-yo may-be-yo)))

(defvar yoficator-hash
  (read-yoficator-database yoficator-database-file yoficator-database-codingsystem)
  "cons (only-yo-hash . may-be-yo-hash) where hashes map words
without yo to corresponding yo-form")

;;;###autoload
(defun run-yoficator ()
  "Run yoficator interactively"
  (interactive)
  (save-restriction
    (save-excursion
      (let (current-e-word
            current-yo-word
            (cutting (concat "\\(?:"
                             (mapconcat 'regexp-quote
                                        yoficator-cutting-strings "\\|")
                             "\\)")))
        (while (re-search-forward
                (concat "\\(?:\\w\\(?:\\w\\|" cutting "\\)*\\)?"
                        "\\(?:е\\|Е\\)"
                        "\\(?:\\w\\(?:\\w\\|" cutting "\\)*\\)?") nil t)
          (save-match-data
            (setq current-e-word
                  (downcase
                   (replace-regexp-in-string cutting "" (match-string 0))))
            (setq current-yo-word (gethash current-e-word (car yoficator-hash))))
          (if current-yo-word
              (replace-match current-yo-word nil)
            (setq current-yo-word (gethash current-e-word (cdr yo-hash)))
            (when current-yo-word
              (if search-highlight
                  (isearch-highlight (match-beginning 0) (match-end 0)))
              (when (y-or-n-p (format "Меняем \"%s\" на \"%s\"? "
                                      current-e-word
                                      current-yo-word))
                (undo-boundary)
                (replace-match current-yo-word nil))
              (isearch-dehighlight))))))))
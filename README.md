# dsl-quote

## Why write this

When writing multi-layer DSLs, there is no clear expansion timing between two adjacent DSL layers.

```lisp
(ql:quickload :lisp-namespace)
(use-package :lisp-namespace)

(define-namespace dsl1)
(define-namespace dsl2)

(defun dsl1-expand (code)
  (if (consp code)
      (destructuring-bind (name . args) code
	(if (dsl1-boundp name)
	    (dsl1-expand (funcall (symbol-dsl1 name) args))
	    (cons name
		  (loop for a in args
			collect (dsl1-expand a)))))
      code))

(defun dsl2-expand (code)
  (if (consp code)
      (destructuring-bind (name . args) code
	(if (dsl2-boundp name)
	    (dsl2-expand (funcall (symbol-dsl2 name) args))
	    (cons name
		  (loop for a in args
			collect (dsl2-expand a)))))
      code))

(setf (symbol-dsl1 'test) 
      (lambda (args) (declare (ignorable args)) "test dsl1"))

(setf (symbol-dsl2 'test) 
      (lambda (args) (declare (ignorable args)) "test dsl2"))
;; Suppose dsl2 needs to expand first, then the result is given to dsl1 to expand
(dsl1-expand (dsl2-expand '(test)))
;; At this point, because the function names conflict between the two layers, the expression cannot be preserved until dsl1 expands
```

`dsl-quote` provides a preservation mechanism, modeled after Common Lisp's `quote`, `quasiquote`, and `comma`.

## Usage

`dsl-quote`, or `dq` for short, is like `quote` but can take multiple values. It is used to specify that the current layer should preserve expressions without expanding them.  
`dsl-quasiquote`, or `dqq` for short, is like `quasiquote` but can take multiple values. Inside it, `dsl-comma` can be used for local expansion, and it can be nested multiple levels.  
`dsl-comma`, or `dc` for short, is like `comma`, but can take multiple values and performs local expansion inside `quasiquote`.  
`dsl-progn` is the same as `progn`, used for distinction.  
`dsl-expand` performs `dsl` expansion.  
`with-dsl` expands the return value of `body` as DSL code.

## Examples

In the problem description at the beginning, you can write the call to the `test` function of `dsl1` like this:

```lisp
(define-namespace dsl1)
(define-namespace dsl2)

;; No need for recursive expansion; dsl-expand will recurse as appropriate. If expansion succeeds, the second return value should be t
(defun dsl1-expand (code)
  (destructuring-bind (name . args) code
    (if (dsl1-boundp name)
	(values (funcall (symbol-dsl1 name) args) t)
	code)))

(defun dsl2-expand (code)
  (destructuring-bind (name . args) code
    (if (dsl2-boundp name)
	(values (funcall (symbol-dsl2 name) args) t)
	code)))

(setf (symbol-dsl1 'test) 
      (lambda (args) (declare (ignorable args)) "test dsl1"))

(setf (symbol-dsl2 'test) 
      (lambda (args) (declare (ignorable args)) "test dsl2"))

(with-dsl (dsl1-expand) (with-dsl (dsl2-expand) '(dq (test))))
;; Returns
;;(DSL-PROGN
;;  "test dsl1")
```

Using with `spinneret` and `parenscript`:

```lisp
(define-namespace widget)

(defun widget-expand (code)
  (destructuring-bind (name . args) code
    (if (widget-boundp name)
	(values (funcall (symbol-widget name) args) t)
	code)))

(defmacro defwidget (name lambda-list &body body)
  (let ((args (gensym)))
    `(eval-when (:compile-toplevel :load-toplevel :execute)
       (setf (symbol-widget ',name)
	     (lambda (,args) 
	       (destructuring-bind ,lambda-list ,args
		 ,@body))))))

;; Here with-html will not be expanded by widget-expand, while the contents in body will be expanded by widget-expand
(defmacro with-page (&body body)
  (with-dsl (widget-expand)
    `(dqq (with-html (dc ,@body)))))

;; Here only body can be expanded by the current DSL (widget-expand here)
(defwidget defbutton (content lambda-list &body body)
  (let ((event (gensym))
	(btn-id (string-downcase (symbol-name (gensym)))))
    (destructuring-bind (content &rest other-attrs) (ensure-cons content)
      `(dqq
	(:button :type "button" :id ,btn-id ,@other-attrs ,content)
	(:script (:raw
		  (ps:ps 
		    (let ((btn (ps:chain document (get-element-by-id ,btn-id))))
		      (setf (ps:@ btn onclick)
			    (lambda (,event)
			      (with-slots ,lambda-list ,event
				(dc ,@body))))))))))))

(print (macroexpand-1 '(with-page (defbutton "click me" ()))))
;; This statement prints
;;(DSL-PROGN
;;  (WITH-HTML
;;    (:BUTTON :TYPE "button" :ID "g894" "click me")
;;    (:SCRIPT
;;     (:RAW
;;      (PARENSCRIPT:PS
;;        (LET ((BTN (PARENSCRIPT:CHAIN DOCUMENT (GET-ELEMENT-BY-ID "g894"))))
;;          (SETF (PARENSCRIPT:@ BTN ONCLICK)
;;                  (LAMBDA (#:G893)
;;                    (WITH-SLOTS NIL
;;                        #:G893)))))))))
;; It also solves the case where the inner DSL needs the outer DSL to expand first
```
## Installation

Currently, it can be used by cloning the repository and configuring it in ASDF:

```lisp
(push #p"~/path/to/dsl-quote/" asdf:*central-registry*)
(asdf:load-system "dsl-quote")
```
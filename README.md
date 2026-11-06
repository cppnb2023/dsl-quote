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
## Usage
`dsl-quote`, or `dq` for short, is similar to `quote` but can accept multiple values; it is used to specify expressions to be retained at the current level and not expanded.

`dsl-quasiquote`, or `dqq` for short, is similar to `quasiquote` but can accept multiple values. `dsl-comma` can be used inside for local expansion, and it supports multiple levels of nesting.

`dsl-comma`, or `dc` for short, is similar to `comma` but can accept multiple values, and performs local expansion inside `quasiquote`.

`dsl-progn` is the same as `progn`, and is used for distinction.

`dsl-expand` performs `dsl` expansion.

`with-dsl` transforms the return value of `body` as `DSL` code.

```lisp
(defmacro foo () '(list 1 2 3))

(with-dsl (macroexpand)
  `(append (foo) (foo)))
;; Returns
;;(APPEND (LIST 1 2 3) (LIST 1 2 3))
(with-dsl (macroexpand)
  `(append (dq (foo)) (foo)))
;; Returns
;;(APPEND (FOO) (LIST 1 2 3))
```

`with-local-dsl` defines local `DSL` code transformations.

```lisp
(with-local-dsl ((foo () "foo outer"))
  (with-local-dsl ((foo () "foo inner"))
    `(concatenate 'string (foo) (dq (foo)))))
;; Returns
;;(CONCATENATE 'STRING "foo inner" "foo outer")
(with-local-dsl ((foo (n) (declare (ignorable n)) "foo outer"))
  (with-local-dsl ((foo (&whole w n) (if (zerop n)
				"foo inner"
				`(dq ,w))))
    `(concatenate 'string (foo 1) (foo 0))))
;; Returns
;;(CONCATENATE 'STRING "foo outer" "foo inner")
```

`dsl-lambda` defines an anonymous `DSL` transformation function and supports `&whole`.

```lisp
(funcall (dsl-lambda (a b) (+ a b)) '(func 1 2))
;; Returns 3
(funcall (dsl-lambda (&whole whole a b) (list whole (+ a b))) '(func 1 2))
;; Returns
;;((FUNC 1 2) 3)
```

`define-prompt` defines IDE code hints for `DSL` transformation functions.

```lisp
(macroexpand-1 '(define-prompt (dsl-func language) (a b c &key (d 0))))
;; Returns
;;(DEFMACRO DSL-FUNC (A B C &KEY (D 0))
;;  (DECLARE (IGNORABLE A B C D))
;;  (ERROR 'SIMPLE-ERROR :FORMAT-CONTROL "~a is ~a dsl macro" :FORMAT-ARGUMENTS
;;         (LIST 'DSL-FUNC 'LANGUAGE)))
```

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
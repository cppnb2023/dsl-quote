(in-package :dsl-quote)

(declaim (ftype (function (t t t) t) dsl-expand%))

(defmacro aif2 (test then &optional else)
  (with-gensyms (win)
    `(multiple-value-bind (it ,win) ,test
       (if ,win ,then ,else))))

(defun collect-next-expand (function args quasi-num)
  (iter (for a in args)
    (aif2 (dsl-expand% function a quasi-num)
	  (appending it)
	  (collecting it))))

(defmacro dsl-progn (&body body)
  "用于区分progn，防止DSL将progn展开"
  `(progn ,@body))

(defun dsl-quote-expand (function args quasi-num)
  (if (= quasi-num 0)
      (values args t)
      `(dsl-quote ,@(collect-next-expand function args quasi-num))))

(defun dsl-quasiquote-expand (function args quasi-num)
  (if (= quasi-num 0)
      (values (collect-next-expand function args (1+ quasi-num)) t)
      `(dsl-quasiquote ,@(collect-next-expand function args (1+ quasi-num)))))

(defun dsl-comma-expand (function args quasi-num)
  (if (> quasi-num 0)
      (if (= quasi-num 1)
	  (values (collect-next-expand function args (1- quasi-num))
		  t)
	  `(dsl-comma ,@(collect-next-expand function args (1- quasi-num))))
      (error 'simple-error
	     :format-control "dsl-comma must in dsl-quasiquote ~s"
	     :format-arguments (list args))))

(defun dsl-other-expand (function code quasi-num)
  (if (= quasi-num 0)
      (aif2 (funcall function code)
	    (dsl-expand% function it quasi-num)
	    (cons (car code)
		  (collect-next-expand function (cdr code) quasi-num)))
      (cons (car code)
	    (collect-next-expand function (cdr code) quasi-num))))

(defun dsl-expand% (function tree quasi-num)
  (if (consp tree)
      (destructuring-bind (name . args) tree
	(cond
	  ((consp name)
	   (collect-next-expand function tree quasi-num))
	  ((or (eq name 'dsl-quote) (eq name 'dq))
	   (dsl-quote-expand function args quasi-num))
	  ((or (eq name 'dsl-quasiquote) (eq name 'dqq))
	   (dsl-quasiquote-expand function args quasi-num))
	  ((or (eq name 'dsl-comma) (eq name 'dc))
	   (dsl-comma-expand function args quasi-num))
	  (t (dsl-other-expand function tree quasi-num))))
      tree))

(defun dsl-expand (function tree)
  "根据function展开代码块tree
   若function成功展开第二个返回值要为t
   (defmaro foo () `(list 1 2 3))
   (dsl-expand #'macroexpand '(foo))
   返回
   (LIST 1 2 3)
   使用dsl-quote
   (dsl-expand #'macroexpand '(dq (foo)))
   返回
   (DSL-PROGN
     (FOO))
   使用dsl-quasiquote 和 dsl-comma
   (dsl-expand #'macroexpand '(dqq (foo) (dc (foo))))
   返回
   (DSL-PROGN
     (FOO)
     (LIST 1 2 3))"
  (aif2 (dsl-expand% function tree 0)
	`(dsl-progn ,@it)
	it))

(defmacro with-dsl ((func) &body body)
  "将body中的返回值作为DSL代码进行转换，返回代码本身不执行
   (defmaro foo () `(list 1 2 3))
   (with-dsl (macroexpand)
     '(dqq (foo) (dc (foo))))
   返回
   (DSL-PROGN
     (FOO)
     (LIST 1 2 3))"
  `(dsl-expand #',func (progn ,@body)))


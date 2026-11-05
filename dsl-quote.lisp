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
      (error "dsl-comma must in dsl-quasiquote")))

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
  (aif2 (dsl-expand% function tree 0)
	`(dsl-progn ,@it)
	it))

(defmacro with-dsl ((func) &body body)
  `(dsl-expand #',func (progn ,@body)))


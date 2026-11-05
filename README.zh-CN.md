# dsl-quote

## 为什么写这个
在编写多层dsl时，相邻的两个dsl层级之间没有明确的展开时机。

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
;;假如需要dsl2先展开后结果再给dsl1展开
(dsl1-expand (dsl2-expand '(test)))
;;此时由于两层之间函数名冲突，不能将表达式保留到dsl1展开
```

`dsl-quote` 提供了一个保留机制，仿照`Common Lisp`的quote，quasiquote和comma。

## 使用方法
`dsl-quote` 或简写为 `dq` 类似quote但可以传多个值，用于描述当前层保留表达式不展开。
`dsl-quasiquote` 或简写为 `dqq` 类似 `quasiquote` 但可以传多个值，内部可用 `dsl-comma` 进行局部展开，可多层嵌套
`dsl-comma` 或简写为 `dc` 类似 `comma` ，但可以传多个值，在 `quasiquote` 内部进行局部展开
`dsl-progn` 和 `progn` 一样，用于区分。
`dsl-expand` 进行 `dsl` 展开
`with-dsl` 将 `body` 返回值作为 `dsl` 代码展开

## 例子
在开头的问题描述中可以这样写调用 `dsl1` 的 `test` 函数
```lisp
(define-namespace dsl1)
(define-namespace dsl2)

;;无需递归展开，dsl-expand会根据情况进行递归，若成功展开第二个返回值要为 t
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
;;返回
;;(DSL-PROGN
;;  "test dsl1")
```

与 `spinneret` 和 `parenscript` 一起使用

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

;;在这里with-html不会被widget-expand展开，而body中的内容会被widget-expand展开
(defmacro with-page (&body body)
  (with-dsl (widget-expand)
    `(dqq (with-html (dc ,@body)))))

;;这里只有body能被当前dsl(在这里是widget-expand)展开
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
;;这个语句打印
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
;;同时也解决内层dsl需要外层dsl先展开的情况
```

## 安装
目前可以通过克隆仓库并在 ASDF 中配置使用：
```lisp
(push #p"~/path/to/dsl-quote/" asdf:*central-registry*)
(asdf:load-system "dsl-quote")
```
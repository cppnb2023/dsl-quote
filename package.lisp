(defpackage :dsl-quote
  (:use :cl :alexandria :iterate)
  (:export #:dsl-expand
	   #:dsl-quote
	   #:dsl-quasiquote
	   #:dsl-comma
	   #:dqq
	   #:dq
	   #:dc
	   #:dsl-progn
	   #:with-dsl))

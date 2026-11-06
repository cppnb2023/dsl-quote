(defpackage :dsl-quote
  (:use :cl :alexandria :iterate :let-plus :anaphora)
  (:export #:dsl-expand
	   #:dsl-quote
	   #:dsl-quasiquote
	   #:dsl-comma
	   #:dqq
	   #:dq
	   #:dc
	   #:dsl-progn
	   #:with-dsl
	   #:with-local-dsl
	   #:dsl-lambda
	   #:define-prompt))

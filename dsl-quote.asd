(defsystem "dsl-quote"
  :description "A lightweight DSL quotation and expansion engine for Common Lisp. "
  :author "cppnb2023 <zxc04039.outlook.com>"
  :license "MIT"
  :version "0.1"
  :serial t
  :depends-on ("alexandria" "iterate")
  :components ((:file "package")
	       (:file "dsl-quote")))

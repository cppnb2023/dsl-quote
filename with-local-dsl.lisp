(in-package :dsl-quote)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun get-condlet-bind-sym (bindings)
    (loop for binding in bindings
	  append (loop for bind in (rest binding)
		       collect (if (listp bind)
				   (car bind) bind)))))

(defmacro condlet* (bindings &body body)
  (let+ ((symbols (remove-duplicates (get-condlet-bind-sym bindings)))
	 ((&with-gensyms bodyfn))
	 ((&labels -> (bindings)
	    (destructuring-bind (first . rest) bindings
	      `(if ,(first first)
		   (let* ,(loop for bind in (rest first)
				collect (if (listp bind)
					    `(,(first bind) ,(second bind))
					    `(,bind nil)))
		     (,bodyfn ,@symbols))
		   ,(if rest
			(-> rest)))))))
    `(flet ((,bodyfn ,symbols ,@body))
       ,(-> bindings))))

(defmacro dsl-lambda (lambda-list &body body)
  "支持&whole的类宏，调用时要传入整块代码调用
   (funcall (dsl-lambda (a b) (list a b)) '(fname 1 2))
   返回
   (1 2)"
  (condlet* (((eq (first lambda-list) '&whole)
	      (whole-sym (second lambda-list))
	      (lambda-list (rest (rest lambda-list)))
	      (dec nil))
	     (t
	      (whole-sym (gensym))
	      (dec `(declare (ignorable ,whole-sym)))))
    `(lambda+ ((&whole ,whole-sym &ign ,@lambda-list))
       ,dec
       ,@body)))

(defmacro with-local-dsl (bindings &body body)
  "进行局部DSL代码转换，返回值是代码本身不执行
   (with-local-dsl ((foo () '(list 1 2 3))
                    (bar () '(list 4 5 6)))
     '(append (foo) (bar)))
   返回
   (append (list 1 2 3) (list 4 5 6))"
  (with-gensyms (hash)
    `(let ((,hash (make-hash-table)))
       ,@(loop for (name ll . body) in bindings
	       collect `(setf (gethash ',name ,hash)
			      (dsl-lambda ,ll ,@body)))
       (with-dsl ((lambda (code)
		    (aif (gethash (car code) ,hash)
			 (values (funcall it code) t)
			 code)))
	 ,@body))))

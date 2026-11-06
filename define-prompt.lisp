(in-package :dsl-quote)

(defun symbol&-p (sym)
  (and (symbolp sym)
       (string= (symbol-name sym) "&" :end1 1)))

(defun get-ll-arguments (ll)
  (iter (with key = nil)
    (for rest on ll)
    (for arg = (first rest))
    (cond
      ((symbol&-p arg) (setf key arg))
      ((symbolp arg) (collecting arg))
      ((listp arg)
       (case key
	 (&optional (collecting (first arg)))
	 (&key (aif (first arg)
		    (if (listp it)
			(collecting (second it))
			(collecting it))))
	 (&body (appending (get-ll-arguments arg))))))))

(defmacro define-prompt ((name language) lambda-list)
  "定义IDE DSL提示"
  `(defmacro ,name ,lambda-list
     (declare (ignorable ,@(get-ll-arguments lambda-list)))
     (error 'simple-error
	    :format-control "~a is ~a dsl macro"
	    :format-arguments (list ',name ',language))))

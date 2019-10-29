;; An expression representing an M symbol.
(def symbol-expr
  (fn name location
    (left (pair name location))))

;; An expression representing an M list.
(def list-expr
  (fn exprs location
    (right (pair exprs location))))

(defn expr.match expr symbol-expr list-expr
  (expr (with symbol-expr) (with list-expr)))

(defn expr.path expr
  (expr.match expr
    (fn _ l (location.path l))
    (fn _ l (location.path l))))

(defn expr.start expr
  (expr.match expr
    (fn _ l (span.from (location.span l)))
    (fn _ l (span.from (location.span l)))))

(defn expr.end expr
  (expr.match expr
    (fn _ l (span.to (location.span l)))
    (fn _ l (span.to (location.span l)))))

;; Changes the path of an expr.
(defnrec expr.with-path path expr
  (expr.match expr
    (fn name l (symbol-expr name (location path (location.span l))))
    (fn exprs l (list-expr (map exprs (expr.with-path path)) (location path (location.span l))))))

(def expr/symbol
  (fn name
    (symbol-expr name (location (symbol expr.m) (span start-position start-position)))))

(def expr/list
  (fn exprs
    (list-expr exprs (location (symbol expr.m) (span start-position start-position)))))

(defn expr/match expr symbol-fn list-fn
  (expr.match expr
    (fn symbol _ (symbol-fn symbol))
    (fn list _ (list-fn list))))

(def expr/nil
  (expr/list nil))

(defn expr/cons car cdr
  (expr/match cdr
    (fn _ (expr/cons car (expr/list (list cdr))))
    (fn list-cdr
      (expr/list (cons car list-cdr)))))

(defn expr/prepend-list expr list
  (expr/match expr
    (fn _ (expr/prepend-list (expr/list (list expr)) list))
    (fn exprs
      (expr/list (concat list exprs)))))

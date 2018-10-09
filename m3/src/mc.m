;; The singleton truthy value, for which `(if true x y)` evaluates to x.
(def true)

;; The singleton falsy value, for which `(if false x y)` evaluates to y.
(def false)

;; The singleton empty list.
(def nil)

;; Appends an element to a list.
(def cons)

;; The first element in a list.
(def car)

;; The rest of the elements in a list.
(def cdr)

;; Adds two integers.
(def add-int)

;; Converts a symbol to an int.
(def symbol->int)

;; Tests if two characters are equal.
(def eq-char)

;; Converts an integer to a character.
(def int->char)

;; Converts a symbol to a character.
(def symbol->char)

;; Tests if two symbols are equal.
(def eq-symbol)

;; A symbol representing the type of a value.
(def type-name)

;; Creates data given a type, a list of field names, and a list of field values.
(def new-data)

;; Accesses a field of data given its name.
(def field)

;; Combines two processes, running them one after another.
(def then-run)

;; Runs a function in a process.
(def run-with)

;; Runs a function which produces a process in a process, then combines them.
(def then-run-with)

;; Runs a process at top level.
(def run-unsafe)

;; Gets a file's data given its name.
(def file)

;; The list of arguments passed to the program.
(def args)

;; Generates the output code given an M tree.
(def generate)

;; A pair of two values.
(def pair
  (new-data (symbol pair)
    (cons (symbol first)
    (cons (symbol second)
      nil))))

;; Creates a pair of two values.
(def new-pair
  (lambda first second
    (pair (cons first (cons second nil)))))

;; The first value in a pair.
(def first (field (symbol first)))

;; The second value in a pair.
(def second (field (symbol second)))

;; True if [x] and [y] are true.
(def and
  (lambda x y
    (if x (y nil) false)))

;; True if [x] or [y] is true.
(def or
  (lambda x y
    (if x true (y nil))))

;; True if [x] is false.
(def not
  (lambda x
    (if x false true)))

;; Composes two functions [f] and [g].
(def compose
  (lambda f g
    (lambda x
      (f (g x)))))

;; Tests if a value is the empty list.
(def is-nil
  (lambda x
    (eq-symbol (type-name x) (symbol nil))))

;; The second element in a list.
(def cadr (compose car cdr))

;; A parse result representing failure.
(def parse-failure
  (new-data (symbol parse-failure)
    (cons (symbol state)
      nil)))

;; Creates a new parse failure.
(def new-parse-failure
  (lambda state
    (parse-failure (cons state nil))))

(def parse-failure.state (field (symbol state)))

;; A parse result representing success.
(def parse-success
  (new-data (symbol parse-success)
    (cons (symbol value)
    (cons (symbol state)
    (cons (symbol rest)
      nil)))))

;; Creates a new parse success.
(def new-parse-success
  (lambda value state rest
    (parse-success (cons value (cons state (cons rest nil))))))

(def parse-success.value (field (symbol value)))
(def parse-success.state (field (symbol state)))
(def parse-success.rest (field (symbol rest)))

;; Tests if a value is a parse success.
(def is-parse-success
  (lambda x
    (eq-symbol (type-name x) (symbol parse-success))))

;; A parser which succeeds only if [f] of the next element is true.
(def predicate-parser
  (lambda f
    (lambda input state
      (if (and (not (is-nil input))
               (lambda (f (car input))))
        (new-parse-success (car input) state (cdr input))
        (new-parse-failure state)))))

;; A parser which always succeeds.
(def success-parser (predicate-parser (lambda true)))

;; Maps [parser]'s result with the function [f].
(def map-parser
  (lambda parser f
    (lambda input state
      (f (parser input state)))))

;; Maps [parser]'s result with the function [f] if the result is a success.
(def map-parser-success
  (lambda parser f
    (map-parser parser
      (lambda result
        (if (is-parse-success result)
          (f result)
          result)))))

;; Maps [parser]'s result's value with the function [f].
(def map-parser-value
  (lambda parser f
    (map-parser-success parser
      (lambda success
        (new-parse-success
          (f (parse-success.value success))
          (parse-success.state success)
          (parse-success.rest success))))))

;; Maps [parser]'s result's state with the function [f].
(def map-parser-state
  (lambda parser f
    (map-parser-success parser
      (lambda success
        (new-parse-success
          (parse-success.value success)
          (f (parse-success.state success))
          (parse-success.rest success))))))

;; Provides the state before [parser] was run.
(def provide-past-state
  (lambda parser
    (lambda input state
      ((map-parser-value parser
        (lambda value
          (new-pair value state)))
      input state))))

;; Combines [parser1] and [parser2].
(def combine-parser
  (lambda parser1 parser2
    (lambda input state
      ((lambda parser1-result
        (if (is-parse-success parser1-result)
          ((lambda parser2-result
            (if (is-parse-success parser2-result)
              (new-parse-success
                (new-pair
                  (parse-success.value parser1-result)
                  (parse-success.value parser2-result))
                (parse-success.state parser2-result)
                (parse-success.rest parser2-result))
              parser2-result))
          (parser2
            (parse-success.rest parser1-result)
            (parse-success.state parser1-result)))
          parser1-result))
      (parser1 input state)))))

;; Combines [parser1] and [parser2], deferring to parser1's result.
(def combine-parser-left
  (lambda parser1 parser2
    (map-parser-value (combine-parser parser1 parser2) first)))

;; Combines [parser1] and [parser2], deferring to parser2's result.
(def combine-parser-right
  (lambda parser1 parser2
    (map-parser-value (combine-parser parser1 parser2) second)))

;; Parses a list of [parser].
(def repeat-parser
  (lambda parser
    (lambda input state
      ((lambda result
        (if (is-parse-success result)
          ((lambda rest-result
            (new-parse-success
              (cons
                (parse-success.value result)
                (parse-success.value rest-result))
              (parse-success.state rest-result)
              (parse-success.rest rest-result)))
          (repeat-parser parser
            (parse-success.rest result)
            (parse-success.state result)))
          (new-parse-success nil state input)))
      (parser input state)))))

;; Parses a non empty list of [parser].
(def repeat-parser1
  (lambda parser
    (map-parser-value
      (combine-parser parser (repeat-parser parser))
        (lambda pair
          (cons (first pair) (second pair))))))

;; Parses [parser2] if [parser1] fails.
(def alternative-parser
  (lambda parser1 parser2
    (lambda input state
      ((lambda parser1-result
        (if (is-parse-success parser1-result)
          parser1-result
          (parser2 input state)))
      (parser1 input state)))))

;; A parser whose implementation is only evaluated once it is called.
(def lazy-parser
  (lambda parser input state
    ((parser nil) input state)))

;; An expression representing an M identifier.
(def identifier-expr
  (new-data (symbol identifier-expr)
    (cons (symbol name)
    (cons (symbol line)
      nil))))

;; Creates a new identifier expression.
(def new-identifier-expr
  (lambda name line
    (identifier-expr (cons name (cons line nil)))))

(def identifier-expr.name (field (symbol name)))
(def identifier-expr.line (field (symbol line)))

;; An expression representing an M list.
(def list-expr
  (new-data (symbol list-expr)
    (cons (symbol exprs)
    (cons (symbol line)
      nil))))

;; Creates a new list expression.
(def new-list-expr
  (lambda exprs line
    (list-expr (cons exprs (cons line nil)))))

(def list-expr.exprs (field (symbol exprs)))
(def list-expr.line (field (symbol line)))

;; The literal number 1.
(def one (symbol->int (symbol 1)))

;; The literal character "(".
(def open-parentheses (symbol->char (symbol "(")))

;; The literal character ")".
(def close-parentheses (symbol->char (symbol ")")))

;; The literal character ";".
(def semicolon (symbol->char (symbol ";")))

;; The literal character "\"".
(def quote (symbol->char (symbol "\"")))

;; The literal character "\\".
(def backslash (symbol->char (symbol "\\")))

;; The literal character " ".
(def space (symbol->char (symbol " ")))

;; The literal character "\b".
(def backspace (symbol->char (symbol "\b")))

;; The literal character "\t".
(def tab (symbol->char (symbol "\t")))

;; The literal character "\n".
(def linefeed (symbol->char (symbol "\n")))

;; The literal character "\v".
(def vtab (symbol->char (symbol "\v")))

;; The literal character "\f".
(def formfeed (symbol->char (symbol "\f")))

;; The literal character "\r".
(def carriage-return (symbol->char (symbol "\r")))

;; The literal character "b".
(def letter-b (symbol->char (symbol "b")))

;; The literal character "t".
(def letter-t (symbol->char (symbol "t")))

;; The literal character "n".
(def letter-n (symbol->char (symbol "n")))

;; The literal character "v".
(def letter-v (symbol->char (symbol "v")))

;; The literal character "f".
(def letter-f (symbol->char (symbol "f")))

;; The literal character "r".
(def letter-r (symbol->char (symbol "r")))

;; True if a character is "\r", "\n", or "\f".
(def is-newline
  (lambda char
    (or (eq-char char linefeed)
        (lambda
          (or (eq-char char carriage-return)
              (lambda
                (eq-char char formfeed)))))))

;; True if a character is a newline, " ", "\t", or "\v".
(def is-whitespace
  (lambda char
    (or (is-newline char)
        (lambda
          (or (eq-char char space)
              (lambda
                (or (eq-char char tab)
                    (lambda (eq-char char vtab)))))))))

;; True if a character is part of an identifier.
(def is-identifier-character
  (lambda char
    (not
      (or (is-whitespace char)
          (lambda
            (or (eq-char char open-parentheses)
                (lambda
                  (eq-char char close-parentheses))))))))

;; Maps an escape code to its character.
(def escape-map
  (lambda char
    (if (eq-char char letter-b) backspace
    (if (eq-char char letter-t) tab
    (if (eq-char char letter-n) linefeed
    (if (eq-char char letter-v) vtab
    (if (eq-char char letter-f) formfeed
    (if (eq-char char letter-r) carriage-return
      char))))))))

;; Reads the contents of a file as a list of characters.
(def file.read (field (symbol read)))

;; Parses a single character.
(def char-parser
  (lambda char
    (predicate-parser (eq-char char))))

;; Parses a newline character.
(def newline-parser
  (map-parser-state
    (predicate-parser is-newline)
    (add-int one)))

;; Parses a whitespace character.
(def whitespace-parser
  (alternative-parser
    newline-parser
    (predicate-parser is-whitespace)))

;; Parses a comment.
(def comment-parser
  (combine-parser
    (predicate-parser (eq-char semicolon))
    (repeat-parser (predicate-parser (compose not is-newline)))))

;; Wraps [parser] to ignore whitepace and comments.
(def ignore-unused
  (lambda parser
    (combine-parser-right
      (repeat-parser (alternative-parser whitespace-parser comment-parser))
      parser)))

(def parser)

;; Parses a single identifier character.
(def identifier-char-parser
  (predicate-parser is-identifier-character))

;; Parses an escape character in an identifier literal.
(def identifier-literal-escape-parser
  (combine-parser-right (char-parser backslash)
    (map-parser-value success-parser escape-map)))

;; Parses a single identifier literal character.
(def identifier-literal-char-parser
  (predicate-parser (compose not (eq-char quote))))

;; Parses an identifier literal.
(def identifier-literal-parser
  (combine-parser-right
    (char-parser quote)
    (combine-parser-left
      (repeat-parser
        (alternative-parser
          identifier-literal-escape-parser
          identifier-literal-char-parser))
      (char-parser quote))))

;; Parses an identifier expression.
(def identifier-expr-parser
  (ignore-unused
    (map-parser-value
      (provide-past-state
        (alternative-parser
          identifier-literal-parser
          (repeat-parser1 identifier-char-parser)))
      (lambda pair
        (new-identifier-expr (first pair) (second pair))))))

;; Parses a list expression.
(def list-expr-parser
  (ignore-unused
    (map-parser-value
      (provide-past-state
        (combine-parser-right
          (char-parser open-parentheses)
          (combine-parser-left
            (lazy-parser (lambda parser))
            (char-parser close-parentheses))))
      (lambda pair
        (new-list-expr (first pair) (second pair))))))

;; Parses an M expression.
(def expr-parser
  (alternative-parser
    identifier-expr-parser
    list-expr-parser))

;; Parses an M file.
(def parser
  (repeat-parser expr-parser))

;; The result of parsing an M file.
(def parse
  (lambda input
    (parse-success.value
      (parser input one))))

;; Compiles [in-file], writing the generated code to [out-file].
(def compile
  (lambda in-file out-file
    (run-with (file.read in-file)
      (lambda char-stream
        (generate in-file out-file
          (parse char-stream))))))

(run-unsafe
  (compile
    (file (car args))
    (file (cadr args))))
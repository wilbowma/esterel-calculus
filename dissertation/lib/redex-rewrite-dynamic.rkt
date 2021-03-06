#lang racket

(provide with-paper-rewriters/proc render-op text mf-t)
(require (except-in esterel-calculus/redex/model/shared quasiquote)
         esterel-calculus/redex/model/instant
         (prefix-in calculus: esterel-calculus/redex/model/calculus)
         (prefix-in standard: esterel-calculus/redex/model/reduction)
         pict
         (prefix-in pict: pict)
         redex/pict
         "util.rkt"
         (except-in "proof-extras.rkt" =)
         syntax/parse/define
         (for-syntax syntax/parse)
         "redex-rewrite.rkt"
         pict/convert)

(define (lift-to-taggable pict tag)
  (if (pict+tag? pict)
      (pict+tag (pict+tag-pict pict) tag)
      (pict+tag pict tag)))
  
(define (text t f [s 12] #:kern? [kern? #t])  
  (lift-to-taggable
   (if kern?
       (kern-text t f s)
       (pict:text t f s))
   t))

(define (kern-text t f s)
  (define split (breakout-manual-adjustment t))
  (apply hbl-append
         (for/list ([segement (in-list split)])
           (if (or (pict-convertible? segement) (pict? segement))
               segement
               (pict:text segement f s)))))

(define (breakout-manual-adjustment t)
  (define (stringify x)
    (apply string (reverse x)))
  (for/fold ([current empty]
             [all empty]
             #:result (reverse (cons (stringify current) all)))
            ([c (in-string t)])
    (match (hash-ref adjustment-table c c)
      [(or (? pict-convertible? x) (? pict? x))
       (values empty (list* x (stringify current) all))]
      [(? char? c) (values (cons c current) all)])))



(define hookup
  (drop-below-ascent
   (text "⇀" Linux-Liberterine-name (default-font-size) #:kern? #f)
   2))
(define hookdown
  (drop-below-ascent
   (text "⇁" Linux-Liberterine-name (default-font-size)  #:kern? #f)
   2))
(define right
  (text "⟶" Linux-Liberterine-name (default-font-size)  #:kern? #f))

(define adjustment-table
  (hash
   #\⇀ hookup
   #\⇁ hookdown
   #\⟶ right))

(define (reduction-arrow)
  (match (continuation-mark-set-first (current-continuation-marks) 'current-reduction-arrow)
    [(or #f 'calculus)
     (render-op/instructions
      hookup
      `((superscript E)))]
    ['standard-reduction
     (render-op/instructions
      hookdown
      `((superscript E)))]
    ['circuit
     (render-op/instructions
      hookup
      `((superscript C)))]
    ['lambda
     (render-op/instructions
      hookup
      `((superscript λ)))]
    ['state
     (render-op/instructions
      hookup
      `((superscript σ)))]))

(set-arrow-pict! '--> reduction-arrow)


(define (render-op p [x #f])
  (define s (~a (if x x p)))
  (define head
    (hbl-append
     (if x p (blank))
     (match (regexp-match* #rx"^[^^_]*" s)
       [(cons r _) (words r)]
       [_ (blank)])))
  (define tails (regexp-match* #rx"(_|\\^)[^^_]*" s))
  (render-op/instructions head tails))

(define (render-op/instructions base ss)
  (define-values (supers subs seq)
    (for/fold ([super empty]
               [sub empty]
               [seq empty]
               #:result (values (reverse super) (reverse sub) (reverse seq)))
              ([s (in-list ss)])
      (match s
        [(or (regexp #rx"\\^(.*)" (list _ r))
             (list 'superscript r))
         (values (cons r super) sub (cons r seq))]
        [(or (regexp #rx"_(.*)" (list _ r))
             (list 'subscript r))
         (values super (cons r sub) (cons r seq))])))
  (define the-super (typeset-supers supers))
  (define the-sub (typeset-subs subs))
  (lift-to-taggable
   (inset
    (refocus
     (hbl-append
      (refocus (hbl-append base the-sub) base)
      the-super)
     base)
    0
    0
    (max (pict-width the-sub) (pict-width the-super))
    0)
   (compute-tag base seq)))

(define (compute-tag base ss)
  (define (to-string x)
    ((match x
       [(? string?) values]
       [(or (? number?) (? symbol?)) ~a]
       [(? lw?) (const "")]
       [(? pict+tag?) pict+tag-tag]
       [(? pict?) compute-tag2])
     x))
  (apply
   string-append
   (to-string base)
   (map to-string ss)))

(define (compute-tag2 p)
  (or (compute-tag2* p) ""))

(define (compute-tag2* p)
  (cond
    [(and (converted-pict? p)
          (pict+tag? (converted-pict-parent p)))
     (pict+tag-tag (converted-pict-parent p))]
    [else
     (let loop ([v #f]
                [l (pict-children p)])
       (cond
         [(empty? l) v]
         [else
          (define x (compute-tag2 (child-pict (first l))))
          (define next
            (cond
              [(and x v)
               (string-append v x)]
              [else (or x v)]))
          (loop next (rest l))]))]))
    
(define (typeset-supers s)
  (render-word-sequence (blank) s +2/5))
(define (typeset-subs s)
  (render-word-sequence (blank) s -2/5))
(define (render-word-sequence base s l)
  (define p 
    (for/fold ([p base])
              ([s (in-list s)])
      (hbl-append
       p
       (scale
        (cond [(string? s) (words s)]
              [(or (number? s) (symbol? s)) (words (~a s))]
              [(pict-convertible? s) s]
              [(lw? s) (render-lw esterel/typeset s)]
              [else (error 'render-op "don't know how to render ~v" s)])
        .7))))
  (lift-bottom-relative-to-baseline
   p
   (* l (pict-height p))))

   

(define (binop op lws)
  (define left (list-ref lws 2))
  (define right (list-ref lws 3))
  (append (do-binop op left right)
          (list right "")))
(define (do-binop op left right [splice #f])
  (define space (text " " (default-style) (default-font-size)))
  (append (list  "")
          (if splice (list splice (just-after left splice)) (list left))
          (list
           (just-after
            (hbl-append
             space
             (if (pict-convertible? op) op (render-op op))
             space)
            left))
          (list "")))
(define (infix op lws)
  (define all (reverse (rest (reverse (rest (rest lws))))))
  (collapse-consecutive-spaces
   (let loop ([all all])
     (match all
       [(list* x (and dots (struct* lw ([e (or '... "...")]))) y rst)
        (append (do-binop op dots y x) (list "")
                (loop (cons y rst)))]
       [(list* x (and dots (struct* lw ([e (or '... "...")]))) rst)
        (list x dots "")]
       [(list* x y rst)
        (append (do-binop op x y) (list "")
                (loop (cons y rst)))]
       [(list x) (list x "")]))))

(define (collapse-consecutive-spaces l)
  (match l
    [(or (list _) (list)) l]
    [(list* "" "" r)
     (collapse-consecutive-spaces (cons "" r))]
    [(cons a b)
     (cons a (collapse-consecutive-spaces b))]))
(define (prefix op lws)
  (define x (list-ref lws 2))
  (list "" (render-op op) #;(just-before op x) x))
(define (replace-font param)
  (let loop ([x (param)])
    (cond
      [(cons? x) (cons (car x) (loop (cdr x)))]
      [else Linux-Liberterine-name])))
(define (def-t str) (text str (default-style) (default-font-size)))
(define (mf-t str) (text str (metafunction-style) (metafunction-font-size)))
(define (nt-t str) (text str (non-terminal-style) (default-font-size)))
(define (nt-sub-t str) (text str (cons 'subscript (non-terminal-style)) (default-font-size)))
(define (literal-t str) (text str (literal-style) (default-font-size)))
(define (par-⊓-pict) (hbl-append (def-t "⊓") (inset (def-t "∥") 0 0 0 -6)))
(define (index-notation lws field)
  (match lws
    [(list open -> (lw can a b c d e f) close)
     (render-can can field)]))
(define (render-can lws [super? #f])
  (define do-rho?
    (match (if (symbol? lws) lws (lw-e (list-ref lws 1)))
      ['Can-θ #t]
      ['Can #f]))
  (cond
    [(symbol? lws)
     (list (Can-name-pict do-rho? super?))]
    [else
     (define arg1 (list-ref lws 2))
     (define arg2 (list-ref lws 3))
     (list (hbl-append (Can-name-pict do-rho? super?)
                       ((white-square-bracket) #t))
           arg1
           ", "
           arg2
           ((white-square-bracket) #f))]))
(define (down-super-n)
  (hbl-append (def-t "↓")
              (text "κ" (cons 'superscript (default-style)) (default-font-size))
              (def-t " ")))
(define (down-super-p)
  (hbl-append (def-t "↓")
              (text "p" (cons 'superscript (default-style)) (default-font-size))
              (def-t " ")))
(define (θ-ref-x-typeset lws)
  (define θ (list-ref lws 2))
  (define x (list-ref lws 3))
  (define ev (list-ref lws 4))
  (list "" θ "(" x ") = " ev ""))
(define (¬θ-ref-x-typeset lws)
  (define θ (list-ref lws 2))
  (define x (list-ref lws 3))
  (define ev (list-ref lws 4))
  (list "" θ "(" x ") ≠ " ev ""))

(define (assert-no-underscore who what s)
  (unless (no-underscore? s)
    (error 'redex-rewrite.rkt
           "cannot typeset ~a unless the ~a argument is an identifier with no _, got ~s"
           who
           what
           s)))
(define (no-underscore? s)
  (and (symbol? s)
       (not (regexp-match #rx"_" (symbol->string s)))))

(define (θ/c-pict)
  (hbl-append (text "θ" (non-terminal-style) (default-font-size))
              (text "c"
                    (cons 'superscript (default-style))
                    (round (* #e1.2 (default-font-size))))))

(define (in-dom-st-thing-is who what dom-ele equals-what lws)
  (define θ (list-ref lws 2))
  #;(assert-no-underscore who what (lw-e θ))
  (define θc-pict (text (~a (lw-e θ)) (non-terminal-style) (default-font-size)))
  (list
   (hbl-append
    (def-t "{ ")
    (text dom-ele (non-terminal-style) (default-font-size))
    (def-t " ∈ dom("))
   θ
   (hbl-append
    (blank 2 0)
    (def-t ") | ")
    (θ/c-pict)
    (blank 1 0)
    (def-t "(")
    (text dom-ele (non-terminal-style) (default-font-size))
    (def-t ") = ")
    equals-what
    (def-t " }"))))

(define alt-ρ-text "ϱ")
(define (alt-ρ) (text alt-ρ-text (default-style) (default-font-size)))

(define (in-dom-st-signals-are who what equals-what lws)
  (in-dom-st-thing-is who what "S"
                      (text equals-what (literal-style) (default-font-size))
                      lws))

(define (in-dom-st-shrd-are-unready who what lws)
  (define res
    (in-dom-st-thing-is who what "s"
                        (hbl-append (def-t "⟨")
                                    (nt-t "ev")
                                    (def-t " , ")
                                    (nt-t "shared-status")
                                    (def-t "⟩"))
                        lws))
  (define extension
    (hbl-append (def-t ", ")
                (nt-t "shared-status")
                (def-t " ∈ {")
                (literal-t "new")
                (def-t " , ")
                (literal-t "old")
                (def-t "}")))
  (append (reverse (cdr (reverse res)))
          (list (hbl-append (last res) extension))))

(define (L-S-pict) (Setof-an-nt "S"))
(define (L-s-pict) (Setof-an-nt "s"))
(define (L-x-pict) (Setof-an-nt "x"))
(define (L-K-pict) (Setof-an-nt "κ"))
(define (Setof-an-nt nt-name)
  (nt-t
   (case nt-name
     [("S") "𝕊"]
     [("s") "𝕤"]
     [("x") "𝕩"]
     [("κ") "𝕜"])))
(define (Can-result-pict)
  (hbl-append (def-t "{ S: ")
              (L-S-pict)
              (def-t ", K: ")
              (L-K-pict)
              (def-t ", sh: ")
              (L-s-pict)
              (def-t " }")))
  
(define (loop^stop-pict)
  (define base-seq (literal-t "loop"))
  (define w (pict-width base-seq))
  (define h (pict-height base-seq))
  (define height-mod #e.5)
  (define w-inset #e.1)
  ;; a little more space to avoid the `l`
  (define w-left-offset #e.12)
  (define bar
    (dc
     (λ (dc dx dy)
       (send dc draw-line
             (+ dx (* w (+ w-left-offset w-inset)))
             dy
             (- (+ dx w) (* w w-inset))
             dy))
     w 1))
  (refocus (lbl-superimpose (vc-append (linewidth (round (* h 1/10)) bar)
                                       (blank 0 (* h height-mod)))
                            base-seq)
           base-seq))

(define (≃-pict x)
  (render-op/instructions
   (text "≃" (metafunction-style) (default-font-size))
   `((superscript ,(text x (metafunction-style) (default-font-size))))))
     
(define (eval-pict x)
  (render-op/instructions
   (text "eval" (metafunction-style) (default-font-size))
   `((superscript ,x))))

(define (eval-e-pict)
  (eval-pict "E"))
(define (eval-c-pict)
  (eval-pict "C"))
(define (eval-h-pict)
  (eval-pict "H"))
(define (≃-e-pict)
  (≃-pict "E"))
(define (≃-c-pict)
  (≃-pict "C"))

(define (sized-↬-pict)
  (define ↬-pict (nt-t "↬"))
  (define x-pict (nt-t "x"))
  (inset (refocus (lbl-superimpose ↬-pict (ghost x-pict))
                  x-pict)
         0 0
         (- (pict-width ↬-pict) (pict-width x-pict))
         0))
(define (Can-θ-name-pict [super #f])
  (Can-name-pict #t super))

(define (Can-name-pict do-rho? [super #f])
  (render-op/instructions
   (mf-t "Can")
   (append
    (if do-rho? `((subscript ,alt-ρ-text)) `())
    (if super `((superscript ,super)) empty))))

(define (CB-judgment-pict)
  (hbl-append
   (text "⊢" (default-style) (default-font-size))
   (text "CB" (cons 'subscript (default-style)) (default-font-size))))

(define (plus-equals) (hbl-append -1 (def-t "+") (def-t "=")))


(define (blocked-pict)
  (hbl-append
   (text "⊢" (default-style) (default-font-size))
   (text "B" (cons 'subscript (default-style)) (default-font-size))))
(define (not-blocked-pict)
  (hbl-append
   (text "⊬" (default-style) (default-font-size))
   (text "B" (cons 'subscript (default-style)) (default-font-size))))


(define (with-paper-rewriters/proc thunk)

  ;                                                                                  
  ;                                                                                  
  ;                                                                                  
  ;      ;;;;                                                                     ;  
  ;    ;;   ;;                                                                    ;  
  ;    ;                                                                          ;  
  ;   ;;          ;;;;    ; ;; ;;    ; ;;;      ;;;;     ;    ;    ; ;;;      ;;; ;  
  ;   ;;         ;;  ;;   ;; ;; ;;   ;;  ;;    ;;  ;;    ;    ;    ;;  ;;    ;;  ;;  
  ;   ;         ;;    ;   ;  ;   ;   ;    ;   ;;    ;    ;    ;    ;    ;   ;;    ;  
  ;   ;         ;;    ;   ;  ;   ;   ;    ;   ;;    ;    ;    ;    ;    ;   ;;    ;  
  ;   ;;        ;;    ;   ;  ;   ;   ;    ;   ;;    ;    ;    ;    ;    ;   ;;    ;  
  ;   ;;        ;;    ;   ;  ;   ;   ;    ;   ;;    ;    ;    ;    ;    ;   ;;    ;  
  ;    ;        ;;    ;   ;  ;   ;   ;    ;   ;;    ;    ;    ;    ;    ;   ;;    ;  
  ;    ;;   ;;   ;;  ;;   ;  ;   ;   ;;  ;;    ;;  ;;    ;   ;;    ;    ;    ;;  ;;  
  ;      ;;;;     ;;;;    ;  ;   ;   ;;;;;      ;;;;     ;;;; ;    ;    ;     ;;; ;  
  ;                                  ;                                               
  ;                                  ;                                               
  ;                                  ;                                               
  ;                                                                                  
  ;                                                                                  

  (with-compound-rewriters
   (['≡e
     (λ (lws)
       (list ""
             (list-ref lws 5)
             (just-after " ≡e " (list-ref lws 5))
             (list-ref lws 6)
             ""))]
    ['≡
     (curry binop "≡^E")]
    ['≡j
     (curry binop "≡^E")]
     ['⇀j
     (curry binop "⇀^E")]
    ['≃
     (curry binop "≃")]
    ['≃λ (curry binop (≃-pict "λ"))]
    ['¬≃
     (curry binop "≄")]
    ['>
     (curry binop ">")]
    ['<
     (curry binop "<")]
    ['⊆
     (curry binop "⊆")]
    
    ['update
     (lambda (lws)
       (match-define (list open update cs w B close) lws)
       (list "" cs " ← " "{ " w " ↦ " B " }"))]
    ['wire-in
     (lambda (lws)
       (match-define (list open name w c close) lws)
       (list w
             " ∈ "
             (hbl-append (mf-t "dom")
                         ((white-square-bracket) #t))
             c
             ((white-square-bracket) #f)))]
    ['eval^boolean
     (lambda (lws)
       (match-define (list open eval cs of b close) lws)
       (list "" cs " ⊢ " of " ↪ " b ""))]
    ['circuit-of (lambda (lws) (list (es c)))]
    
    ['Eval
     (λ (lws)
       (list (hbl-append (text "Eval" (metafunction-style) (default-font-size))
                         (text "(" (default-style) (default-font-size)))
             (list-ref lws 5)
             " , "
             (list-ref lws 6)
             ") = "
             (list-ref lws 7)
             ""))]
    ['if
     (λ (lws)
       (match lws
         [(list open _ rest ...)
          (list* open "if0" " " rest)]))]

    ['Lflatten
     (lambda (lws)
       (list "" (list-ref lws 2)))]
    ['i
     (lambda (lws)
       (list
        (render-op/instructions
         (render-lw esterel-eval (list-ref lws 2))
         `((superscript i)))))]
    ['o
     (lambda (lws)
       (list
        (render-op/instructions
         (render-lw esterel-eval (list-ref lws 2))
         `((superscript o)))))]
    ['K
     (lambda (lws)
       (list "K" (list-ref lws 2) ""))]
    
    ['Lpresentin
     (λ (lws)
       (in-dom-st-signals-are "Lpresentin" "θc" "present" lws))]
    ['Lget-unknown-signals
     (λ (lws)
       (in-dom-st-signals-are "Lget-unknown-signals" "θ" "unknown" lws))]
    ['Lget-unready-shared
     (λ (lws) (in-dom-st-shrd-are-unready "Lget-unready-shared" "θ" lws))]
    ['⇀
     (λ (lws)
       (list ""
             (list-ref lws 2)
             (hbl-append (def-t " ") (reduction-arrow) (def-t " "))
             (list-ref lws 3)
             ""))]
    ['⇀2
     (λ (lws)
       (list ""
             (list-ref lws 2)
             (hbl-append (def-t " ") (reduction-arrow) (def-t " "))
             (list-ref lws 3)
             ""))]
    ['⟶
     (curry binop '⟶)]
    ['⟶^s
     (curry binop '⟶^S)]
    ['⟶^r
     (curry binop '⟶^R)]
    ['⟶^c
     (curry binop '⟶^C)]
    ['⇀^r
     (curry binop '⇀^R)]
    ['⇀λ
     (curry binop '⇀^λ)]
    ['⇀λ2
     (curry binop '⇀^λ)]
    ['≡λ (curry binop '≡^λ)]
    
    ['→
     (λ (lws)
       (list ""
             (list-ref lws 3)
             (def-t " → ")
             (list-ref lws 4)
             ""))]
    ['→*
     (λ (lws)
       (list ""
             (list-ref lws 4)
             (hbl-append (def-t " →")
                         (inset (def-t "*") -2 0 0 0)
                         (def-t " "))
             (list-ref lws 5)
             ""))]
    ['CB
     (λ (lws)
       (list (hbl-append (CB-judgment-pict)
                         (text "  " (default-style) (default-font-size)))
             (list-ref lws 2)
             ""))]
    ['compile
     (λ (lws)
       (define p (list-ref lws 2))
       (list "⟦"
             p
             "⟧"))]
    ['of
     (λ (lws)
       (define p (list-ref lws 2))
       (define key (list-ref lws 3))
       (list "" p "(" key ")"))]
    ['=
     (curry infix "=")]
    ['=/checked
     (curry infix "=")]
    ['not-=
     (lambda (x) (binop "≠" x))]
    ['not-=/checked
     (lambda (x) (binop "≠" x))]
    ['δ
     (λ (lws)
       (define e (list-ref lws 2))
       (define θ (list-ref lws 3))
       (list (hbl-append 2
                         (eval-h-pict)
                         ;(text "Eval" '(italic . "Brush Script MT") 10)
                         ;(text "Eval" '"SignPainter" 10)
                         ;(text "Eval" '"Snell Roundhand" 10)
                         ((white-square-bracket) #t))
             e
             " , "
             θ
             ((white-square-bracket) #f)))]
    ['δ*
     (λ (lws)
       (define e (reverse (rest (reverse (rest (rest lws))))))
       (append (list (mf-t "δ")
                     ((white-square-bracket) #t))
               (add-between e ", ")
               (list ((white-square-bracket) #f))))]
    ['blocked-or-done
     (λ (lws)
       (define p (list-ref lws 3))
       (assert-no-underscore "blocked-or-done" "p" (lw-e p))
       (list "("
             (list-ref lws 2)
             (text " ⊢ " (default-style) (default-font-size))
             (list-ref lws 3)
             (hbl-append
              (def-t " blocked or ")
              (nt-t (~a (lw-e p)))
              (def-t " ∈ ")
              (nt-t "done")
              (def-t ")"))))]
    ['done
     (λ (lws)
       (define p (list-ref lws 2))
       (list ""
             p
             (hbl-append
              (def-t " ∈ ")
              (render-op/instructions (nt-t "p") `((superscript D))))))]
    ['blocked
     (λ (lws)
       (list ""
             (list-ref lws 2)
             "; "
             (list-ref lws 3)
             "; "
             (list-ref lws 4)
             (hbl-append
              (words " ")
              (blocked-pict))
             " "
             (list-ref lws 5)))]
    ['blocked-pure
     (λ (lws)
       (list ""
             (list-ref lws 2)
             "; "
             (list-ref lws 3)
             "; "
             (list-ref lws 4)
             (hbl-append
              (words " ")
              (blocked-pict))
             " "
             (list-ref lws 5)))]
    ['not-blocked
     (λ (lws)
       (list ""
             (list-ref lws 2)
             "; "
             (list-ref lws 3)
             "; "
             (list-ref lws 4)
             (hbl-append
              (words " ")
              (not-blocked-pict))
             " "
             (list-ref lws 5)))]

    ['blocked-e
     (λ (lws)
       (list ""
             (list-ref lws 2) "; "
             (list-ref lws 3) "; "
             (list-ref lws 4)
             (render-op "⊢_e")
             (list-ref lws 5)))]
    ['good
     (λ (lws)
       (list ""
             (list-ref lws 2)
             (text " ⊢ " (default-style) (default-font-size))
             (list-ref lws 3)
             " det"))]
    ['next-instant (λ (lws) (list (mf-t "Ɛ")
                                  ((white-square-bracket) #t)
                                  (list-ref lws 2)
                                  ((white-square-bracket) #f)))]
    ['reset-θ (λ (lws) (list "⌊" (list-ref lws 2) "⌋"))]
    ['S-code-s
     (λ (lws)
       (cond
         [(= (lw-line (list-ref lws 2))
             (lw-line (list-ref lws 3)))
          ;; the whole Can expression is on a single line
          (list "{ S = "
                (list-ref lws 2)
                ", K = "
                (list-ref lws 3)
                ", sh = "
                (list-ref lws 4)
                " }")]
         [else
          ;; the Can expression is on three single lines
          ;; so we need to line up the prefixes properly
          (define open-brace (def-t "{"))
          (define raw-S: (def-t "S = "))
          (define raw-k: (def-t "K = "))
          (define raw-sh: (def-t "sh = "))
          (define spacer (ghost (lbl-superimpose raw-S: raw-k: raw-sh:)))
          (define S: (hbl-append open-brace (rbl-superimpose raw-S: spacer)))
          (define k: (hbl-append (ghost open-brace) (rbl-superimpose raw-k: spacer)))
          (define sh: (hbl-append (ghost open-brace) (rbl-superimpose raw-sh: spacer)))
          (list ""
                (just-before S: (list-ref lws 2))
                (list-ref lws 2)
                (just-after "," (list-ref lws 2))
                (just-before k: (list-ref lws 3))
                (list-ref lws 3)
                (just-after "," (list-ref lws 3))
                (just-before sh: (list-ref lws 4))
                (list-ref lws 4)
                (just-after " }" (list-ref lws 4))
                "")]))]
    ['->S (λ (lws) (index-notation lws "S"))]
    ['->K (λ (lws) (index-notation lws "K"))]
    ['->sh (λ (lws) (index-notation lws "sh"))]
    ['all-ready?
     (λ (lws)
       (define L (list-ref lws 2))
       (define θ (list-ref lws 3))
       (define A (list-ref lws 4))
       (define p (list-ref lws 5))
       (list (hbl-append (def-t "∀ ") (nt-t "s")) " ∈ " L ". "
             (hbl-append
              (nt-t "s") (def-t " ∉ ") (es/unchecked (->sh Can-θ)) ((white-square-bracket) #t)
              (def-t "(") (alt-ρ) (def-t " ⟨"))
             θ ", " A "⟩ " p ")"
             (hbl-append (def-t ", ·") ((white-square-bracket) #f))))]
    ['distinct
     (λ (lws)
       (list ""
             (list-ref lws 2)
             (just-after " ∩" (list-ref lws 2))
             (list-ref lws 3)
             " = ∅ "))]
    ['Xs
     (λ (lws)
       (list (hbl-append (def-t "{ ")
                         (nt-t "x")
                         (def-t " | ")
                         (nt-t "x")
                         (def-t " ∈ "))
             (list-ref lws 2)
             " }"))]
    ['L2set
     (λ (lws)
       (list "{ "
             (list-ref lws 2)
             " , "
             (list-ref lws 3)
             " }"))]
    ['L1set
     (λ (lws)
       (list "{ "
             (list-ref lws 2)
             " }"))]
    ['L0set (λ (lws) (list "∅"))]
    ['Ldom
     (λ (lws)
       (list (mf-t "dom")
             ((white-square-bracket) #t)
             (list-ref lws 2)
             ((white-square-bracket) #f)))]
    ['L∈dom
     (λ (lws)
       (list ""
             (list-ref lws 2)
             " ∈ "
             (hbl-append (mf-t "dom") ((white-square-bracket) #t))
             (list-ref lws 3)
             ((white-square-bracket) #f)))]
    ['Lwithoutdom
     (λ (lws)
       (define θ (list-ref lws 2))
       (define S (list-ref lws 3))
       (list (def-t "(")
             θ
             (def-t " \\ {")
             S
             (def-t "})")))]
    ['LFV/e
     (λ (lws)
       (list (mf-t "FV")
             ((white-square-bracket) #t)
             (list-ref lws 2)
             ((white-square-bracket) #f)))]
    #;
    ['closed
     (lambda (lws)
       (list (mf-t "FV")
             ((white-square-bracket) #t)
             (list-ref lws 2)
             ((white-square-bracket) #f)
             " = ∅"))]
             
    ['Lmax*
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (define arg2 (list-ref lws 3))
       (define κ_1 (hbl-append (nt-t "κ") (nt-sub-t "1")))
       (define κ_2 (hbl-append (nt-t "κ") (nt-sub-t "2")))
       (list (hbl-append (def-t "{ ")
                         (es (max-mf κ_1 κ_2))
                         (def-t " | ")
                         κ_1
                         (def-t " ∈ "))
             arg1
             (hbl-append (def-t " , ")
                         κ_2
                         (def-t " ∈ "))
             arg2
             " }"))]
    ['Lresort
     ;; hide resort calls
     (λ (lws)
       (define arg (list-ref lws 2))
       (list "" arg ""))]
    ['max-mf
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (define arg2 (list-ref lws 3))
       (list (mf-t "max") ((white-square-bracket) #t) arg1 " , " arg2 ((white-square-bracket) #f)))]
    ['par-⊓
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (define arg2 (list-ref lws 3))
       (list "" arg1
             (let ()
               (define spacer (ghost (def-t "l")))
               (hbl-append spacer (par-⊓-pict) spacer))
             arg2 ""))]
    
    ['Lharp...
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (list
        (hbl-append (inset (def-t "{") 0 0 1 0)
                    ;;                    v   space is already included in down-super-n
                    (down-super-n) (def-t "x | x ∈ "))
        arg1 (inset (def-t "}") 2 0 0 0)))]
    ['↓
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (list (down-super-n) arg1 ""))]
    ['harp
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (list (down-super-p) arg1 ""))]
    ['greater-than-2
     (λ (lws)
       (define arg1 (list-ref lws 2))
       (list "" arg1 " > 2"))]
    ['without (λ (lws)
                (define K (list-ref lws 2))
                (define n (list-ref lws 3))
                (list "" K " \\ { " n " }"))]
    ['Can-θ (λ (lws)
              (render-can lws))]
    ['θ-ref (λ (lws)
              (define θ (list-ref lws 2))
              (define arg (list-ref lws 3))
              (list "" θ "(" arg ")"))]
    ['θ-get-S (λ (lws)
                (define θ (list-ref lws 2))
                (define arg (list-ref lws 3))
                (list "" θ "(" arg ")"))]
    ['θ-ref-S (λ (lws)
                (define θ (list-ref lws 2))
                (define S (list-ref lws 3))
                (define status (list-ref lws 4))
                (list "" θ "(" S ") = " status ""))]
    ['θ-ref-s (λ (lws)
                (define θ (list-ref lws 2))
                (define s (list-ref lws 3))
                (define ev (list-ref lws 4))
                (define shared-status (list-ref lws 5))
                (list "" θ "(" s ") = ⟨" ev " , " shared-status "⟩"))]
    ['θ-ref-x θ-ref-x-typeset]
    ['θ-ref-x-but-also-rvalue-false-is-ok-if-ev-is-zero θ-ref-x-typeset]
    ['θ-ref-S-∈ (λ (lws)
                  (define θ (list-ref lws 2))
                  (define S (list-ref lws 3))
                  (define L (list-ref lws 4))
                  (list "" θ "(" S ") ∈ " L ""))]
    ['¬θ-ref-x ¬θ-ref-x-typeset]
    ['¬θ-ref-x-and-also-not-rvalue-false ¬θ-ref-x-typeset]
    ['¬θ-ref-S
     (λ (lws)
       (define θ (list-ref lws 2))
       (define S (list-ref lws 3))
       (define status (list-ref lws 4))
       (list "" θ "(" S ") ≠ " status ""))]
    ['mtθ+S (λ (lws)
              (define S (list-ref lws 2))
              (define status (list-ref lws 3))
              (list "{ " S " ↦ " status " }"))]
    ['mtθ+s (λ (lws)
              (define s (list-ref lws 2))
              (define ev (list-ref lws 3))
              (define shared-status (list-ref lws 4))
              (list "{ " s " ↦ ⟨" ev " , " shared-status "⟩ }"))]
    ['mtθ+x (λ (lws)
              (define x (list-ref lws 2))
              (define ev (list-ref lws 3))
              (list "{ " x " ↦ " ev " }"))]

    ['add2 (λ (lws)
             (define n (list-ref lws 2))
             (list "" n "+2"))]
    ['id-but-typeset-some-parens (λ (lws) (list "(" (list-ref lws 2) ")"))]
    ['parens (λ (lws)
               (list "(" (list-ref lws 2) ")"))]
    ['∀x (λ (lws)
           (match (lw-e (list-ref lws 2))
             ["“(suc n)”" '("n+1")]
             [else
              (list ""
                    (list-ref lws 2)
                    "")]))]
    ['∀ (λ (lws)
          (define var (list-ref lws 2))
          (define body (list-ref lws 3))
          (cond
            [(= (+ 1 (lw-line var)) (lw-line body))
             (list (hbl-append (words "(") (leading-∀))
                   var
                   (build-lw "."
                             (lw-line var) (lw-line-span var)
                             (+ (lw-column var) (lw-column-span var))
                             1)
                   body ")")]
            [else
             (list (hbl-append (words "(") (leading-∀))
                   var ". " body ")")]))]
    ['sub1 (λ (lws)
             (define n (list-ref lws 2))
             (list "" n "-1"))]
    ['∃ (λ (lws)
          (define var (list-ref lws 2))
          (define type (list-ref lws 3))
          (define body (list-ref lws 4))
          (list "∃ " var ". " body ""))]
    ['ρ (λ (lws)
          (if (= (length lws) 5)
              (list (list-ref lws 0)
                    (alt-ρ) " "
                    (list-ref lws 2)
                    (just-after "." (list-ref lws 2))
                    (list-ref lws 3)
                    (list-ref lws 4))
              (list (list-ref lws 0)
                    (just-after (hbl-append (alt-ρ) (def-t " ")) (list-ref lws 0))
                    "⟨"
                    (list-ref lws 2)
                    ", "
                    (list-ref lws 3)
                    "⟩"
                    (just-after "." (list-ref lws 3))
                    (list-ref lws 4)
                    (list-ref lws 5))))]
    ['ρ1 (λ (lws)
           (list (list-ref lws 0)
                 (just-after (alt-ρ) (list-ref lws 0))
                 " "
                 (list-ref lws 2)
                 (just-after "." (list-ref lws 2))
                 (list-ref lws 3)
                 (list-ref lws 4)))]
    ['A-⊓ (λ (lws) (binop "⊓" lws))]
    ['<- (λ (lws) (binop "←" lws))]
    ;; note: Lset-sub must match Lwithoutdom / restriction's typesetting
    ['Lset-sub (λ (lws) (binop "\\" lws))]
    ['LU (λ (lws) (binop "∪" lws))]
    ['L⊂ (λ (lws) (binop "⊆" lws))]
    ['L∈ (λ (lws) (binop "∈" lws))]
    ['L∈-OI (λ (lws) (binop "∈" lws))]
    ['L∈-OI/first (λ (lws) (binop "∈" lws))]
    ['L¬∈ (λ (lws) (binop "∉" lws))]
    ['Path∈ (λ (lws) (binop "∈" lws))]
    ['different (λ (lws) (binop "≠" lws))]
    ['same (λ (lws) (binop "=" lws))]
    ['Σ (λ (lws) (infix "+" lws))]
    ['∧ (λ (lws) (infix "∧" lws))]
    ['- (λ (lws) (infix "-" lws))]
    ['<= (λ (lws) (list (list-ref lws 0)
                        (hbl-append (plus-equals) (def-t " "))
                        (list-ref lws 2)
                        (list-ref lws 3)
                        (list-ref lws 4)))]
    ['Suc (λ (lws)
            (list "1+"
                  (list-ref lws 2)))]
    ['and (curry infix '∧)]
    ['or (curry infix '∨)]
    ['=> (curry infix '⇒)]
    ['binds
     (curry binop "\\")]
    ['A->= (curry binop "≥")]
    ['not (curry prefix '¬)]

    ['eval^circuit
     (lambda (lws)
       (list (eval-c-pict)
             ((white-square-bracket) #t)
              (list-ref lws 2)
              ", "
             (list-ref lws 3)
             ((white-square-bracket) #f)))]
    ['eval^esterel
     (lambda (lws)
       (list (eval-e-pict)
             ((white-square-bracket) #t)
             (list-ref lws 2)
             ", "
             (list-ref lws 3)
             ((white-square-bracket) #f)))]
    ['evalλ
     (lambda (lws)
       (list (eval-pict "λ")
             ((white-square-bracket) #t)
             (list-ref lws 2)
             ((white-square-bracket) #f)))]
    ['≃^circuit
     (lambda (e) (binop (≃-c-pict) e))]
    ['≃^esterel
     (lambda (e) (binop (≃-e-pict) e))]
    ['circ
     (lambda (lws)
       (cons "" (infix "×" lws)))]
    ['present
     (lambda (lws)
       (match lws
         [(list* o _ r)
          (list* o
                 (text "if" (literal-style) (default-font-size))
                 " "
                 r)]))]

    ['tup
     (lambda (lws)
       (append (list "⟨")
               (infix "," lws)
               (list "⟩")))]
    ['restrict-defintion
     (lambda (_)
       (define a [es absent])
       (define b [es (θ-get-S θ S)])
       (define (mx p)
         (lbl-superimpose
          p
          (ghost a)
          (ghost b)))
       (list
        (vl-append
         (hbl-append (mx a) (def-t " where ") [es/unchecked (L∈ S O)] (def-t ", ") [es (θ-ref-S θ S ⊥)] (def-t ", and ") [es/unchecked (L¬∈ S (->S (Can-θ p ·)))])
         (hbl-append (mx b) (def-t " where ") [es/unchecked (L∈ S O)]))))]
    ['count
     (lambda (lws)
       (match-define (list _ _ body _) lws)
       (list "𝒮"
             ((white-square-bracket) #t)
             body
             ((white-square-bracket) #f)))]
    ['complete-with-respect-to
     (lambda (lws)
       (match-define (list _ _ body ... _) lws)
       `(,(mf-t "complete-wrt")
         ,((white-square-bracket) #t)
         ,@(add-between body ", ")
         ,((white-square-bracket) #f)))]

    ['all-bot
     (lambda (lws)
       (match-define (list oparen _ body ... cparen) lws)
       `(,(mf-t "nc")
         ,((white-square-bracket) #t)
         ,@(add-between body (def-t ", "))
         ,((white-square-bracket) #f)))]
    ['all-bot-rec
     (lambda (lws)
       (match-define (list oparen _ body ... cparen) lws)
       `(,(mf-t "nc-r")
         ,((white-square-bracket) #t)
         ,@(add-between body (def-t ", "))
         ,((white-square-bracket) #f)))]
    ['all-bot-S
     (lambda (lws)
       (match-define (list oparen _ body ... cparen) lws)
       `(,(mf-t "nc-S")
         ,((white-square-bracket) #t)
         ,@(add-between body (def-t ", "))
         ,((white-square-bracket) #f)))]
    ['all-bot-n
     (lambda (lws)
       (match-define (list oparen _ body ... cparen) lws)
       `(,(mf-t "nc-κ")
         ,((white-square-bracket) #t)
         ,@(add-between body (def-t ", "))
         ,((white-square-bracket) #f)))]
    ['⊥-implies-⊥-S
     (lambda (_)
       (list
        (hbl-append
         (def-t "∀ ")
         (es (L∈ S (->S (Can p-pure θ))))
         (def-t ", ")
         (es (θ-ref-S θ S ⊥))
         (def-t " ")
         (es ⇒)
         (def-t " ")
         (es (= (of cs Si) (of cs So) ⊥)))))]
    ['⊥-implies-⊥-n
     (lambda (_)
       (list
        (hbl-append
         (def-t "∀ ")
         (es (L∈ n (->K (Can p-pure θ))))
         (def-t ", ")
         (es (= (of cs (K n)) ⊥)))))]
    ['∘ (curry binop "∘")])
        
        
             
   
   ;                                                              
   ;                                                              
   ;                                              ;;              
   ;      ;;                                      ;;              
   ;     ;;;       ;;                                             
   ;     ; ;       ;;                                             
   ;     ; ;;    ;;;;;;      ;;;;    ; ;; ;;    ;;;;        ;;;   
   ;     ;  ;      ;;       ;;  ;;   ;; ;; ;;      ;      ;;   ;  
   ;    ;;  ;      ;;      ;;    ;   ;  ;   ;      ;      ;       
   ;    ;   ;;     ;;      ;;    ;   ;  ;   ;      ;      ;       
   ;    ;   ;;     ;;      ;;    ;   ;  ;   ;      ;     ;;       
   ;   ;;;;;;;     ;;      ;;    ;   ;  ;   ;      ;      ;       
   ;   ;     ;;    ;;      ;;    ;   ;  ;   ;      ;      ;       
   ;   ;     ;;    ;;  ;    ;;  ;;   ;  ;   ;      ;      ;;   ;  
   ;  ;;      ;     ;;;;     ;;;;    ;  ;   ;   ;;;;;;     ;;;;   
   ;                                                              
   ;                                                              
   ;                                                              
   ;                                                              
   ;                                                              

   (with-atomic-rewriters
    (;; for postercircuit-red-pict
     ['C^esterel (lambda () (render-op/instructions (nt-t "C") `((superscript E))))]
     ['C^js (lambda () (render-op/instructions (nt-t "C") `((superscript JS))))]
     ['e^js (lambda () (render-op/instructions (nt-t "e") `((superscript JS))))]

     ['all-bot (lambda () (mf-t "nc"))]
     ['all-bot-rec (lambda () (mf-t "nc-r"))]
     ['all-bot-S (lambda () (mf-t "nc-S"))]
     ['all-bot-n (lambda () (mf-t "nc-κ"))]
     
     ['ρ (λ () (alt-ρ))]

     ;; bring this a bit more together
     [':= (λ () (hbl-append -1 (def-t ":") (def-t "=")))]
     
     ;; we don't want `n` to look like a non-terminal
     ;; currently, ev in the redex model contains hooks
     ;; to include external values in Racket. When presenting
     ;; the calculus, we really want `ev` to be just `n`.
     ;['n (λ () (text "n" (default-style) (default-font-size)))]
     ['ev (λ () (text "n" (non-terminal-style) (default-font-size)))]
     ;; just for tagging
     ['p (λ () (text "p" (non-terminal-style) (default-font-size)))]
     ['q (λ () (text "q" (non-terminal-style) (default-font-size)))]

     ;; because · renders as {} for environment sets.
     ['dot (λ () (text "·" (default-style) (default-font-size)))]
     
     ;; render nat and mat as n and m for the proofs
     ['nat (λ () (text "n" (non-terminal-style) (default-font-size)))]
     ['mat (λ () (text "m" (non-terminal-style) (default-font-size)))]

     ;; hack to have two ρ forms
     ['ρ1 (λ () (text "ρ" (non-terminal-style) (default-font-size)))]
     
     ['reset-θ (λ () (def-t "⌊·⌋"))]

     ;; D is used as a convention to mean a deterministic `E` but
     ;; we forgo this for the typesetting
     ['D (λ () (text "E" (non-terminal-style) (default-font-size)))]

     ;; same with the pure variants
     ['p-pure+GO
      (λ ()
        (render-op/instructions
         (text "p" (non-terminal-style) (default-font-size))
         `((superscript p) (subscript GO))))]
     ['q-pure+GO
      (λ ()
        (render-op/instructions
         (text "q" (non-terminal-style) (default-font-size))
         `((superscript p) (subscript GO))))]
     ['r-pure+GO
      (λ ()
        (render-op/instructions
         (text "r" (non-terminal-style) (default-font-size))
         `((superscript p) (subscript GO))))]
     ['p-pure (λ ()
                (render-op/instructions
                 (text "p" (non-terminal-style) (default-font-size))
                 `((superscript p))))]
     ['q-pure (λ ()
                (render-op/instructions
                 (text "q" (non-terminal-style) (default-font-size))
                 `((superscript p))))]
     ['r-pure (λ ()
                (render-op/instructions
                 (text "r" (non-terminal-style) (default-font-size))
                 `((superscript p))))]
     ['C-pure (λ ()
                (render-op/instructions
                 (text "C" (non-terminal-style) (default-font-size))
                 `((superscript p))))]
     ['C-pure+GO (λ ()
                   (render-op/instructions
                    (text "C" (non-terminal-style) (default-font-size))
                    `((superscript p) (subscript GO))))]
     ['E-pure (λ ()
                (render-op/instructions
                 (text "E" (non-terminal-style) (default-font-size))
                 `((superscript p))))]
     ['E1-pure (λ ()
                (render-op/instructions
                 (text "E1" (non-terminal-style) (default-font-size))
                 `((superscript p))))]
     ['p-unex (λ () (text "p" (non-terminal-style) (default-font-size)))]
     ['q-unex (λ () (text "q" (non-terminal-style) (default-font-size)))]
     ['wire-value (λ () (text "e" (non-terminal-style) (default-font-size)))]

     ['max-mf (λ () (def-t "max"))]
     ['→ (λ () (def-t "→"))]
     ['<- (λ () (text "←" (default-style) (default-font-size)))]
     ['<= (λ () (plus-equals))]
     ['loop^stop (λ () (loop^stop-pict))]

     ['eval^circuit (lambda () (eval-c-pict))]
     ['eval^esterel (lambda () (eval-e-pict))]

     ['not (lambda () (words "¬"))]
     
     ['done (λ () (render-op/instructions (nt-t "p") `((superscript D))))]
     ['stopped (λ () (render-op/instructions (nt-t "p") `((superscript S))))]
     ['complete* (λ () (render-op/instructions (nt-t "p") `((superscript C))))]
     ['paused
      (lambda () (text "p̂" (cons 'no-combine (non-terminal-style)) (default-font-size)))]

     ['hole (lambda () (text "○" (default-style) (default-font-size)))]
     ['Cc1
      (λ ()
        (render-op/instructions
         (text "C" (non-terminal-style) (default-font-size))
         `((superscript c) (subscript 1))))]
      
                    
     ['A->= (lambda () (render-op "≥"))]
     ['↓ (λ () (down-super-n))]
     ['harp (λ () (down-super-p))]
     ['and (lambda () (def-t "∧"))]
     ['or (lambda () (def-t "∨"))]
     ['closed
      (lambda ()
        (mf-t "closed"))]
     
     
     ['next-instant (λ () (mf-t "Ɛ"))]
     ['par-⊓ (λ () (par-⊓-pict))]
     ['Can-θ (λ () (Can-θ-name-pict))]
     ['Can (λ () (Can-name-pict #f))]
     ['CB (λ () (CB-judgment-pict))]
     ['· (λ () (def-t "{}"))]
     ['L-S (λ () (L-S-pict))]
     ['L-s (λ () (L-s-pict))]
     ['L-x (λ () (L-x-pict))]
     ['L-n (λ () (L-K-pict))]
     ['Can-result (λ () (Can-result-pict))]
     ['θ/c (λ () (θ/c-pict))]
     ['c
      (lambda ()
        (text "ɕ" (non-terminal-style) (default-font-size)))]
     ['circuit
      (lambda ()
        (text "ɕ" (non-terminal-style) (default-font-size)))]
     ['cs
      (lambda ()
        (render-op/instructions
         (text "θ" (non-terminal-style) (default-font-size))
         `((superscript ,(nt-t "ɕ")))))]
     ['present (λ () (text "1" (default-style) (default-font-size)))]
     ['absent (λ () (text "0" (default-style) (default-font-size)))]
     ['unknown (λ () (text "⊥" (default-style) (default-font-size)))]

     ['≃^circuit ≃-c-pict]
     ['≃^esterel ≃-e-pict]
     ['≃ (lambda () (def-t "≃"))]
     ['≡
      (lambda () (render-op '≡^E))]
     ['≡j
      (lambda () (render-op '≡^E))]
     ['⇀
      (lambda () (reduction-arrow))]
     ['⇀2
      (lambda () (reduction-arrow))]
     ['⟶
      (lambda () (render-op '⟶^E))]
     ['⟶^s
      (lambda () (render-op '⟶^S))]
     ['⟶^r
      (lambda () (render-op '⟶^R))]
     ['⟶^c
      (lambda () (render-op '⟶^C))]
     ['⇀^r (lambda () (render-op '⇀^R))]
     ['⇀λ (lambda () (render-op '⇀^λ))]
     ['⇀λ2 (lambda () (render-op '⇀^λ))]
     ['≡λ (lambda () (render-op '≡^λ))]
    
     ['blocked blocked-pict]
     ['blocked-pure blocked-pict]
     ['not-blocked not-blocked-pict]
     ['restrict (lambda () (mf-t "restrict"))]
     ['complete-with-respect-to (lambda () (mf-t "complete-wrt"))]
     ['θr
      (lambda ()
        (render-op/instructions
         (text "θ" (non-terminal-style) (default-font-size))
         `((superscript ,(text "r" (non-terminal-style) (default-font-size))))))]

     ['tt (lambda () (text "tt" (list* 'italic 'combine (literal-style)) (default-font-size)))]
     ['ff (lambda () (text "ff" (list* 'italic 'combine (literal-style)) (default-font-size)))]
     ;; results
     ['R (lambda ()
           (text "R" (non-terminal-style) (default-font-size)))]
     ['count (lambda () (words "𝒮"))]
     ['compile
      (λ () (text "⟦·⟧" (default-style) (default-font-size)))]
     ['statusr
      (lambda ()
        (render-op/instructions
         (text "status" (non-terminal-style) (default-font-size))
         `((superscript r))))]
     ['So (λ ()
            (render-op/instructions
             (text "S" (non-terminal-style) (default-font-size))
             `((superscript o))))]
     ['sub (lambda () (mf-t "sub"))]
     ['Si
      (lambda ()
        (render-op/instructions
         (text "S" (non-terminal-style) (default-font-size))
         `((superscript i))))]
     ['δ (λ () (eval-h-pict))]
     ['δ* (λ () (mf-t "δ"))]
     ['const (λ () (nt-t "c"))]
     ['≃λ (lambda () (≃-pict "λ"))]
     ['evalλ
     (lambda () (eval-pict "λ"))]
     ['set! (lambda () (def-t "σ"))])
    (define owsb (white-square-bracket))
    (parameterize* ([default-font-size (get-the-font-size)]
                    [metafunction-font-size (get-the-font-size)]
                    [label-style Linux-Liberterine-name]
                    [grammar-style Linux-Liberterine-name]
                    [paren-style Linux-Liberterine-name]
                    [literal-style Linux-Liberterine-name]
                    [metafunction-style (cons 'italic Linux-Liberterine-name)]
                    [non-terminal-style (cons 'bold Linux-Liberterine-name)]
                    [non-terminal-subscript-style (replace-font non-terminal-subscript-style)]
                    [non-terminal-superscript-style (replace-font non-terminal-superscript-style)]
                    [default-style Linux-Liberterine-name]
                    [white-square-bracket
                     (lambda (open?)
                       (let ([text (current-text)])
                         (define s (ghost (owsb open?)))
                         (refocus
                          (lbl-superimpose
                           (scale
                            (text (if open? "⟬" "⟭")
                                  (default-style)
                                  (default-font-size))
                            1.05)
                           s)
                          s)))])
      (thunk)))))

(define (words str)
  (text str (default-style) (default-font-size)))

(define (bords str)
  (text str (cons 'bold (default-style)) (default-font-size)))

(define-syntax (with-atomic-rewriters stx)
  (syntax-case stx ()
    [(_ () b ...) #'(let () b ...)]
    [(_ ([x e] . more) b ...) #'(with-atomic-rewriter x e (with-atomic-rewriters more b ...))]))

(define (indent p) (hc-append (blank 10 0) p))

(define (leading-∀) (hbl-append (term->pict esterel-eval ∀) (words " ")))

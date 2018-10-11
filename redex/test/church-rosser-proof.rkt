#lang racket
(provide (all-defined-out))
(require redex/reduction-semantics
         esterel-calculus/redex/model/shared
         esterel-calculus/redex/model/calculus
         "model-test.rkt"
         "generator.rkt"
         rackunit
         (for-syntax syntax/parse
                     racket/list
                     racket/syntax
                     racket/sequence))
(module+ test (require rackunit))

(define-extended-language esterel-gen esterel-eval
  (e ::= (+ s/l ...))
  (s/l ::= s x n)
  (ev ::= n)
  (i ::= (emit S) (<= s e) (:= x e))
  (R ::=
     i
     (present S p q)
     (if x p q) (shared s := e p) (var x := e p)))

(define debug #f)

;; property:
;; p RPar q && p RPar q'
;; => ∃q'', q Rpar q'' && q' Rpar q''

(define (check-par-diamond)
  (redex-check
   esterel-gen
   p
   (do-test `p)
   #:prepare fixup2
   #:attempts 1000)
  (redex-check
   esterel-gen
   (p (name i (S_!_g S_!_g ...)) (name o (S_!_g S_!_g ...)) ((S ...) ...))
   (let-values ([(p e) (calc-shuffle `p 3)])
     (do-test p))
   #:prepare fixup
   #:attempts 100))

(define (reduce p)
  (apply-reduction-relation R p))
(define (zero-to-two p)
  (define one (reduce p))
  (append
   (cons p one)
   (append-map reduce one)))

(define (do-test p)
  (redex-let
   esterel-eval
   ([p p])
   (when debug (displayln (term p)))
   (define candidates (reduce `p))
   (define result
     (for*/and ([c1 (in-list candidates)]
                [c2 (in-list candidates)])
       (define out1 (zero-to-two c1))
       (define out2 (zero-to-two c2))
       (define result
         (for*/or ([o1 (in-list out1)]
                   [o2 (in-list out2)])
           (equal? o1 o2)))
       (unless result
         (printf "p = ~a\n" `p)
         (printf "q = ~a\n" c1)
         (pretty-print out1)
         (printf "q' = ~a\n" c2)
         (pretty-print out2))
       result))
   result))

(define (fixup2 p)
  `(clear-dups ,p))

(define-metafunction esterel-eval
  clear-dups : any -> any
  [(clear-dups (ρ θ p))
   (ρ (remove-dups θ) (clear-dups p))]
  [(clear-dups (loop p))
   (loop (clear-dups p))]
  [(clear-dups (any ...))
   ((clear-dups any) ...)]
  [(clear-dups any) any])

(define-metafunction esterel-eval
  remove-dups : θ -> θ
  [(remove-dups θ) θ])

(module+ test
  (test-case ""
    (check-true
     (do-test
      `(par
        (ρ {(sig S present) ·} nothing)
        (ρ {(sig ST present) ·} nothing))))
    (check-true
     (do-test
      `(par
        (ρ {(sig S unknown) ·} nothing)
        (ρ {(sig ST unknown) ·} nothing))))
    (check-true
     (do-test
      `(ρ {(sig S unknown)
           ((sig S1 unknown)
            ((var· x 0) ·))}
          (if x nothing (emit S1)))))
    (check-true
     (do-test
      `(seq
        (ρ ((sig Sg350095 unknown) ·) pause)
        (loop pause))))
    (check-true
     (do-test
      `(seq
        (ρ
         ((sig Sg13633 unknown) ·)
         (par
          pause
          (seq
           (emit Sg13633)
           nothing)))
        (seq nothing nothing))))
    (check-true
     (do-test
      `(seq
        (ρ
         ((sig Sg144814 absent) ((sig Sg144815 unknown) ·))
         (par
          pause
          (present Sg144814 nothing (emit Sg144815))))
        (loop pause))))
    (check-true
     (do-test
      `(par
         (signal SxYWk (shared sYpw := (+) (exit 0)))
         (ρ
          ·
          (shared sn := (+) pause)))))
    (check-par-diamond)))


(define-relation esterel-eval
   ~ ⊂ E x E
   [(~ hole hole)]
   [(~ (seq E q) (seq E_* q_*))
    (~ E E_*)]
   [(~ (par E q) (par E_* q_*))
    (~ E E_*)]
   [(~ (par p E) (par p_* E_*))
    (~ E E_*)]
   [(~ (trap E) (trap E_*))
    (~ E E_*)]
   [(~ (suspend E S) (suspend E_* S))
    (~ E E_*)])

(module+ test
  (let ()
    (local-require "binding.rkt")
    (define-judgment-form esterel-L
      #:mode (epull I)
      [(R-in-E p)
       (θ-in-E p)
       -------------
       (epull p)])

    (define-judgment-form esterel-L
      #:mode (R-in-E I)
      [(R-in-E R)]
      [(R-in-E p)
       ---------
       (R-in-E (seq p q))]
      [(R-in-E p)
       ---------
       (R-in-E (par p q))]
      [(R-in-E q)
       -------------
       (R-in-E (par p q))]
      [(R-in-E p)
       -------------
       (R-in-E (trap p))]
      [(R-in-E p)
       ------------
       (R-in-E (suspend p S))])

    (define-judgment-form esterel-L
      #:mode (θ-in-E I)
      [(θ-in-E (ρ θ p))]
      [(θ-in-E p)
       ------------
       (θ-in-E (seq p q))]
      [(θ-in-E p)
       ----------
       (θ-in-E (par p q))]
      [(θ-in-E q)
       ----------
       (θ-in-E (par p q))]
      [(θ-in-E p)
       ---------
       (θ-in-E (trap p))]
      [(θ-in-E p)
       ------------
       (θ-in-E (suspend p S))])

    #|
    ∀ E_in1, R, E_in2, θ, p_in
    E_in[R] = E_in2[(ρ θ p_in)] => ∃E_out s.t E_out[R] = E_in2[p_in], E_out ~ E_in1
    |#
    (define-judgment-form esterel-L
      #:mode (prop I)
      [(where (in-hole E_in1 R) p_in)
       (where (in-hole E_in2 (ρ θ p)) p_in)
       (where (in-hole E_out R) (in-hole E_in2 p))
       (~ E_out E_in1)
       ----------------
       (prop p_in)])

    (redex-check
     esterel-L
     #:satisfying (epull p)
     (judgment-holds (prop p))
     #:attempts 1000)))
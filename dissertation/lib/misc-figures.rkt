#lang racket

(require esterel-calculus/redex/model/shared
         esterel-calculus/redex/model/potential-function
         redex/reduction-semantics
         redex/pict
         pict
         "redex-rewrite.rkt"
         (only-in "proof-extras.rkt"
                  esterel/typeset))

(provide lang/pure lang/state supp-lang
         lang/env lang/loop lang/eval
         next-instant-pict
         Can-pict Canθ-pict
         Can-all-pict Can-loop-pict Can-host-pict
         supp-non-terminals
         theta-stuff-1
         theta-stuff-1b
         theta-stuff-2
         theta-stuff-3
         theta-stuff-4
         theta-stuff-5
         e-stuff
         circuit-lang
         environments1
         environments1
         nt-∈-line)

(define (nt-∈-line lhs rhs lhs-spacer)
  (hbl-append (rbl-superimpose
               (hbl-append (text lhs (non-terminal-style) (default-font-size))
                           (text " ∈" (default-style) (default-font-size)))
               lhs-spacer)
              (text " " (default-style) (default-font-size))
              (text rhs (default-style) (default-font-size))))

(define environments1
  (let ()
    (define-extended-language whatever esterel-eval
      (p ::= .... (ρ θ A p))
      (A ::= GO WAIT)
      (stat ::= present absent unknown))
    (define spacer1 (ghost (text "stat" (non-terminal-style) (default-font-size))))
    (define spacer2 (ghost (text " ::=" (default-style) (default-font-size))))
    (define spacer (hbl-append spacer1 spacer2))
    (with-paper-rewriters
     (vl-append
      (render-language whatever)
      (nt-∈-line "S" "Signal Names" spacer)
      (hbl-append
       (rbl-superimpose
        spacer
        (hbl-append (es θ) (text " : " (default-style) (default-font-size))))
       #;(rbl-superimpose (es θ) spacer1)
       #;(lbl-superimpose (text " : " (default-style) (default-font-size)) spacer2)
       (es S)
       (text " → " (default-style) (default-font-size))
       (es status))))))
  
(define environments2
  (let ()
    (define-extended-language whatever esterel-eval
      (p ::= .... (ρ θ A p))
      (A ::= GO WAIT))
    (with-paper-rewriters
     (render-language whatever))))

(define-extended-language el esterel/typeset
  (E ::=
     hole
     (seq E q)
     (par E q)
     (par p E)
     (suspend E S)
     (trap E)))
(define lang/eval
  (with-paper-rewriters
   (render-language el #:nts '(E))))
      

(define circuit-lang
  (with-paper-rewriters
   (define lhs-spacer
     (ghost
      (hbl-append
       (text "I" (non-terminal-style) (default-font-size))
       (text ", " (default-style) (default-font-size))
       (text "O" (non-terminal-style) (default-font-size))
       (text " ::=" (default-style) (default-font-size)))))
   (vl-append
    (render-language esterel/typeset #:nts '(wire-value c I O EQ B))
    (htl-append 50
                (nt-∈-line "w" "wire names" lhs-spacer)))))
  

(define lang/pure
  (with-paper-rewriters
   (define lhs-spacer
     (ghost
      (hbl-append
       [es p-pure]
       (text ", " (default-style) (default-font-size))
       [es q-pure]
       (text " ::=" (default-style) (default-font-size)))))
   
   (vl-append
    (render-language esterel-eval #:nts '(p-pure q-pure))
    (htl-append
     50
     (vl-append (nt-∈-line "S" "signal variables" lhs-spacer))))))

(define-extended-language esterel+loop esterel/typeset
  (p ::= .... (loop^stop p q))
  (E ::= .... (loop^stop E q))
  (paused ::= .... (loop^stop paused q)))
(define lang/loop
  (with-paper-rewriters
   (render-language esterel+loop #:nts '(p q E paused))))

(define-extended-language esterel+env esterel/typeset
  (p q ::= .... (ρ θr A p))
  (status ::= present absent unknown)
  (statusr ::= present unknown)
  (A ::= GO WAIT))

(define lang/env
  (with-paper-rewriters
   (define lhs-spacer
     (ghost
      (hbl-append
       (text "p" (non-terminal-style) (default-font-size))
       (text ", " (default-style) (default-font-size))
       (text "q" (non-terminal-style) (default-font-size))
       (text " ::=" (default-style) (default-font-size)))))
   
   (vl-append
    (render-language esterel+env #:nts '(p q A status statusr))
    (htl-append
     50
     (vl-append (hbl-append (es θ)
                            (text " : " (default-style) (default-font-size))
                            (es (⟶ S status)))
                (hbl-append (es θr)
                            (text " : " (default-style) (default-font-size))
                            (es (⟶ S statusr))))))))


(define lang/state
  (with-paper-rewriters
   (define lhs-spacer
     (ghost
      (hbl-append
       (text "p" (non-terminal-style) (default-font-size))
       (text ", " (default-style) (default-font-size))
       (text "q" (non-terminal-style) (default-font-size))
       (text " ::=" (default-style) (default-font-size)))))
   (define (nt-∈-line lhs rhs)
     (hbl-append (rbl-superimpose
                  (hbl-append (text lhs (non-terminal-style) (default-font-size))
                              (text " ∈" (default-style) (default-font-size)))
                  lhs-spacer)
                 (text " " (default-style) (default-font-size))
                 (text rhs (default-style) (default-font-size))))
   (vl-append
    (render-language esterel #:nts '(p q))
    (htl-append
     50
     (vl-append (nt-∈-line "S" "signal variables")
                (nt-∈-line "s" "shared variables"))
     (vl-append (nt-∈-line "x" "sequential variables")
                (nt-∈-line "e" "host expressions"))))))

(define theta-join-rules
  (with-paper-rewriters
   (vl-append
    (table
     2
     (list (es (θ-ref-S (id-but-typeset-some-parens (<- θ_1 θ_2)) S (θ-ref θ_2 S)))
           (hbl-append (words "if ")
                       (es (L∈ S (Ldom θ_2))))
           (es (θ-ref-S (id-but-typeset-some-parens (<- θ_1 θ_2)) S (θ-ref θ_1 S)))
           (hbl-append (words "if ")
                       (es (L¬∈ S (Ldom θ_2)))))
     lbl-superimpose lbl-superimpose 10 0)
    (hbl-append (words "... ditto for ")
                (es s)
                (words " and ")
                (es x)))))

(define singleton-thetas
  (with-paper-rewriters
   (vl-append
    (es (mtθ+S S status))
    (es (mtθ+s s n shared-status))
    (es (mtθ+x x n)))))

(define theta-stuff-1
  (with-paper-rewriters
   (hbl-append (bords "Empty Environment")
               (words ": ")
               (es ·))))

(define theta-stuff-1b
  (with-paper-rewriters
   (vl-append
    (hbl-append (bords "Singleton Environments")
                (words ": { « var » ↦ « val » }"))
    (indent singleton-thetas))))

(define theta-stuff-2
  (with-paper-rewriters
   (vl-append
    (hbl-append (bords "Environment Composition")
                (words ": ")
                (es (<- θ θ)))
    (indent theta-join-rules))))

(define theta-stuff-3
  (with-paper-rewriters
   (vl-append
    (hbl-append (bords "Complete Environments")
                (words ": ")
                (es θ/c))
    (indent (vl-append (words "A complete environment is one")
                       (hbl-append (words "where no signals are ")
                                   (es unknown))
                       (hbl-append (words " and all shared variables are ")
                                   (es ready)))))))

(define theta-stuff-4
  (with-paper-rewriters
   (vl-append
    (hbl-append (bords "Resetting Environments")
                (words ": ")
                (es (reset-θ θ)))
    (indent (vl-append (words "Resetting a complete environment")
                       (hbl-append (words "updates all signals to ")
                                   (es unknown))
                       (hbl-append (words "and all shared variables to ")
                                   (es old)))))))

(define theta-stuff-5
  (with-paper-rewriters
   (vl-append
    (hbl-append (bords "Restricting the Domain")
                (words ": ")
                (es (Lwithoutdom θ S)))
    (indent (vl-append (words "Restricting the domain of an")
                       (words "environment removes the")
                       (hbl-append (words "binding for ") (es S)))))))

(define e-stuff
  (with-paper-rewriters
   (vl-append
    (bords "Embedded host language expressions")
    (indent
     (vl-append
      (hbl-append (es e) (words ": host expressions"))
      (hbl-append (es (LFV/e e))
                  (words ": all ")
                  (es x)
                  (words " and ")
                  (es s)
                  (words " that appear free in ")
                  (es e))
      (hbl-append (es/unchecked (δ e θ))
                  (words ": evaluation; produces ")
                  (es n)))))))

(define supp-non-terminals
  (with-paper-rewriters
      (render-language esterel-eval
                    #:nts
                    '(stopped done paused E p q A
                             status shared-status))))

(define supp-lang
  (with-paper-rewriters
   (htl-append
    16
    (vc-append
     supp-non-terminals
     
     (parameterize ([metafunction-combine-contract-and-rules
                     (λ (c-p rule-p)
                       (vl-append
                        (blank 0 10)
                        (vl-append 2 c-p rule-p)))])
       (vl-append
        (inset (ghost (text "a")) 0 (- (/ (pict-height (text "a")) 2) 0 0))
        (bords "Metafunctions:")
        (inset (render-metafunction harp #:contract? #t)
               0 -5 0 0))))
    (vl-append
     10
     theta-stuff-1
     theta-stuff-1b
     theta-stuff-2
     theta-stuff-3
     theta-stuff-4
     theta-stuff-5
     e-stuff))))

(define κ-pict
  (with-paper-rewriters
   (hbl-append (es κ) (text " ∈ Natural Numbers" (default-style))))) 

(define ↓-pict
  (with-paper-rewriters
   (parameterize ([metafunction-pict-style 'left-right/vertical-side-conditions]
                  [where-make-prefix-pict (λ () (text "if " (default-style)))])
     (frame (inset (render-metafunction ↓ #:contract? #t)
                   6 4 4 6)))))

(define Can-all-pict
  (with-paper-rewriters
   (vl-append
    20
    κ-pict 
    (rt-superimpose
     (parameterize ([metafunction-pict-style 'left-right/vertical-side-conditions]
                    [sc-linebreaks
                     (for/list ([i (in-range 23)])
                       (or (= i 15)
                           (= i 16)))])
       (render-metafunction Can #:contract? #t))
     (vr-append 10 ↓-pict)))))
(define Can-pict
  (with-paper-rewriters
   (vl-append
    20
    κ-pict 
    (rt-superimpose
     (parameterize ([metafunction-pict-style 'left-right/vertical-side-conditions]
                    [metafunction-cases
                     (list 0 1 2 3 4 5 6 7 8 9 12 14 15 16)]
                    [sc-linebreaks
                     (for/list ([i (in-range 15)])
                       (or (= i 12)
                           (= i 13)))])
       (render-metafunction Can #:contract? #t))
     (vr-append 10 ↓-pict)))))
(define Can-loop-pict
  (with-paper-rewriters
   (parameterize ([metafunction-pict-style 'left-right/vertical-side-conditions]
                  [metafunction-cases
                   (list 10 11)])
     (render-metafunction Can #:contract? #f))))
(define Can-host-pict
  (with-paper-rewriters
   (parameterize ([metafunction-pict-style 'left-right/vertical-side-conditions]
                  [metafunction-cases
                   (list 17 18 19 20 21 22)])
     (render-metafunction Can #:contract? #f))))

(define Canθ-pict
  (with-paper-rewriters
   (parameterize ([metafunction-pict-style 'left-right/vertical-side-conditions])
     (render-metafunction Can-θ #:contract? #t))))

(define next-instant-pict
  (with-paper-rewriters
   (render-metafunction next-instant #:contract? #t)))

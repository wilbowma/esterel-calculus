#lang racket
(require "lib.rkt"
         slideshow)

(define (example1)
  (define an-aterm
    (aterm (signal S
             (seq (emit S)
                  (present S
                           (emit SO1)
                           (emit SO2))))))

  (define (add-S-arrow label)
    (add-arc an-aterm
             '(2 1 1)
             ct-find
             '(2 2 1)
             rc-find
             (cons 80 -90)
             label
             #:start-pull 1.5
             #:end-pull 2
             #:start-angle (* pi 1/2)
             #:end-angle pi
             ))

  (define with-S-⊥ (add-S-arrow '⊥))
  (define with-S-1 (add-S-arrow 1))
  
  (slide (aterm->pict an-aterm))
  (slide (aterm->pict with-S-⊥))
  (slide (aterm->pict (add-left-finger with-S-⊥ '())))
  (slide (aterm->pict (add-left-finger with-S-⊥ '(2))))
  (slide (aterm->pict (add-right-finger with-S-⊥ '(2 1))))
  (slide (aterm->pict (add-left-finger with-S-1 '(2 2))))
  (slide (aterm->pict (add-left-finger with-S-1 '(2 2 2)))))

(define (example2)
  (define an-aterm
    (aterm (signal S
             (par (emit S)
                  (present S
                           (emit SO1)
                           (emit SO2))))))

  (define (add-S-arrow label)
    (add-arc an-aterm
             '(2 1 1)
             ct-find
             '(2 2 1)
             rc-find
             (cons 80 -90)
             label
             #:start-pull 1.5
             #:end-pull 2
             #:start-angle (* pi 1/2)
             #:end-angle pi
             ))

  (define with-S-⊥ (add-S-arrow '⊥))
  (define with-S-1 (add-S-arrow 1))

  (slide (aterm->pict an-aterm))
  (slide (aterm->pict with-S-⊥))
  (slide (aterm->pict (add-left-finger with-S-⊥ '())))
  (slide (aterm->pict (add-left-finger with-S-⊥ '(2))))
  (slide (aterm->pict (add-right-finger (add-left-finger with-S-⊥ '(2 2)) '(2 1))))
  (slide (aterm->pict (add-left-finger with-S-1 '(2 2))))
  (slide (aterm->pict (add-left-finger with-S-1 '(2 2 2)))))


(define (constructive-cycle-example)
  (define an-aterm
    (aterm (signal S1
             (signal S2
               (par
                (present S1
                         nothing
                         (emit S2))
                (present S2
                         nothing
                         (emit S1))
                (emit S2))))))

  (define (add-S1-arrow label an-aterm)
    (add-arc an-aterm
             '(2 2 2 3 1)
             rc-find
             '(2 2 1 1)
             rc-find
             (cons 130 -100)
             label
             #:start-pull 1
             #:end-pull 1.2
             #:start-angle 0
             #:end-angle pi
             ))

  (define (add-S2-nested-arrow label an-aterm)
    (add-arc an-aterm
             '(2 2 1 3 1)
             rc-find
             '(2 2 2 1)
             rc-find
             (cons 80 10)
             label
             #:start-pull 1
             #:end-pull 1
             #:start-angle 0
             #:end-angle pi
             ))

  (define (add-S2-arrow label an-aterm)
    (add-arc an-aterm
             '(2 2 3 1)
             ct-find
             '(2 2 2 1)
             lb-find
             (cons -40 -25)
             label
             ))

  (define (with-arrows S1-label S2-nested-label S2-label)
    (add-S2-arrow
     S2-label
     (add-S2-nested-arrow
      S2-nested-label
      (add-S1-arrow
       S1-label
       an-aterm))))
  
  (define ⊥⊥⊥ (with-arrows '⊥ '⊥ '⊥))
  (define ⊥⊥1 (with-arrows '⊥ '⊥ 1))
  (define 0⊥1 (with-arrows 0 '⊥ 1))
  (define a011 (with-arrows 0 1 1))
  
  (slide (aterm->pict an-aterm))
  (slide (aterm->pict ⊥⊥⊥))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '())))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '(2))))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '(2 2))))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '(2 2 1) '(2 2 2) '(2 2 3))))
  (slide (aterm->pict (add-left-finger ⊥⊥1 '(2 2 1) '(2 2 2))))
  (slide (aterm->pict (add-right-finger (add-left-finger 0⊥1 '(2 2 1)) '(2 2 2 2))))
  (slide (aterm->pict (add-right-finger (add-left-finger 0⊥1 '(2 2 1 3)) '(2 2 2 2))))
  (slide (aterm->pict (add-right-finger a011 '(2 2 2 2)))))

(define (nonconstructive-cycle-example)
  (define an-aterm
    (aterm (signal S1
             (signal S2
               (par
                (present S1
                         nothing
                         (emit S2))
                (present S2
                         nothing
                         (emit S1)))))))

  (define (add-S1-arrow label an-aterm)
    (add-arc an-aterm
             '(2 2 2 3 1)
             rc-find
             '(2 2 1 1)
             rc-find
             (cons 130 -100)
             label
             #:start-pull 1
             #:end-pull 1.2
             #:start-angle 0
             #:end-angle pi
             ))

  (define (add-S2-nested-arrow label an-aterm)
    (add-arc an-aterm
             '(2 2 1 3 1)
             rc-find
             '(2 2 2 1)
             rc-find
             (cons 80 10)
             label
             #:start-pull 1
             #:end-pull 1
             #:start-angle 0
             #:end-angle pi
             ))

  (define (add-S2-arrow label an-aterm)
    (add-arc an-aterm
             '(2 2 3 1)
             ct-find
             '(2 2 2 1)
             lb-find
             (cons -40 -25)
             label
             ))

  (define (with-arrows S1-label S2-nested-label S2-label)
    (add-S2-nested-arrow
     S2-nested-label
     (add-S1-arrow
      S1-label
      an-aterm)))
  
  (define ⊥⊥⊥ (with-arrows '⊥ '⊥ '⊥))
  (define ⊥⊥1 (with-arrows '⊥ '⊥ 1))
  (define 0⊥1 (with-arrows 0 '⊥ 1))
  (define a011 (with-arrows 0 1 1))
  
  (slide (aterm->pict an-aterm))
  (slide (aterm->pict ⊥⊥⊥))
  
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '())))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '(2))))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '(2 2))))
  (slide (aterm->pict (add-left-finger ⊥⊥⊥ '(2 2 1) '(2 2 2))))
;  (slide (aterm->pict (add-left-finger ⊥⊥1 '(2 2 1) '(2 2 2))))
;  (slide (aterm->pict (add-right-finger (add-left-finger 0⊥1 '(2 2 1)) '(2 2 2 2))))
;  (slide (aterm->pict (add-right-finger (add-left-finger 0⊥1 '(2 2 1 3)) '(2 2 2 2))))
;  (slide (aterm->pict (add-right-finger a011 '(2 2 2 2))))
  )

;(example1)
;(example2)
;(constructive-cycle-example)
(nonconstructive-cycle-example)
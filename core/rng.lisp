;; Random number interfaces and implementations
;; Copyright (C) 2014 Dr. John A.R. Williams

;; Author: Dr. John A.R. Williams <J.A.R.Williams@jarw.org.uk>
;; Keywords:

;;; Copying:

;; This file is part of Lisp Educational Network Simulator (LENS)

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; LENS is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Mersenne Twister random number generator is provided as default
;; random number functions take a rng index (default 0) which is the index
;; in the current *context* i.e. the index in the current component
;; rng map.

;;; Code:
(in-package :lens)

(deftype uint(nbits)
  "Unsigned integer type of length nbits"
  `(integer 0 ,(1- (expt 2 nbits))))

(defgeneric rand(stream &optional limit)
  (:documentation "* Arguments

- stream :: a random number sequence stream

* Optional Arguments

- limit :: a +real+ (default 1.0)

* Description

Return a random number /x/ of same type as /limit/ from a random
number sequence stream in the range 0<= /x/ <= /limit/ . See also
[[randExc]]")
  (:method((state random-state) &optional (limit 1.0d0))
    (random limit state)))

(defgeneric randExc(stream &optional limit)
    (:documentation "* Arguments

- stream :: a random number sequence stream

* Optional Arguments

- limit :: a +real+ (default 1.0)

* Description

Return a random number /x/ of same type as /limit/ from a random
number sequence stream in the range 0<= /x/ < /limit/ . See also
[[rand]].
"))

(defun urandom(size)
  "* Arguments

- seed :: an =integer=

* Description

Return an integer /size/ octets long read from the system random stream
/dev/urandom"
  (with-open-file(is "/dev/urandom" :direction :input
                     :element-type 'unsigned-byte)
    (let ((v 0))
      (dotimes(x size)
        (setf v (dpb (read-byte is) (byte 8 (* 8 x)) v)))
      v)))

(defgeneric seed(stream seed)
  (:documentation "* Arguments

- stream :: a random number sequence stream
- seed :: a 32 bit =integer= or =t=

Reseed /stream/ using /seed/. A seed value of =t= will use the system
random source to seed")
  (:method (stream (seed (eql 't)))
    (seed stream (urandom 4))))

(defconstant +mt-k2^32+ (expt 2 32))
(defconstant +mt-k-inverse-2^32f+ (expt 2.0f0 -32.0f0)
  "1/(2^32), as a floating-point number")
(defconstant +mt-k-inverse-2^32-1f+ (/ 1.0f0 (1- +mt-k2^32+))
  "1/(2^32), as a floating-point number")

(defconstant +mt-n+ 624)
(defconstant +mt-m+ 397)
(defconstant +mt-upper-mask+ #x80000000 "most significant w-r bits")
(defconstant +mt-lower-mask+ #x7FFFFFFF "least significant r bits")

(defclass mt-random-state()
  ;; Could have avoided MTI, which is an index into ARR, with a
  ;; fill pointer in ARR.  MTI more closely follows the reference
  ;; implementation.
  ;; ARR corresponts to "mt[]" in the reference implementation.
  ;; Probably should have called it MT after all.  Oh well.
    ((arr :type array :initform (make-array +mt-n+ :element-type '(uint 32)))
     (mti :type fixnum :initform +mt-n+)
     (seed :initarg :seed :initform nil
           :documentation "The initial seed value.")
     (count :initform 0
            :documentation "The number of random values extracted."))
  (:documentation "* Description

The Mersenne Twister is an algorithm for generating random numbers.  It
was designed with consideration of the flaws in various other generators.
The period, 2^19937-1, and the order of equidistribution, 623 dimensions,
are far greater.  The generator is also fast; it avoids multiplication and
division, and it benefits from caches and pipelines.  For more information
see the inventors' web page at http://www.math.keio.ac.jp/~matumoto/emt.html

* Reference

M. Matsumoto and T. Nishimura, 'Mersenne Twister: A 623-Dimensionally
Equidistributed Uniform Pseudo-Random Number Generator', ACM Transactions on
Modeling and Computer Simulation, Vol. 8, No. 1, January 1998, pp 3-30."))

(defmethod print-object((m mt-random-state) stream)
    (print-unreadable-object(m stream :type t :identity t)
      (format stream "~D (seed=~D)"
              (slot-value m 'count) (slot-value m 'seed))))

(defmethod initialize-instance :after ((mt mt-random-state) &key (seed t))
  (seed mt seed))

(defmethod seed((mt mt-random-state) (n integer))
  "Initialize generator state with seed."
  (with-slots(mti seed count) mt
    (setf mti +mt-n+
          seed n
          count 0))
  (let ((state (slot-value mt 'arr)))
    (setf (aref state 0) (logand n #xFFFFFFFF))
    (dotimes(i (1- +mt-n+))
      (let((r (aref state i)))
       ;; See Knuth TAOCP Vol 2, 3rd Ed, p.106 for multiplier.
        (setf (aref state (1+ i))
              (logand
               (+ (* 1812433253 (logxor r (ash r -30))) (1+ i))
               #xFFFFFFFF))))))

;; initial implementation
;; (defmethod seed((mt mt-random-state) (n integer))
;;      "Use the single integer to expand into a bunch of
;; integers to use as an MT-RANDOM-STATE.
;; Copied from the 'sgenrand' function in mt19937int.c.
;; This is mostly an internal function.  I recommend using
;; MAKE-MT-RANDOM-STATE unless specific circumstances dictate otherwise."
;;      (setf (slot-value mt 'mti) +mt-n+)
;;      (labels
;;          ((next-seed (n) (mod (1+ (* 69069 n)) +mt-k2^32+))
;;           (get-hi16 (n) (logand n #xFFFF0000))
;;           (next-elt (n)
;;             (logior (get-hi16 n)
;;                     (ash (get-hi16 (next-seed n)) -16))))
;;        (do ((i 0 (1+ i))
;;             (sd n (next-seed (next-seed sd))))
;;            ((>= i +mt-n+))
;;          (setf (aref (slot-value mt 'arr) i) (next-elt sd)))))

(defmethod seed((mt mt-random-state) (state sequence))
   (assert (eql (length state) +mt-n+))
	 (assert (not (find-if #'integerp state)))
   (setf (slot-value mt 'mti) 0
         (slot-value mt 'arr) (copy-seq (coerce state 'array))))

(defmethod seed((mt mt-random-state) (state mt-random-state))
  (with-slots(mti seed count arr) mt
   (setf mti (slot-value state 'mti)
         arr (copy-seq (slot-value state 'arr))
         seed (slot-value state 'seed)
         count (slot-value state 'count))))

(defun mt-refill (mt-random-state)
    "In the C program mt19937int.c, there is a function called 'genrand', & in
that function there is a block of code to execute when the mt[] array is
exhausted.  This function is that block of code.  I've removed it from my
[[mt-genrand]] function for clarity."
    ;; This function is pretty much a direct translation of the C function.
    ;; In other words, you're about to see some very un-Lispy code.
    (let* ((matrix-a #x9908B0DF)
           (mag01 (coerce (list 0 matrix-a) 'vector)))
      (with-slots(mti arr) mt-random-state
        (let (y kk)
          (setq kk 0)
        (do ()
            ((>= kk (- +mt-n+ +mt-m+)))
          (setq y (logior
                   (logand (aref arr kk) +mt-upper-mask+)
                   (logand (aref arr (1+ kk)) +mt-lower-mask+)))
          (setf (aref arr kk)
                (logxor
                 (aref arr (+ kk +mt-m+))
                 (ash y -1)
                 (aref mag01 (logand y 1))))
          (incf kk))
        (do ()
            ((>= kk (- +mt-n+ 1)))
          (setq y (logior
                   (logand (aref arr kk) +mt-upper-mask+)
                   (logand (aref arr (1+ kk)) +mt-lower-mask+)))
          (setf (aref arr kk)
                (logxor (aref arr (+ kk (- +mt-m+ +mt-n+)))
                        (ash y -1)
                        (aref mag01 (logand y 1))))
          (incf kk))
        (setq y (logior
                 (logand (aref arr (- +mt-n+ 1)) +mt-upper-mask+)
                 (logand(aref arr 0) +mt-lower-mask+)))
        (setf (aref arr (- +mt-n+ 1))
              (logxor (aref arr (- +mt-m+ 1)) (ash y -1)
                      (aref mag01 (logand y 1))))
        (setf mti  0)))))

(declaim (inline mt-tempering-shift-u mt-tempering-shift-s
                 mt-tempering-shift-t mt-tempering-shift-l))
(defun mt-tempering-shift-u (n)
  (mod (ash n -11) +mt-k2^32+))

(defun mt-tempering-shift-s (n)
  (mod (ash n 7) +mt-k2^32+))

(defun mt-tempering-shift-t (n)
  (mod (ash n 15) +mt-k2^32+))

(defun mt-tempering-shift-l (n)
  (mod (ash n -18) +mt-k2^32+))

(defun mt-genrand (mt-random-state)
  (incf (slot-value mt-random-state 'count))
  (let ((mt-tempering-mask-b #x9d2c5680)
        (mt-tempering-mask-c #xefc60000))
     (with-slots(mti arr) mt-random-state
       (when (>= mti +mt-n+) (mt-refill mt-random-state))
       (let ((y (aref arr mti)))
         (incf mti)
      ;; The following separate, explicit SETQ & other expressions
      ;; could be compacted/optimized into a single arithmetic expression
      ;; that does not store into any temporary variables.  That could be
      ;; more efficient at run-time, but I have chosen instead of immitate
      ;; the statements in the C program, mt19937int.c.
         (setf y (logxor y (mt-tempering-shift-u y)))
         (setf y (logxor y (logand (mt-tempering-shift-s y)
                                   mt-tempering-mask-b)))
         (setf y (logxor y (logand (mt-tempering-shift-t y)
                                   mt-tempering-mask-c)))
         (setf y (logxor y (mt-tempering-shift-l y)))
         y))))

(defmethod rand((state mt-random-state) &optional (n 1.0d0))
  (assert (plusp n))
  (if (integerp n)
      #+castelia-compatability
      (let ((used n))
        (dolist(m '(1 2 4 8 16))
          (setf used (logior used (ash used (- m)))))
        (do((i (logand (mt-genrand state) used)
               (logand (mt-genrand state) used)))
           ((<= i n) i)))
      #-castelia-compatability
      (mod
       (do ((bits-needed (log n 2))
            (bit-count 0 (+ 32 bit-count))
            (r 0  (+ (ash r 32) (mt-genrand state))))
           ((>= bit-count bits-needed) r))
       n)
      (* (mt-genrand state)  +mt-k-inverse-2^32-1f+ n)))

(defmethod randExc((state mt-random-state) &optional (n 1.0d0))
  (* (mt-genrand state) +mt-k-inverse-2^32f+ n))

;; if no context we use an array of 1 randomly seeded mt-random-state
(let ((rng-streams
       (make-array 1 :initial-element (make-instance 'mt-random-state))))
  (defmethod rng-map((context (eql nil)))
    rng-streams))

(declaim (inline %gendblrand %genintrand))
(defun %gendblrand(rng)
  "* Arguments

- rng :: an =integer=

* Description

Return a pseudo-random =double float= /x/ in the range 0<=/x/<1d0
from random number generator number /rng/ in the current [[*context*]]."
(randExc (aref (rng-map *context*) rng)))

(defun %genintrand(limit rng)
"* Arguments

- limit :: an positive =integer= of 32 bits or less
- rng :: an =integer=

* Description

Return a pseudo-random =integer= /x/ in the range 0<=/x/</limit/
from random number generator number /rng/  in the current context."
 (rand (aref (rng-map *context*) rng) (1- limit)))

(defun uniform(a b &optional (rng 0))
  "* Arguments

- a :: a =real= number
- b :: a =real= number

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate /x/ =double float= with uniform distribution in the range /a/<=/x/<=/b/ from random number stream /rng/ in the current context."
  (+ a (* (%gendblrand rng) (- b a))))


(defun exponential(mean &optional (rng 0))
  "* Arguments

- mean :: a =real= number

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate =double float= from the exponential
distribution with the given mean /mean/ (that is, with parameter
lambda=1/mean/) from random number stream /rng/ in the current
context."
  (* (- mean) (log (- 1.0d0 (%gendblrand rng)))))

(defun normal(&optional (mean 0d0) (stddev 1.0d0) (rng 0))
  "* Optional Arguments

- mean :: a =real= number (default 0)
- stddev ::  a =real= number (default 1d0)
- rng :: an =integer= (default 0)

* Description

Returns a random variate from the normal distribution with the given
 mean /mean/ and standard deviation /stddev/ from the random number stream
 /rng/ in the current context."
  (let ((u (- 1.0d0 (%gendblrand rng)))
        (v (- 1.0d0 (%gendblrand rng))))
    (+ mean (* stddev (sqrt (* -2.0d0 (log u))) (cos (* 2 pi v))))))

(defun lognormal(m w &optional (rng 0))
  "* Arguments

- m :: a =real= number
- w ::  a =real= number

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the lognormal distribution with scale
parameter /m/ and shape parameter /w/ from the random number stream
/rng/ in the current context. /m/ and /w/ correspond to the parameters
of the underlying [[normal]] distribution (/m/: mean,/w/: standard
deviation.)"
  (exp (normal m w rng)))

(defun truncnormal(&optional (m 0d0) (d 1.0d0) (rng 0))
  "* Optional Arguments

- m :: a =real= number (default 0d0)
- d ::  a =real= number (default 1d0)
- rng :: an =integer= (default 0)

* Description

Return the Normal distribution (from [[normal]] truncated to
nonnegative values from the random number stream /rng/ in the current
context.

It is implemented with a loop that discards negative values until a
nonnegative one comes. This means that the execution time is not
bounded: a large negative mean with much smaller stddev is likely to
result in a large number of iterations.

The mean and stddev parameters /m/ and /d/ serve as parameters to the
normal distribution before truncation. The actual random variate
returned will have a different mean and standard deviation."
  (do ((res (normal m d rng) (normal m d rng)))
      ((>= res 0) res)))

(defun %gamma-Marsaglia2000(a rng)
  "From: A Simple Method for Generating Gamma Variables, George Marsaglia and
 Wai Wan Tsang, ACM Transactions on Mathematical Software, Vol. 26, No. 3,
 September 2000. Available online."
  (assert (> a 1))
  (let* ((d (- a 1/3))
         (c (/ 1.0d0 (sqrt (* d 9.0d0))))
         x u v)
    (loop
        (loop
            :do (setf x (normal 0 1.0d0 rng)
                      v (+ 1.0d0 (* c x)))
           :while (<= v 0))
       (setf v (* v v v)
             u (%gendblrand rng))
       (when (or (< u (- 1.0 (* 0.0331 x x x x)))
                 (< (log u) (+ (* 0.5 x x) (* d (+ (- 1.0 v) (log v))))))
         (return (* d v))))))

(defun %gamma-MarsagliaTransf(alpha rng)
  "We can derive the alpha<1 case from the alpha>1 case. See note at the
 end of Section 6 of the Marsaglia2000 paper (see above)."
  (assert (< alpha 1));
  (* (%gamma-Marsaglia2000 (+ 1 alpha) rng)
     (expt (%gendblrand rng) (/ 1 alpha))))

(defun gamma-d(alpha theta &optional (rng 0))
"* Arguments

- alpha :: a positive =real= number
- theta ::  a positive =real= number

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the gamma distribution with parameters
/alpha/>0, /theta/>0 from the random number stream /rng/ in the current
context. /alpha/ is known as the shape parameter, and /theta/
as the scale parameter.

Some sources in the literature use the inverse scale parameter
/beta/ = 1 / /theta/, called the rate parameter. Various other notations
can be found in the literature; our usage of (alpha,theta) is consistent
with Wikipedia and Mathematica (Wolfram Research).

Gamma is the generalization of the Erlang distribution for non-integer
/k/ values, which becomes the alpha parameter. The chi-square distribution
is a special case of the gamma distribution.

For /alpha/=1, Gamma becomes the exponential distribution with /mean/=/theta/.

The mean of this distribution is /alpha*theta/, and variance is /alpha*theta/^2.

Generation: if /alpha/=1, it is generated as [[exponential]](theta).

For alpha>1, we make use of the acceptance-rejection method in
\"A Simple Method for Generating Gamma Variables, George Marsaglia and
Wai Wan Tsang\", ACM Transactions on Mathematical Software, Vol. 26, No. 3,
September 2000.

The alpha<1 case makes use of the alpha>1 algorithm, as suggested by the
above paper."
  (assert (and (> alpha 0) (> theta 0)))
  (cond
    ((< (abs (1- alpha)) DOUBLE-FLOAT-EPSILON)
     (exponential theta rng))
    ((< alpha 1.0)
     (* theta (%gamma-MarsagliaTransf alpha rng)))
    (t
     (* theta (%gamma-Marsaglia2000 alpha rng)))))

(defun beta(alpha1 alpha2 &optional (rng 0))
  "* Arguments

- alpha1 :: a positive =real= number
- alpha2 ::  a positive =real= number

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the beta distribution with parameters
 /alpha1/, /alpha2/ from the random number stream /rng/ in the current
context.

Generation is using relationship to Gamma distribution (see
[[gamma-d]]): if /Y1/ has gamma distribution with /alpha=alpha1/ and /beta=1/
and /Y2/ has gamma distribution with /alpha=alpha2/ and /beta=2/, then /Y =
Y1/(Y1+Y2)/ has beta distribution with parameters /alpha1/ and /alpha2/."
  (assert (and (> alpha1 0) (> alpha2 0)))
  (let ((y1 (gamma-d alpha1 1.0 rng))
        (y2 (gamma-d alpha1 1.0 rng)))
    (/ y1 (+ y1 y2))))

(defun erlang-k(k m  &optional (rng 0))
  "* Arguments

- k :: a positive integer
- m ::  a positive =real= number

* Optional Arguments

- rng :: an =integer= (default 0)

Returns a random variate from the Erlang distribution with /k/ phases
and mean /m/ using the random number stream /rng/ in the current
context.

This is the sum of /k/ mutually independent random variables, each with
exponential distribution. Thus, the /k/th arrival time in the Poisson
process follows the Erlang distribution.

Erlang with parameters /m/ and /k. is gamma-distributed (see
[[gamma-d]] with /alpha/=/k/ and /beta/=/m/ / /k/.

Generation makes use of the fact that exponential distributions
sum up to Erlang."
  (let ((u 1.0d0))
    (dotimes(i k) (setf u (* u (- 1.0d0 (%gendblrand rng)))))
    (- (* (/ m k) (log u)))))

(defun chi-square(k &optional (rng 0))
  "* Arguments

- k :: a positive integer

* Optional Arguments

- rng :: an =integer= (default 0)

Returns a random variate from the chi-square distribution with /k/
degrees of freedom using the random number stream /rng/ in the current
context.

The chi-square distribution arises in statistics. If Y_i are /k/
independent random variates from the normal distribution with unit
variance, then the sum-of-squares (sum(Y_i^2)) has a chi-square
distribution with /k/ degrees of freedom.

The expected value of this distribution is /k/. Chi_square with
parameter /k/ is gamma-distributed with /alpha/=/k//2, /beta/=2.

Generation is using relationship to gamma distribution (see [[gamma-d]])."
  (if (zerop (mod k 2))
      (erlang-k (ash k -1) k rng)
      (gamma-d (/ k 2) 2 rng)))

(defun student-t(i  &optional (rng 0))
  "* Arguments

- i :: a positive integer

* Optional Arguments

- rng :: an =integer= (default 0)

Returns a random variate from the student-t distribution with /i/
degrees of freedom  using the random number stream /rng/ in the current
context.

If Y1 has a normal distribution and Y2 has a
chi-square distribution with k degrees of freedom then X = Y1 /
sqrt(Y2/k) has a student-t distribution with k degrees of freedom.

Generation is using relationship to gamma and [[chi-square]]."
  (let ((z (normal 0 1 rng))
        (w (sqrt (/ (chi-square i rng) i))))
    (/ z w)))

(defun cauchy(a b &optional (rng 0))
  "* Arguments

- a :: a /real/
- b :: a positive /real/

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the Cauchy distribution (also called
Lorentzian distribution) with parameters a,b where b>0 using the
random number stream /rng/ in the current context.

This is a continuous distribution describing resonance behavior.
It also describes the distribution of horizontal distances at which
a line segment tilted at a random angle cuts the x-axis.

Generation uses the inverse transform."
  (assert (> b 0))
  (+ a (* b (tan (* pi (%gendblrand rng))))))

(defun triang(a b c &optional (rng 0))
  "* Arguments

- a :: a /real/
- b :: a /real/
- c :: a /real/

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the triangular distribution with parameters
/a/ <= /b/ <= /c/.

Generation uses inverse transform."
  (assert (and (<= a b c) (/= a c)))
  (let ((u (%gendblrand rng))
        (beta (/ (- b a) (- c a))))
    (+ a (* (- c a)
            (if (< u beta)
                (sqrt (* beta u))
                (- 1.0 (* (sqrt (- 1.0 beta)) (- 1.0 u))))))))

(defun weibull(a b &optional (rng 0))
   "* Arguments

- a :: a /real/ in range /a>0/
- b :: a /real/ in range /b>0/

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the Weibull distribution where /a/ is
the 'scale' parameter and /b/ is the shape parameter.  Sometimes
Weibull is given with /alpha/ and /beta/ parameters, then /alpha=b/
and /beta=a/. Uses random number stream /rng/ in the current context.

The Weibull distribution gives the distribution of lifetimes of objects.
It was originally proposed to quantify fatigue data, but it is also used
in reliability analysis of systems involving a weakest link, e.g.
in calculating a device's mean time to failure.

When /b=1/, (weibull a b) is exponential with mean /a/.

Generation uses inverse transform."

  (assert (and (> a 0) (> b 0)))
  (* a (expt (- (log (- 1.0 (%gendblrand rng)))) (/ 1.0 b))))

(defun pareto-shifted(a b c &optional (rng 0))
  "* Arguments

- a :: a /real/
- b :: a /real/
- c :: a /real/

* Optional Arguments

- rng :: an =integer= (default 0)

* Description

Returns a random variate from the shifted generalized Pareto distribution.

 Generation uses inverse transform."
  (assert (/= a 0))
  (let ((upow (expt (- 1.0 (%gendblrand rng)) (/ 1.0 a))))
    (- (/ b upow) c)))

(defun do-histogram(values &key (min -1) (max 1) (n 10))
  (let ((buckets (make-array (+ 2 n) :element-type 'fixnum))
        (w (/ (- max min) n)))
    (map
     'nil
     #'(lambda(v)
         (incf
          (aref buckets
                (cond
                  ((< v min) 0)
                  ((>= v max) (1+ n))
                  (t (1+ (floor (/ (- v min) w))))))))
     values)
    buckets))

;; discrete

(defun intuniform(a b &optional (rng 0))
  "* Arguments

- a :: an =integer=
- b :: an =integer=

* Optional Arguments

- rng :: an =integer=  (default 0)

* Description

Returns a random integer /x/ with uniform distribution in the range /a<=x<=b/
 using the random number stream /rng/ in the current
context."
  (+ a (%genintrand (1+ (- b a)) rng)))

(defun bernoulli(p &optional (rng 0))
  "* Arguments

- p :: an =integer=

* Optional Arguments

- rng :: an =integer=  (default 0)

* Description

Returns the result of a Bernoulli trial with probability /p/,
 that is, 1 with probability /p/ and 0 with probability /(1-p)/ using the random number stream /rng/  in the current context."
  (assert (<= 0 p 1))
  (if (> p (%gendblrand rng)) 1 0))

(defun binomial(n p  &optional (rng 0))
  "* Arguments

- n :: an =integer= /n>0/
- p :: an =integer= /0<=p<=1/

* Optional Arguments

- rng :: an =integer=  (default 0)

* Description

Return a random integer from the binomial distribution with
parameters /n/ and /p/, that is, the number of successes in /n/ independent
trials with probability /p/ using the random number stream /rng/ in the current
context.

Generation is using the relationship to Bernoulli
distribution (runtime is proportional to /n/)."
  (let ((x 0))
    (dotimes(i n)
      (let ((u (%gendblrand rng)))
        (if (> p u) (incf x))))
    x))

(defun geometric(p  &optional (rng 0))
 "* Arguments

- p :: an =integer= /p>0/

* Optional Arguments

- rng :: an =integer=  (default 0)

* Description

Returns a random integer from the geometric distribution with parameter /p/.
That is, the number of independent trials with probability /p/ until the
first success. Uses the random number stream /rng/ in the current
context.

This is the /n=1/ special case of the negative binomial distribution.

Generation uses inverse transform."
 (assert (and (>= p 0) (< p 1)))
 (let ((a (/ 1 (log (- 1 p)))))
   (floor (* a (log (- 1 (%gendblrand rng)))))))


(defun negbinomial(n p  &optional (rng 0))
"* Arguments

- n :: an =integer= /n>0/
- p :: an =integer= /0<=p<=1/

* Optional Arguments

- rng :: an =integer=  (default 0)

* Description

Returns a random integer from the negative binomial distribution with
parameters /n/ and /p/, that is, the number of failures occurring
before /n/ successes in independent trials with probability /p/ of
success.  Uses the random number stream /rng/ in the current context.

Generation is using the relationship to geometric distribution (runtime is
proportional to /n/)."
 (let ((x 0))
    (dotimes(i n)
      (incf x (geometric p rng)))
    x))

(defun poisson(lambda &optional (rng 0))
"* Arguments

- lambda :: an =integer= /lambda>0/

* Optional Arguments

- rng :: an =integer=  (default 0)

* Description

Returns a random integer from the Poisson distribution with parameter /lambda/,
that is, the number of arrivals over unit time where the time between
successive arrivals follow exponential distribution with parameter
/lambda/.   Uses the random number stream /rng/ in the current context.

/lambda/ is also the mean (and variance) of the distribution.

Generation method depends on value of /lambda/:

  - 0</lambda/<=30: count number of events /lambda>30/:
  - Acceptance-Rejection due to Atkinson (see Banks, page 166)"
  (if (> lambda 30.0)
      (loop
         :with a = (* pi (sqrt (/ lambda 3.0)))
         :with b = (/ a lambda)
         :with c = (- 0.767 (/ 3.36 lambda))
         :with d = (- (log c) (log b) lambda)
         :for y =
         (loop
            :for u = (%gendblrand rng)
            :for y = (/ (- a (log (/ (- 1.0 u) y))) b)
            :when (> y 0.5)
            :do (return y))
         :for x = (floor (+ y 0.5))
         :for v = (%gendblrand rng)
         :when (<= (+ (- a (* b y))
                      (log (/ v (+ 1 (expt (exp (- a (* b y))) 2)))))
                   (+ d (* x (log lambda)) (- (log x))))
         :do (return x))
      (loop
         :with a = (exp (- lambda))
         :for x = -1 :then (1+ x)
         :for p = 1.0 :then (* p (%gendblrand rng))
         :when (<= p a) :do (return x))))

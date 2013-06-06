(in-package :lens.wsn)

(defstruct orientation
  (phi 0.0 :type double-float :read-only t)
  (theta 0.0 :type double-float :read-only t))

(defstruct location
  (coord (make-coord) :type coord)
  (orientation (make-orientation) :type orientation)
  cell) ;; cell this entity is in - used by wireless-channel

(defmethod parse-input((spec (eql 'location)) value &key &allow-other-keys)
  (let ((coords
         (parse-input 'list value
                      :type '(number :coerce-to double-float)
                      :min-length 2 :max-length 5)))
    (make-location
     :coord (make-coord (first coords) (second coords) (or (third coords) 0.0d0))
     :orientation (make-orientation :phi (or (fourth coords) 0.0d0)
                                    :theta (or (fifth coords) 0.0d0)))))

(defclass mobility(wsn-module)
  ((location :type location :parameter t :initarg :location :reader location
             :documentation "current location initalized from parameter file")
   (static-p :initform t :initarg :static-p :reader static-p))
  (:metaclass module-class))

(defmethod initialize((instance mobility) &optional (stage 0))
  (case stage
    (0 (setf (location-cell (location instance)) (index (node instance)))))
  (call-next-method))

(defgeneric (setf location)(location instance)
  (:documentation "Change location in mobility manager")
  (:method((location coord) (instance mobility))
    (assert (not (static-p instance))
            ()
            "Attempt to change location of static node ~A" (node instance))
    (setf (location-coord (location instance)) location)
    (emit instance 'node-move)
    location))

(defmethod configure :after ((instance mobility))
  (parse-deployment instance)
  (eventlog "~A initial location is ~A" (node instance) (location instance)))

(defun parse-deployment(instance)
  (let* ((network (network instance))
         (node (node instance))
         (xlen (coord-x (field network)))
         (ylen (coord-y (field network)))
         (zlen (coord-z (field network))))
    (multiple-value-bind(deployment start-index)
        (range-getf (deployment network) (index node))
      (setf
       (slot-value instance 'location)
       (cond
         ((not deployment)
          (read-parameter node 'coord 'coord))
         ((eql deployment 'uniform)
          (make-coord (uniform 0 xlen) (uniform 0 ylen) (uniform 0 zlen)))
         ((eql deployment 'center)
          (make-coord (/ xlen 2) (/ ylen 2) (/ zlen 2)))
         ((and (listp deployment)
               (member (first deployment) '(grid randomized)))
          (let* ((gridi (- (index node) start-index))
                 (gridx (second deployment))
                 (gridy (third deployment))
                 (gridz (fourth deployment))
                 (grid
                  (make-coord
                   (* (mod gridi gridx) (/ xlen (1- gridx)))
                   (* (mod (floor gridi gridx) gridy) (/ ylen (1- gridy)))
                   (if (and gridz zlen)
                       (* (mod (floor gridi (* gridx gridy)) gridz)
                          (/ zlen (1- gridz)))
                       0.0))))
            (if (eql (first deployment) 'randomized)
                (flet((rn(len grid)
                        (let ((s (/ len grid)))
                          (min (- s) (max s (normal 0 (* 0.3 s)))))))
                  (coord+
                   grid
                   (make-coord
                    (rn xlen gridx)
                    (rn ylen gridy)
                    (if (and gridz zlen) (rn zlen gridz) 0.0))))
                grid)))
         (t (error "Unknown deployment parameter: ~A" deployment)))))))

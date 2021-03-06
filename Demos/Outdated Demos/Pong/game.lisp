(ql:quickload "cl-liballegro")

(defpackage #:game
  (:use :cl :cffi)
  (:export #:main))
(in-package #:game)

(defparameter *game-running* t)
(defparameter *window-width* 800)
(defparameter *window-height* 600)
(defparameter *fps* 60)
(defparameter *timer-dt* (/ 1.0d0 *fps*)) 
(defparameter *dt* (coerce *timer-dt* 'single-float))

(defvar *fps-timer*)
(defvar *event-queue*)
(defvar *display*)
(defvar *keyboard-state*)
(defvar *mouse-state*)
(defvar *entity-list*)
(defvar *component-container*)

(defclass keyboard-state ()
  ((key-w :accessor key-w :initform nil)
   (key-a :accessor key-a :initform nil)
   (key-s :accessor key-s :initform nil)
   (key-d :accessor key-d :initform nil)
   (key-up :accessor key-up :initform nil)
   (key-down :accessor key-down :initform nil)))

(defmacro get-event-type (event)
  `(foreign-slot-value ,event 'al:allegro-event 'al::type))

(defmacro with-event (event &body body)
  `(let ((,event (foreign-alloc 'al:allegro-event)))
     ,@body))
(defmacro with-update-display-event-loop (ev event-type &body body)
  `(with-event ,ev
     (let ((redraw nil)
	   (,event-type))
       (loop while *game-running* do
	    (al:wait-for-event *event-queue* ,ev)
	    (setf ,event-type (get-event-type ,ev))
	    (if (= al:+allegro-event-timer+ event-type)
		(progn
		  (setf redraw t)
		  (update-game))		    
		,@body)
	    (when (and redraw (al:is-event-queue-empty *event-queue*))
	      (setf redraw nil)
	      (display-game))))))

(defun create-entity (entity)
  (setf (gethash entity *component-container*) (list))
  (pushnew entity *entity-list*))
(defun add-entity (component-list)
  (let ((entity (gensym)))
    (create-entity entity)
    (setf (gethash entity *component-container*) component-list)))
(defun remove-entity (entity)
  (setf *entity-list* (remove entity *entity-list*))
  (remhash entity *component-container*))
(defun get-entity (entity) (gethash entity *component-container*))
(defun list-has-component-type-p (component-list component-type)
  (loop for comp in component-list when (typep comp component-type) return t))
(defun get-component (entity component-type)
  (let ((component-list (gethash entity *component-container*)))
    (loop for comp in component-list
       when (typep comp component-type) return comp)))
(defun add-component (entity component)
  (if (member entity *entity-list*)
      (if (not (list-has-component-type-p (gethash entity *component-container*)
					  (class-of component)))
	  (pushnew component (gethash entity *component-container*))
	  (print "The component already exists"))
      (print "The entity does not exist")))
(defun get-entities-with-component-type (component-type)
  (loop for v being the hash-values in *component-container* using (hash-key k)
     when (list-has-component-type-p v component-type) collect k))
(defun get-all-components-with-type (component-type)
  (loop for v being the hash-values in *component-container* using (hash-key k)
       when (list-has-component-type-p v component-type) 
     collect (get-component k component-type)))

(defclass component () ())
(defclass location-component (component)
  ((x :initarg :x :initform 0 :accessor x)
   (y :initarg :y :initform 0 :accessor y)
   (angle :initarg :angle :initform 0 :accessor angle)))
(defclass sprite-component (component)
  ((bitmap :initarg :bitmap :accessor bitmap)
   (bitmap-path :initarg :bitmap-path :accessor bitmap-path)
   (width :initarg :width :accessor width)
   (height :initarg :height :accessor height)))
(defmethod initialize-instance :after ((sprite sprite-component) &key)
  (with-slots (bitmap bitmap-path width height) sprite
    (setf bitmap (al:load-bitmap (bitmap-path sprite)))
    (setf width (al:get-bitmap-width bitmap))
    (setf height (al:get-bitmap-height bitmap))))
(defclass physics-component (component)
  ((dx :initarg :dx :initform 0 :accessor dx)
   (dy :initarg :dy :initform 0 :accessor dy)
   (ax :initarg :ax :initform 0 :accessor ax)
   (ay :initarg :ay :initform 0 :accessor ay)))
(defclass keyboard-component (component) ())
(defclass keyboard2-component (component) ())
(defclass ball-component (component) ())
(defclass player-component (component) ())

(defun drawing-system ()
  (loop for entity in *entity-list* do
       (let ((sprite (get-component entity 'sprite-component))
	     (location (get-component entity 'location-component)))
	 (when (and sprite location)
	   (al:draw-bitmap (bitmap sprite) (x location) (y location) 0)))))
(defun physics-system ()
  (loop for entity in *entity-list* do
       (let ((physics (get-component entity 'physics-component))
	     (location (get-component entity 'location-component)))
	 (when (and physics location)
	   (incf (dx physics) (* (ax physics) *dt*))
	   (incf (dy physics) (* (ay physics) *dt*))
	   (incf (x location) (* (dx physics) *dt*))
	   (incf (y location) (* (dy physics) *dt*))))))
(defun keyboard-system ()
  (loop for entity in *entity-list* do
       (let ((physics (get-component entity 'physics-component))
	     (keyboard (get-component entity 'keyboard-component)))
	 (when (and keyboard physics)
	   (cond ((key-w *keyboard-state*) (setf (dy physics) -400.0))
		 ((key-s *keyboard-state*) (setf (dy physics) 400.0))
		 (t (setf (dy physics) 0.0)))))))
(defun keyboard2-system ()
  (loop for entity in *entity-list* do
       (let ((physics (get-component entity 'physics-component))
	     (keyboard (get-component entity 'keyboard2-component)))
	 (when (and keyboard physics)
	   (cond ((key-up *keyboard-state*) (setf (dy physics) -400.0))
		 ((key-down *keyboard-state*) (setf (dy physics) 400.0))
		 (t (setf (dy physics) 0.0)))))))
(defun further-left-or-right-p (first-entity second-entity)
  (let ((first-location (get-component first-entity 'location-component))
	(first-sprite (get-component first-entity 'sprite-component))
	(second-location (get-component second-entity 'location-component))
	(second-sprite (get-component second-entity 'sprite-component)))
    (if (or (> (x second-location) (+ (x first-location) (width first-sprite)))
	    (> (x first-location) (+ (x second-location) (width second-sprite))))
	t
	nil)))
(defun further-up-or-down-p (first-entity second-entity)
  (let ((first-location (get-component first-entity 'location-component))
	(first-sprite (get-component first-entity 'sprite-component))
	(second-location (get-component second-entity 'location-component))
	(second-sprite (get-component second-entity 'sprite-component)))
    (if (or (> (y second-location) (+ (y first-location) (height first-sprite)))
	    (> (y first-location) (+ (y second-location) (height second-sprite))))
	t
	nil)))
(defun detect-collide (first-entity second-entity)
  (if (or (further-left-or-right-p first-entity second-entity)
	  (further-up-or-down-p first-entity second-entity))
      nil
      t))
(defun ball-system ()
  (let* ((player-list (get-entities-with-component-type 'player-component))
	 (ball (first (get-entities-with-component-type 'ball-component)))
	 (ball-physics (get-component ball 'physics-component))
	 (ball-location (get-component ball 'location-component)))
    (if (or (detect-collide ball (first player-list))
	    (detect-collide ball (second player-list)))
	(setf (dx ball-physics) (* -1 (dx ball-physics))))
    (if (or (< (y ball-location) 0)
	    (> (y ball-location) (- 600 16)))
	(setf (dy ball-physics) (* -1 (dy ball-physics))))
    (when (or (< (x ball-location) 0)
	      (> (x ball-location) 800))
      (setf (x ball-location) 382)
      (setf (y ball-location) 282))))

(defun update-game ()      
  (keyboard-system)
  (keyboard2-system)
  (physics-system)
  (ball-system))
(defun display-game ()
  (al:clear-to-color 1.0 1.0 1.0 1.0)
  (drawing-system)
  (al:flip-display))
(defun keyboard-handler (event event-type)
  (with-foreign-slots ((al::keyboard) event al:allegro-event)
    (with-foreign-slots ((al::keycode) al::keyboard al:allegro-keyboard-event)
      (when (= event-type al:+allegro-event-key-down+)
	(if (= al::keycode al:+allegro-key-d+)
	    (setf (key-d *keyboard-state*) t))
	(if (= al::keycode al:+allegro-key-a+)
	    (setf (key-a *keyboard-state*) t))
	(if (= al::keycode al:+allegro-key-w+)
	    (setf (key-w *keyboard-state*) t))
	(if (= al::keycode al:+allegro-key-s+)
	    (setf (key-s *keyboard-state*) t))
	(if (= al::keycode al:+allegro-key-up+)
	    (setf (key-up *keyboard-state*) t))
	(if (= al::keycode al:+allegro-key-down+)
	    (setf (key-down *keyboard-state*) t)))
      (when (= event-type al:+allegro-event-key-up+)
	(if (= al::keycode al:+allegro-key-d+)
	    (setf (key-d *keyboard-state*) nil))
	(if (= al::keycode al:+allegro-key-a+)
	    (setf (key-a *keyboard-state*) nil))
	(if (= al::keycode al:+allegro-key-w+)
	    (setf (key-w *keyboard-state*) nil))
	(if (= al::keycode al:+allegro-key-s+)
	    (setf (key-s *keyboard-state*) nil))
	(if (= al::keycode al:+allegro-key-up+)
	    (setf (key-up *keyboard-state*) nil))
	(if (= al::keycode al:+allegro-key-down+)
	    (setf (key-down *keyboard-state*) nil))))))

(defmacro keyboard-event-p (event-type)
  `(or (= al:+allegro-event-key-down+ ,event-type)
       (= al:+allegro-event-key-char+ ,event-type)
       (= al:+allegro-event-key-up+ ,event-type)))

(defun event-handler (event event-type)
  (cond ((keyboard-event-p event-type)
	 (keyboard-handler event event-type))
	((= al:+allegro-event-display-close+ event-type) (setf *game-running* nil))))

(defun initialize-display ()
  (al:set-new-display-flags 132)
  (setf *display* (al:create-display *window-width* *window-height*))
  (al:clear-to-color 0.0 0.0 0.0 1.0)
  (al:flip-display))
(defun initialize-input ()
  (setf *keyboard-state* (make-instance 'keyboard-state)))

(defun initialize-events ()
  (setf *fps-timer* (al:create-timer *timer-dt*))
  (setf *event-queue* (al:create-event-queue))
  (al:register-event-source *event-queue* (al:get-display-event-source *display*))
  (al:register-event-source *event-queue* (al:get-timer-event-source *fps-timer*))
  (al:register-event-source *event-queue* (al:get-keyboard-event-source))
  (al:register-event-source *event-queue* (al:get-mouse-event-source))
  (al:start-timer *fps-timer*))

(defun initialize-allegro ()
  (al:init)
  (al:init-image-addon)
  (al:init-font-addon)
  (al:install-audio)
  (al:init-acodec-addon)
  (al:init-primitives-addon)
  (al:install-keyboard)
  (al:install-mouse))
  
(defun shutdown-game ()
  (al:destroy-timer *fps-timer*)
  (al:destroy-display *display*)
  (al:destroy-event-queue *event-queue*))

(defun game-loop ()
  (with-update-display-event-loop event event-type
    (event-handler event event-type)))

(defun initialize-game ()
  (setf *game-running* t)
  (initialize-allegro)
  (initialize-display)
  (initialize-input)
  (initialize-events)
  (setf *entity-list* (list))
  (setf *component-container* (make-hash-table))
 
  (add-entity (list (make-instance 'physics-component)
		    (make-instance 'location-component :y 300)
		    (make-instance 'player-component)
		    (make-instance 'keyboard-component)
		    (make-instance 'sprite-component :bitmap-path "player.png")))
  (add-entity (list (make-instance 'physics-component)
		    (make-instance 'player-component)
		    (make-instance 'keyboard2-component)
		    (make-instance 'location-component :x 792 :y 300)
		    (make-instance 'sprite-component :bitmap-path "player.png")))
  (add-entity (list (make-instance 'physics-component :dx 200 :dy 200)
		    (make-instance 'location-component :x 392 :y 292)
		    (make-instance 'ball-component)
		    (make-instance 'sprite-component :bitmap-path "ball.png"))))

(defun main ()
  (initialize-game)
  (game-loop)
  (shutdown-game))

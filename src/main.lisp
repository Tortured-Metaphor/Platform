(defpackage :platform
  (:use :cl)
  (:import-from :uiop #:getenv)
  (:import-from :asdf #:find-system #:system-source-directory)
  (:import-from :bordeaux-threads #:make-thread #:join-thread)
  (:export #:main))

(in-package :platform)

;;; ---------------------------------------------------------------------------
;;; Constants and simple helpers
;;; ---------------------------------------------------------------------------

(defparameter *window-width* 1024)
(defparameter *window-height* 768)
(defparameter *target-fps* 60)
(defparameter *gravity* 2000.0d0)
(defparameter *move-speed* 300.0d0)
(defparameter *jump-speed* 700.0d0)
(defparameter *ground-height* 96)

(defun ground-top ()
  "Return the y coordinate (in pixels) of the ground's top surface."
  (- *window-height* *ground-height*))

(defun seconds-per-frame ()
  (/ 1.0d0 *target-fps*))

;;; ---------------------------------------------------------------------------
;;; Game state
;;; ---------------------------------------------------------------------------

(defstruct player
  (x 0.0d0 :type double-float)
  (y 0.0d0 :type double-float)
  (vx 0.0d0 :type double-float)
  (vy 0.0d0 :type double-float)
  (width 48 :type fixnum)
  (height 64 :type fixnum)
  (on-ground nil :type boolean))

(defstruct input-state
  (left nil :type boolean)
  (right nil :type boolean)
  (jump nil :type boolean)
  (jump-press nil :type boolean)
  (quit nil :type boolean)
  (restart nil :type boolean))

(defun make-initial-player ()
  (let ((player (make-player)))
    (reset-player! player)
    player))

(defun reset-player! (player)
  "Put PLAYER back at the spawn location on top of the ground."
  (let ((spawn-x (- (/ *window-width* 2.0d0) (/ (player-width player) 2.0d0)))
        (spawn-y (- (ground-top) (player-height player))))
    (setf (player-x player) spawn-x
          (player-y player) (float spawn-y 0.0d0)
          (player-vx player) 0.0d0
          (player-vy player) 0.0d0
          (player-on-ground player) t))
  player)

(defun player-bottom (player)
  (+ (player-y player) (player-height player)))

;;; ---------------------------------------------------------------------------
;;; Font loading utilities
;;; ---------------------------------------------------------------------------

(defparameter *font-search-paths*
  '("resources/DejaVuSans.ttf"
    "/Library/Fonts/Arial.ttf"
    "/System/Library/Fonts/Supplemental/Arial.ttf"
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    "C:/Windows/Fonts/arial.ttf"))

(defun system-relative-path (suffix)
  (let ((system (ignore-errors (find-system :platform))))
    (when system
      (merge-pathnames suffix (system-source-directory system)))))

(defun resolve-font-path ()
  "Locate a usable TrueType font for SDL2-ttf, honoring $PLATFORM_FONT_PATH."
  (let* ((env-path (getenv "PLATFORM_FONT_PATH"))
         (candidate-paths (remove nil (append (when env-path (list env-path))
                                              (list (system-relative-path "resources/DejaVuSans.ttf"))
                                              *font-search-paths*))))
    (or (loop for path in candidate-paths
              for pathname = (probe-file path)
              when pathname
                do (return (namestring pathname)))
        (error "No font file found. Set PLATFORM_FONT_PATH or place a font in resources/."))))

;;; ---------------------------------------------------------------------------
;;; Input handling
;;; ---------------------------------------------------------------------------

(defun handle-key-event (event input-state event-type)
  (plus-c:c-let ((raw sdl2-ffi:sdl-event :from event))
    (let* ((key (raw :key))
           (keysym (key :keysym))
           (scancode (sdl2:scancode keysym))
           (down? (eq event-type :keydown))
           (repeat? (and down? (not (zerop (key :repeat))))))
      (unless repeat?
        (case scancode
          (:scancode-left (setf (input-state-left input-state) down?))
          (:scancode-right (setf (input-state-right input-state) down?))
          (:scancode-space
           (setf (input-state-jump input-state) down?)
           (when down?
             (setf (input-state-jump-press input-state) t)))
          (:scancode-r (when down?
                         (setf (input-state-restart input-state) t)))
          (:scancode-escape (when down?
                              (setf (input-state-quit input-state) t))))))))

(defun poll-input (input-state)
  "Consume all pending SDL events and update INPUT-STATE accordingly."
  (sdl2:with-sdl-event (event)
    (loop while (> (sdl2:next-event event :poll) 0) do
      (let ((event-type (sdl2:get-event-type event)))
        (case event-type
          (:quit (setf (input-state-quit input-state) t))
          ((:keydown :keyup) (handle-key-event event input-state event-type)))))))

(defun clear-transient-input (input-state)
  (setf (input-state-jump-press input-state) nil
        (input-state-restart input-state) nil))

;;; ---------------------------------------------------------------------------
;;; Simulation update
;;; ---------------------------------------------------------------------------

(defun horizontal-direction (input-state)
  (- (if (input-state-right input-state) 1 0)
     (if (input-state-left input-state) 1 0)))

(defun clamp-player-horizontal (player)
  (let ((min-x 0.0d0)
        (max-x (- (float *window-width* 0.0d0)
                  (float (player-width player) 0.0d0))))
    (when (< (player-x player) min-x)
      (setf (player-x player) min-x))
    (when (> (player-x player) max-x)
      (setf (player-x player) max-x))))

(defun resolve-ground-collision (player)
  (let ((ground (float (ground-top) 0.0d0))
        (bottom (player-bottom player)))
    (when (>= bottom ground)
      (setf (player-y player) (- ground (player-height player))
            (player-vy player) 0.0d0
            (player-on-ground player) t))))

(defun update-world (player input-state dt)
  "Advance the simulation by DT seconds using INPUT-STATE."
  (when (input-state-restart input-state)
    (reset-player! player))
  (let ((dir (horizontal-direction input-state)))
    (setf (player-vx player) (* dir *move-speed*)))
  (when (and (input-state-jump-press input-state)
             (player-on-ground player))
    (setf (player-vy player) (- *jump-speed*)
          (player-on-ground player) nil))
  (incf (player-vy player) (* *gravity* dt))
  (incf (player-x player) (* (player-vx player) dt))
  (incf (player-y player) (* (player-vy player) dt))
  (clamp-player-horizontal player)
  (resolve-ground-collision player)
  (when (> (player-y player) *window-height*)
    (reset-player! player)))

;;; ---------------------------------------------------------------------------
;;; Rendering helpers
;;; ---------------------------------------------------------------------------

(defun set-render-draw-color (renderer r g b a)
  (sdl2:set-render-draw-color renderer r g b a))

(defun draw-rect (renderer x y w h)
  (sdl2:with-rects ((rect (round x) (round y) w h))
    (sdl2:render-fill-rect renderer rect)))

(defun render-score-text (renderer font)
  (let* ((surface (sdl2-ttf:render-utf8-solid font "Score: 0" 255 255 255 255))
         (texture (sdl2:create-texture-from-surface renderer surface)))
    (unwind-protect
         (let ((w (sdl2:surface-width surface))
               (h (sdl2:surface-height surface)))
           (sdl2:with-rects ((dest 24 24 w h))
             (sdl2:render-copy renderer texture :dest-rect dest)))
      (when texture (sdl2:destroy-texture texture))
      (when surface (sdl2:free-surface surface)))))

(defun draw-scene (renderer font player)
  "Render the current frame."
  (set-render-draw-color renderer 18 18 28 255)
  (sdl2:render-clear renderer)
  ;; Ground
  (set-render-draw-color renderer 62 59 86 255)
  (draw-rect renderer 0 (ground-top) *window-width* *ground-height*)
  ;; Player
  (set-render-draw-color renderer 234 168 46 255)
  (draw-rect renderer (player-x player) (player-y player)
             (player-width player) (player-height player))
  ;; UI text
  (render-score-text renderer font)
  (sdl2:render-present renderer))

;;; ---------------------------------------------------------------------------
;;; Main loop
;;; ---------------------------------------------------------------------------

(defun current-time-seconds ()
  (/ (sdl2:get-ticks) 1000.0d0))

(defun run-game-loop (renderer font player input target-dt)
  (let ((accumulator 0.0d0)
        (running t)
        (previous (current-time-seconds)))
    (loop while running do
      (poll-input input)
      (when (input-state-quit input)
        (setf running nil)
        (return))
      (let* ((now (current-time-seconds))
             (frame-time (- now previous)))
        (setf previous now
              accumulator (min 0.25d0 (+ accumulator frame-time))))
      (loop while (>= accumulator target-dt) do
        (update-world player input target-dt)
        (decf accumulator target-dt))
      (draw-scene renderer font player)
      (clear-transient-input input))))

(defun main (&key auto-quit-seconds)
  "Entry point: initialize SDL subsystems, run loop, clean up."
  (sdl2:with-init (:video)
    (sdl2-ttf:init)
    (let ((window nil)
          (renderer nil)
          (font nil))
      (unwind-protect
           (let* ((font-path (resolve-font-path))
                  (window-flags '(:shown))
                  (renderer-flags '(:accelerated :presentvsync)))
             (setf window (sdl2:create-window :title "Platform"
                                              :w *window-width*
                                              :h *window-height*
                                              :flags window-flags))
             (setf renderer (sdl2:create-renderer window -1 renderer-flags))
             (setf font (sdl2-ttf:open-font font-path 24))
             (let* ((player (make-initial-player))
                    (input (make-input-state))
                    (target-dt (seconds-per-frame))
                    (quit-thread (when auto-quit-seconds
                                   (make-thread (lambda ()
                                                  (sleep auto-quit-seconds)
                                                  (sdl2:push-event :quit))))))
               (unwind-protect
                    (run-game-loop renderer font player input target-dt)
                 (when quit-thread
                   (join-thread quit-thread)))))
        (when font (sdl2-ttf:close-font font))
        (when renderer (sdl2:destroy-renderer renderer))
        (when window (sdl2:destroy-window window))
        (sdl2-ttf:quit)))))

(defsystem "platform"
  :description "A tiny SDL2 platformer scaffold in Common Lisp."
  :author "David"
  :license "MIT"
  :version "0.1.0"
  :depends-on (:sdl2 :sdl2-image :sdl2-ttf)
  :serial t
  :components ((:module "src"
                 :components ((:file "main")))))

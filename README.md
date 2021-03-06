![alt logo](http://alleg.sourceforge.net/images/logo.png)

Description
--------------

Interface and bindings to the [Allegro 5 game programming library](http://alleg.sourceforge.net/)

I hope for it to be as clean and neat as cl-opengl.

Check out how the [bindings' source code](allegro) is organized and compare it to the 
[API reference](http://alleg.sourceforge.net/a5docs/5.0.10/).


Usages
--------------
1. `al_*` becomes `al:*`
2. `(al:rest secs)` is `(al:rest-time secs)` because of symbol interference with #'cl:rest.
3. `allegro_*` is removed in many places
4. Many enums are shortened, check [constants.lisp](allegro/constants.lisp) if you need help finding them.
5. Many other type names have changed too, chec [types.lisp](allegro/types.lisp) if you need help finding them.
6. Anything that requires or returns an allegro_color structure likely has a different usage.
 
***Feel free to raise an issue to request a feature or for me to work on something***

TODO
--------------
1. Look over lisp interface design again. Might have to ditch the generic methods because of 2. & 3.
2. Go over unwind-protect to ensure things safely get deleted.
3. Get the restart-cases working so users can recover from screwing up. (Also check out handler-case?)
4. Think about whether to use (al:uninstall-system) to cleanup or not.

Functionality
--------------
Everything is pretty much added.
One might require some familiarity with cffi to use the most out of the bindings. (For now)

**I won't work on the following sections because I am under the impression
that Common Lisp has more suitable implementations or it just is not practical. (Might eventually
do it for completeness though)
Feel free to explain otherwise and I'll listen.**

* File I/O 
* Filesystem 
* Memory 
* Threads 
* UTF-8

FAQ
--------------
1. **How do I `(ql:quickload "cl-liballegro")` from any location?**
 * Either add the path to your asdf by putting this line to your ~/.sbclrc file *(remember to change '\' -> '/')*: 
```
(push #p"/path/to/cl-liballegro/" asdf:*central-registry*)
```
 * Or copy cl-liballegro to /path/to/quicklisp/local-projects/cl-liballegro
 
2. **Why can't my program find the DLL in Windows?**

 There are path problems in Windows because the DLL files (which contain all the functions the CFFI calls upon) 
 doesn't have a default location unlike in Unix environments. When the library loads in Windows, ***it will look for 
 the DLL in the current folder of the FILE.LISP that evaluates `(ql:quickload "cl-liballegro")`*** This means you must 
 have a copy of the DLL file in the directory of FILE.LISP, not in the cl-liballegro directory unless the FILE.LISP is 
 in there. SLIME however, likes to change the default search folder to the one Emacs is in when it starts.

 **SBCL Only** - `Open command prompt in the folder that contains both the DLL and game.lisp`
```
> sbcl
> (load "game.lisp")                      ; File contains (ql:quickload "cl-liballegro")
```

 **Emacs + SLIME**
```
C-x C-f /path/to/Desktop/file9.lisp
M-x slime
C-x C-f /path/to/Desktop/game/game.lisp ; File contains (ql:quickload "cl-liballegro")
C-c C-l                                 ; Looks for the DLL at /path/to/Desktop/allegro.dll
```
```
C-x C-f /path/to/Desktop/file9.lisp
C-x C-f /path/to/Desktop/game/game.lisp ; File contains (ql:quickload "cl-liballegro")
M-x slime
C-c C-l                                 ; Looks for the DLL at /path/to/Desktop/game/allegro.dll
```
```
M-x slime
C-x C-f /path/to/Desktop/game/game.lisp ; File contains (ql:quickload "cl-liballegro")
C-c C-l                                 ; Looks for the DLL at /whatever/default/emacs/directory/allegro.dll
```

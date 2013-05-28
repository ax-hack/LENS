(in-package :lens.wsn)

(defstruct node-move from to)

(register-signal
 'node-move
 "Emitted immediately after node location has changed with node-move type value")

(register-signal
 'radio-on
 "Emitted when radio is switched on with value containing radio parameters")

(register-signal
 'radio-off
 "Emitted when radio is switched off with value containing radio parameters")

(register-signal
 'out-of-energy
 "Emitted as soon as a module is out of energy")


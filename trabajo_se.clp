; auxiliar functions
(deffunction ceil(?value)
  (bind ?x (mod ?value 1))
  (if (> ?x 0) then
      (+ (integer ?value) 1)
    else
      (integer ?value)
  )
)

(deffunction truncate(?value ?digits)
  (bind ?exp (** 10 ?digits))
  (bind ?x (* ?value ?exp))
  (bind ?x (integer ?x))
  (/ ?x ?exp)
)

; templates
(deftemplate Service
  (slot id (type INTEGER)) ; identificador del servicio
  (slot name (allowed-values Sanitary Firemen Policemen)) ; tipo de servicio
  (multislot location (type FLOAT)) ; localización de la estación de servicio
  (slot n_members (type INTEGER)) ; número de trabajadores disponibles para atender una emergencia
  (slot movement_speed (type FLOAT)) ; velocidad de movimiento para alcanzar una emergencia
  (slot prep_time (type FLOAT)) ; tiempo necesario para prepararse para atender una emergencia
)

(deftemplate Emergency
  (slot id (type INTEGER)) ; identificador de la emergencia
  (slot type (allowed-values natural_disaster thief homicide pandemic car_crash)); tipo de emergencia
  (multislot location (type FLOAT)) ; lugar donde se produjo la emergencia
  (slot n_affected_people (type INTEGER)) ; número de personas afectadas en la emergencia
)

(deftemplate Solution
  (slot id_solution (type INTEGER))
  (slot code_error (type INTEGER)); <0 error |  >= 0 success
  (slot id_emergency (type INTEGER))
  (slot name_emergency (allowed-values natural_disaster thief homicide pandemic car_crash))
  (slot id_service (type INTEGER)) ; -1 id code_error is <0
  (multislot name_service (allowed-values Sanitary Firemen Policemen))
)
; (choose-service ?id ?type ?n_affected ?loc_X ?loc_Y ?e)
(deftemplate choose-service
  (slot id (type INTEGER))
  (slot type (allowed-values natural_disaster thief homicide pandemic car_crash))
  (slot n_affected (type INTEGER))
  (slot x (type FLOAT))
  (slot y (type FLOAT))
  (slot e)
)

(deffacts example_thief

  (Service
    (id 1)
    (name Sanitary)
    (location  0.0 0.0)
    (n_members 100)
    (movement_speed 2.0)
    (prep_time 0.3)
  )

  (Service
    (id 1)
    (name Firemen)
    (location  0.0 0.0)
    (n_members 100)
    (movement_speed 2.0)
    (prep_time 0.3)
  )

  (Service
    (id 1)
    (name Policemen)
    (location  0.0 0.0)
    (n_members 1)
    (movement_speed 2.0)
    (prep_time 0.3)
  )

  (Emergency
    (id 7)
    (type natural_disaster)
    (location 10.0 2.0)
    (n_affected_people 100)
  )

)

; error code:
;   >= 0 -> success
;   -1 -> not enough members

(defrule notifyExistenceService
  (Service (name ?name) (id ?id) (location ?loc_X ?loc_Y))
  =>
  (printout t "Service " ?name " situated at (" ?loc_X " " ?loc_Y ") ready!" crlf)
  (do-for-all-facts ((?ch choose-service)) TRUE
    (bind ?id ?ch:id)
    (bind ?type ?ch:type)
    (bind ?n_affected ?ch:n_affected)
    (bind ?x ?ch:x)
    (bind ?y ?ch:y)
    (bind ?e ?ch:e)
    (retract ?ch)
    (assert (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?x) (y ?y) (e ?e)))
  )
)

(defrule emergencySpotted
  ?e <- (Emergency (id ?id) (type ?type) (location ?loc_X ?loc_Y) (n_affected_people ?n_affected))
  =>
  (printout t "A emergency appeared!" crlf)
  (assert
    (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?loc_X) (y ?loc_Y) (e ?e))
  )
)

; Contar el número de miembros total de un servicio
(deffunction count_members(?service_name)
  (bind ?count 0)
  (do-for-all-facts ((?service Service)) TRUE
    (if (eq ?service:name ?service_name)
     then
      (bind ?count (+ ?count ?service:n_members))
    )
  )
  (return ?count)
)

; Emergency type handler
(defrule is-thief
  ?serv <- (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?x) (y ?y) (e ?em))
  (test (eq ?type thief))
  (test (>= (count_members Policemen) (ceil (/ ?n_affected 10)) ))
  =>
  (printout t "Is a thief emergency" crlf)

  ; calculate required staff: 1 member/10 people
  (bind ?staff_policemen (ceil (/ ?n_affected 10)))
  (bind ?num_policemen (count_members Policemen))

  (if (>= ?num_policemen ?staff_policemen)
   then
    (assert (call Policemen ?id ?x ?y ?staff_policemen))
   else
    (printout t "ERROR: there are not enough policemen to attend to the emergency " ?id " : " (- ?num_policemen ?staff_policemen) crlf)
    (assert (Solution (id_solution (integer (* 1000 (time)))) (code_error -1) (id_emergency ?id) (name_emergency ?type) (id_service -1) (name_service Policemen)))

    (retract ?em)
    (assert (Emergency
      (id ?id)
      (type thief)
      (location ?x ?y)
      (n_affected_people ?n_affected)
    ))
  )

  ; delete choose-service
  (retract ?serv)
)

(defrule is-natural_disaster
  ?serv <- (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?x) (y ?y) (e ?em))
  (test (eq ?type natural_disaster))
  (test (>= (count_members Policemen) (ceil (/ ?n_affected 10)) ))
  (test (>= (count_members Firemen) (ceil (/ ?n_affected 10)) ))
  (test (>= (count_members Sanitary) (ceil (/ ?n_affected 10)) ))
  =>
  (printout t "Is a natural disaster emergency" crlf)
  ; calculate required staff: 1 member/10 people
  (bind ?staff_policemen (ceil (/ ?n_affected 10)))
  (bind ?staff_sanitary (ceil (/ ?n_affected 10)))
  (bind ?staff_firemen (ceil (/ ?n_affected 10)))

  (bind ?num_policemen (count_members Policemen))
  (bind ?num_sanitary (count_members Sanitary))
  (bind ?num_firemen (count_members Firemen))

  (if (and (>= ?num_policemen ?staff_policemen) (>= ?num_sanitary ?staff_sanitary) (>= ?num_firemen ?staff_firemen))
   then
    (assert (call Policemen ?id ?x ?y ?staff_policemen))
    (assert (call Sanitary ?id ?x ?y ?staff_sanitary))
    (assert (call Firemen ?id ?x ?y ?staff_firemen))
   else
    (printout t "ERROR: there are not enough policemen, sanitary or firemen to attend to the emergency " ?id " : " (- ?num_policemen ?staff_policemen) crlf)
    (assert (Solution (id_solution (integer (* 1000 (time)))) (code_error -1) (id_emergency ?id) (name_emergency ?type) (id_service -1) (name_service Policemen Sanitary Firemen)))

    (retract ?em)
    (assert (Emergency
      (id ?id)
      (type natural_disaster)
      (location ?x ?y)
      (n_affected_people ?n_affected)
    ))
  )

  ; delete choose-service
  (retract ?serv)
)

(defrule is-homicide
  ?serv <- (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?x) (y ?y) (e ?em))
  (test (eq ?type homicide))
  (test (>= (count_members Policemen) (ceil (/ ?n_affected 10)) ))
  (test (>= (count_members Sanitary) (ceil (/ ?n_affected 10)) ))
  =>
  (printout t "Is a homicide emergency" crlf)
  ; calculate required staff: 1 member/10 people
  (bind ?staff_policemen (ceil (/ ?n_affected 10)))
  (bind ?staff_sanitary (ceil (/ ?n_affected 10)))

  (bind ?num_policemen (count_members Policemen))
  (bind ?num_sanitary (count_members Sanitary))

  (if (and (>= ?num_policemen ?staff_policemen) (>= ?num_sanitary ?staff_sanitary))
   then
    (assert (call Policemen ?id ?x ?y ?staff_policemen))
    (assert (call Sanitary ?id ?x ?y ?staff_sanitary))
   else
    (printout t "ERROR: there are not enough policemen or sanitary to attend to the emergency " ?id " : " (- ?num_policemen ?staff_policemen) crlf)
    (assert (Solution (id_solution (integer (time))) (code_error -1) (id_emergency ?id) (name_emergency ?type) (id_service -1) (name_service Policemen Sanitary)))

    (retract ?em)
    (assert (Emergency
      (id ?id)
      (type homicide)
      (location ?x ?y)
      (n_affected_people ?n_affected)
    ))
  )
  ; delete choose-service
  (retract ?serv)
)

(defrule is-pandemic
  ?serv <- (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?x) (y ?y) (e ?em))
  (test (eq ?type pandemic))
  (test (>= (count_members Sanitary) (ceil (/ ?n_affected 10)) ))
  =>
  (printout t "Is a pandemic emergency" crlf)
  ; calculate required staff: 1 member/10 people
  (bind ?staff_sanitary (ceil (/ ?n_affected 10)))

  (bind ?num_sanitary (count_members Sanitary))

  (if (>= ?num_sanitary ?staff_sanitary)
   then
    (assert (call Sanitary ?id ?x ?y ?staff_sanitary))
   else
    (printout t "ERROR: there are not enough sanitary to attend to the emergency " ?id " : " (- ?num_sanitary ?staff_sanitary) crlf)
    (assert (Solution (id_solution (integer (* 1000 (time)))) (code_error -1) (id_emergency ?id) (name_emergency ?type) (id_service -1) (name_service Sanitary)))

    (retract ?em)
    (assert (Emergency
      (id ?id)
      (type pandemic)
      (location ?x ?y)
      (n_affected_people ?n_affected)
    ))
  )
  ; delete choose-service
  (retract ?serv)
)

(defrule is-car-crash
  ?serv <- (choose-service (id ?id) (type ?type) (n_affected ?n_affected) (x ?x) (y ?y) (e ?em))
  (test (eq ?type car_crash))
  (test (>= (count_members Policemen) (ceil (/ ?n_affected 10)) ))
  (test (>= (count_members Firemen) (ceil (/ ?n_affected 10)) ))
  =>
  (printout t "Is a car crash emergency" crlf)

  ; Calculate required staff: 1 member/10 people
  (bind ?staff_policemen (ceil (/ ?n_affected 10)))
  (bind ?staff_firemen (ceil (/ ?n_affected 10)))

  (bind ?num_policemen (count_members Policemen))
  (bind ?num_firemen (count_members Firemen))

  (if (and (>= ?num_policemen ?staff_policemen) (>= ?num_firemen ?staff_firemen))
   then
    (assert (call Policemen ?id ?x ?y ?staff_policemen))
    (assert (call Firemen ?id ?x ?y ?staff_firemen))
   else
    (printout t "ERROR: there are not enough policemen or firemen and to attend to the emergency " ?id " : " (- ?num_policemen ?staff_policemen) crlf)
    (assert (Solution (id_solution (integer (* 1000 (time)))) (code_error -1) (id_emergency ?id) (name_emergency ?type) (id_service -1) (name_service Policemen Firemen)))

    (retract ?em)
    (assert (Emergency
      (id ?id)
      (type car_crash)
      (location ?x ?y)
      (n_affected_people ?n_affected)
    ))
  )

  ; retract choose-service
  (retract ?serv)
)

; ----------------------------------------------------------------------------------------------------------


(defrule calculate-station-distance
  ?call <- (call ?name ?emergency_id ?x ?y ?staff)
  =>
  (do-for-all-facts ((?service Service)) TRUE
    (if (eq ?service:name ?name)
     then
      (bind ?id ?service:id)
      (bind ?locx (nth$ 1 (fact-slot-value ?service location)))
      (bind ?locy (nth$ 2 (fact-slot-value ?service location)))

      ; distancia euler entre estacion y emergencia = dist  | time = dist/speed + preparation_time
      (bind ?dist (sqrt (+ (* (- ?x ?locx) (- ?x ?locx)) (* (- ?y ?locy) (- ?y ?locy)))) )
      (bind ?mov_time (/ ?dist ?service:movement_speed))
      (bind ?time (+ ?mov_time ?service:prep_time))

      (assert (distance-station ?name ?emergency_id ?service:id ?time ?staff))
    )
  )
  (retract ?call)
)

(defrule attend-emergency
  ?ds <- (distance-station ?type ?emergency_id ?service_id ?time ?staff)
  ?service <- (Service (id ?id_service) (n_members ?n_members))
  (forall (and (distance-station ?emer_id ?serv_id ?ds_time ?s)
               (Service (id ?serv_id) (n_members ?n_mem))
          )
          (test (<= ?time ?ds_time))
  )
  (test (eq ?id_service ?service_id))
  =>
  (retract ?ds)
  ; eliminar staff del servicio
  (bind ?resto (- ?staff ?n_members)); numero de miembros restantes que hacen falta
  (bind ?new_n_members 0); numero de miembros que quedaran en el servicio
  (if (>= ?resto 0)
   then
      (bind ?new_n_members 0)
   else
      (bind ?resto 0)
      (bind ?new_n_members (- ?n_members ?staff))
  )
  (modify ?service (n_members ?new_n_members))
  ; actualizar todos los distance-station
  (do-for-all-facts ((?distance_station distance-station)) TRUE
    (bind ?tipo (nth$ 1 (fact-slot-value ?distance_station implied)) )
    (bind ?emergencia_id (nth$ 2 (fact-slot-value ?distance_station implied)) )
    (bind ?servicio_id (nth$ 3 (fact-slot-value ?distance_station implied)) )
    (bind ?tiempo (nth$ 4 (fact-slot-value ?distance_station implied)) )
    (bind ?staff (nth$ 5 (fact-slot-value ?distance_station implied)) )
    (if (and
          (eq ?tipo ?type)
          (eq ?emergencia_id ?emergency_id)
        )
     then
      (retract ?distance_station)
      (assert (distance-station ?tipo ?emergencia_id ?servicio_id ?tiempo ?resto))
    )
  )

  ;(printout t "La emergencia " ?emergency_id "  " ?type " station [" ?service_id "] time " ?time " -- " ?staff crlf)
  (bind ?miembros (- ?n_members ?new_n_members))
  (if (> ?miembros 0)
    then
    ; 10 members of station 10 have attended the emergency 3
    (printout t ?miembros " members of station " ?service_id " have attended the emergency " ?emergency_id crlf)

    ; encontrar nombre de servicio para el id y ...
    (bind ?service_name Policemen)
    (do-for-all-facts ((?service Service)) TRUE
      (if (eq ?service:id ?service_id)
       then
        (bind ?service_name ?service:name)
        (break)
      )
    )
    ; ... encontrar nombre de emergencia para el id.
    (bind ?emergency_type natural_disaster)
    (do-for-all-facts ((?emergency Emergency)) TRUE
      (if (eq ?emergency_id ?emergency:id)
       then
        (bind ?emergency_type ?emergency:type)
        (break)
      )
    )
    (assert (Solution (id_solution (integer (* 1000 (time)))) (code_error 0) (id_emergency ?emergency_id) (name_emergency ?emergency_type) (id_service ?service_id) (name_service ?service_name)))
  )
)

(defrule finish-emergency-service
  ?end_service <- (end-service ?id ?staff)
  ?serv <- (Service (id ?id_serv) (name ?serv_name) (location ?loc_X ?loc_Y) (n_members ?members) (movement_speed ?speed) (prep_time ?time))
  (test (eq ?id ?id_serv))
  =>
  (retract ?serv)
  (assert
    (Service
      (id ?id)
      (name ?serv_name)
      (location ?loc_X ?loc_Y)
      (n_members (+ ?members ?staff))
      (movement_speed ?speed)
      (prep_time ?time)
    )
  )
  (retract ?end_service)
)

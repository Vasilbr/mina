(** Transactions included in a block with the associated block data which is the protocol state body of the previous block. TODO: This will change to current block*)

module Block_data : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type t = Mina_state.Protocol_state.Body.Value.Stable.V2.t
      [@@deriving sexp]
    end
  end]

  type var

  val typ :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> (var, t) Snark_params.Tick.Typ.t
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V2 : sig
      type 'a t =
        { transaction : 'a
        ; block_data : Block_data.Stable.V2.t
        ; global_slot : Mina_numbers.Global_slot.Stable.V1.t
        }
      [@@deriving sexp]
    end
  end]
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type 'a t = 'a Poly.Stable.V2.t [@@deriving sexp]
  end
end]

val transaction : 'a t -> 'a

val block_data : _ t -> Block_data.t

val global_slot : _ t -> Mina_numbers.Global_slot.t

open Core_kernel
open Async_kernel
open Mina_base
open Mina_transaction
module Ledger = Mina_ledger.Ledger

[%%versioned:
module Stable : sig
  module V2 : sig
    type t [@@deriving sexp]

    val hash : t -> Staged_ledger_hash.Aux_hash.t
  end
end]

module Transaction_with_witness : sig
  (* TODO: The statement is redundant here - it can be computed from the witness and the transaction *)
  type t =
    { transaction_with_info : Ledger.Transaction_applied.t
    ; state_hash : State_hash.t * State_body_hash.t
    ; statement : Transaction_snark.Statement.t
    ; init_stack : Transaction_snark.Pending_coinbase_stack_state.Init_stack.t
    ; ledger_witness : Mina_ledger.Sparse_ledger.t
    ; block_global_slot : Mina_numbers.Global_slot.t
    }
  [@@deriving sexp]
end

module Ledger_proof_with_sok_message : sig
  type t = Ledger_proof.t * Sok_message.t
end

module Available_job : sig
  type t [@@deriving sexp]
end

module Space_partition : sig
  type t = { first : int * int; second : (int * int) option } [@@deriving sexp]
end

module Job_view : sig
  type t [@@deriving sexp, to_yojson]
end

module Make_statement_scanner (Verifier : sig
  type t

  val verify :
       verifier:t
    -> Ledger_proof_with_sok_message.t list
    -> unit Or_error.t Deferred.Or_error.t
end) : sig
  val scan_statement :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> t
    -> statement_check:
         [ `Full of State_hash.t -> Mina_state.Protocol_state.value Or_error.t
         | `Partial ]
    -> verifier:Verifier.t
    -> ( Transaction_snark.Statement.t
       , [ `Empty | `Error of Error.t ] )
       Deferred.Result.t

  val check_invariants :
       t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> statement_check:
         [ `Full of State_hash.t -> Mina_state.Protocol_state.value Or_error.t
         | `Partial ]
    -> verifier:Verifier.t
    -> error_prefix:string
    -> registers_begin:Mina_state.Registers.Value.t option
    -> registers_end:Mina_state.Registers.Value.t
    -> (unit, Error.t) Deferred.Result.t
end

val empty :
  constraint_constants:Genesis_constants.Constraint_constants.t -> unit -> t

val fill_work_and_enqueue_transactions :
     t
  -> Transaction_with_witness.t list
  -> Transaction_snark_work.t list
  -> ( (Ledger_proof.t * (Transaction.t With_status.t * State_hash.t) list)
       option
     * t )
     Or_error.t

val latest_ledger_proof :
     t
  -> ( Ledger_proof_with_sok_message.t
     * (Transaction.t With_status.t * State_hash.t * Mina_numbers.Global_slot.t)
       list )
     option

val free_space : t -> int

val base_jobs_on_latest_tree : t -> Transaction_with_witness.t list

(* a 0 index means next-to-latest tree *)
val base_jobs_on_earlier_tree :
  t -> index:int -> Transaction_with_witness.t list

val hash : t -> Staged_ledger_hash.Aux_hash.t

(** All the transactions in the order in which they were applied*)
val staged_transactions : t -> Transaction.t With_status.t list

(** All the transactions with parent protocol state of the block in which they were included in the order in which they were applied*)
val staged_transactions_with_protocol_states :
     t
  -> get_state:(State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
  -> ( Transaction.t With_status.t
     * Mina_state.Protocol_state.value
     * Mina_numbers.Global_slot.t )
     list
     Or_error.t

(** Available space and the corresponding required work-count in one and/or two trees (if the slots to be occupied are in two different trees)*)
val partition_if_overflowing : t -> Space_partition.t

val statement_of_job : Available_job.t -> Transaction_snark.Statement.t option

val snark_job_list_json : t -> string

(** All the proof bundles *)
val all_work_statements_exn :
  t -> Transaction_snark.Statement.t One_or_two.t list

(** Required proof bundles for a certain number of slots *)
val required_work_pairs : t -> slots:int -> Available_job.t One_or_two.t list

(**K proof bundles*)
val k_work_pairs_for_new_diff : t -> k:int -> Available_job.t One_or_two.t list

(** All the proof bundles for 2**transaction_capacity_log2 slots that can be used up in one diff *)
val work_statements_for_new_diff :
  t -> Transaction_snark.Statement.t One_or_two.t list

(** True if the latest tree is full and transactions would be added on to a new tree *)
val next_on_new_tree : t -> bool

(**update scan state metrics*)
val update_metrics : t -> unit Or_error.t

(** Hashes of the protocol states required for proving transactions*)
val required_state_hashes : t -> State_hash.Set.t

(** Validate protocol states required for proving the transactions. Returns an association list of state_hash and the corresponding state*)
val check_required_protocol_states :
     t
  -> protocol_states:
       Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
  -> Mina_state.Protocol_state.value State_hash.With_state_hashes.t list
     Or_error.t

(** All the proof bundles for snark workers*)
val all_work_pairs :
     t
  -> get_state:(State_hash.t -> Mina_state.Protocol_state.value Or_error.t)
  -> (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
     One_or_two.t
     list
     Or_error.t

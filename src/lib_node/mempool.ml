type t = {
  known_valid: Operation_hash.t list ;
  pending: Operation_hash.Set.t ;
}
type mempool = t

let encoding =
  let open Data_encoding in
  conv
    (fun { known_valid ; pending } -> (known_valid, pending))
    (fun (known_valid, pending) -> { known_valid ; pending })
    (obj2
       (req "known_valid" (list Operation_hash.encoding))
       (req "pending" (dynamic_size Operation_hash.Set.encoding)))

let bounded_encoding ?max_operations () =
  match max_operations with
  | None -> encoding
  | Some max_operations ->
      Data_encoding.check_size
        (8 + max_operations * Operation_hash.size)
        encoding

let empty = {
  known_valid = [] ;
  pending = Operation_hash.Set.empty ;
}

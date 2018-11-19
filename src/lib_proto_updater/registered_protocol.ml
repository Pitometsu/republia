module type T = sig
  module P : sig
    val hash: Protocol_hash.t
    include Rpb_protocol_environment_shell.PROTOCOL
  end
  include (module type of (struct include P end))
  module Block_services :
    (module type of (struct include Block_services.Make(P)(P) end))
  val complete_b58prefix : Context.t -> string -> string list Lwt.t
end

type t = (module T)

let build_v1 hash =
  let (module F) = Rpb_protocol_registerer.Registerer.get_exn hash in
  let module Name = struct
    let name = Protocol_hash.to_b58check hash
  end in
  let module Env = Rpb_protocol_environment_shell.MakeV1(Name)() in
  (module struct
    module Raw = F(Env)
    module P = struct
      let hash = hash
      include Env.Lift(Raw)
    end
    include P
    module Block_services = Block_services.Make(P)(P)
    let complete_b58prefix = Env.Context.complete
  end : T)

module VersionTable = Protocol_hash.Table

let versions : (module T) VersionTable.t =
  VersionTable.create 20

let sources : Protocol.t VersionTable.t =
  VersionTable.create 20

let mem hash =
  VersionTable.mem versions hash ||
  Rpb_protocol_registerer.Registerer.mem hash

let get_exn hash =
  try VersionTable.find versions hash
  with Not_found ->
    let proto = build_v1 hash in
    VersionTable.add versions hash proto ;
    proto

let get hash =
  try Some (get_exn hash)
  with Not_found -> None

let list () =
  VersionTable.fold (fun _ p acc -> p :: acc) versions []

let list_embedded () =
  VersionTable.fold (fun k _ acc -> k :: acc) sources []

let get_embedded_sources_exn hash =
  VersionTable.find sources hash

let get_embedded_sources hash =
  try Some (get_embedded_sources_exn hash)
  with Not_found -> None

module Register_embedded
    (Env : Rpb_protocol_environment_shell.V1)
    (Proto : Env.Updater.PROTOCOL)
    (Source : sig
       val hash: Protocol_hash.t option
       val sources: Protocol.t
     end) = struct

  let () =
    let hash =
      match Source.hash with
      | None -> Protocol.hash Source.sources
      | Some hash -> hash in
    let module Name = struct
      let name = Protocol_hash.to_b58check hash
    end in
    VersionTable.add
      sources hash Source.sources ;
    VersionTable.add
      versions hash
      (module struct
        module P = struct
          let hash = hash
          include Env.Lift(Proto)
        end
        include P
        module Block_services = Block_services.Make(P)(P)
        let complete_b58prefix = Env.Context.complete
      end : T)

end

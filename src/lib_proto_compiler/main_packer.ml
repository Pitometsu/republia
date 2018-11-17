let (//) = Filename.concat

let () =
  Random.self_init () ;
  let anonymous = ref [] in
  let args_spec = [ ] in
  let usage_msg =
    Printf.sprintf "Usage: %s [options] <srcdir>" Sys.argv.(0) in
  Arg.parse args_spec (fun s -> anonymous := s :: !anonymous) usage_msg ;
  let source_dir =
    match List.rev !anonymous with
    | [ source_dir ] -> source_dir
    | _ -> Arg.usage args_spec usage_msg ; Pervasives.exit 1 in
  let hash, protocol =
    match Lwt_main.run (Lwt_utils_unix.Protocol.read_dir source_dir) with
    | Ok v -> v
    | Error err ->
        Format.kasprintf Pervasives.failwith
          "Failed to read TEZOS_PROTOCOL: %a" pp_print_error err in
  (* Generate the 'functor' *)
  Packer.dump stdout hash
    (Array.map
       begin fun { Protocol.name ; _ }  ->
         let name_lowercase = String.uncapitalize_ascii name in
         source_dir // name_lowercase ^ ".ml"
       end
       (Array.of_list protocol.components))

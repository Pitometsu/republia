open Updater_logging

let (//) = Filename.concat

(** Compiler *)

let datadir = ref None
let get_datadir () =
  match !datadir with
  | None ->
      fatal_error "Node not initialized" ;
      Lwt_exit.exit 1
  | Some m -> m

let init dir =
  datadir := Some dir

let compiler_name = "Rpb-protocol-compiler"

let do_compile hash p =
  assert (p.Protocol.expected_env = V1) ;
  let datadir = get_datadir () in
  let source_dir = datadir // Protocol_hash.to_short_b58check hash // "src" in
  let log_file = datadir // Protocol_hash.to_short_b58check hash // "LOG" in
  let plugin_file = datadir // Protocol_hash.to_short_b58check hash //
                    Format.asprintf "protocol_%a" Protocol_hash.pp hash
  in
  begin
    Lwt_utils_unix.Protocol.write_dir source_dir ~hash p >>=? fun () ->
    let compiler_command =
      (Sys.executable_name,
       Array.of_list [compiler_name; "-register"; plugin_file; source_dir]) in
    let fd = Unix.(openfile log_file [O_WRONLY; O_CREAT; O_TRUNC] 0o644) in
    Lwt_process.exec
      ~stdin:`Close ~stdout:(`FD_copy fd) ~stderr:(`FD_move fd)
      compiler_command >>= return
  end >>= function
  | Error err ->
      log_error "Error %a" pp_print_error err ;
      Lwt.return_false
  | Ok (Unix.WSIGNALED _ | Unix.WSTOPPED _) ->
      log_error "INTERRUPTED COMPILATION (%s)" log_file;
      Lwt.return_false
  | Ok (Unix.WEXITED x) when x <> 0 ->
      log_error "COMPILATION ERROR (%s)" log_file;
      Lwt.return_false
  | Ok (Unix.WEXITED _) ->
      try Dynlink.loadfile_private (plugin_file ^ ".cmxs"); Lwt.return_true
      with Dynlink.Error err ->
        log_error "Can't load plugin: %s (%s)"
          (Dynlink.error_message err) plugin_file;
        Lwt.return_false

let compile hash p =
  if Rpb_protocol_registerer.Registerer.mem hash then
    Lwt.return_true
  else begin
    do_compile hash p >>= fun success ->
    let loaded = Rpb_protocol_registerer.Registerer.mem hash in
    if success && not loaded then
      log_error "Internal error while compiling %a" Protocol_hash.pp hash;
    Lwt.return loaded
  end

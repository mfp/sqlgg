(**
  Sqlite3 OCaml traits for sqlgg
  by ygrek
  2015-07-09

  This is free and unencumbered software released into the public domain.

  Anyone is free to copy, modify, publish, use, compile, sell, or
  distribute this software, either in source code form or as a compiled
  binary, for any purpose, commercial or non-commercial, and by any
  means.

  For more information, please refer to <http://unlicense.org/>
*)

open Printf

module M = struct

module S = Sqlite3

module Types = struct
  module Bool = struct type t = bool end
  module Int = Int64
  module Text = struct type t = string end
  module Float = struct type t = float end
  (* you probably want better type, e.g. (int*int) or Z.t *)
  module Decimal = Float
  module Datetime = Float (* ? *)
  module Any = Text
end

type statement = S.stmt * string
type 'a connection = S.db
type params = statement * int * int ref
type row = statement
type result = unit

type num = int64
type text = string
type any = string
type datetime = float

exception Oops of string

module Conv = struct
  open S.Data
  exception Type_mismatch of t
  let () = Printexc.register_printer (function Type_mismatch x -> Some (sprintf "Conv.Type_mismatch %s" (to_string_debug x)) | _ -> None)
  let bool = "Bool", function INT i -> i <> 0L | x -> raise (Type_mismatch x)
  let int = "Int", function INT i -> i | x -> raise (Type_mismatch x)
  let text = "Text", function TEXT s | BLOB s -> s | x -> raise (Type_mismatch x)
  let float = "Float", function FLOAT x -> x | x -> raise (Type_mismatch x)
  let decimal = "Decimal", function INT i -> Int64.to_float i | FLOAT x -> x | x -> raise (Type_mismatch x)
end

let get_column_ty (name,conv) =
  begin fun (stmt,sql) index ->
    try conv (S.column stmt index)
    with exn -> raise (Oops (sprintf "get_column_%s %u for %s : %s" name index sql (Printexc.to_string exn)))
  end,
  begin fun (stmt,sql) index ->
    try match S.column stmt index with S.Data.NULL -> None | x -> Some (conv x)
    with exn -> raise (Oops (sprintf "get_column_%s_nullable %u for %s : %s" name index sql (Printexc.to_string exn)))
  end

let get_column_Bool, get_column_Bool_nullable = get_column_ty Conv.bool
let get_column_Int, get_column_Int_nullable = get_column_ty Conv.int
let get_column_Text, get_column_Text_nullable = get_column_ty Conv.text
let get_column_Any, get_column_Any_nullable = get_column_ty Conv.text
let get_column_Float, get_column_Float_nullable = get_column_ty Conv.float
let get_column_Decimal, get_column_Decimal_nullable = get_column_ty Conv.decimal
let get_column_Datetime, get_column_Datetime_nullable = get_column_ty Conv.float

let test_ok sql rc =
  if rc <> S.Rc.OK then
    raise (Oops (sprintf "test_ok %s for %s" (S.Rc.to_string rc) sql))

let bind_param d ((stmt,sql),nr_params,index) =
  assert (!index < nr_params);
  let rc = S.bind stmt (!index+1) d in
  incr index;
  test_ok sql rc

let start_params stmt n = (stmt, n, ref 0)
let finish_params (_,n,index) = assert (n = !index); ()

let set_param_null = bind_param S.Data.NULL
let set_param_Text stmt v = bind_param (S.Data.TEXT v) stmt
let set_param_Any = set_param_Text
let set_param_Bool stmt v = bind_param (S.Data.INT (if v then 1L else 0L)) stmt
let set_param_Int stmt v = bind_param (S.Data.INT v) stmt
let set_param_Float stmt v = bind_param (S.Data.FLOAT v) stmt
let set_param_Decimal = set_param_Float
let set_param_Datetime = set_param_Float

let no_params _ = ()

let try_finally final f x =
  let r =
    try f x with exn -> final (); raise exn
  in
    final ();
    r

let with_sql db sql f =
  let stmt = S.prepare db sql in
  try_finally
    (fun () -> test_ok sql (S.finalize stmt))
    f (stmt,sql)

let select db sql set_params callback =
  with_sql db sql (fun stmt ->
    set_params stmt;
    while S.Rc.ROW = S.step (fst stmt) do
      callback stmt
    done)

let execute db sql set_params =
  with_sql db sql (fun stmt ->
    set_params stmt;
    let rc = S.step (fst stmt) in
    if rc <> S.Rc.DONE then raise (Oops (sprintf "execute : %s" sql));
    Int64.of_int (S.changes db)
  )

let select_one_maybe db sql set_params convert =
  with_sql db sql (fun stmt ->
    set_params stmt;
    if S.Rc.ROW = S.step (fst stmt) then
      Some (convert stmt)
    else
      None)

let select_one db sql set_params convert =
  with_sql db sql (fun stmt ->
    set_params stmt;
    if S.Rc.ROW = S.step (fst stmt) then
      convert stmt
    else
      raise (Oops (sprintf "no row but one expected : %s" sql)))

end

let () =
  (* checking signature match *)
  let module S = (M:Sqlgg_traits.M) in ()

include M

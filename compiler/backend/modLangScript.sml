open preamble astTheory;
open backend_commonTheory;

val _ = new_theory "modLang";

val _ = set_grammar_ancestry ["ast"];

(* The first intermediate language modLang. It removes modules and resolves all
 * global scoping. Each value definition gets allocated a slot in a global
 * variable store, and each constructor gets a unique global identifier.
 * It removes andalso and orelse and replaces them with if, and removes the
 * AallocEmpty primitive op and replaces it with an alloc call with 0.
 *
 * The AST of modLang differs from the source language by having two variable
 * reference forms, one to reference local bindings (still by name) and one to
 * reference global bindings (by index). At the top level, modules are gone.
 * Top-level lets and letrecs no longer bind names (or have patterns), and the
 * lets come with just a number indicating how many bindings to install in the
 * global environment. Constructor names are replaced with numbers, and type and
 * exception definitions record the arities of the constructors rather than the
 * types. Type annotations are also gone.
 *)

(* Copied from the semantics, but with AallocEmpty missing. GlobalVar ops have
 * been added. *)
val _ = Datatype `
 op =
  (* Operations on integers *)
    Opn opn
  | Opb opb
  (* Operations on words *)
  | Opw word_size opw
  | Shift word_size shift num
  | Equality
  (* FP operations *)
  | FP_cmp fp_cmp
  | FP_uop fp_uop
  | FP_bop fp_bop
  (* Function application *)
  | Opapp
  (* Reference operations *)
  | Opassign
  | Opref
  | Opderef
  (* Word8Array operations *)
  | Aw8alloc
  | Aw8sub
  | Aw8length
  | Aw8update
  (* Word/integer conversions *)
  | WordFromInt word_size
  | WordToInt word_size
  (* string/bytearray conversions *)
  | CopyStrStr
  | CopyStrAw8
  | CopyAw8Str
  | CopyAw8Aw8
  (* Char operations *)
  | Ord
  | Chr
  | Chopb opb
  (* String operations *)
  | Implode
  | Strsub
  | Strlen
  | Strcat
  (* Vector operations *)
  | VfromList
  | Vsub
  | Vlength
  (* Array operations *)
  | Aalloc
  | Asub
  | Alength
  | Aupdate
  (* Configure the GC *)
  | ConfigGC
  (* Call a given foreign function *)
  | FFI string
  (* Allocate the given number of new global variables *)
  | GlobalVarAlloc num
  (* Initialise given global variable *)
  | GlobalVarInit num
  (* Get the value of the given global variable *)
  | GlobalVarLookup num`;

val _ = type_abbrev ("ctor_id", ``:num``);
(* NONE represents the exception type *)
val _ = type_abbrev ("type_id", ``:num option``);

val _ = Datatype `
  pat =
  | Pany
  | Pvar varN
  | Plit lit
  | Pcon ((ctor_id # type_id) option) (pat list)
  | Pref pat`;

val _ = Datatype`
  exp =
    Raise tra exp
  | Handle tra exp ((pat # exp) list)
  | Lit tra lit
  | Con tra ((ctor_id # type_id) option) (exp list)
  | Var_local tra varN
  | Fun tra varN exp
  | App tra op (exp list)
  | If tra exp exp exp
  | Mat tra exp ((pat # exp) list)
  | Let tra (varN option) exp exp
  | Letrec tra ((varN # varN # exp) list) exp`;

val exp_size_def = definition"exp_size_def";

val exp6_size_APPEND = Q.store_thm("exp6_size_APPEND[simp]",
  `modLang$exp6_size (e ++ e2) = exp6_size e + exp6_size e2`,
  Induct_on`e`>>simp[exp_size_def])

val exp6_size_REVERSE = Q.store_thm("exp6_size_REVERSE[simp]",
  `modLang$exp6_size (REVERSE es) = exp6_size es`,
  Induct_on`es`>>simp[exp_size_def])

val _ = Datatype`
 dec =
    Dlet exp
  (* The first number is the identity for the type. The sptree maps arities to
   * how many constructors have that arity *)
  | Dtype num (num spt)
  (* The first number is the identity of the exception. The second number is the
   * constructor's arity *)
  | Dexn num num`;

val _ = export_theory ();

open preamble;
open ASCIInumbersTheory;
open bigStepTheory typeSystemTheory astTheory elabTheory lexer_funTheory;
open initialEnvTheory;
open gramTheory cmlPtreeConversionTheory;

val _ = new_theory "repl";

val _ = Hol_datatype `
repl_state = <| (* Elaborator state *)
                type_bindings : tdef_env;
                (* Type system state *)
                tdecs : decls; tenvM : tenvM; tenvC : tenvC; tenv : tenvE;
                (* Semantics state *)
                envM : envM; envC : envC; store : (v count_store # tid_or_exn set # modN set); envE : envE |>`;

val _ = Hol_datatype `
repl_result =
    Terminate
  | Diverge
  | Result of string => repl_result`;

val update_repl_state_def = Define `
update_repl_state ast state type_bindings tdecs tenvM tenvC tenv store envC r =
  case r of
    | Rval (envM,envE) =>
        <| type_bindings := type_bindings ++ state.type_bindings;
           tdecs := tdecs;
           tenvM := tenvM ++ state.tenvM;
           tenvC := merge_tenvC tenvC state.tenvC;
           tenv := bind_var_list2 tenv state.tenv;
           store := store;
           envM := envM ++ state.envM;
           envC := merge_envC envC state.envC;
           envE := envE ++ state.envE |>
    | Rerr _ =>
        (* We need to record the attempted module names (if any), so that it
        * can't be defined later.  To avoid the situation where a failing module
        * defines some datatype constructors and puts them into the store before
        * failing. *)
        state with <| store := store;
                      tdecs := tdecs |>`;

val print_envM_def = Define `
print_envM envM = CONCAT (MAP (λ(x,m). "module " ++ x ++ " = <structure>\n") envM)`;

val print_envC_def = Define `
print_envC (menvC,envC) = CONCAT (MAP (λ(x,c). x ++ " = <constructor>\n") envC)`;

val print_lit_def = Define `
(print_lit (IntLit i) = int_to_string i) ∧
(print_lit (StrLit s) = string_to_string s) ∧
(print_lit (Bool T) = "true") ∧
(print_lit (Bool F) = "false") ∧
(print_lit Unit = "()")`;

val print_v_def = Define `
(print_v (Litv l) = print_lit l) ∧
(print_v (Conv _ _) = "<constructor>") ∧
(print_v (Closure _ _ _) = "<fn>") ∧
(print_v (Recclosure _ _ _) = "<fn>") ∧
(print_v (Loc _) = "<ref>")`;

val print_envE_def = Define `
print_envE types envE = CONCAT (MAP (\(x,v). "val " ++ x ++ ":" ++ FAPPLY types x ++ " = " ++ print_v v ++ "\n") envE)`;

val print_result_def = Define `
(print_result types (Tdec _) envC (Rval (envM,envE)) = print_envC envC ++ print_envE types envE) ∧
(print_result _ (Tmod mn _ _) _ (Rval _) = "structure "++mn++" = <structure>\n") ∧
(print_result _ _ _ (Rerr Rtimeout_error) = "<timeout error>\n") ∧
(print_result _ _ _ (Rerr Rtype_error) = "<type error>\n") ∧
(print_result _ _ _ (Rerr (Rraise e)) = "raise " ++ print_v e ++ "\n")`;

val tc_to_string_def = Define `
(tc_to_string (TC_name id) ⇔ id_to_string id) ∧
(tc_to_string TC_int ⇔ "<int>") ∧
(tc_to_string TC_string ⇔ "<string>") ∧
(tc_to_string TC_bool ⇔ "<bool>") ∧
(tc_to_string TC_unit ⇔ "<unit>") ∧
(tc_to_string TC_ref ⇔ "<ref>") ∧
(tc_to_string TC_exn ⇔ "<exn>")`;

val type_to_string_def = tDefine "type_to_string" `
(type_to_string (Tvar tvn) ⇔ tvn) ∧
(type_to_string (Tvar_db n) ⇔ num_to_dec_string n) ∧
(type_to_string (Tapp [t1;t2] TC_fn) ⇔ 
  "(" ++ type_to_string t1 ++ "->" ++ type_to_string t2 ++ ")") ∧
(type_to_string (Tapp ts TC_fn) ⇔ "<bad function type>") ∧
(type_to_string (Tapp ts TC_tup) ⇔
  "(" ++ types_to_string ts ++ ")") ∧
(type_to_string (Tapp [] tc) ⇔ tc_to_string tc) ∧
(type_to_string (Tapp ts tc) ⇔ 
  "(" ++ types_to_string ts ++ ") " ++ tc_to_string tc) ∧
(types_to_string [] ⇔ "") ∧
(types_to_string [t] ⇔ type_to_string t) ∧
(types_to_string (t::ts) ⇔ type_to_string t ++ ", " ++ types_to_string ts)`
(wf_rel_tac `measure (\x. case x of INL x => t_size x | INR x => t1_size x)`);

val tenv_to_string_map_def = Define `
(tenv_to_string_map [] ⇔ FEMPTY) ∧
(tenv_to_string_map ((x, (_, t)) :: tenv) ⇔
  tenv_to_string_map tenv |+ (x, type_to_string t))`;

val remove_count_def = Define `
remove_count ((count,store),tdecls,mods) = (store,tdecls,mods)`;

val (ast_repl_rules, ast_repl_ind, ast_repl_cases) = Hol_reln `

(!state.
  ast_repl state [] [] Terminate) ∧

(!state type_errors ast asts top rest type_bindings' tdecs' tenvM' tenvC' tenv' store' envC' r.
  (elab_top state.type_bindings ast = (type_bindings', top)) ∧
  (type_top state.tdecs state.tenvM state.tenvC state.tenv top tdecs' tenvM' tenvC' tenv') ∧
  evaluate_top F (state.envM, state.envC, state.envE) state.store top (store',envC',r) ∧
  ast_repl (update_repl_state top state type_bindings' (union_decls tdecs' state.tdecs) tenvM' tenvC' tenv' store' envC' r) type_errors asts rest
  ⇒
  ast_repl state (F::type_errors) (SOME ast::asts) (Result (print_result (tenv_to_string_map tenv') top envC' r) rest)) ∧

(!state type_errors ast asts top type_bindings' tdecs' tenvM' tenvC' tenv'.
  (elab_top state.type_bindings ast =
   (type_bindings', top)) ∧
  (type_top state.tdecs state.tenvM state.tenvC state.tenv top tdecs' tenvM' tenvC' tenv') ∧
  top_diverges (state.envM, state.envC, state.envE) (remove_count state.store) top
  ⇒
  ast_repl state (F::type_errors) (SOME ast::asts) Diverge) ∧

(!state type_errors ast asts rest.
  ast_repl state type_errors asts rest
  ⇒
  ast_repl state (T::type_errors) (SOME ast::asts) (Result "<type error>\n" rest)) ∧

(!state x type_errors asts rest.
  ast_repl state type_errors asts rest
  ⇒
  ast_repl state (x::type_errors) (NONE::asts) (Result "<parse error>\n" rest))`;

val parse_def = Define`
  parse toks =
    case some pt. valid_ptree cmlG pt ∧ ptree_head pt = NT (mkNT nREPLTop) ∧
                  ptree_fringe pt = MAP TOK toks
    of
       NONE => NONE
     | SOME p => ptree_REPLTop p
`

val repl_def = Define `
repl init_repl_state type_errors input = ast_repl init_repl_state type_errors (MAP parse (split_top_level_semi (lexer_fun input)))`;

val _ = export_theory ();

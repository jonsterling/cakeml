open preamble miscLib;
open astTheory bigStepTheory initialEnvTheory interpTheory inferTheory typeSystemTheory modLangTheory conLangTheory bytecodeTheory bytecodeExtraTheory;
open bigClockTheory untypedSafetyTheory inferSoundTheory modLangProofTheory conLangProofTheory typeSoundInvariantsTheory typeSoundTheory;
open compute_bytecodeLib compute_interpLib compute_inferenceLib compute_compilerLib;

val _ = new_theory "initialProgram";

val _ = ParseExtras.temp_tight_equality ();

val _ = Hol_datatype `
  comp_environment = <| inf_mdecls : modN list;
                        inf_tdecls : typeN id list;
                        inf_edecls : conN id list;
                        inf_tenvM : (tvarN, (tvarN, num # infer_t) alist) alist;
                        inf_tenvC : tenvC;
                        inf_tenvE : (tvarN, num # infer_t) alist;
                        comp_rs : compiler_state |>`;

val _ = Hol_datatype `
  sem_environment = <| sem_envM : envM;
                       sem_envC : envC;
                       sem_envE : envE;
                       sem_s : v store;
                       sem_tids : tid_or_exn set;
                       sem_mdecls : modN set |>`;

val invariant_def = Define `
invariant se ce bs ⇔
  ?genv gtagenv rd.
    type_sound_invariants (NONE : (v,v) result option)
                          (convert_decls (ce.inf_mdecls, ce.inf_tdecls, ce.inf_edecls),
                           convert_menv ce.inf_tenvM,
                           ce.inf_tenvC,
                           bind_var_list2 (convert_env2 ce.inf_tenvE) Empty,
                           se.sem_tids,
                           se.sem_envM,
                           se.sem_envC,
                           se.sem_envE,
                           se.sem_s) ∧
    infer_sound_invariant ce.inf_tenvM ce.inf_tenvC ce.inf_tenvE ∧
    se.sem_mdecls = set ce.inf_mdecls ∧
    env_rs (se.sem_envM, se.sem_envC, se.sem_envE) ((0,se.sem_s),se.sem_tids,se.sem_mdecls) (genv,gtagenv,rd) ce.comp_rs bs ∧
    bs.clock = NONE ∧ code_labels_ok bs.code ∧ code_executes_ok bs`;

val add_to_env_def = Define `
add_to_env e prog =
  let inf_env = infer_prog (e.inf_mdecls,e.inf_tdecls,e.inf_edecls) e.inf_tenvM e.inf_tenvC e.inf_tenvE prog init_infer_state in
  let (rs',code) = compile_initial_prog e.comp_rs prog in
    case inf_env of
      | (Success ((mdecls',tdecls',edecls'), tenvM', tenvC', tenvE'), st) =>
            SOME
             (<| inf_mdecls := mdecls' ++ e.inf_mdecls;
                 inf_tdecls := tdecls' ++ e.inf_tdecls;
                 inf_edecls := edecls' ++ e.inf_edecls;
                 inf_tenvM := tenvM' ++ e.inf_tenvM;
                 inf_tenvC := merge_tenvC tenvC' e.inf_tenvC;
                 inf_tenvE := tenvE' ++ e.inf_tenvE;
                 comp_rs := rs' |>,
              code)
      | _ => NONE`;

val add_to_sem_env_def = Define `
add_to_sem_env se prog =
  case run_eval_prog (se.sem_envM,se.sem_envC,se.sem_envE) ((10000,se.sem_s),se.sem_tids,se.sem_mdecls) prog of
     | (((cnt,s),tids,mdecls),envC,Rval (envM,envE)) =>
         SOME 
         <| sem_envM := envM ++ se.sem_envM;
            sem_envC := merge_envC envC se.sem_envC;
            sem_envE := envE ++ se.sem_envE;
            sem_s := s;
            sem_tids := tids;
            sem_mdecls := mdecls |>
     | _ => NONE`;

val compile_thm =
  SIMP_RULE (srw_ss()++boolSimps.DNF_ss) [AND_IMP_INTRO, evaluate_whole_prog_def] compilerProofTheory.compile_initial_prog_thm;

val add_to_env_invariant_lem = Q.prove (
`!envM envC envE cnt s tids prog cnt' s' envM' envC' envE' tids' mdecls' e e' code bs bs'.
  closed_prog prog ∧
  evaluate_whole_prog T (envM,envC,envE) ((cnt,s),tids,set e.inf_mdecls) prog (((cnt',s'),tids',mdecls'),envC',Rval (envM',envE')) ∧
  invariant <| sem_envM := envM; sem_envC := envC; sem_envE := envE; sem_s := s; sem_tids := tids; sem_mdecls := set e.inf_mdecls |> e bs ∧
  SOME (e',code) = add_to_env e prog ∧
  SOME bs' = bc_eval (bs with <| code   := bs.code ++ REVERSE code
                               ; pc     := next_addr bs.inst_length bs.code |>)
  ⇒
  invariant <| sem_envM := envM' ++ envM;
               sem_envC := merge_envC envC' envC;
               sem_envE := envE' ++ envE;
               sem_s := s';
               sem_tids := tids';
               sem_mdecls := mdecls' |>
            e' (bs' with clock := NONE)`,
 rw [add_to_env_def, LET_THM] >>
 every_case_tac >>
 fs [] >>
 `?rs' code. compile_initial_prog e.comp_rs prog = (rs',code)` by metis_tac [pair_CASES] >>
 fs [] >>
 rw [] >>
 fs [invariant_def] >>
 imp_res_tac infer_prog_sound >>
 simp [] >>
 `evaluate_prog F (envM,envC,envE) ((0,s),tids,set e.inf_mdecls) prog (((0,s'),tids',mdecls'),envC',Rval (envM',envE'))`
          by (rw [prog_clocked_unclocked_equiv] >>
              fs [evaluate_whole_prog_def] >>
              imp_res_tac prog_clocked_min_counter >>
              fs [] >>
              metis_tac []) >>
 `~prog_diverges (envM,envC,envE) (s,tids,set e.inf_mdecls) prog` by metis_tac [untyped_safety_prog] >>
 imp_res_tac prog_type_soundness >>
 fs [convert_decls_def] >>
 ntac 2 (pop_assum (fn _ => all_tac)) >>
 res_tac >>
 pop_assum mp_tac >>
 pop_assum (fn _ => all_tac) >>
 rw [] >>
 pop_assum (qspec_then `0` assume_tac) >>
 fs [typeSoundInvariantsTheory.update_type_sound_inv_def, evaluate_whole_prog_def] >>
 imp_res_tac determTheory.prog_determ >>
 fs [] >>
 rw [] >>
 fs [union_decls_def, convert_menv_def, typeSysPropsTheory.bvl2_append, convert_env2_def] >>
 rw [] >>
 qabbrev_tac `bs1 = bs with <| clock := SOME cnt; code := bs.code++REVERSE code; pc := next_addr bs.inst_length bs.code |>` >>
 qabbrev_tac `bc0 = bs.code` >>
 `env_rs (envM,envC,envE) ((cnt,s),tids,set e.inf_mdecls) (genv,gtagenv,rd) e.comp_rs (bs1 with code := bc0)`
             by (UNABBREV_ALL_TAC >>
                 rw [bc_state_fn_updates] >>
                 match_mp_tac compilerProofTheory.env_rs_with_bs_irr >>
                 qexists_tac`bs with clock := SOME cnt` >> simp[] >>
                 match_mp_tac compilerProofTheory.env_rs_change_clock >>
                 first_assum(match_exists_tac o concl) >>
                 simp[bc_state_component_equality]) >>
 `bs1.code = bc0 ++ REVERSE code`
             by (UNABBREV_ALL_TAC >>
                 rw [bc_state_fn_updates]) >>
 `IS_SOME bs1.clock`
             by (UNABBREV_ALL_TAC >>
                 rw [bc_state_fn_updates]) >>
 `bs1.pc = next_addr bs1.inst_length bc0` by simp[Abbr`bc0`,Abbr`bs1`] >>
 `?bs'' grd''.
    bc_next^* bs1 bs'' ∧ bc_fetch bs'' = SOME (Stop T) ∧
    bs''.output = bs1.output ∧
    env_rs (envM' ++ FST (envM,envC,envE),merge_envC cenv2 (FST (SND (envM,envC,envE))), envE' ++ SND (SND (envM,envC,envE))) ((cnt',s'),decls2',set q''' ∪ set e.inf_mdecls) grd'' rs' bs''`
               by metis_tac [compile_thm] >>
 fs [] >>
 pop_assum(mp_tac o MATCH_MP (REWRITE_RULE[GSYM AND_IMP_INTRO] compilerProofTheory.env_rs_change_clock)) >>
 simp[] >> disch_then(qspecl_then[`0`,`NONE`]mp_tac) >> simp[] >> strip_tac >>
 `bc_next^* (bs with <| code := bc0 ++ REVERSE code; pc := next_addr bs.inst_length bc0 |>) bs' ∧
  ¬?s3. bc_next bs' s3`
            by metis_tac [bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next] >>
 `bs' = (bs'' with clock := NONE)` by (
   qmatch_assum_abbrev_tac`bc_next^* bs0 bs'` >>
   qspecl_then[`bs1`,`bs''`]mp_tac bytecodeClockTheory.RTC_bc_next_can_be_unclocked >>
   discharge_hyps >- simp[] >> strip_tac >>
   `bs1 with clock := NONE = bs0` by (
     simp[Abbr`bs0`,Abbr`bs1`,bc_state_component_equality] ) >>
   fs[] >>
   qspecl_then[`bs0`,`bs'' with clock := NONE`]mp_tac bytecodeEvalTheory.RTC_bc_next_bc_eval >>
   discharge_hyps >- simp[] >>
   discharge_hyps >- (
     simp[bytecodeEvalTheory.bc_eval1_thm,bytecodeEvalTheory.bc_eval1_def,
          bytecodeClockTheory.bc_fetch_with_clock] ) >>
   rw[] >> fs[] ) >>
 unabbrev_all_tac >>
 fs [] >>
 imp_res_tac RTC_bc_next_preserves >>
 fs [] >>
 MAP_EVERY qexists_tac [`FST grd''`, `FST (SND grd'')`, `SND (SND grd'')`] >>
 rw []
 >- (imp_res_tac compilerProofTheory.compile_initial_prog_code_labels_ok >>
     match_mp_tac bytecodeLabelsTheory.code_labels_ok_append >>
     simp[])
 >- (simp[code_executes_ok_def] >> disj1_tac >>
     metis_tac[bytecodeClockTheory.bc_fetch_with_clock,RTC_REFL]));

val add_to_env_invariant = Q.prove (
`!ck envM envC envE cnt s tids prog cnt' s' envM' envC' envE' tids' mdecls' e e' code bs bs'.
  closed_prog prog ∧
  evaluate_whole_prog ck (envM,envC,envE) ((cnt,s),tids,set e.inf_mdecls) prog (((cnt',s'),tids',mdecls'),envC',Rval (envM',envE')) ∧
  invariant <| sem_envM := envM; sem_envC := envC; sem_envE := envE; sem_s := s; sem_tids := tids; sem_mdecls := set e.inf_mdecls |> e bs ∧ 
  SOME (e',code) = add_to_env e prog ∧
  SOME bs' = bc_eval (bs with <| code   := bs.code ++ REVERSE code
                               ; pc     := next_addr bs.inst_length bs.code |>)
  ⇒ 
  invariant <| sem_envM := envM' ++ envM;
               sem_envC := merge_envC envC' envC;
               sem_envE := envE' ++ envE;
               sem_s := s';
               sem_tids := tids';
               sem_mdecls := mdecls' |>
            e' (bs' with clock := NONE)`,
 rw [] >>
 cases_on `ck`
 >- metis_tac [add_to_env_invariant_lem] >>
 fs [evaluate_whole_prog_def] >>
 imp_res_tac bigClockTheory.prog_add_clock >>
 fs [] >>
 match_mp_tac add_to_env_invariant_lem  >>
 rw [evaluate_whole_prog_def] >>
 MAP_EVERY Q.EXISTS_TAC [`count'`,`s`, `tids`, `prog`, `0`, `e`, `code`, `bs`] >>
 fs [no_dup_mods_def, no_dup_top_types_def]);

val prim_env_def = Define `
prim_env =
add_to_env <| inf_mdecls := [];
              inf_tdecls := [];
              inf_edecls := [];
              inf_tenvM := [];
              inf_tenvC := ([],[]);
              inf_tenvE := [];
              comp_rs := <| next_global := 0;
                            globals_env := (FEMPTY, FEMPTY);
                            contags_env := (1, (FEMPTY,FEMPTY), FEMPTY);
                            exh := FEMPTY;
                            rnext_label := 0 |> |>
        prim_types_program`;

val prim_sem_env_def = Define `
prim_sem_env =
add_to_sem_env <| sem_envM := []; sem_envC := ([],[]); sem_envE := []; sem_s := []; sem_tids := {}; sem_mdecls := {} |> prim_types_program`;

val empty_bc_state_def = Define `
empty_bc_state = <| 
      stack := [];
      code := [];
      pc := 0;
      refs := FEMPTY;
      globals := [];
      handler := 0;
      output := "";
      inst_length := K 0;
      clock := NONE |>`;

val prim_bs_def = Define `
prim_bs = bc_eval (empty_bc_state 
                   with <| code   := empty_bc_state.code ++ REVERSE (SND (THE prim_env))
                         ; pc     := next_addr empty_bc_state.inst_length empty_bc_state.code |>)`

val the_compiler_compset = the_compiler_compset false

val prim_env_eq = save_thm ("prim_env_eq",
  ``prim_env``
  |> SIMP_CONV(srw_ss())[prim_env_def,add_to_env_def,LET_THM,prim_types_program_def]
  |> CONV_RULE(computeLib.CBV_CONV the_inference_compset)
  |> CONV_RULE(computeLib.CBV_CONV the_compiler_compset));

val prim_sem_env_eq = save_thm ("prim_sem_env_eq",
  ``prim_sem_env``
  |> SIMP_CONV(srw_ss())[prim_sem_env_def,add_to_sem_env_def,prim_types_program_def]
  |> CONV_RULE(computeLib.CBV_CONV the_interp_compset));

val prim_bs_eq = save_thm ("prim_bs_eq",
  ``prim_bs``
  |> SIMP_CONV(srw_ss())[prim_bs_def, empty_bc_state_def, prim_env_eq]
  |> CONV_RULE(computeLib.CBV_CONV the_bytecode_compset));

val to_ctMap_list_def = Define `
to_ctMap_list tenvC =
  flat_to_ctMap_list (SND tenvC) ++ FLAT (MAP (\(mn, tenvC). flat_to_ctMap_list tenvC) (FST tenvC))`;

val to_ctMap_def = Define `
  to_ctMap tenvC = FEMPTY |++ REVERSE (to_ctMap_list tenvC)`;

val thms = [to_ctMap_def, to_ctMap_list_def, libTheory.emp_def, flat_to_ctMap_def, flat_to_ctMap_list_def, prim_env_eq];

val to_ctMap_prim_tenvC =
  SIMP_CONV (srw_ss()) thms ``to_ctMap (FST (THE prim_env)).inf_tenvC``;

val prim_env_inv = Q.store_thm ("prim_env_inv",
`?se e code bs.
  prim_env = SOME (e,code) ∧
  prim_sem_env = SOME se ∧
  prim_bs = SOME bs ∧
  invariant se e bs`,
 rw [prim_env_eq, prim_sem_env_eq, invariant_def, prim_bs_eq, GSYM PULL_EXISTS]
 >- (rw [typeSoundInvariantsTheory.type_sound_invariants_def] >>
     MAP_EVERY qexists_tac [`to_ctMap (FST (THE prim_env)).inf_tenvC`, 
                            `[]`, 
                            `(set (FST (THE prim_env)).inf_mdecls, set (FST (THE prim_env)).inf_tdecls, set (FST (THE prim_env)).inf_edecls)`, 
                            `[]`, 
                            `(FST (THE prim_env)).inf_tenvC`] >>
     `consistent_con_env (to_ctMap (FST (THE prim_env)).inf_tenvC) (THE prim_sem_env).sem_envC (FST (THE prim_env)).inf_tenvC`
         by (rw [to_ctMap_prim_tenvC] >>
             rw [consistent_con_env_def, libTheory.emp_def, tenvC_ok_def, prim_env_eq, prim_sem_env_eq,
                 flat_tenvC_ok_def, terminationTheory.check_freevars_def, ctMap_ok_def, miscTheory.FEVERY_ALL_FLOOKUP,
                 miscTheory.flookup_fupdate_list, semanticPrimitivesTheory.lookup_con_id_def]
             >- (every_case_tac >>
                 rw [] >>
                 rw [terminationTheory.check_freevars_def])
             >- (Cases_on `cn` >>
                 fs [id_to_n_def] >>
                 every_case_tac >>
                 fs [])
             >- (Cases_on `cn` >>
                 fs [id_to_n_def] >>
                 every_case_tac >>
                 fs [])) >>
     rw []
     >- (rw [consistent_decls_def, prim_env_eq, prim_sem_env_eq, RES_FORALL] >>
         every_case_tac >>
         fs [])
     >- (rw [consistent_ctMap_def, to_ctMap_prim_tenvC, prim_env_eq, prim_sem_env_eq, RES_FORALL] >>
         PairCases_on `x` >>
         fs [] >>
         every_case_tac >>
         fs [FDOM_FUPDATE_LIST])
     >- rw [ctMap_has_exns_def, to_ctMap_prim_tenvC, miscTheory.flookup_fupdate_list]
     >- rw [tenvM_ok_def]
     >- rw [tenvM_ok_def, convert_menv_def]
     >- rw [Once type_v_cases]
     >- fs [prim_sem_env_eq]
     >- rw [to_ctMap_prim_tenvC, convert_env2_def, bind_var_list2_def,
            Once type_v_cases, libTheory.emp_def]
     >- rw [type_s_def, semanticPrimitivesTheory.store_lookup_def] 
     >- rw [weakM_def, convert_menv_def]
     >- rw [weakeningTheory.weakC_refl, prim_env_eq]
     >- rw [decls_ok_def, prim_env_eq, decls_to_mods_def, SUBSET_DEF, GSPECIFICATION]
     >- (rw [prim_env_eq, convert_decls_def] >>
         metis_tac [weakeningTheory.weak_decls_refl])
     >- rw [prim_env_eq, weak_decls_only_mods_def, convert_decls_def])
 >- rw [infer_sound_invariant_def,check_menv_def,check_cenv_def,check_flat_cenv_def,terminationTheory.check_freevars_def,check_env_def]
 >- (simp[compilerProofTheory.env_rs_def,LENGTH_NIL_SYM] >>
     qexists_tac`
      FEMPTY |++ [(("NONE",TypeId (Short "option")), (none_tag, 0));
              (("SOME",TypeId (Short "option")), (some_tag, 1));
              (("nil",TypeId (Short "list")), (nil_tag, 0:num));
              (("::",TypeId (Short "list")), (cons_tag, 2));
              (("Bind",TypeExn (Short "Bind")), (bind_tag,0));
              (("Div",TypeExn (Short "Div")), (div_tag,0));
              (("Eq",TypeExn (Short "Eq")), (eq_tag,0));
              (("Subscript",TypeExn(Short"Subscript")),(subscript_tag,0))]` >>
     simp[Once RIGHT_EXISTS_AND_THM] >>
     conj_tac >- EVAL_TAC >>
     simp[PULL_EXISTS] >>
     CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`[]` >> simp[RIGHT_EXISTS_AND_THM] >>
     simp[RIGHT_EXISTS_AND_THM,GSYM CONJ_ASSOC] >>
     conj_tac >- (EVAL_TAC >> simp[s_to_i1_cases] >> simp[Once v_to_i1_cases] >> simp[Once v_to_i1_cases]) >>
     CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`[]` >>
     CONV_TAC SWAP_EXISTS_CONV >> qexists_tac`[]` >>
     simp[RIGHT_EXISTS_AND_THM] >>
     conj_tac >- (
       EVAL_TAC >> simp[s_to_i2_cases] >>
       conj_tac >- (
         conj_tac >- (
           rpt gen_tac >>
           BasicProvers.CASE_TAC >>
           IF_CASES_TAC >- rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           IF_CASES_TAC >- (rw[FLOOKUP_UPDATE,FLOOKUP_FUNION] >> simp[]) >>
           simp[] ) >>
         conj_tac >- (
           simp[miscTheory.IN_FRANGE_FLOOKUP,FLOOKUP_UPDATE,FLOOKUP_FUNION] >>
           rw[] >> every_case_tac >> fs[] >> rw[] >>
           EVAL_TAC ) >>
         conj_tac >- rw[] >>
         rpt gen_tac >>
         rw[] >> fs[] ) >>
       rpt gen_tac >>
       rw[] >> simp[] ) >>
     EVAL_TAC >> rw[] >>
     qexists_tac`<|cls:=FEMPTY;sm:=[]|>` >>
     simp[miscTheory.FEVERY_ALL_FLOOKUP] >>
     disj1_tac >>
     srw_tac[boolSimps.DNF_ss][Once RTC_CASES1])
 >- fs [bytecodeLabelsTheory.code_labels_ok_def, bytecodeLabelsTheory.uses_label_def]
 >- (
   simp[code_executes_ok_def] >>
   disj1_tac >>
   Q.PAT_ABBREV_TAC`bs0:bc_state = X` >>
   `∃bs1. bc_eval bs0 = SOME bs1 ∧ bc_fetch bs1 = SOME (Stop T)` by (
     simp[Abbr`bs0`] >>
     CONV_TAC(QUANT_CONV(LAND_CONV (computeLib.CBV_CONV the_bytecode_compset))) >>
     simp[] >>
     CONV_TAC (computeLib.CBV_CONV the_bytecode_compset) ) >>
   metis_tac[bytecodeEvalTheory.bc_eval_SOME_RTC_bc_next]))

 (*
val basis_env_def = Define `
basis_env =
add_to_env (FST (THE prim_env)) basis_program`;

val basis_sem_env_def = Define `
basis_sem_env =
add_to_sem_env (THE prim_sem_env) basis_program`;

val basis_bs_def = Define `
basis_bs = bc_eval (THE prim_bs 
                    with <| code   := (THE prim_bs).code ++ REVERSE (SND (THE basis_env))
                          ; pc     := next_addr (THE prim_bs).inst_length (THE prim_bs).code |>)`

val basis_env_eq = save_thm ("basis_env_eq",
  ``basis_env``
  |> SIMP_CONV(srw_ss())[basis_env_def,add_to_env_def,LET_THM,basis_program_def, prim_env_eq,
                         mk_binop_def, mk_unop_def]
  |> CONV_RULE(computeLib.CBV_CONV the_inference_compset)
  |> CONV_RULE(computeLib.CBV_CONV the_compiler_compset));

(* Too big to evaluate in a reasonable timely was due to exponential explosion in closure envs 
val basis_sem_env_eq = save_thm ("basis_sem_env_eq",
  ``basis_sem_env``
  |> SIMP_CONV(srw_ss())[basis_sem_env_def,add_to_sem_env_def,basis_program_def, mk_binop_def, mk_unop_def, prim_sem_env_eq]
  |> CONV_RULE(computeLib.CBV_CONV the_interp_compset));
  *)

(* This also takes too long, probably due to linear lookup of instruction fetching *)
val basis_bs_eq = save_thm ("basis_bs_eq",
  ``basis_bs``
  |> SIMP_CONV std_ss [prim_bs_eq, basis_bs_def, basis_env_eq]
  |> CONV_RULE(computeLib.CBV_CONV the_bytecode_compset)

val basis_env_inv = Q.store_thm ("basis_env_inv",
`?se e code bs.
  basis_env = SOME (e,code) ∧
  basis_sem_env = SOME se ∧
  basis_bs = SOME bs ∧
  invariant se e bs`,
 rw [basis_env_def, basis_sem_env_def] >>
 strip_assume_tac prim_env_inv >>
 `?e'. add_to_env e basis_program = SOME e'` by (
   fs[prim_env_eq] >> rw[] >>
   simp[add_to_env_def] >>
   rpt BasicProvers.CASE_TAC >- simp[UNCURRY] >>
   qsuff_tac`F`>-rw[]>>pop_assum mp_tac>>
   simp[basis_program_def,mk_binop_def,mk_unop_def] >>
   CONV_TAC(computeLib.CBV_CONV the_inference_compset)) >>
 `?se'. add_to_sem_env se basis_program = SOME se'` by (
   fs[prim_sem_env_eq] >> rw[] >>
   simp[add_to_sem_env_def] >>
   rpt BasicProvers.CASE_TAC >>
   pop_assum mp_tac >>
   simp[basis_program_def] >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl1 = ("+",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl2 = ("-",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl3 = ("*",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl4 = ("div",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl5 = ("mod",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl6 = ("<",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl7 = (">",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl8 = ("<=",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl9 = (">=",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl10 = ("=",Closure X Y Z)` >>
   REWRITE_TAC[Once mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   Q.PAT_ABBREV_TAC`cl11 = (":=",Closure X Y Z)` >>
   Q.PAT_ABBREV_TAC`cl12 = ("~",Closure X Y Z)` >>
   REWRITE_TAC[mk_binop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   REWRITE_TAC[mk_unop_def] >> CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   rw[]) >>
 rw [] >>
 fs [add_to_sem_env_def] >>
 every_case_tac >>
 fs [] >>
 imp_res_tac run_eval_prog_spec >>
 fs [] >>
 rw [] >>
 match_mp_tac add_to_env_invariant >>
 rw [evaluate_whole_prog_def] >>
 MAP_EVERY qexists_tac [`T`, `10000`, `se.sem_s`, `se.sem_tids`, `basis_program`, `q`, `e`] >>
 rw []
 >- (
   rw[basis_program_def] >>
   CONV_TAC(computeLib.CBV_CONV the_free_vars_compset) >>
   rw[mk_binop_def,mk_unop_def] >>
   CONV_TAC(computeLib.CBV_CONV the_free_vars_compset))
 >- (
   rw[basis_program_def] >>
   CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   fs[prim_env_eq] >> rw[] )
 >- (
   rw[basis_program_def] >>
   CONV_TAC(computeLib.CBV_CONV the_interp_compset) >>
   rw[mk_binop_def,mk_unop_def] )
 >- (fs [invariant_def] >>
     metis_tac [])
 >- (fs [invariant_def] >>
     metis_tac []));
     *)

val _ = export_theory();

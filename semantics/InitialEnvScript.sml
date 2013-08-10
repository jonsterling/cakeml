(*Generated by Lem from initialEnv.lem.*)
open bossLib Theory Parse res_quanTheory
open fixedPointTheory finite_mapTheory listTheory pairTheory pred_setTheory
open integerTheory set_relationTheory sortingTheory stringTheory wordsTheory

val _ = numLib.prefer_num();



open AltBigStepTheory TypeSystemTheory BigStepTheory SmallStepTheory SemanticPrimitivesTheory ElabTheory AstTheory TokensTheory LibTheory

val _ = new_theory "InitialEnv"

(*open Lib*)
(*open Ast*)
(*open SemanticPrimitives*)
(*open TypeSystem*)
(*open Elab*)

(*val init_env : envE*)
val _ = Define `
 init_env =  
([("+", Closure [] "x" (Fun "y" (App (Opn Plus) (Var (Short "x")) (Var (Short "y")))));
   ("-", Closure [] "x" (Fun "y" (App (Opn Minus) (Var (Short "x")) (Var (Short "y")))));
   ("*", Closure [] "x" (Fun "y" (App (Opn Times) (Var (Short "x")) (Var (Short "y")))));
   ("div", Closure [] "x" (Fun "y" (App (Opn Divide) (Var (Short "x")) (Var (Short "y")))));
   ("mod", Closure [] "x" (Fun "y" (App (Opn Modulo) (Var (Short "x")) (Var (Short "y")))));
   ("<", Closure [] "x" (Fun "y" (App (Opb Lt) (Var (Short "x")) (Var (Short "y")))));
   (">", Closure [] "x" (Fun "y" (App (Opb Gt) (Var (Short "x")) (Var (Short "y")))));
   ("<=", Closure [] "x" (Fun "y" (App (Opb Leq) (Var (Short "x")) (Var (Short "y")))));
   (">=", Closure [] "x" (Fun "y" (App (Opb Geq) (Var (Short "x")) (Var (Short "y")))));
   ("=", Closure [] "x" (Fun "y" (App Equality (Var (Short "x")) (Var (Short "y")))));
   (":=", Closure [] "x" (Fun "y" (App Opassign (Var (Short "x")) (Var (Short "y")))));
   ("~", Closure [] "x" (App (Opn Minus) (Lit (IntLit ( & 0))) (Var (Short "x"))));
   ("!", Closure [] "x" (Uapp Opderef (Var (Short "x"))));
   ("ref", Closure [] "x" (Uapp Opref (Var (Short "x"))))])`;


(*val init_envC : envC*)
val _ = Define `
 init_envC =  
((Short "nil", (0, TypeId (Short "list"))) ::
  (Short "::", (2, TypeId (Short "list"))) :: MAP (\ cn . (Short cn, (0, TypeExn))) ["Bind"; "Div"; "Eq"])`;


(*val init_tenv : tenvE*)
val _ = Define `
 init_tenv = ( FOLDR 
    (\ (tn,tvs,t) tenv . Bind_name tn tvs t tenv) 
    Empty 
    [("+", 0, Tfn Tint (Tfn Tint Tint));
     ("-", 0, Tfn Tint (Tfn Tint Tint));
     ("*", 0, Tfn Tint (Tfn Tint Tint));
     ("div", 0, Tfn Tint (Tfn Tint Tint));
     ("mod", 0, Tfn Tint (Tfn Tint Tint));
     ("<", 0, Tfn Tint (Tfn Tint Tbool));
     (">", 0, Tfn Tint (Tfn Tint Tbool));
     ("<=", 0, Tfn Tint (Tfn Tint Tbool));
     (">=", 0, Tfn Tint (Tfn Tint Tbool));
     ("=", 1, Tfn (Tvar_db 0) (Tfn (Tvar_db 0) Tbool));
     (":=", 1, Tfn (Tref (Tvar_db 0)) (Tfn (Tvar_db 0) Tunit));
     ("~", 0, Tfn Tint Tint);
     ("!", 1, Tfn (Tref (Tvar_db 0)) (Tvar_db 0));
     ("ref", 1, Tfn (Tvar_db 0) (Tref (Tvar_db 0)))])`;


(*val init_tenvC : tenvC*)
val _ = Define `
 init_tenvC =  
((Short "nil", (["'a"], [], TypeId (Short "list"))) ::
  (Short "::", (["'a"], [Tvar "'a"; Tapp [Tvar "'a"] (TC_name (Short "list"))], TypeId (Short "list"))) :: MAP (\ cn . (Short cn, ([], [], TypeExn))) ["Bind"; "Div"; "Eq"])`;


(*val init_type_bindings : tdef_env*)
val _ = Define `
 init_type_bindings =  
([("int", TC_int);
   ("bool", TC_bool);
   ("ref", TC_ref);
   ("exn", TC_exn);
   ("unit", TC_unit);
   ("list", TC_name (Short "list"))])`;

val _ = export_theory()


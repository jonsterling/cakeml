open HolKernel Parse boolLib bossLib;

val _ = new_theory "ml_translator_test";

open listTheory pairTheory ml_translatorLib ml_translatorTheory;

(* This file contains a collection of functions that have in the past
   turned out to be tricky to translate. *)

val ZIP2_def = Define `
  (ZIP2 ([],[]) z = []) /\
  (ZIP2 (x::xs,y::ys) z = (x,y) :: ZIP2 (xs, ys) 5)`

val res = translate ZIP2_def;

val ZIP4_def = Define `
  ZIP4 xs = ZIP2 xs 6`

val res = translate ZIP4_def;

val char_to_byte_def = Define`
  char_to_byte c = (n2w (ORD c) : word8)`;

val res = translate char_to_byte_def;

(* TODO: why doesn't this work?
val string_to_bytes_def = Define`
  string_to_bytes s = MAP char_to_byte (mlstring$explode s)`;

val res = translate string_to_bytes_def;
*)

val _ = (print_asts := true);

val _ = export_theory();

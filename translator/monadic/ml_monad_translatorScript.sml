open preamble ml_translatorTheory ml_translatorLib ml_pmatchTheory patternMatchesTheory
open astTheory libTheory bigStepTheory semanticPrimitivesTheory
open terminationTheory ml_progLib ml_progTheory
open set_sepTheory cfTheory cfStoreTheory cfTacticsLib Satisfy
open cfHeapsBaseTheory basisFunctionsLib AC_Sort

open ml_monadBaseTheory

val _ = new_theory "ml_monad_translator";

val _ = temp_overload_on ("monad_bind", ``st_ex_bind``);
val _ = temp_overload_on ("monad_unitbind", ``\x y. st_ex_bind x (\z. y)``);
val _ = temp_overload_on ("monad_ignore_bind", ``\x y. st_ex_bind x (\z. y)``);
val _ = temp_overload_on ("ex_bind", ``st_ex_bind``);
val _ = temp_overload_on ("ex_return", ``st_ex_return``);

val _ = temp_overload_on ("CONTAINER", ``ml_translator$CONTAINER``);


val HCOND_EXTRACT = cfLetAutoTheory.HCOND_EXTRACT;

(*********** Comes from cfLetAutoLib.sml ***********************************************)	 
(* [dest_pure_fact]
   Deconstruct a pure fact (a heap predicate of the form &P) *)
val set_sep_cond_tm = ``set_sep$cond : bool -> hprop``;
fun dest_pure_fact p =
  case (dest_term p) of
  COMB dp =>
    (if same_const set_sep_cond_tm (#1 dp) then (#2 dp)
    else raise (ERR "dest_pure_fact" "Not a pure fact"))
  | _ => raise (ERR "dest_pure_fact" "Not a pure fact");
(***************************************************************************************)

fun PURE_FACTS_FIRST_CONV H =
  let
      val preds = list_dest dest_star H
      val (pfl, hpl) = List.partition (can dest_pure_fact) preds
      val ordered_preds = pfl @ hpl
  in
      if List.null ordered_preds then REFL H
      else
	  let val H' = List.foldl (fn (x, y) => mk_star(y, x)) (List.hd ordered_preds)
				  (List.tl ordered_preds)
          (* For some strange reason, AC_CONV doesn't work *)
          val H_to_norm = STAR_AC_CONV H
	  val norm_to_H' = (SYM(STAR_AC_CONV H') handle UNCHANGED => REFL H')
	  in TRANS H_to_norm norm_to_H'
	  end
  end;

val EXTRACT_PURE_FACTS_CONV =
  (RATOR_CONV PURE_FACTS_FIRST_CONV)
  THENC (SIMP_CONV pure_ss [GSYM STAR_ASSOC])
  THENC (SIMP_CONV pure_ss [HCOND_EXTRACT])
  THENC (SIMP_CONV pure_ss [STAR_ASSOC]);

(* TODO: use EXTRACT_PURE_FACT_CONV to rewrite EXTRACT_PURE_FACTS_TAC *)
fun EXTRACT_PURE_FACTS_TAC (g as (asl, w)) =
  let
      fun is_hprop a = ((dest_comb a |> fst |> type_of) = ``:hprop`` handle HOL_ERR _ => false)
      val hpreds = List.filter is_hprop asl
      val hpreds' = List.map (fst o dest_comb) hpreds
      val hpreds_eqs = List.map (PURE_FACTS_FIRST_CONV) hpreds'
  in
      ((fs hpreds_eqs) >> fs[GSYM STAR_ASSOC] >> fs[HCOND_EXTRACT] >> fs[STAR_ASSOC]) g
  end;
(***********************************************************************************************)

val _ = temp_type_abbrev("state",``:'ffi semanticPrimitives$state``);

(* fun auto_prove proof_name (goal,tac) = let
  val (rest,validation) = tac ([],goal) handle Empty => fail()
  in if length rest = 0 then validation [] else let
  in failwith("auto_prove failed for " ^ proof_name) end end

fun D th = let
  val th = th |> DISCH_ALL |> PURE_REWRITE_RULE [AND_IMP_INTRO]
  in if is_imp (concl th) then th else DISCH T th end *)

(* a few basics *)
val with_same_refs = Q.store_thm("with_same_refs",
  `(s with refs := s.refs) = s`,
  simp[state_component_equality])

val with_same_ffi = Q.store_thm("with_same_ffi",
  `(s with ffi := s.ffi) = s`,
  simp[state_component_equality]);

(* REFS_PRED *)
val REFS_PRED_def = Define `REFS_PRED H refs s = (H refs * GC) (store2heap s.refs)`;
val VALID_REFS_PRED_def = Define `VALID_REFS_PRED H = ?(s : unit state) refs. REFS_PRED H refs s`;

(*
 * Proof of REFS_PRED_APPEND:
 * `REFS_PRED H refs s ==> REFS_PRED H refs (s with refs := s.refs ++ junk)`
 *)
val store2heap_aux_Mem = Q.store_thm("store2heap_aux_Mem",
`!s n x. x IN (store2heap_aux n s) ==> ?n' v. x = Mem n' v`,
Induct_on `s`
 >-(rw[IN_DEF, store2heap_def, store2heap_aux_def]) >>
rw[] >> fs[IN_DEF, store2heap_def, store2heap_aux_def] >>
last_x_assum IMP_RES_TAC >>
fs[]);

val store2heap_aux_IN_LENGTH = Q.store_thm ("store2heap_aux_IN_LENGTH",
`!s r x n. Mem r x IN (store2heap_aux n s) ==> r < n + LENGTH s`,
Induct THENL [all_tac, Cases] \\
fs [store2heap_aux_def] \\
Cases_on `r` \\ fs [] \\ rewrite_tac [ONE] \\
rpt strip_tac \\ fs[ADD_CLAUSES, GSYM store2heap_aux_suc] \\
metis_tac[]
);

val store2heap_aux_DISJOINT = Q.store_thm("store2heap_aux_DISJOINT",
`!n s1 s2. DISJOINT (store2heap_aux n s1) (store2heap_aux (n + LENGTH s1) s2)`,
rw[DISJOINT_DEF, INTER_DEF, EMPTY_DEF] >>
fs[GSPECIFICATION_applied] >>
sg `!x. {x | x ∈ store2heap_aux n s1 ∧ x ∈ store2heap_aux (n + LENGTH s1) s2} x = (\x. F) x`
>-(
    rw[] >>
    `!A B. ~A \/ ~B <=> A /\ B ==> F` by (metis_tac[]) >>
    POP_ASSUM (fn x => PURE_REWRITE_TAC [x]) >>
    DISCH_TAC >> rw[] >>
    IMP_RES_TAC store2heap_aux_Mem >>
    rw[] >>
    IMP_RES_TAC store2heap_aux_IN_bound >>
    IMP_RES_TAC store2heap_aux_IN_LENGTH >>
    bossLib.DECIDE_TAC
) >>
POP_ASSUM (fn x => ASSUME_TAC (EXT x)) >> fs[]);

val store2heap_aux_SPLIT = Q.store_thm("store2heap_aux_SPLIT",
`!s1 s2 n. SPLIT (store2heap_aux n (s1 ++ s2)) (store2heap_aux n s1, store2heap_aux (n + LENGTH s1) s2)`,
fs[SPLIT_def] >> fs[store2heap_aux_append_many] >>
metis_tac[UNION_COMM, store2heap_aux_append_many, store2heap_aux_DISJOINT]);

val store2heap_DISJOINT = Q.store_thm("store2heap_DISJOINT",
`DISJOINT (store2heap s1) (store2heap_aux (LENGTH s1) s2)`,
fs[store2heap_def] >> metis_tac[store2heap_aux_DISJOINT, arithmeticTheory.ADD]);

(* If the goal is: (\x. P x) = (\x. Q x), applies SUFF_TAC ``!x. P x = Q x`` *)
fun SUFF_ABS_TAC (g as (asl, w)) =
  let
      val (e1, e2) = dest_eq w
      val (x1, e1') = dest_abs e1
      val (x2, e2') = dest_abs e2
      val _ = if x1 <> x2 then failwith "" else ()
      val w' = mk_forall(x1,  mk_eq(e1', e2'))
  in
      (SUFF_TAC w' THEN rw[]) g
  end;

val store2heap_SPLIT = Q.store_thm("store2heap_SPLIT",
`!s1 s2. SPLIT (store2heap (s1 ++ s2)) (store2heap s1, store2heap_aux (LENGTH s1) s2)`,
fs[store2heap_def] >> metis_tac[store2heap_aux_SPLIT, arithmeticTheory.ADD]);

val SPLIT_DECOMPOSWAP = Q.store_thm("SPLIT_DECOMPOSWAP",
`SPLIT s1 (s2, s3) ==> SPLIT s2 (u, v) ==> SPLIT s1 (u, v UNION s3)`,
fs[SPLIT_def, UNION_ASSOC, DISJOINT_SYM] >> rw[] >> fs[DISJOINT_SYM, DISJOINT_UNION_BOTH]);

val STORE_APPEND_JUNK = Q.store_thm("STORE_APPEND_JUNK",
`!H s junk. (H * GC) (store2heap s) ==> (H * GC) (store2heap (s ++ junk))`,
rw[] >>
qspecl_then [`s`, `junk`] ASSUME_TAC store2heap_SPLIT >>
fs[STAR_def] >>
qexists_tac `u` >>
qexists_tac `v UNION (store2heap_aux (LENGTH s) junk)` >>
`!H. GC H` by (rw[cfHeapsBaseTheory.GC_def, SEP_EXISTS] >> qexists_tac `\x. T` >> fs[]) >>
POP_ASSUM (fn x => fs[x]) >>
irule SPLIT_DECOMPOSWAP >>
instantiate >> fs[store2heap_def]);

val REFS_PRED_append = Q.store_thm("REFS_PRED_append",
`!H refs s. REFS_PRED H refs s ==> REFS_PRED H refs (s with refs := s.refs ++ junk)`,
rw[REFS_PRED_def, STORE_APPEND_JUNK]);

(*
 * Proof of STORE_EXTRACT_FROM_HPROP:
 * `!l xv H s. (REF (Loc l) xv * H) (store2heap s) ==> ?ps. ((ps ++ [Refv xv]) ≼ s) /\ LENGTH ps = l`
 *)

val store2heap_aux_LOC_MEM = Q.store_thm("store2heap_aux_LOC_MEM",
`!l xv H n s. (REF (Loc l) xv * H) (store2heap_aux n s) ==> Mem l (Refv xv) IN (store2heap_aux n s)`,
rw[store2heap_aux_def] >>
fs[STAR_def, SPLIT_def] >>
fs[REF_def, SEP_EXISTS] >>
fs[HCOND_EXTRACT] >>
fs[cell_def, one_def] >>
rw[] >>
last_x_assum (fn x => rw[GSYM x]));

val store2heap_LOC_MEM = Q.store_thm("store2heap_LOC_MEM",
`!l xv H s. (REF (Loc l) xv * H) (store2heap s) ==> Mem l (Refv xv) IN (store2heap s)`,
rw[store2heap_def, store2heap_aux_LOC_MEM] >> IMP_RES_TAC store2heap_aux_LOC_MEM);

val isPREFIX_TAKE = Q.store_thm("isPREFIX_TAKE",
`!l s. isPREFIX (TAKE l s) s`,
rw[] >>
`isPREFIX (TAKE l s) (TAKE l s ++ DROP l s)` by fs[TAKE_DROP] >>
metis_tac[TAKE_DROP]);

val isPREFIX_APPEND_EQ = Q.store_thm("isPREFIX_APPEND_EQ",
`!a1 a2 b1 b2. LENGTH a1 = LENGTH a2 ==> (isPREFIX (a1 ++ b1) (a2 ++ b2) <=> a2 = a1 /\ isPREFIX b1 b2)`,
Induct_on `a1` >- fs[LENGTH_NIL_SYM] >>
rw[] >>
Cases_on `a2` >- fs[] >>
fs[] >> metis_tac[]);

val STORE_DECOMPOS_FROM_HPROP = Q.store_thm("STORE_DECOMPOS_FROM_HPROP",
`!l xv H s. (REF (Loc l) xv * H) (store2heap s) ==> ?ps. ((ps ++ [Refv xv]) ≼ s) /\ LENGTH ps = l`,
rw[] >>
IMP_RES_TAC store2heap_LOC_MEM >>
IMP_RES_TAC store2heap_IN_EL >>
qexists_tac `TAKE l s` >>
Cases_on `l + 1 <= LENGTH s`
>-(
    fs[LENGTH_TAKE] >>
    SUFF_TAC ``isPREFIX [Refv (xv : v)] (DROP l s)``
    >- metis_tac[LENGTH_TAKE, LENGTH_DROP, GSYM isPREFIX_APPEND_EQ, TAKE_DROP] >>
    FIRST_ASSUM (fn x => PURE_REWRITE_TAC[x]) >>
    SUFF_TAC ``Refv (xv:v) = HD(DROP l s)``
    >-( fs[] >> Cases_on `DROP l s` >- fs[DROP_NIL] >> fs[]) >>
    fs[hd_drop]
) >>
irule FALSITY >>
IMP_RES_TAC store2heap_IN_LENGTH >>
fs[]);

val STORE_EXTRACT_FROM_HPROP = Q.store_thm("STORE_EXTRACT_FROM_HPROP",
`!l xv H s. (REF (Loc l) xv * H) (store2heap s) ==>
!junk. EL l (s ++ junk) = Refv xv`,
rw[] >>
IMP_RES_TAC STORE_DECOMPOS_FROM_HPROP >>
fs[IS_PREFIX_APPEND] >>
first_x_assum(fn x => CONV_RULE (CHANGED_CONV (SIMP_CONV pure_ss [GSYM APPEND_ASSOC])) x |> ASSUME_TAC) >>
`~NULL ([Refv xv] ++ (l' ++ junk))` by fs[NULL_EQ] >>
IMP_RES_TAC EL_LENGTH_APPEND >>
fs[HD] >>
metis_tac[]);

val SPLIT3_swap12 = Q.store_thm("SPLIT3_swap12",
`!h h1 h2 h3. SPLIT3 h (h1, h2, h3) = SPLIT3 h (h2, h1, h3)`,
rw[SPLIT3_def, UNION_COMM, CONJ_COMM] >> metis_tac[DISJOINT_SYM]);

val SPLIT_of_SPLIT3_1u3 = Q.store_thm("SPLIT_of_SPLIT3_1u3",
`∀h h1 h2 h3. SPLIT3 h (h1,h2,h3) ⇒ SPLIT h (h2, h1 ∪ h3)`,
metis_tac[SPLIT3_swap12, SPLIT_of_SPLIT3_2u3]);

val SEPARATE_STORE_ELEM_IN_HEAP = Q.store_thm("SEPARATE_STORE_ELEM_IN_HEAP",
`!s0 x s1. SPLIT3 (store2heap (s0 ++ [x] ++ s1)) (store2heap s0, {Mem (LENGTH s0) x}, store2heap_aux (LENGTH s0 + 1) s1)`,
sg `!(s0 : v store) s1 x. SPLIT (store2heap_aux (LENGTH s0) (x::s1)) ({Mem (LENGTH s0) x}, store2heap_aux (LENGTH s0 + 1) s1)`
>-(
    rw[store2heap_def] >>
    PURE_REWRITE_TAC[Once rich_listTheory.CONS_APPEND] >>
    PURE_REWRITE_TAC [GSYM (EVAL ``store2heap_aux (LENGTH (s0 : v store)) [x]``)] >>
    ASSUME_TAC (EVAL ``LENGTH [x : v store_v]``) >>
    metis_tac[store2heap_aux_SPLIT, ADD_COMM]
) >>
rw[] >>
qspecl_then [`s0`, `[x] ++ s1`] ASSUME_TAC store2heap_SPLIT >> fs[] >>
last_x_assum(qspecl_then [`s0`, `s1`, `x`] ASSUME_TAC) >>
fs[SPLIT_def, SPLIT3_def] >>
rw[]
>-(metis_tac[UNION_ASSOC, EQ_REFL])
>-(DISCH_TAC >> IMP_RES_TAC store2heap_IN_LENGTH >> fs[]) >>
metis_tac[DISJOINT_UNION_BOTH, EQ_REFL]);

val REF_HPROP_SAT_EQ = Q.store_thm("REF_HPROP_SAT_EQ",
`!l xv s. REF (Loc l) xv s <=> s = {Mem l (Refv xv)}`,
fs[REF_def, SEP_EXISTS, HCOND_EXTRACT, cell_def, one_def]);

val SPLIT_UNICITY_R = Q.store_thm("SPLIT_UNICITY_R",
`SPLIT s (u, v) ==> (SPLIT s (u, v') <=> v' = v)`,
fs[SPLIT_EQ]);

val STORE_SAT_LOC_STAR_H_EQ = Q.store_thm("STORE_SAT_LOC_STAR_H_EQ",
`!s0 xv s1 H. (Loc (LENGTH s0) ~~> xv * H) (store2heap (s0 ++ [Refv xv] ++ s1)) <=>
H ((store2heap s0) UNION (store2heap_aux (LENGTH s0 + 1) s1))`,
rw[] >>
qspecl_then [`s0`, `Refv xv`, `s1`] ASSUME_TAC SEPARATE_STORE_ELEM_IN_HEAP >>
IMP_RES_TAC SPLIT_of_SPLIT3_1u3 >>
last_x_assum(fn x => ALL_TAC) >>
EQ_TAC
>-(
    rw[STAR_def, REF_HPROP_SAT_EQ] >>
    IMP_RES_TAC SPLIT_UNICITY_R >>
    fs[]
) >>
DISCH_TAC >>
rw[STAR_def] >>
instantiate >>
rw[REF_HPROP_SAT_EQ]);

val STORE_UPDATE_HPROP = Q.store_thm("STORE_UPDATE_HPROP",
`(Loc l ~~> xv * H) (store2heap s) ==> (Loc l ~~> xv' * H) (store2heap (LUPDATE (Refv xv') l s))`,
DISCH_TAC >>
sg `?s0 s1. s = s0 ++ [Refv xv] ++ s1 /\ LENGTH s0 = l`
>-(
    IMP_RES_TAC STORE_DECOMPOS_FROM_HPROP >>
    IMP_RES_TAC rich_listTheory.IS_PREFIX_APPEND >>
    SATISFY_TAC
) >>
rw[LUPDATE_APPEND1, LUPDATE_APPEND2, LUPDATE_def] >>
metis_tac[STORE_SAT_LOC_STAR_H_EQ, REF_HPROP_SAT_EQ, STAR_def]);

(*
 * Definition of EvalM
 *)

val EvalM_def = Define `
  EvalM env exp P H <=>
    !(s:unit state) refs. REFS_PRED H refs s  ==>
    !junk.
    ?s2 res refs2. evaluate F env (s with refs := s.refs ++ junk) exp (s2,res) /\
    P (refs, s) (refs2, s2, res) /\ REFS_PRED H refs2 s2`;

(* refinement invariant for ``:('a, 'b, 'c) M`` *)
val _ = type_abbrev("M", ``:'a -> ('b, 'c) exc # 'a``);

val MONAD_def = Define `
  MONAD (a:'a->v->bool) (b: 'b->v->bool) (x:('refs, 'a, 'b) M)
                                    (state1:'refs,s1:unit state)
                                     (state2:'refs,s2:unit state,
                                      res: (v,v) result) =
    case (x state1, res) of
      ((Success y, st), Rval v) => (st = state2) /\ a y v
    | ((Failure e, st), Rerr (Rraise v)) => (st = state2) /\
                                              b e v
    | _ => F`

(* return *)

val EvalM_return = Q.store_thm("EvalM_return",
  `!H b. Eval env exp (a x) ==>
    EvalM env exp (MONAD a b (ex_return x)) H`,
  rw[Eval_def,EvalM_def,st_ex_return_def,MONAD_def] \\
  first_x_assum(qspec_then`(s with refs := s.refs ++ junk).refs`strip_assume_tac)
  \\ IMP_RES_TAC (evaluate_empty_state_IMP
                  |> INST_TYPE [``:'ffi``|->``:unit``]) \\
  asm_exists_tac \\ simp[] \\ PURE_REWRITE_TAC[GSYM APPEND_ASSOC] \\
  MATCH_MP_TAC REFS_PRED_append \\ simp[]
  );

(* bind *)

val EvalM_bind = Q.store_thm("EvalM_bind",
  `!H c. EvalM env e1 (MONAD b c (x:('refs, 'b, 'c) M)) H /\
    (!x v. b x v ==> EvalM (write name v env) e2 (MONAD a c ((f x):('refs, 'a, 'c) M)) H) ==>
    EvalM env (Let (SOME name) e1 e2) (MONAD a c (ex_bind x f)) H`,
  rw[EvalM_def,MONAD_def,st_ex_return_def,PULL_EXISTS] \\
  first_x_assum drule \\
  disch_then(qspec_then`junk`strip_assume_tac) \\
  Cases_on`x refs` \\ Cases_on`q` \\ Cases_on`res` \\ fs[]
  >- (
    rw[Once evaluate_cases] \\
    srw_tac[DNF_ss][] \\ disj1_tac \\
    asm_exists_tac \\ rw[] \\
    first_x_assum drule \\ disch_then drule \\
    disch_then(qspec_then`[]`strip_assume_tac) \\
    fs[GSYM write_def,namespaceTheory.nsOptBind_def,st_ex_bind_def,with_same_refs] \\
    asm_exists_tac \\ fs[] \\ metis_tac[] )
  \\ Cases_on`e` \\ fs[] \\
  rw[Once evaluate_cases] \\
  srw_tac[DNF_ss][] \\ disj2_tac \\
  asm_exists_tac \\ rw[] \\
  rw[st_ex_bind_def]);

(* lift pure refinement invariants *)

val _ = type_abbrev("H",``:'a -> 'refs # unit state ->
                                 'refs # unit state # (v,v) result -> bool``);

val PURE_def = Define `
  PURE a (x:'a) (refs1:'refs,s1:unit state) (refs2,s2,res:(v,v) result) =
    ?v:v junk. (res = Rval v) /\ (refs1 = refs2) /\ (s2 = s1 with refs := s1.refs ++ junk) /\ a x v`;

val Eval_IMP_PURE = Q.store_thm("Eval_IMP_PURE",
  `!H env exp P x. Eval env exp (P x) ==> EvalM env exp (PURE P x) H`,
  rw[Eval_def,EvalM_def,PURE_def,PULL_EXISTS]
  \\ first_x_assum(qspec_then`(s with refs := s.refs ++ junk).refs`strip_assume_tac)
  \\ IMP_RES_TAC (evaluate_empty_state_IMP
                  |> INST_TYPE [``:'ffi``|->``:unit``])
  \\ fs[]
  \\ metis_tac[REFS_PRED_append ,APPEND_ASSOC]);

(* function abstraction and application *)

val ArrowP_def = Define `
  (ArrowP : ('refs -> hprop) -> ('a, 'refs) H -> ('b, 'refs) H -> ('a -> 'b) -> v -> bool) H a b f c =
     !x refs1 s1 refs2 s2 (res:(v,v) result).
       a x (refs1,s1) (refs2,s2,res) /\ REFS_PRED H refs1 s1 ==>
       ?junk v env exp.
       (refs2 = refs1) /\ (s2 = s1 with refs := s1.refs ++ junk) /\
       (res = Rval v) /\ do_opapp [c;v] = SOME (env,exp) /\
       !junk. ?refs3 s3 res3.
         evaluate F env (s2 with refs := s2.refs ++ junk) exp (s3,res3) /\
         b (f x) (refs1,s1) (refs3,s3,res3) /\
         REFS_PRED H refs3 s3`;

val ArrowM_def = Define `
(ArrowM : ('refs -> hprop) -> ('a, 'refs) H -> ('b, 'refs) H -> ('a -> 'b, 'refs) H) H a b =
     PURE (ArrowP H a b)`;

(*val _ = add_infix("-M->",400,HOLgrammars.RIGHT)
val _ = overload_on ("-M->",``ArrowM``) *)

val evaluate_list_cases = let
  val lemma = evaluate_cases |> CONJUNCTS |> el 2
  in CONJ (``evaluate_list a5 a6 a7 [] (a9,Rval a10)``
           |> SIMP_CONV (srw_ss()) [Once lemma])
          (``evaluate_list a5 a6 a7 (x::xs) (a9,Rval a10)``
           |> SIMP_CONV (srw_ss()) [Once lemma]) end

val EvalM_ArrowM = Q.store_thm("EvalM_ArrowM",
  `!H. EvalM env x1 ((ArrowM H a b) f) H ==>
    EvalM env x2 (a x) H ==>
    EvalM env (App Opapp [x1;x2]) (b (f x)) H`,
  rw[EvalM_def,ArrowM_def,ArrowP_def,PURE_def,PULL_EXISTS]
  \\ rw[Once evaluate_cases,evaluate_list_cases,PULL_EXISTS]
  \\ first_x_assum drule \\ rw[]
  \\ srw_tac[DNF_ss][] \\ disj1_tac
  \\ first_x_assum(qspec_then`junk`strip_assume_tac)
  \\ first_x_assum drule \\ rw[]
  \\ first_x_assum(qspec_then`[]`strip_assume_tac)
  \\ fs[with_same_refs]
  \\ first_x_assum drule \\ rw[]
  \\ first_x_assum(qspec_then`junk'`strip_assume_tac) \\ fs[]
  \\ asm_exists_tac \\ rw[] \\ fs[]
  \\ asm_exists_tac \\ rw[]
  \\ asm_exists_tac \\ rw[]
  \\ asm_exists_tac \\ rw[]);

val EvalM_Fun = Q.store_thm("EvalM_Fun",
  `!H. (!v x. a x v ==> EvalM (write name v env) body (b (f x)) H) ==>
    EvalM env (Fun name body) ((ArrowM H (PURE a) b) f) H`,
  rw[EvalM_def,ArrowM_def,ArrowP_def,PURE_def,Eq_def]
  \\ rw[Once evaluate_cases,PULL_EXISTS]
  \\ rw[Once state_component_equality, REFS_PRED_append]
  \\ rw[Once state_component_equality]
  \\ rw[do_opapp_def,GSYM write_def]
  \\ last_x_assum drule \\ rw[]
  \\ first_x_assum drule \\ rw[]
  \\ first_x_assum(qspec_then `junk ++ junk'` assume_tac)
  \\ rw[]
  \\ SATISFY_TAC);

val EvalM_Fun_Eq = Q.store_thm("EvalM_Fun_Eq",
  `!H. (!v. a x v ==> EvalM (write name v env) body (b (f x)) H) ==>
    EvalM env (Fun name body) ((ArrowM H (PURE (Eq a x)) b) f) H`,
  rw[EvalM_def,ArrowM_def,ArrowP_def,PURE_def,Eq_def]
  \\ rw[Once evaluate_cases,PULL_EXISTS]
  \\ rw[Once state_component_equality,REFS_PRED_append]
  \\ rw[Once state_component_equality]
  \\ rw[do_opapp_def,GSYM write_def]
  \\ PURE_REWRITE_TAC [GSYM APPEND_ASSOC]
  \\ last_x_assum drule \\ rw[]
  \\ first_x_assum drule \\ rw[]
  \\ first_x_assum(qspec_then `junk ++ junk'` assume_tac)
  \\ rw[] \\ SATISFY_TAC);

(* More proofs *)
val EvalM_Fun_PURE_IMP = Q.store_thm("EvalM_Fun_PURE_IMP",
  `!H. VALID_REFS_PRED H ==>
    EvalM env (Fun n exp) (PURE P f) H ==>
    P f (Closure env n exp)`,
  fs [EvalM_def,PURE_def,PULL_EXISTS,Once evaluate_cases, VALID_REFS_PRED_def]
     \\ rw [] \\ metis_tac[]);

val LOOKUP_VAR_EvalM_IMP = Q.store_thm("LOOKUP_VAR_EvalM_IMP",
  `!H. VALID_REFS_PRED H ==>
    (!env. LOOKUP_VAR n env v ==> EvalM env (Var (Short n)) (PURE P g) H) ==>
    P g v`,
  fs [LOOKUP_VAR_def,lookup_var_def,EvalM_def,PURE_def,AND_IMP_INTRO,
      Once evaluate_cases,PULL_EXISTS,PULL_FORALL, VALID_REFS_PRED_def]
  \\ `nsLookup (<|v := nsBind n v nsEmpty|>).v (Short n) = SOME v` by EVAL_TAC
  \\ metis_tac[]);

val EvalM_ArrowM_IMP = Q.store_thm("EvalM_ArrowM_IMP",
  `!H. VALID_REFS_PRED H ==>
   EvalM env (Var x) ((ArrowM H a b) f) H ==>
    Eval env (Var x) (ArrowP H a b f)`,
  rw[ArrowM_def,EvalM_def,Eval_def,PURE_def,PULL_EXISTS, VALID_REFS_PRED_def] \\
  first_x_assum drule \\
  disch_then(qspec_then`[]`strip_assume_tac) \\
  fs[Once evaluate_cases] \\
  rw[state_component_equality]);

val EvalM_PURE_EQ = Q.store_thm("EvalM_PURE_EQ",
  `!H. VALID_REFS_PRED H ==>
   EvalM env (Fun n exp) (PURE P x) H = Eval env (Fun n exp) (P x)`,
  REPEAT STRIP_TAC \\ EQ_TAC \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC std_ss [Eval_IMP_PURE]
  \\ FULL_SIMP_TAC std_ss [Eval_def,EvalM_def,PURE_def,PULL_EXISTS]
  \\ fs[VALID_REFS_PRED_def] \\ rw[]
  \\ first_x_assum drule
  \\ disch_then(qspec_then`[]`strip_assume_tac)
  \\ fs[Once evaluate_cases]
  \\ rw[state_component_equality]);

val EvalM_Var_SIMP = Q.store_thm("EvalM_Var_SIMP",
  `EvalM (write n x env) (Var (Short y)) p H =
    if n = y then EvalM (write n x env) (Var (Short y)) p H
             else EvalM env (Var (Short y)) p H`,
  SIMP_TAC std_ss [EvalM_def] \\ SRW_TAC [] []
  \\ ASM_SIMP_TAC (srw_ss()) [Once evaluate_cases]
  \\ ASM_SIMP_TAC (srw_ss()) [Once evaluate_cases,write_def]);

val EvalM_Recclosure = Q.store_thm("EvalM_Recclosure",
  `!H. (!v. a n v ==>
         EvalM (write name v (write_rec [(fname,name,body)] env2 env2))
               body (b (f n)) H) ==>
    LOOKUP_VAR fname env (Recclosure env2 [(fname,name,body)] fname) ==>
    EvalM env (Var (Short fname)) ((ArrowM H (PURE (Eq a n)) b) f) H`,
  GEN_TAC \\ NTAC 2 STRIP_TAC \\ IMP_RES_TAC LOOKUP_VAR_THM
  \\ POP_ASSUM MP_TAC \\ POP_ASSUM (K ALL_TAC) \\ POP_ASSUM MP_TAC
  \\ rw[Eval_def,Arrow_def,EvalM_def,ArrowM_def,PURE_def,ArrowP_def,PULL_EXISTS]
  \\ ntac 2 (pop_assum mp_tac)
  \\ rw[Once evaluate_cases]
  \\ rw[Once evaluate_cases]
  \\ fs[state_component_equality]
  \\ rw[Eq_def,do_opapp_def,Once find_recfun_def,REFS_PRED_append]
  \\ fs[build_rec_env_def,write_rec_def,FOLDR,write_def]
  \\ METIS_TAC[APPEND_ASSOC]);

val IND_HELP = Q.store_thm("IND_HELP",
  `!env cl.
      LOOKUP_VAR x env cl /\
      EvalM env (Var (Short x)) ((ArrowM H b1 b2) f) H ==>
      EvalM (write x cl cl_env) (Var (Short x)) ((ArrowM H b1 b2) f) H`,
  rw[EvalM_def,Eval_def,ArrowM_def,PURE_def,PULL_EXISTS,LOOKUP_VAR_def]
  \\ rw[Once evaluate_cases]
  \\ fs[Once evaluate_cases]
  \\ rfs[write_def,state_component_equality,lookup_var_def]
  \\ METIS_TAC[]);

val write_rec_one = Q.store_thm("write_rec_one",
  `write_rec [(x,y,z)] env env = write x (Recclosure env [(x,y,z)] x) env`,
  SIMP_TAC std_ss [write_rec_def,write_def,build_rec_env_def,FOLDR]);

(* Eq simps *)

val EvalM_FUN_FORALL = Q.store_thm("EvalM_FUN_FORALL",
  `!H. (!x. EvalM env exp (PURE (p x) f) H) ==>
    EvalM env exp (PURE (FUN_FORALL x. p x) f) H`,
  rw[EvalM_def,PURE_def]
  \\ first_x_assum drule
  \\ simp[PULL_EXISTS,FUN_FORALL]
  \\ strip_tac
  \\ first_assum(qspecl_then[`ARB`,`junk`]strip_assume_tac)
  \\ asm_exists_tac \\ simp[]
  \\ qx_gen_tac`x`
  \\ first_assum(qspecl_then[`x`,`junk`]strip_assume_tac)
  \\ imp_res_tac determTheory.big_exp_determ \\ fs[]);

val EvalM_FUN_FORALL_EQ = Q.store_thm("EvalM_FUN_FORALL_EQ",
  `!H. (!x. EvalM env exp (PURE (p x) f) H) =
    EvalM env exp (PURE (FUN_FORALL x. p x) f) H`,
  REPEAT STRIP_TAC \\ EQ_TAC \\ FULL_SIMP_TAC std_ss [EvalM_FUN_FORALL]
  \\ fs [EvalM_def,PURE_def,PULL_EXISTS,FUN_FORALL] \\ METIS_TAC []);

val M_FUN_FORALL_PUSH1 = Q.prove(
  `(FUN_FORALL x. ArrowP H a (PURE (b x))) = (ArrowP H a (PURE (FUN_FORALL x. b x)))`,
  rw[FUN_EQ_THM,FUN_FORALL,ArrowP_def,PURE_def,PULL_EXISTS]
  \\ reverse EQ_TAC >- METIS_TAC[] \\ rw[]
  \\ first_x_assum drule \\ rw[]
  \\ first_assum(qspec_then`ARB`strip_assume_tac) \\ fs[]
  \\ fs[state_component_equality]
  \\ qx_gen_tac`junk2`
  \\ first_assum(qspecl_then[`ARB`,`junk2`]strip_assume_tac)
  \\ asm_exists_tac \\ fs[]
  \\ qx_gen_tac`y`
  \\ first_assum(qspecl_then[`y`,`junk2`]strip_assume_tac)
  \\ imp_res_tac determTheory.big_exp_determ \\ fs[]) |> GEN_ALL;

val M_FUN_FORALL_PUSH2 = Q.prove(
  `(FUN_FORALL x. ArrowP H ((PURE (a x))) b) =
    (ArrowP H (PURE (FUN_EXISTS x. a x)) b)`,
  FULL_SIMP_TAC std_ss [ArrowP_def,FUN_EQ_THM,AppReturns_def,
    FUN_FORALL,FUN_EXISTS,PURE_def] \\ METIS_TAC []) |> GEN_ALL;

val FUN_EXISTS_Eq = Q.prove(
  `(FUN_EXISTS x. Eq a x) = a`,
  SIMP_TAC std_ss [FUN_EQ_THM,FUN_EXISTS,Eq_def]) |> GEN_ALL;

val M_FUN_QUANT_SIMP = save_thm("M_FUN_QUANT_SIMP",
  LIST_CONJ [FUN_EXISTS_Eq,M_FUN_FORALL_PUSH1,M_FUN_FORALL_PUSH2]);

(* otherwise *)

val EvalM_otherwise = Q.store_thm("EvalM_otherwise",
  `!H b n. EvalM env exp1 (MONAD a b x1) H ==>
        (!i. EvalM (write n i env) exp2 (MONAD a b x2) H) ==>
        EvalM env (Handle exp1 [(Pvar n,exp2)]) (MONAD a b (x1 otherwise x2)) H`,
  SIMP_TAC std_ss [EvalM_def] \\ REPEAT STRIP_TAC
  \\ SIMP_TAC (srw_ss()) [Once evaluate_cases]
  \\ Q.PAT_X_ASSUM `!s refs. bb ==> bbb` (MP_TAC o Q.SPECL [`s`,`refs`])
  \\ FULL_SIMP_TAC std_ss [] \\ REPEAT STRIP_TAC
  \\ first_x_assum(qspec_then`junk`strip_assume_tac)
  \\ Cases_on `res` THEN1
   (srw_tac[DNF_ss][] >> disj1_tac \\
    asm_exists_tac \\ fs[MONAD_def,otherwise_def] \\
    CASE_TAC \\ fs[] \\ CASE_TAC \\ fs[] )
  \\ Q.PAT_X_ASSUM `MONAD xx yy zz t1 t2` MP_TAC
  \\ SIMP_TAC std_ss [Once MONAD_def] \\ STRIP_TAC
  \\ Cases_on `x1 refs` \\ FULL_SIMP_TAC (srw_ss()) []
  \\ Cases_on `q` \\ FULL_SIMP_TAC (srw_ss()) [otherwise_def]
  \\ Cases_on `e` \\ FULL_SIMP_TAC (srw_ss()) [otherwise_def]
  \\ srw_tac[DNF_ss][] \\ disj2_tac \\ disj1_tac
  \\ asm_exists_tac \\ fs[]
  \\ simp[Once evaluate_cases,pat_bindings_def,pmatch_def,GSYM write_def]
  \\ first_x_assum drule
  \\ qmatch_goalsub_rename_tac`write n v`
  \\ disch_then(qspecl_then[`v`,`[]`]strip_assume_tac)
  \\ fs[with_same_refs]
  \\ asm_exists_tac \\ fs[]
  \\ fs[MONAD_def]
  \\ CASE_TAC \\ fs[]
  \\ CASE_TAC \\ fs[]
  \\ asm_exists_tac \\ fs[]);

(* if *)

val EvalM_If = Q.store_thm("EvalM_If",
  `!H. (a1 ==> Eval env x1 (BOOL b1)) /\
    (a2 ==> EvalM env x2 (a b2) H) /\
    (a3 ==> EvalM env x3 (a b3) H) ==>
    (a1 /\ (CONTAINER b1 ==> a2) /\ (~CONTAINER b1 ==> a3) ==>
     EvalM env (If x1 x2 x3) (a (if b1 then b2 else b3)) H)`,
  rpt strip_tac \\ fs[]
  \\ `∀(H:'a -> hprop). EvalM env x1 (PURE BOOL b1) H` by metis_tac[Eval_IMP_PURE]
  \\ fs[EvalM_def,PURE_def, BOOL_def,PULL_EXISTS]
  \\ rpt strip_tac
  \\ first_x_assum drule
  \\ disch_then(qspec_then`junk`strip_assume_tac)
  \\ simp[Once evaluate_cases]
  \\ simp_tac(srw_ss()++DNF_ss)[]
  \\ disj1_tac
  \\ asm_exists_tac
  \\ simp[do_if_def]
  \\ rw[]
  \\ first_x_assum (match_mp_tac o MP_CANON)
  \\ fs[ml_translatorTheory.CONTAINER_def]);

val Eval_Var_SIMP2 = Q.store_thm("Eval_Var_SIMP2",
  `Eval (write x i env) (Var (Short y)) p =
      if x = y then p i else Eval env (Var (Short y)) p`,
  SIMP_TAC (srw_ss()) [Eval_def,Once evaluate_cases] \\ SRW_TAC [] []
  \\ ASM_SIMP_TAC (srw_ss()) [Eval_def,Once evaluate_cases]
  \\ ASM_SIMP_TAC (srw_ss()) [Eval_def,
       Once evaluate_cases,write_def]
  \\ simp[state_component_equality]);

val EvalM_Let = Q.store_thm("EvalM_Let",
  `!H. Eval env exp (a res) /\
    (!v. a res v ==> EvalM (write name v env) body (b (f res)) H) ==>
    EvalM env (Let (SOME name) exp body) (b (LET f res)) H`,
  rw[]
  \\ imp_res_tac Eval_IMP_PURE
  \\ fs[EvalM_def]
  \\ rpt strip_tac
  \\ first_x_assum drule
  \\ disch_then(qspec_then`junk`strip_assume_tac)
  \\ simp[Once evaluate_cases,GSYM write_def,namespaceTheory.nsOptBind_def]
  \\ srw_tac[DNF_ss][]
  \\ fs[PURE_def] \\ rveq
  \\ srw_tac[DNF_ss][] \\ disj1_tac
  \\ asm_exists_tac \\ fs[]);

(* PMATCH *)

val EvalM_PMATCH_NIL = Q.store_thm("EvalM_PMATCH_NIL",
  `!H b x xv a.
      Eval env x (a xv) ==>
      CONTAINER F ==>
      EvalM env (Mat x []) (b (PMATCH xv [])) H`,
  rw[ml_translatorTheory.CONTAINER_def]);

val EvalM_PMATCH = Q.store_thm("EvalM_PMATCH",
  `!H b a x xv.
      ALL_DISTINCT (pat_bindings p []) ⇒
      (∀v1 v2. pat v1 = pat v2 ⇒ v1 = v2) ⇒
      Eval env x (a xv) ⇒
      (p1 xv ⇒ EvalM env (Mat x ys) (b (PMATCH xv yrs)) H) ⇒
      EvalPatRel env a p pat ⇒
      (∀env2 vars.
        EvalPatBind env a p pat vars env2 ∧ p2 vars ⇒
        EvalM env2 e (b (res vars)) H) ⇒
      (∀vars. PMATCH_ROW_COND pat (K T) xv vars ⇒ p2 vars) ∧
      ((∀vars. ¬PMATCH_ROW_COND pat (K T) xv vars) ⇒ p1 xv) ⇒
      EvalM env (Mat x ((p,e)::ys))
        (b (PMATCH xv ((PMATCH_ROW pat (K T) res)::yrs))) H`,
  rw[EvalM_def] >>
  imp_res_tac Eval_IMP_PURE >>
  fs[EvalM_def] >>
  rw[Once evaluate_cases,PULL_EXISTS] >> fs[] >>
  first_x_assum drule >>
  disch_then(qspec_then`junk`strip_assume_tac) >>
  fs[PURE_def] \\ rveq \\
  srw_tac[DNF_ss][] \\ disj1_tac \\
  asm_exists_tac \\ fs[] \\
  rw[Once evaluate_cases,PULL_EXISTS] >>
  Cases_on`∃vars. PMATCH_ROW_COND pat (K T) xv vars` >> fs[] >- (
    imp_res_tac pmatch_PMATCH_ROW_COND_Match >>
    qpat_x_assum`p1 xv ⇒ $! _`kall_tac >>
    qpat_x_assum`_ ==> p1 xv`kall_tac >>
    fs[EvalPatRel_def] >>
    first_x_assum(qspec_then`vars`mp_tac)>>simp[] >> strip_tac >>
    first_x_assum(fn th => first_assum(strip_assume_tac o MATCH_MP th)) >>
    fs[PMATCH_ROW_COND_def] \\
    last_x_assum (qspec_then `s.refs ++ junk'` ASSUME_TAC) \\ rw[] \\
    `EvalPatBind env a p pat vars (env with v := nsAppend (alist_to_ns env2) env.v)`
    by (
	simp[EvalPatBind_def,sem_env_component_equality] \\
        qexists_tac `v` >> fs[] >>
      qspecl_then[`s.refs ++ junk'`,`p`,`v`,`[]`,`env`]mp_tac(CONJUNCT1 pmatch_imp_Pmatch) \\
      simp[] \\
      metis_tac[] ) \\
    first_x_assum drule \\ simp[]
    \\ disch_then(qspec_then`s`mp_tac)
    \\ disch_then drule
    \\ disch_then(qspec_then`junk'`strip_assume_tac) \\ fs[]
    \\ asm_exists_tac \\ fs[]
    \\ simp[PMATCH_def,PMATCH_ROW_def,PMATCH_ROW_COND_def] >>
    `(some x. pat x = pat vars) = SOME vars` by (
      simp[optionTheory.some_def] >>
      METIS_TAC[] ) >>
    simp[] >>
    asm_exists_tac \\ fs[]) >>
  drule (GEN_ALL pmatch_PMATCH_ROW_COND_No_match)
  \\ disch_then drule \\ disch_then drule
  \\ simp[] \\ strip_tac \\
  first_x_assum(qspec_then`s`mp_tac) \\
  disch_then drule \\
  simp[Once evaluate_cases,PULL_EXISTS] \\
  disch_then(qspec_then`junk`mp_tac) \\
  strip_tac \\ imp_res_tac determTheory.big_exp_determ \\ fs[] \\
  rw[] \\ asm_exists_tac \\ fs[] \\
  fs[PMATCH_def,PMATCH_ROW_def] \\
  asm_exists_tac \\ fs[]);

(* read and update refs *)

val EvalM_read_heap = Q.store_thm("EvalM_read_heap",
`!vname loc x TYPE EXC_TYPE H get_var.
  nsLookup env.v (Short vname) = SOME (Loc loc) ==>
  EvalM env (App Opderef [Var (Short vname)])
  (MONAD TYPE EXC_TYPE (λrefs. (Success (get_var refs), refs)))
  (λrefs. (SEP_EXISTS xv. (Loc loc) ~~> xv * &(TYPE (get_var refs) xv)) * H refs)`,
  rw[EvalM_def]
  \\ rw[Once evaluate_cases,evaluate_list_cases,PULL_EXISTS]
  \\ ntac 6 (rw[Once evaluate_cases])
  \\ fs[REFS_PRED_def]
  \\ fs[SEP_CLAUSES, SEP_EXISTS_THM]
  \\ EXTRACT_PURE_FACTS_TAC
  \\ fs[GSYM STAR_ASSOC]
  \\ rw[do_app_def]
  \\ rw[store_lookup_def,EL_APPEND1,EL_APPEND2]
  >-(
      qexists_tac `s with refs := s.refs ++ junk`
      \\ IMP_RES_TAC STORE_EXTRACT_FROM_HPROP \\ POP_ASSUM (fn x => fs[x])
      \\ fs[with_same_refs, with_same_ffi]
      \\ fs[MONAD_def]
      \\ instantiate
      \\ fs[STAR_ASSOC, STORE_APPEND_JUNK]
  ) >>
  fs[MONAD_def] (* , get_the_type_constants_def] *)
  \\ IMP_RES_TAC store2heap_LOC_MEM
  \\ IMP_RES_TAC store2heap_IN_LENGTH
  \\ `LENGTH init_type_constants_refs >= LENGTH s.refs` by fs[]
  \\ fs[]);

val EvalM_write_heap = Q.store_thm("EvalM_write_heap",
  `!vname loc x TYPE EXC_TYPE H get_var set_var env exp.
  (!refs x. get_var (set_var x refs) = x) ==>
  (!refs x. H (set_var x refs) = H refs) ==>
  nsLookup env.v (Short vname) = SOME (Loc loc) ==>
  Eval env exp (TYPE x) ==>
  EvalM env (App Opassign [Var (Short vname); exp])
  ((MONAD UNIT_TYPE EXC_TYPE) (λrefs. (Success (), set_var x refs)))
  (λrefs. (SEP_EXISTS xv. (Loc loc) ~~> xv * &(TYPE (get_var refs) xv)) * H refs)`,
  rw[]
  \\ ASSUME_TAC (Thm.INST_TYPE [``:'a`` |-> ``:'c``, ``:'b`` |-> ``:'a``] Eval_IMP_PURE)
  \\ POP_ASSUM IMP_RES_TAC
  \\ fs[EvalM_def] \\ rw[]
  \\ rw[Once evaluate_cases,evaluate_list_cases,PULL_EXISTS]
  \\ ntac 3 (rw[Once(CONJUNCT2 evaluate_cases)])
  \\ rw[CONJUNCT1 evaluate_cases |> Q.SPECL[`F`,`env`,`s`,`Var _`]]
  \\ srw_tac[DNF_ss][] \\ disj1_tac
  \\ Q.PAT_X_ASSUM `!H. P` IMP_RES_TAC
  \\ fs[REFS_PRED_def]
  \\ first_x_assum(qspec_then `junk` strip_assume_tac)
  \\ fs[PURE_def] \\ rw[]
  \\ asm_exists_tac \\ fs[]
  \\ fs[do_app_def]
  \\ qexists_tac `Rval (Conv NONE [])`
  \\ qexists_tac `set_var x refs`
  \\ qexists_tac `LUPDATE (Refv v) loc (s.refs ++ junk')`
  \\ qexists_tac `s.ffi`
  \\ qpat_x_assum `P (store2heap s.refs)` (fn x => ALL_TAC)
  \\ fs[store_assign_def,EL_APPEND1,EL_APPEND2,store_v_same_type_def]
  \\ fs[SEP_CLAUSES, SEP_EXISTS_THM]
  \\ EXTRACT_PURE_FACTS_TAC
  \\ fs[GSYM STAR_ASSOC] \\ IMP_RES_TAC store2heap_LOC_MEM
  \\ IMP_RES_TAC store2heap_IN_LENGTH
  \\ IMP_RES_TAC STORE_EXTRACT_FROM_HPROP
  \\ POP_ASSUM (qspec_then `[]` ASSUME_TAC)
  \\ fs[] \\ POP_ASSUM(fn x => ALL_TAC)
  \\ fs[MONAD_def]
  \\ instantiate
  \\ CONV_TAC (STRIP_QUANT_CONV (RATOR_CONV PURE_FACTS_FIRST_CONV))
  \\ fs[GSYM STAR_ASSOC] \\ fs[HCOND_EXTRACT]
  \\ fs[LUPDATE_APPEND1,LUPDATE_APPEND2,LUPDATE_def]
  \\ IMP_RES_TAC STORE_UPDATE_HPROP
  \\ first_x_assum(qspec_then `v` ASSUME_TAC)
  \\ fs[]);

val _ = (print_asts := true);

val _ = export_theory();

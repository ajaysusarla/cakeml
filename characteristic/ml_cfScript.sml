open HolKernel Parse boolLib bossLib preamble;
open set_sepTheory ml_translatorTheory;

val _ = new_theory "ml_cf";

(* Heaps *)
val _ = type_abbrev("heap", ``:(num # v) -> bool``);

val store2heap_aux_def = Define `
  store2heap_aux n [] = ({}: heap) /\
  store2heap_aux n ((Refv v) :: t) = (n, v) INSERT (store2heap_aux (n+1: num) t) /\
  store2heap_aux n (_ :: t) = store2heap_aux (n+1: num) t`;

val store2heap_def = Define `store2heap l = store2heap_aux (0: num) l`;

val store2heap_aux_append_Refv = Q.prove (
  `!s n x. store2heap_aux n (s ++ [Refv x]) = (LENGTH s + n, x) INSERT store2heap_aux n s`,
  Induct THENL [all_tac, Cases] \\ fs [store2heap_aux_def, INSERT_COMM]
  \\ fs [DECIDE ``(LENGTH s + 1) = SUC (LENGTH s)``]
);

val store2heap_aux_append_Varray = Q.prove (
  `!s n. store2heap_aux n (s ++ [Varray _]) = store2heap_aux n s`,
  Induct THENL [all_tac, Cases] \\ fs [store2heap_aux_def, INSERT_COMM]
);

val store2heap_aux_append_W8array = Q.prove (
  `!s n. store2heap_aux n (s ++ [W8array _]) = store2heap_aux n s`,
  Induct THENL [all_tac, Cases] \\ fs [store2heap_aux_def, INSERT_COMM]
);

val store2heap_append_Refv = Q.prove (
  `!s x. store2heap (s ++ [Refv x]) = (LENGTH s, x) INSERT store2heap s`,
  fs [store2heap_def, store2heap_aux_append_Refv]
);

val store2heap_aux_suc = Q.prove (
  `!s n u v. ((u, v) IN store2heap_aux n s) = ((SUC u, v) IN store2heap_aux (SUC n) s)`,
  Induct
  THEN1 (strip_tac \\ fs [store2heap_def, store2heap_aux_def])
  THEN1 (
    Cases \\
    once_rewrite_tac [store2heap_aux_def] \\ rpt strip_tac \\
    pop_assum (qspecl_then [`n+1`, `u`, `v`] assume_tac) \\
    fs [DECIDE ``SUC n + 1 = SUC (n + 1)``]
  )
);

val store2heap_aux_IN_bound = Q.prove (
  `!s n u v. (u, v) IN store2heap_aux n s ==> (u >= n)`,
  Induct THENL [all_tac, Cases] \\ fs [store2heap_aux_def] \\
  rpt strip_tac \\ fs [] \\ first_assum (qspecl_then [`n+1`, `u`, `v`] drule) \\
  rw_tac arith_ss []
);
 

val store2heap_alloc_disjoint = Q.prove (
  `!s x. ~ ((LENGTH s, x) IN (store2heap s))`,
  Induct
  THEN1 (strip_tac \\ fs [store2heap_def, store2heap_aux_def])
  THEN1 (
    Cases \\ fs [store2heap_def, store2heap_aux_def] \\
    rewrite_tac [ONE] \\
    fs [GSYM store2heap_aux_suc]
  )
);

val store2heap_IN_LENGTH = Q.prove (
  `!s r x. (r, x) IN (store2heap s) ==> r < LENGTH s`,
  Induct THENL [all_tac, Cases] \\
  fs [store2heap_def, store2heap_aux_def] \\
  Cases_on `r` \\ fs [] \\ rewrite_tac [ONE] \\
  rpt strip_tac \\ fs [GSYM store2heap_aux_suc] \\ metis_tac []
);

val tac_store2heap_IN = 
  Induct THENL [all_tac, Cases] \\ fs [store2heap_def, store2heap_aux_def] \\
  Cases_on `r` \\ fs [] \\
  rewrite_tac [ONE] \\ rpt strip_tac \\
  fs [GSYM store2heap_aux_suc] \\ TRY (metis_tac []) \\
  qspecl_then [`s`, `1`, `0`, `x'`] drule store2heap_aux_IN_bound \\
  rw_tac arith_ss []
;

val store2heap_IN_type = Q.prove (
  `!s r x. (r, x) IN (store2heap s) ==> EL r s = Refv x`,
  tac_store2heap_IN
);

val store2heap_IN_unique_key = Q.prove (
  `!s r x. (r, x) IN (store2heap s) ==> !x'. (r, x') IN (store2heap s) ==> x = x'`,
  tac_store2heap_IN
);

(* todo: fix fragile names & refactor *)
val store2heap_LUPDATE = Q.prove (
  `!s r x y. 
    (r, y) IN (store2heap s) ==>
    store2heap (LUPDATE (Refv x) r s) = (r, x) INSERT ((store2heap s) DELETE (r, y))`,
  Induct THENL [all_tac, Cases] \\ fs [store2heap_def, store2heap_aux_def] \\ (
    Cases_on `r`
    \\ fs [LUPDATE_def, INSERT_DEF, DELETE_DEF, EXTENSION, store2heap_aux_def]
    THEN1 (
      qx_genl_tac [`x`, `y`] \\
      qspecl_then [`s`, `1`, `0`, `y`] assume_tac store2heap_aux_IN_bound \\
      fs [] \\ rw_tac std_ss [] \\ metis_tac []
    )
  )

  (* `a` is fragile *)
  THEN1 (
    qx_genl_tac [`x`, `y`] \\ strip_tac \\ qx_gen_tac `u` \\
    qspecl_then [`s`, `1`, `0`, `a`] assume_tac store2heap_aux_IN_bound \\ 
    Cases_on `u = (0,a)` \\ Cases_on `u` \\ fs []

    (* fix names *)
    THEN1 (
      Cases_on `q` \\ fs [] \\
      qcase_tac `(SUC nn, xx) IN store2heap_aux 1 (LUPDATE _ _ _)` \\
      qpat_assum `_ IN store2heap_aux 1 _` mp_tac \\
      rewrite_tac [ONE, GSYM store2heap_aux_suc] \\ rpt strip_tac \\
      first_assum drule \\ disch_then (qspecl_then [`x`, `(nn, xx)`] assume_tac) \\
      fs []
    )
    THEN1 (
      qspecl_then [`s`, `1`, `0`, `r`] assume_tac store2heap_aux_IN_bound \\
      qspecl_then [`LUPDATE (Refv x) n s`, `1`, `0`, `r`] assume_tac store2heap_aux_IN_bound \\
      Cases_on `q` \\ fs [] \\
      qpat_assum `(SUC _,_) IN store2heap_aux 1 _` mp_tac \\
      rewrite_tac [ONE, GSYM store2heap_aux_suc] \\ rpt strip_tac \\
      first_assum drule \\ disch_then (qspecl_then [`x`, `(n', r)`] assume_tac) \\
      fs []
    )
  )

  THEN (
    rewrite_tac [ONE, GSYM store2heap_aux_suc] \\ ntac 3 strip_tac \\
    qx_gen_tac `x'` \\ Cases_on `x'` \\ 
    qspecl_then [`s`, `1`, `0`, `r`] assume_tac store2heap_aux_IN_bound \\
    qspecl_then [`LUPDATE (Refv x) n s`, `1`, `0`, `r`] assume_tac store2heap_aux_IN_bound \\
    Cases_on `q` \\ fs [GSYM store2heap_aux_suc] \\
    first_assum drule \\ disch_then (qspecl_then [`x`, `(n', r)`] assume_tac) \\
    fs []
  )
);

(* st2heap: 'ffi state -> heap *)
val st2heap_def = Define `
  st2heap (:'ffi) (st: 'ffi state) = store2heap st.refs`;

(* Utils *)
val SPLIT3_def = Define `
  SPLIT3 (s:'a set) (u,v,w) =
    ((u UNION v UNION w = s) /\
     DISJOINT u v /\ DISJOINT v w /\ DISJOINT u w)`;

(* Heap assertions *)
val _ = type_abbrev("hprop", ``:heap -> bool``);

val STARPOST_def = Define `
  STARPOST (Q: v -> hprop) (H: hprop) = \x. (Q x) * H`;

val SEP_IMPPOST_def = Define `
  SEP_IMPPOST (Q1: v -> hprop) (Q2: v -> hprop) =
    !x. SEP_IMP (Q1 x) (Q2 x)`;

val _ = overload_on ("*+", Term `STARPOST`);
val _ = add_infix ("*+", 480, HOLgrammars.LEFT);

(* Locality *)

(* local = frame rule + consequence rule + garbage collection *)

val local_def = Define `
  local cf env (H: hprop) (Q: v -> hprop) =
    !(h: heap). H h ==> ?H1 H2 H3 Q1.
      (H1 * H2) h /\
      cf env H1 Q1 /\
      SEP_IMPPOST (Q1 *+ H2) (Q *+ H3)`;

val is_local_def = Define `
  is_local cf = (cf = local cf)`;

(** App *)

val app_basic_def = Define `
  app_basic (:'ffi) (f: v) (x: v) env (H: hprop) (Q: v -> hprop) =
    !(h: heap) (i: heap) (st: 'ffi state).
      SPLIT (st2heap (:'ffi) st) (h, i) ==> H h ==>
      ?exp (v': v) (h': heap) (g: heap) (st': 'ffi state).
        SPLIT3 (st2heap (:'ffi) st') (h', g, i) /\
        Q v' h' /\
        (do_opapp [f;x] = SOME (env, exp)) /\
        evaluate F env st exp (st', Rval v')`;

val app_basic_local = Q.prove(
  `!f x. is_local (app_basic (:'ffi) f x)`,
  cheat);

val app_def = Define `
  app (:'ffi) (f: v) ([]: v list) env (H: hprop) (Q: v -> hprop) = F /\
  app (:'ffi) f [x] env H Q = app_basic (:'ffi) f x env H Q /\
  app (:'ffi) f (x::xs) env H Q =
    app_basic (:'ffi) f x env H
      (\g. SEP_EXISTS H'. H' * (cond (app (:'ffi) g xs env H' Q)))`;

val app_local = Q.prove(
  `!f xs. is_local (app (:'ffi) f xs)`,
  cheat);


val app_ref_def = Define `
  app_ref (x: v) env H Q =
    !(r: num). SEP_IMP (H * one (r, x)) (Q (Loc r))`;

val app_assign_def = Define `
  app_assign (r: num) (x: v) env H Q =
    ?x' F.
      SEP_IMP H (F * one (r, x')) /\
      SEP_IMP (F * one (r, x)) (Q (Conv NONE []))`;

val app_deref_def = Define `
  app_deref (r: num) env H Q =
    ?x F.
      SEP_IMP H (F * one (r, x)) /\
      SEP_IMP H (Q x)`;

(* ANF related *)

val exp2v_def = Define `
  exp2v _ (Lit l) = SOME (Litv l) /\
  exp2v env (Var name) = lookup_var_id name env /\
  exp2v _ _ = NONE`;

val exp2v_evaluate = Q.prove (
  `!e env st v. exp2v env e = SOME v ==>
   evaluate F env st e (st, Rval v)`,
  Induct \\ fs [exp2v_def] \\ prove_tac [bigStepTheory.evaluate_rules]
);

val exp2v_list_def = Define `
  exp2v_list env [] = SOME [] /\
  exp2v_list env (x :: xs) =
    (case exp2v env x of
      | NONE => NONE
      | SOME v =>
        (case exp2v_list env xs of
          | NONE => NONE
          | SOME vs => SOME (v :: vs)))`;

val exp2v_list_evaluate = Q.prove (
  `!l lv env st. exp2v_list env l = SOME lv ==>
   evaluate_list F env st l (st, Rval lv)`,
  Induct
  THEN1 (fs [exp2v_list_def] \\ prove_tac [bigStepTheory.evaluate_rules])
  THEN1 (
    rpt strip_tac \\ fs [exp2v_list_def] \\
    Cases_on `exp2v env h` \\ fs [] \\
    Cases_on `exp2v_list env l` \\ fs [] \\
    qpat_assum `_::_ = _` (assume_tac o GSYM) \\
    once_rewrite_tac [bigStepTheory.evaluate_cases] \\ fs [] \\
    qexists_tac `st` \\ fs [exp2v_evaluate]
  )
);

val evaluate_list_rcons = Q.prove (
  `!env st st' st'' l x lv v.
     evaluate_list F env st l (st', Rval lv) /\
     evaluate F env st' x (st'', Rval v) ==>
     evaluate_list F env st (l ++ [x]) (st'', Rval (lv ++ [v]))`,

  Induct_on `l`
  THEN1 (
    rpt strip_tac \\ fs [] \\
    qpat_assum `evaluate_list _ _ _ _ _` mp_tac \\
    once_rewrite_tac [bigStepTheory.evaluate_cases] \\ fs [] \\
    rpt strip_tac \\ qexists_tac `st''` \\ fs [] \\
    prove_tac [bigStepTheory.evaluate_rules]
  )
  THEN1 (
    rpt strip_tac \\ fs [] \\
    qpat_assum `evaluate_list _ _ _ _ _` mp_tac \\
    once_rewrite_tac [bigStepTheory.evaluate_cases] \\ fs [] \\
    rpt strip_tac \\ 
    Q.LIST_EXISTS_TAC [`v'`, `vs ++ [v]`] \\ fs [] \\
    asm_exists_tac \\ fs [] \\
    metis_tac []
  )
);

val exp2v_list_REVERSE = Q.prove (
  `!l (st: 'ffi state) lv env. exp2v_list env l = SOME lv ==>
   evaluate_list F env st (REVERSE l) (st, Rval (REVERSE lv))`,
  Induct \\ rpt gen_tac \\ disch_then (assume_tac o GSYM) \\
  fs [exp2v_list_def]
  THEN1 (prove_tac [bigStepTheory.evaluate_rules])
  THEN1 (
    Cases_on `exp2v env h` \\ fs [] \\
    Cases_on `exp2v_list env l` \\ fs [] \\
    first_assum drule \\ disch_then (qspec_then `st` assume_tac) \\
    match_mp_tac evaluate_list_rcons \\ qexists_tac `st` \\
    fs [exp2v_evaluate]
  )
);

(* CF *)

val cf_lit_def = Define `
  cf_lit l = local (\env H Q. SEP_IMP H (Q (Litv l)))`;

val cf_con_def = Define `
  cf_con cn args = local (\env H Q.
    ?argsv cv.
      do_con_check env.c cn (LENGTH args) /\
      (build_conv env.c cn argsv = SOME cv) /\
      (exp2v_list env args = SOME argsv) /\
      SEP_IMP H (Q cv))`;

val cf_var_def = Define `
  cf_var name = local (\env H Q.
    !h. H h ==> ?v. lookup_var_id name env = SOME v /\ Q v h)`;

val cf_seq_def = Define `
  cf_seq F1 F2 = local (\env H Q.
    ?Q'. F1 env H Q' /\ !xv. F2 env (Q' xv) Q)`;

val cf_let_def = Define `
  cf_let n F1 F2 = local (\env H Q.
    ?Q'. F1 env H Q' /\
         !xv. F2 (env with <| v := opt_bind n xv env.v |>) (Q' xv) Q)`;

val cf_app2_def = Define `
  cf_app2 (:'ffi) f x = local (\env H Q.
    ?fv xv.
      exp2v env f = SOME fv /\
      exp2v env x = SOME xv /\
      app_basic (:'ffi) fv xv env H Q)`;

val cf_fundecl_def = Define `
  cf_fundecl (:'ffi) f n F1 F2 = local (\env H Q.
    !fv.
      (!xv H' Q'.
        F1 (env with v := (n, xv)::env.v) H' Q' ==>
        app_basic (:'ffi) fv xv (env with v := (n, xv)::env.v) H' Q')
      ==>
      F2 (env with v := (f, fv)::env.v) H Q)`;

val cf_ref_def = Define `
  cf_ref x = local (\env H Q.
    ?xv.
      exp2v env x = SOME xv /\
      app_ref xv env H Q)`;

val cf_assign_def = Define `
  cf_assign r x = local (\env H Q.
    ?rv xv.
      exp2v env r = SOME (Loc rv) /\
      exp2v env x = SOME xv /\
      app_assign rv xv env H Q)`;

val cf_deref_def = Define `
  cf_deref r = local (\env H Q.
    ?rv.
      exp2v env r = SOME (Loc rv) /\
      app_deref rv env H Q)`;

val is_bound_Fun_def = Define `
  is_bound_Fun (SOME _) (Fun _ _) = T /\
  is_bound_Fun _ _ = F`;

val Fun_body_def = Define `
  Fun_body (Fun _ body) = body`;

val Fun_param_def = Define `
  Fun_param (Fun n _) = n`;

val SOME_val_def = Define `
  SOME_val (SOME x) = x`; 

val cf_def = tDefine "cf" `
  cf (:'ffi) (Lit l) = cf_lit l /\
  cf (:'ffi) (Con opt args) = cf_con opt args /\ 
  cf (:'ffi) (Var name) = cf_var name /\
  cf (:'ffi) (Let opt e1 e2) =
    (if is_bound_Fun opt e1 then
       cf_fundecl (:'ffi) (SOME_val opt) (Fun_param e1)
         (cf (:'ffi) (Fun_body e1)) (cf (:'ffi) e2)
     else
       cf_let opt (cf (:'ffi) e1) (cf (:'ffi) e2)) /\
  cf (:'ffi) (App op args) =
    (case op of
        | Opapp =>
          (case args of
             | [f; x] => cf_app2 (:'ffi) f x
             | _ => \env H Q. F)
        | Opref => 
          (case args of
             | [x] => cf_ref x
             | _ => \env H Q. F)
        | Opassign => 
          (case args of
             | [r; x] => cf_assign r x
             | _ => \env H Q. F)
        | Opderef => 
          (case args of
             | [r] => cf_deref r
             | _ => \env H Q. F)
        | _ => \env H Q.F) /\
  cf _ _ = \env H Q. F`

  (WF_REL_TAC `measure (exp_size o SND)` \\ rw [] \\
   Cases_on `opt` \\ Cases_on `e1` \\ fs [is_bound_Fun_def, Fun_body_def] \\
   fs [astTheory.exp_size_def]);

val cf_ind = fetch "-" "cf_ind";

val cf_defs = [cf_def, cf_lit_def, cf_con_def, cf_var_def, cf_fundecl_def, cf_let_def,
               cf_seq_def,cf_app2_def, cf_ref_def, cf_assign_def, cf_deref_def];

(* Soundness of cf *)

val sound_def = Define `
  sound (:'ffi) e R =
    !env H Q. R env H Q ==>
    !st h_i h_k. SPLIT (st2heap (:'ffi) st) (h_i, h_k) ==>
    H h_i ==>
      ?v st' h_f h_g.
        SPLIT3 (st2heap (:'ffi) st') (h_f, h_k, h_g) /\
        evaluate F env st e (st', Rval v) /\
        Q v h_f`;

val SPLIT_ss = rewrites [SPLIT_def,SPLIT3_def,SUBSET_DEF,DISJOINT_DEF,DELETE_DEF,IN_INSERT,UNION_DEF,
                         SEP_EQ_def,EXTENSION,NOT_IN_EMPTY,IN_DEF,IN_UNION,IN_INTER,IN_DIFF];

val SPLIT_TAC = FULL_SIMP_TAC (pure_ss++SPLIT_ss) [] \\ METIS_TAC [];
val SPLIT2_TAC = fs [SPLIT_def,SPLIT3_def,SUBSET_DEF,DISJOINT_DEF,DELETE_DEF,IN_INSERT,UNION_DEF,
                         SEP_EQ_def,EXTENSION,NOT_IN_EMPTY,IN_DEF,IN_UNION,IN_INTER,IN_DIFF]
                 \\ metis_tac [];

val star_split = Q.prove (
  `!H1 H2 H3 H4 h1 h2 h3 h4.
     ((H1 * H2) (h1 UNION h2) ==> (H3 * H4) (h3 UNION h4)) ==>
     DISJOINT h1 h2 ==> H1 h1 ==> H2 h2 ==>
     ?u v. H3 u /\ H4 v /\ SPLIT (h3 UNION h4) (u, v)`,
  fs [STAR_def] \\ rpt strip_tac \\
  `SPLIT (h1 UNION h2) (h1, h2)` by SPLIT_TAC \\
  metis_tac []
);

val sound_local = Q.prove (
  `!e R. sound (:'ffi) e R ==> sound (:'ffi) e (local R)`,
  rpt strip_tac \\ rewrite_tac [sound_def, local_def] \\ rpt strip_tac \\
  res_tac \\ qcase_tac `(H_i * H_k) h_i` \\ qcase_tac `R env H_i Q_f` \\
  qcase_tac `SEP_IMPPOST (Q_f *+ H_k) (Q *+ H_g)` \\
  fs [STAR_def] \\ qcase_tac `H_i h'_i` \\ qcase_tac `H_k h'_k` \\
  `SPLIT (st2heap (:'ffi) st) (h'_i, h_k UNION h'_k)` by SPLIT_TAC \\
  qpat_assum `sound _ _ _` (drule o REWRITE_RULE [sound_def]) \\
  rpt (disch_then drule) \\ rpt strip_tac \\ qcase_tac `SPLIT3 _ (h'_f, _, h'_g)` \\
  fs [SEP_IMPPOST_def, STARPOST_def, SEP_IMP_def, STAR_def] \\
  first_x_assum (qspecl_then [`v`, `h'_f UNION h'_k`] assume_tac) \\
  `DISJOINT h'_f h'_k` by SPLIT_TAC \\
  `?h_f h''_g. Q v h_f /\ H_g h''_g /\ SPLIT (h'_f UNION h'_k) (h_f, h''_g)` by
    metis_tac [star_split] \\
  Q.LIST_EXISTS_TAC [`v`, `st'`, `h_f`, `h'_g UNION h''_g`] \\ fs [] \\
  SPLIT_TAC
);

val sound_false = Q.prove (`!e. sound (:'ffi) e (\env H Q. F)`, rewrite_tac [sound_def]);

val cf_base_case_tac =
  match_mp_tac sound_local \\ rewrite_tac [sound_def] \\ rpt strip_tac \\
  fs [] \\ res_tac \\
  qcase_tac `SPLIT (st2heap _ st) (h_i, h_k)` \\
  `SPLIT3 (st2heap (:'ffi) st) (h_i, h_k, {})` by SPLIT_TAC \\
  rpt (asm_exists_tac \\ fs []) \\
  once_rewrite_tac [bigStepTheory.evaluate_cases] \\ fs [SEP_IMP_def]
;  

val cf_strip_sound_tac =
  match_mp_tac sound_local \\ rewrite_tac [sound_def] \\ rpt strip_tac \\ fs [] \\
  once_rewrite_tac [bigStepTheory.evaluate_cases] \\
  fs [libTheory.opt_bind_def, PULL_EXISTS] (* \\ *)
;

fun cf_evaluate_list_tac st =
  rpt (
    once_rewrite_tac [bigStepTheory.evaluate_cases] \\ fs [] \\
    qexists_tac st \\ fs [exp2v_evaluate] \\
    TRY (qmatch_rename_tac `evaluate_list _ _ _ [] _` \\
         prove_tac [bigStepTheory.evaluate_rules])
  )
;

val cf_sound = Q.prove (
  `!(r: 'ffi itself) e. sound (:'ffi) e (cf (:'ffi) e)`,
  recInduct cf_ind \\ rpt strip_tac \\
  rewrite_tac cf_defs \\ fs [] \\ rewrite_tac [sound_false]
  THEN1 (* Lit *) cf_base_case_tac
  THEN1 (
    (* Con *)
    cf_base_case_tac \\ fs [PULL_EXISTS, st2heap_def] \\
    mp_tac exp2v_list_REVERSE \\ rpt (disch_then drule) \\
    strip_tac \\ qexists_tac `cv` \\ qexists_tac `REVERSE argsv` \\ fs []
  )
  THEN1 (* Var *) cf_base_case_tac
  THEN1 (
    (* Let *)
    Cases_on `is_bound_Fun opt e1` \\ fs []
    THEN1 (
      (* function declaration *)
      Cases_on `opt` \\ Cases_on `e1` \\
      fs [is_bound_Fun_def, Fun_body_def, Fun_param_def, SOME_val_def] \\
      cf_strip_sound_tac \\ qcase_tac `Fun n body` \\
      GEN_EXISTS_TAC "v'" `Closure env n body` \\
      first_x_assum (qspec_then `Closure env n body` assume_tac) \\
      qmatch_assum_abbrev_tac `HH ==> cf _ e2 _ _ _` \\ qsuff_tac `HH` \\ qunabbrev_tac `HH`
      THEN1 (
        strip_tac \\ first_assum drule \\ strip_tac \\
        qpat_assum `sound _ e2 _` (drule o REWRITE_RULE [sound_def]) \\
        rpt (disch_then drule) \\ strip_tac \\
        qexists_tac `v` \\ GEN_EXISTS_TAC "s2" `st` \\
        rpt (asm_exists_tac \\ fs []) \\
        once_rewrite_tac [bigStepTheory.evaluate_cases] \\ fs []
      )
      THEN1 (
        rpt strip_tac \\ fs [app_basic_def] \\ rpt strip_tac \\
        qpat_assum `sound _ body _` (drule o REWRITE_RULE [sound_def]) \\
        disch_then (mp_tac o Q.SPEC `st'`) \\ rpt (disch_then drule) \\ strip_tac \\ 
        fs [semanticPrimitivesTheory.do_opapp_def] \\
        `SPLIT3 (st2heap (:'ffi) st'') (h_f,h_g,i)` by SPLIT_TAC \\
        rpt (asm_exists_tac \\ fs [])
      )
    )
    THEN1 (
      (* other cases of let-binding *)
      cf_strip_sound_tac \\
      qpat_assum `sound _ e1 _` (drule o REWRITE_RULE [sound_def]) \\
      rpt (disch_then drule) \\ strip_tac \\
      first_assum (qspec_then `v` assume_tac) \\
      qpat_assum `sound _ e2 _` (drule o REWRITE_RULE [sound_def]) \\
      `SPLIT (st2heap (:'ffi) st') (h_f, h_k UNION h_g)` by SPLIT_TAC \\
      disch_then (mp_tac o Q.SPEC `st'`) \\ rpt (disch_then drule) \\ strip_tac \\
      `SPLIT3 (st2heap (:'ffi) st'') (h_f',h_k, h_g UNION h_g')` by SPLIT_TAC \\
      rpt (asm_exists_tac \\ fs [])
    )
  )
  THEN1 (
    (* App *)
    Cases_on `op` \\ fs [sound_false] \\ every_case_tac \\ fs [sound_false] \\
    cf_strip_sound_tac 
    THEN1 (
      (* Opapp *)
      fs [app_basic_def] \\ res_tac \\
      qcase_tac `SPLIT3 (st2heap _ st') (h_f, h_g, h_k)` \\
      `SPLIT3 (st2heap (:'ffi) st') (h_f, h_k, h_g)` by SPLIT_TAC \\
      GEN_EXISTS_TAC "vs" `[xv; fv]` \\
      asm_exists_tac \\ fs [] \\
      prove_tac [exp2v_evaluate, bigStepTheory.evaluate_rules]
    )
    THEN1 (
      (* Opassign *)
      fs [app_assign_def, SEP_IMP_def, STAR_def, one_def, st2heap_def] \\
      `evaluate_list F env st [h'; h] (st, Rval [xv; Loc rv])` by (cf_evaluate_list_tac `st`) \\
      qpat_assum `!s. H s ==> _` drule \\ strip_tac \\
      qcase_tac `SPLIT h_i (h_i', _)` \\ qcase_tac `FF h_i'` \\
      GEN_EXISTS_TAC "vs" `[xv; Loc rv]` \\ 
      fs [semanticPrimitivesTheory.do_app_def, semanticPrimitivesTheory.store_assign_def] \\
      `rv < LENGTH st.refs` by (mp_tac store2heap_IN_LENGTH \\ SPLIT2_TAC) \\
      `store_v_same_type (EL rv st.refs) (Refv xv)` by (
        fs [semanticPrimitivesTheory.store_v_same_type_def] \\
        qspecl_then [`st.refs`, `rv`, `x'`] assume_tac store2heap_IN_type \\
        `(rv, x') IN store2heap st.refs` by SPLIT_TAC \\ fs []
      ) \\
      `SPLIT3 (store2heap (LUPDATE (Refv xv) rv st.refs))
         ((rv, xv) INSERT h_i', h_k, {})` by (
        mp_tac store2heap_LUPDATE \\ mp_tac store2heap_IN_unique_key \\
        SPLIT2_TAC
      ) \\
      rpt (asm_exists_tac \\ fs []) \\
      first_assum match_mp_tac \\ qexists_tac `h_i'` \\
      strip_assume_tac store2heap_IN_unique_key \\ SPLIT_TAC
    )
    THEN1 (
      (* Opref *)
      fs [semanticPrimitivesTheory.do_app_def, semanticPrimitivesTheory.store_alloc_def] \\
      fs [st2heap_def, app_ref_def, SEP_IMP_def, STAR_def, one_def] \\
      GEN_EXISTS_TAC "vs" `[xv]` \\
      first_x_assum (qspecl_then [`LENGTH st.refs`, `(LENGTH st.refs,xv) INSERT h_i`] mp_tac) \\
      impl_tac
      THEN1 (qexists_tac `h_i` \\ assume_tac store2heap_alloc_disjoint \\ SPLIT_TAC)
      THEN1 (
        strip_tac \\ once_rewrite_tac [CONJ_COMM] \\
        `evaluate_list F env st [h] (st, Rval [xv])` by (cf_evaluate_list_tac `st`) \\
        rpt (asm_exists_tac \\ fs []) \\ fs [store2heap_append_Refv] \\
        assume_tac store2heap_alloc_disjoint \\ qexists_tac `{}` \\ SPLIT_TAC
      )
    )
    THEN1 (
      (* Opderef *)
      `evaluate_list F env st [h] (st, Rval [Loc rv])` by (cf_evaluate_list_tac `st`) \\
      fs [st2heap_def, app_deref_def, SEP_IMP_def, STAR_def, one_def] \\
      rpt (qpat_assum `!s. H s ==> _` drule \\ strip_tac) \\ fs [] \\
      qcase_tac `SPLIT h_i (h_i', {(rv,x)})` \\ qcase_tac `FF h_i'` \\
      GEN_EXISTS_TAC "vs" `[Loc rv]` \\
      fs [semanticPrimitivesTheory.do_app_def, semanticPrimitivesTheory.store_lookup_def] \\
      `rv < LENGTH st.refs` by (mp_tac store2heap_IN_LENGTH \\ SPLIT2_TAC) \\
      `SPLIT3 (store2heap st.refs) (h_i, h_k, {})` by SPLIT_TAC \\
      rpt (asm_exists_tac \\ fs []) \\
      qspecl_then [`st.refs`, `rv`, `x`] assume_tac store2heap_IN_type \\
      `(rv,x) IN store2heap st.refs` by SPLIT_TAC \\ fs []
    )
);

val cf_sound' = Q.prove (
  `!e env H Q st.
     cf (:'ffi) e env H Q ==> H (st2heap (:'ffi) st) ==>
     ?st' h_f h_g v.
       evaluate F env st e (st', Rval v) /\
       SPLIT (st2heap (:'ffi) st') (h_f, h_g) /\
       Q v h_f`,

  rpt strip_tac \\ qspecl_then [`(:'ffi)`, `e`] assume_tac cf_sound \\
  fs [sound_def, st2heap_def] \\
  `SPLIT (store2heap st.refs) (store2heap st.refs, {})` by SPLIT_TAC \\
  res_tac \\ qcase_tac `SPLIT3 (store2heap st'.refs) (h_f, {}, h_g)` \\
  `SPLIT (store2heap st'.refs) (h_f, h_g)` by SPLIT_TAC \\
  rpt (asm_exists_tac \\ fs [])
);

val _ = export_theory();

open HolKernel Parse boolLib bossLib
open asmLib arm6_targetTheory arm_stepLib;

val () = new_theory "arm6_targetProof"

val () = wordsLib.guess_lengths ()

(* some lemmas ---------------------------------------------------------- *)

val valid_immediate = Q.prove(
  `!i. IS_SOME (EncodeARMImmediate i) = valid_immediate i`,
  simp [valid_immediate_def])

val valid_immediate2 =
   valid_immediate
   |> Drule.SPEC_ALL
   |> Thm.SYM
   |> REWRITE_RULE [GSYM quantHeuristicsTheory.SOME_THE_EQ_SYM]
   |> Thm.EQ_IMP_RULE
   |> fst
   |> Drule.GEN_ALL

val arm6_config =
  REWRITE_RULE [valid_immediate] arm6_targetTheory.arm6_config

val arm6_asm_ok =
  REWRITE_RULE [valid_immediate] arm6_targetTheory.arm6_asm_ok

val lem1 = Q.prove(
   `!n m. n < 16 /\ n <> 13 /\ n <> 15 ==>
          RName_PC <> R_mode m (n2w n) /\ n MOD 16 <> 15`,
   CONV_TAC (Conv.ONCE_DEPTH_CONV SYM_CONV)
   \\ simp [arm_stepTheory.R_x_pc]
   )

val lem2 = asmLib.v2w_BIT_n2w 4
val lem3 = asmLib.v2w_BIT_n2w 5

val lem4 =
   blastLib.BBLAST_PROVE ``0w <= c /\ c <= 4095w ==> c <=+ 4095w: word32``

val lem5 =
   blastLib.BBLAST_PROVE
      ``~(0w <= c) /\ 0xFFFFF001w <= c ==> -1w * c <=+ 4095w: word32``

val lem6 = Q.prove(
   `!s state c n.
      target_state_rel arm6_target s state /\ n < 16 /\ n <> 13 /\ n <> 15 /\
      aligned 2 (c + s.regs n) ==>
      aligned 2 (c + state.REG (R_mode state.CPSR.M (n2w n)))`,
   rw [asmPropsTheory.target_state_rel_def, alignmentTheory.aligned_extract,
       arm6_target_def, arm6_config_def, lem1]
   )

val lem7 = Q.prove(
   `!a: word24. aligned 2 (sw2sw ((a @@ (0w: word2)): 26 word) : word32)`,
   srw_tac [wordsLib.WORD_EXTRACT_ss] [alignmentTheory.aligned_extract]
   )

fun bprove tm =
   Q.prove (tm, simp [markerTheory.Abbrev_def, alignmentTheory.aligned_extract]
                \\ blastLib.BBLAST_TAC)

val jmp_tm =
   ``0xFE000008w <= c /\ c <= 0x2000007w: word32 /\ aligned 2 (c: word32)``

val cjmp_tm =
   ``0xFE00000Cw <= c /\ c <= 0x200000Bw: word32 /\ aligned 2 (c: word32)``

val lem8 = bprove
   `(^jmp_tm ==>
     0xFE000000w <= c + 0xFFFFFFF8w /\ c + 0xFFFFFFF8w <= 0x1FFFFFCw) /\
    (^cjmp_tm ==>
     0xFE000000w <= c + 0xFFFFFFF4w /\ c + 0xFFFFFFF4w <= 0x1FFFFFCw)`

val lem9 = bprove
  `Abbrev (a = (25 >< 2) (c + 0xFFFFFFF8w): word24) /\ a ' 23 /\ ^jmp_tm ==>
   (-1w *
   (v2w
      [~a ' 22; ~a ' 21; ~a ' 20; ~a ' 19; ~a ' 18; ~a ' 17; ~a ' 16;
       ~a ' 15; ~a ' 14; ~a ' 13; ~a ' 12; ~a ' 11; ~a ' 10; ~a ' 9;
       ~a ' 8; ~a ' 7; ~a ' 6; ~a ' 5; ~a ' 4; ~a ' 3; ~a ' 2; ~a ' 1;
       ~a ' 0; T; T] + 1w) = c - 8w)`

val lem10 = bprove
  `Abbrev (a = (25 >< 2) (c + 0xFFFFFFF8w): word24) /\ ~a ' 23 /\ ^jmp_tm ==>
   (v2w
      [a ' 22; a ' 21; a ' 20; a ' 19; a ' 18; a ' 17; a ' 16; a ' 15;
       a ' 14; a ' 13; a ' 12; a ' 11; a ' 10; a ' 9; a ' 8; a ' 7; a ' 6;
       a ' 5; a ' 4; a ' 3; a ' 2; a ' 1; a ' 0; F; F] = c - 8w)`

val lem11 =
   (REWRITE_RULE [wordsTheory.WORD_ADD_0] o  Q.INST [`c` |-> `0w`] o
    Drule.SPEC_ALL) lem6

val lem12 = Q.prove(
   `!x: word32. aligned 2 x ==> ~word_bit 1 x /\ ~word_bit 0 x`,
   simp [alignmentTheory.aligned_extract]
   \\ blastLib.BBLAST_TAC
   )

(*
val lem12 =
   Drule.GEN_ALL
      (Drule.IMP_TRANS lem11
         (Q.SPEC `state.REG (R_mode state.CPSR.M (n2w n))` lem12))
*)

val lem15 = bprove
  `Abbrev (a = (25 >< 2) (c + 0xFFFFFFF8w): word24) /\ ^jmp_tm ==>
     (sw2sw
        ((v2w
            [a ' 23; a ' 22; a ' 21; a ' 20; a ' 19; a ' 18; a ' 17; a ' 16;
             a ' 15; a ' 14; a ' 13; a ' 12; a ' 11; a ' 10; a ' 9; a ' 8;
             a ' 7; a ' 6; a ' 5; a ' 4; a ' 3; a ' 2; a ' 1; a ' 0]: word24
             @@ (0w: word2)) : 26 word) = c - 8w)`

val lem16 = bprove
   `!c r: word32.
       Abbrev (r = c + 0xFFFFFFF4w) /\ ^cjmp_tm ==>
       (sw2sw
        ((v2w
          [r ' 25; r ' 24; r ' 23; r ' 22; r ' 21; r ' 20; r ' 19; r ' 18;
           r ' 17; r ' 16; r ' 15; r ' 14; r ' 13; r ' 12; r ' 11; r ' 10;
           r ' 9; r ' 8; r ' 7; r ' 6; r ' 5; r ' 4; r ' 3; r ' 2]: word24
          @@ (0w: word2)) : 26 word) = c - 12w)`

fun tac n =
   simp [Ntimes armTheory.EncodeARMImmediate_aux_def n,
         wordsLib.WORD_DECIDE ``-1w = 15w: word4``]
   \\ strip_tac
   \\ qunabbrev_tac `i`
   \\ simp []
   \\ CONV_TAC
        (LAND_CONV (RAND_CONV (Conv.DEPTH_CONV blastLib.BBLAST_CONV)
                               THENC DEPTH_CONV bitstringLib.v2w_n2w_CONV))
   \\ simp []
   \\ blastLib.FULL_BBLAST_TAC
   \\ blastLib.BBLAST_TAC

val decode_imm_thm = Q.prove(
   `!c.
      valid_immediate c ==>
      let imm12 = THE (EncodeARMImmediate c) in
         w2w (v2w [imm12 ' 7; imm12 ' 6; imm12 ' 5; imm12 ' 4;
                   imm12 ' 3; imm12 ' 2; imm12 ' 1; imm12 ' 0]: word8) #>>
         w2n (v2w [imm12 ' 11; imm12 ' 10; imm12 ' 9; imm12 ' 8; F] : word5) =
         c`,
   strip_tac
   \\ simp_tac std_ss [valid_immediate_def, armTheory.EncodeARMImmediate_def]
   \\ qabbrev_tac `i = EncodeARMImmediate_aux (15w,c)`
   \\ pop_assum mp_tac
   \\ Cases_on `(31 >< 8) c = 0w: word24` >- tac 1
   \\ Cases_on `(31 >< 8) (c #<< 2) = 0w: word24` >- tac 2
   \\ Cases_on `(31 >< 8) (c #<< 4) = 0w: word24` >- tac 3
   \\ Cases_on `(31 >< 8) (c #<< 6) = 0w: word24` >- tac 4
   \\ Cases_on `(31 >< 8) (c #<< 8) = 0w: word24` >- tac 5
   \\ Cases_on `(31 >< 8) (c #<< 10) = 0w: word24` >- tac 6
   \\ Cases_on `(31 >< 8) (c #<< 12) = 0w: word24` >- tac 7
   \\ Cases_on `(31 >< 8) (c #<< 14) = 0w: word24` >- tac 8
   \\ Cases_on `(31 >< 8) (c #<< 16) = 0w: word24` >- tac 9
   \\ Cases_on `(31 >< 8) (c #<< 18) = 0w: word24` >- tac 10
   \\ Cases_on `(31 >< 8) (c #<< 20) = 0w: word24` >- tac 11
   \\ Cases_on `(31 >< 8) (c #<< 22) = 0w: word24` >- tac 12
   \\ Cases_on `(31 >< 8) (c #<< 24) = 0w: word24` >- tac 13
   \\ Cases_on `(31 >< 8) (c #<< 26) = 0w: word24` >- tac 14
   \\ Cases_on `(31 >< 8) (c #<< 28) = 0w: word24` >- tac 15
   \\ Cases_on `(31 >< 8) (c #<< 30) = 0w: word24` >- tac 16
   \\ tac 17
   )

val decode_imm_thm = SIMP_RULE (bool_ss++boolSimps.LET_ss) [] decode_imm_thm

val decode_some_encode_immediate =
   decode_imm_thm
   |> Q.SPEC `c`
   |> Q.DISCH `EncodeARMImmediate c = SOME x`
   |> SIMP_RULE std_ss [valid_immediate_def]
   |> Drule.GEN_ALL

val decode_some_encode_neg_immediate =
   decode_imm_thm
   |> Q.SPEC `~c`
   |> Q.DISCH `EncodeARMImmediate (~c) = SOME x`
   |> SIMP_RULE std_ss [valid_immediate_def]
   |> Drule.GEN_ALL

val decode_imm12_thm =
   blastLib.BBLAST_PROVE
     ``!c: word32.
       c <=+ 4095w ==>
       (w2w (v2w [c ' 11; c ' 10; c ' 9; c ' 8; c ' 7; c ' 6;
                  c ' 5; c ' 4; c ' 3; c ' 2; c ' 1; c ' 0] : word12) = c)``

val decode_neg_imm12_thm = Q.prove(
   `!c: word32 d.
       0xFFFFF001w <= c /\ ~(0w <= c) /\ Abbrev (d = -1w * c) ==>
       (-1w *
        w2w (v2w [d ' 11; d ' 10; d ' 9; d ' 8; d ' 7; d ' 6;
                  d ' 5; d ' 4; d ' 3; d ' 2; d ' 1; d ' 0] : word12) = c)`,
   rw []
   \\ qunabbrev_tac `d`
   \\ blastLib.FULL_BBLAST_TAC
   )

val decode_imm8_thm1 = Q.prove(
   `!c: word32.
       8w <= c /\ c <= 263w ==>
       (EncodeARMImmediate (c + 0xFFFFFFF8w) =
        SOME ((7 >< 0) (c + 0xFFFFFFF8w)))`,
   rw [armTheory.EncodeARMImmediate_def,
       Once armTheory.EncodeARMImmediate_aux_def]
   \\ blastLib.FULL_BBLAST_TAC
   )

val decode_imm8_thm3 = Q.prove(
   `!c: word32.
       ~(8w <= c) /\ 0xFFFFFF09w <= c ==>
       (EncodeARMImmediate (-1w * c + 8w) = SOME ((7 >< 0) (-1w * c + 8w)))`,
   rw [armTheory.EncodeARMImmediate_def,
       Once armTheory.EncodeARMImmediate_aux_def]
   \\ blastLib.FULL_BBLAST_TAC
   )

val loc_lem =
  utilsLib.map_conv asmLib.mk_blast_thm
    [``(31 >< 24) (a - 8w : word32) : word8``,
     ``(23 >< 16) (a - 8w : word32) : word8``,
     ``(15 >< 8) (a - 8w : word32) : word8``,
     ``(7 >< 0) (a - 8w : word32) : word8``,
     ``(31 >< 24) (-1w * a + 8w : word32) : word8``,
     ``(23 >< 16) (-1w * a + 8w : word32) : word8``,
     ``(15 >< 8) (-1w * a + 8w : word32) : word8``,
     ``(7 >< 0) (-1w * a + 8w : word32) : word8``]

val word_lo_not_carry = Q.prove(
   `!a b. (a <+ b) = ~CARRY_OUT a (~b) T`,
   simp [wordsTheory.ADD_WITH_CARRY_SUB, wordsTheory.WORD_NOT_LOWER_EQUAL]
   )

val word_lt_n_eq_v = Q.prove(
   `!a b: word32. (a < b) = ((word_bit 31 (a + -1w * b) <> OVERFLOW a (~b) T))`,
   simp [wordsTheory.ADD_WITH_CARRY_SUB, GSYM wordsTheory.WORD_LO]
   \\ blastLib.BBLAST_TAC
   )

val SetPassCondition =
   utilsLib.map_conv
     (SIMP_CONV (srw_ss()++boolSimps.LET_ss) [armTheory.SetPassCondition_def])
     [``SetPassCondition 0w s``,
      ``SetPassCondition 1w s``,
      ``SetPassCondition 2w s``,
      ``SetPassCondition 3w s``,
      ``SetPassCondition 10w s``,
      ``SetPassCondition 11w s``,
      ``SetPassCondition 14w s``]

local
   open armTheory
   val () = utilsLib.setStepConv (Conv.DEPTH_CONV bitstringLib.extract_v2w_CONV)
   val EV = utilsLib.STEP (K (utilsLib.datatype_rewrites true "arm" ["SRType"]),
                           ``s:arm_state``)
   val Shift_C_rwt =
      EV [Shift_C_def, LSL_C_def, LSR_C_def, ASR_C_def, ROR_C_def, RRX_C_def]
         [] []
         ``Shift_C (value,typ,amount,carry_in)
           : arm_state -> ('a word # bool) # arm_state``
         |> hd
         |> SIMP_RULE std_ss []
   val arm_imm_lem = Q.prove(
      `((if n = 0 then ((w, c1), s) else ((w #>> n, c2), s)) =
        ((w #>> n, if n = 0 then c1 else c2), s)) /\
       (2 * w2n (v2w [a; b; c; d] : word4) =
        w2n (v2w [a; b; c; d; F] : word5))`,
      rw [] \\ wordsLib.n2w_INTRO_TAC 5 \\ blastLib.BBLAST_TAC
      )
in
   val ARMExpandImm_C_rwt =
      EV [armTheory.ARMExpandImm_C_def, Shift_C_rwt, arm_imm_lem] [] []
        ``ARMExpandImm_C (^(bitstringSyntax.mk_vec 12 0), c)``
        |> hd
        |> REWRITE_RULE [wordsTheory.w2n_eq_0]
end

val reg_mode_eq = Q.prove(
   `!m ms1 ms2.
       (ms1.REG o R_mode m = ms2.REG o R_mode m) <=>
       (!i. ms1.REG (R_mode m (n2w i)) = ms2.REG (R_mode m (n2w i))) /\
       (ms1.REG RName_PC = ms2.REG RName_PC)`,
   rw [FUN_EQ_THM]
   \\ eq_tac
   \\ strip_tac
   >- metis_tac [arm_stepTheory.R_mode]
   \\ Cases
   \\ simp []
   )

val aligned_add = Q.prove(
   `!p a b. aligned p a ==> (aligned p (a + b) = aligned p b)`,
   metis_tac [wordsTheory.WORD_ADD_COMM, alignmentTheory.aligned_add_sub]
   )

val _ = diminish_srw_ss ["MOD_ss"]

val adc_lem1 = Q.prove(
  `!r2 r3 : word32 r4 : word32.
      CARRY_OUT r2 r3 (CARRY_OUT r4 (-1w) T) <=>
      4294967296 <= w2n r2 + (w2n r3 + 1)`,
  rw [wordsTheory.add_with_carry_def]
)

val adc_lem2 = Q.prove(
  `!r2 r3 : word32 r4 : word32.
      FST (add_with_carry (r2,r3,CARRY_OUT r4 (-1w) T)) =
      n2w (w2n r2 + (w2n r3 + 1))`,
  rw [wordsTheory.add_with_carry_def]
)

val adc_lem3 = Q.prove(
  `!r2 r3 : word32. CARRY_OUT r2 r3 F <=> 4294967296 <= w2n r2 + w2n r3`,
  rw [wordsTheory.add_with_carry_def]
)

val adc_lem4 = Q.prove(
  `!r2 r3 : word32. FST (add_with_carry (r2,r3,F)) = n2w (w2n r2 + w2n r3)`,
  rw [wordsTheory.add_with_carry_def]
)

val mul_long_lem1 = Q.prove(
  `!a : word32 b. (31 >< 0) (w2w a * w2w b : word64) = a * b`,
  srw_tac [wordsLib.WORD_EXTRACT_ss]
    [Once wordsTheory.WORD_EXTRACT_OVER_MUL])

val mul_long_lem2 = Q.prove(
  `!a : word32 b : word32.
    n2w ((w2n a * w2n b) DIV 4294967296) =
    (63 >< 32) (w2w a * w2w b : word64) : word32`,
  Cases
  \\ Cases
  \\ fs [wordsTheory.w2w_n2w, wordsTheory.word_mul_n2w,
         wordsTheory.word_extract_n2w, bitTheory.BITS_THM]
  )

(* some rewrites ---------------------------------------------------------- *)

val encode_rwts =
   let
      open armTheory
   in
      [arm6_enc_def, arm6_bop_def, arm6_sh_def, arm6_cmp_def,
       arm6_encode_def, arm6_encode1_def, encode_def,
       e_branch_def, e_data_def, e_load_def, e_store_def,
       e_multiply_def, EncodeImmShift_def, EncodeImmShift_def
      ]
   end

val enc_rwts =
   [asmPropsTheory.offset_monotonic_def, lem4, lem5, lem8, decode_imm8_thm1,
    decode_imm8_thm3, arm_stepTheory.Aligned, alignmentTheory.aligned_0,
    alignmentTheory.aligned_numeric, arm6_asm_ok, Once valid_immediate2] @
   encode_rwts @ asmLib.asm_rwts

val enc_ok_rwts =
   [asmPropsTheory.enc_ok_def, arm6_config, arm6_asm_ok] @ encode_rwts

(* some custom tactics ---------------------------------------------------- *)

val bytes_in_memory_thm = Q.prove(
   `!s state a b c d.
      target_state_rel arm6_target s state /\
      bytes_in_memory s.pc [a; b; c; d] s.mem s.mem_domain ==>
      (state.exception = NoException) /\
      (state.Architecture = ARMv6) /\
      ~state.Extensions Extension_Security /\
      ~state.CPSR.T /\
      ~state.CPSR.J /\
      ~state.CPSR.E /\
      GoodMode state.CPSR.M /\
      ((1 >< 0) (state.REG RName_PC) = 0w: word32) /\
      aligned 2 (state.REG RName_PC) /\
      (state.MEM (state.REG RName_PC + 3w) = d) /\
      (state.MEM (state.REG RName_PC + 2w) = c) /\
      (state.MEM (state.REG RName_PC + 1w) = b) /\
      (state.MEM (state.REG RName_PC) = a) /\
      state.REG RName_PC + 3w IN s.mem_domain /\
      state.REG RName_PC + 2w IN s.mem_domain /\
      state.REG RName_PC + 1w IN s.mem_domain /\
      state.REG RName_PC IN s.mem_domain`,
   rw [asmPropsTheory.sym_target_state_rel, arm6_ok_def, arm6_target_def,
       arm6_config_def, asmSemTheory.bytes_in_memory_def]
   \\ rfs [alignmentTheory.aligned_extract]
   )

val bytes_in_memory_thm2 = Q.prove(
   `!w s state a b c d.
      target_state_rel arm6_target s state /\
      bytes_in_memory (s.pc + w) [a; b; c; d] s.mem s.mem_domain ==>
      (state.MEM (state.REG RName_PC + w + 3w) = d) /\
      (state.MEM (state.REG RName_PC + w + 2w) = c) /\
      (state.MEM (state.REG RName_PC + w + 1w) = b) /\
      (state.MEM (state.REG RName_PC + w) = a) /\
      state.REG RName_PC + w + 3w IN s.mem_domain /\
      state.REG RName_PC + w + 2w IN s.mem_domain /\
      state.REG RName_PC + w + 1w IN s.mem_domain /\
      state.REG RName_PC + w IN s.mem_domain`,
   rw [asmPropsTheory.sym_target_state_rel, arm6_ok_def, arm6_target_def,
       arm6_config_def, asmSemTheory.bytes_in_memory_def]
   \\ rfs []
   )

val arm_op2 = HolKernel.syntax_fns2 "arm"

local
   val bool1 = utilsLib.rhsc o blastLib.BBLAST_CONV o fcpSyntax.mk_fcp_index
   fun boolify n tm =
      List.tabulate (n, fn i => bool1 (tm, numLib.term_of_int (n - 1 - i)))
   val bytes = List.concat o List.rev o List.map (boolify 8)
   val step6 = arm_stepLib.arm_eval "v6"
   fun step state x l =
      let
         val v = listSyntax.mk_list (bytes l, Type.bool)
      in
         (Q.INST [`s` |-> state] o Drule.DISCH_ALL o step6) (x, v)
      end
   val (_, _, dest_DecodeARM, is_DecodeARM) = arm_op2 "DecodeARM"
   val is_arm6_next = #4 (HolKernel.syntax_fns1 "arm6_target" "arm6_next")
   val arm6_next =
     Drule.GEN_ALL (Thm.AP_THM arm6_targetTheory.arm6_next_def ``s:arm_state``)
   val i_tm = ``R_mode ms.CPSR.M (n2w i)``
   fun fail_if_vacuous_tac gs =
     (if List.hd (fst gs) = boolSyntax.T then NO_TAC else all_tac) gs
   fun next_state_tac0 step_list (asl, g) =
     (let
         val x as (pc, l, _, _) =
            List.last
              (List.mapPartial (Lib.total asmLib.dest_bytes_in_memory) asl)
         val x_tm = asmLib.mk_bytes_in_memory x
         val l = fst (listSyntax.dest_list l)
         val th = case Lib.total wordsSyntax.dest_word_add pc of
                     SOME (_, w) => Thm.SPEC w bytes_in_memory_thm2
                   | NONE => bytes_in_memory_thm
         val (tac, the_state) =
            case asmLib.find_env is_arm6_next g of
               SOME (t, tm) =>
                 let
                    val etm = ``env ^t ^tm : arm_state``
                    val r = utilsLib.rhsc (SIMP_CONV (srw_ss()) [] ``^tm.REG``)
                 in
                    (`(!a. a IN s1.mem_domain ==> ((^etm).MEM a = ms.MEM a)) /\
                      !i. (^etm).REG ^i_tm = ^r ^i_tm`
                     by (qpat_x_assum `!i:num s:arm_state. P`
                           (fn th =>
                              strip_assume_tac
                                 (SIMP_RULE (srw_ss())
                                    [set_sepTheory.fun2set_eq]
                                    (Q.SPECL [`^t`, `^tm`] th))
                              \\ assume_tac th)
                         \\ fs [DISCH_ALL arm_stepTheory.R_x_not_pc,
                                combinTheory.UPDATE_APPLY]),
                     etm)
                 end
             | NONE => (all_tac, ``ms:arm_state``)
         val step_thm = step `^the_state` step_list l
      in
         imp_res_tac th
         \\ tac
         \\ assume_tac step_thm
         \\ NO_STRIP_REV_FULL_SIMP_TAC (srw_ss())
              [lem1, lem2, lem3, lem4, lem7, decode_imm12_thm,
               decode_imm_thm, alignmentTheory.aligned_0,
               alignmentTheory.aligned_numeric,
               combinTheory.UPDATE_APPLY, combinTheory.UPDATE_EQ]
         \\ fail_if_vacuous_tac
         \\ Tactical.PAT_X_ASSUM x_tm kall_tac
         \\ SUBST1_TAC (Thm.SPEC the_state arm6_next)
         \\ asmLib.byte_eq_tac
         \\ NO_STRIP_REV_FULL_SIMP_TAC (srw_ss())
               [alignmentTheory.aligned_0, alignmentTheory.aligned_numeric,
                Once boolTheory.LET_THM, loc_lem]
         \\ TRY (Q.PAT_X_ASSUM `NextStateARM qq = qqq` kall_tac)
      end
      handle List.Empty => FAIL_TAC "next_state_tac: empty") (asl, g)
in
   val next_state_tac =
     next_state_tac0 [true]
     ORELSE next_state_tac0 [true, false]
     ORELSE next_state_tac0 [false, true]
end

val adc_lem1 = Q.prove(
  `!r2 r3 : word32 r4 : word32.
      CARRY_OUT r2 r3 (CARRY_OUT r4 (-1w) T) <=>
      4294967296 <= w2n r2 + (w2n r3 + 1)`,
  rw [wordsTheory.add_with_carry_def]
)

val adc_lem2 = Q.prove(
  `!r2 r3 : word32 r4 : word32.
      FST (add_with_carry (r2,r3,CARRY_OUT r4 (-1w) T)) =
      n2w (w2n r2 + (w2n r3 + 1))`,
  rw [wordsTheory.add_with_carry_def]
)

val adc_lem3 = Q.prove(
  `!r2 r3 : word32. CARRY_OUT r2 r3 F <=> 4294967296 <= w2n r2 + w2n r3`,
  rw [wordsTheory.add_with_carry_def]
)

val adc_lem4 = Q.prove(
  `!r2 r3 : word32. FST (add_with_carry (r2,r3,F)) = n2w (w2n r2 + w2n r3)`,
  rw [wordsTheory.add_with_carry_def]
)

local
   val i_tm = ``R_mode ms.CPSR.M (n2w i)``
   val reg_tac =
      asmLib.env_tac
        (fn (t, s) =>
           let
              val r = utilsLib.rhsc (SIMP_CONV (srw_ss()) [] ``^s.REG``)
           in
              (``!i. (env ^t ^s).REG ^i_tm = ^r ^i_tm``,
               qpat_x_assum `!i:num s:arm_state. P`
                  (fn th =>
                     strip_assume_tac
                        (SIMP_RULE (srw_ss()) [] (Q.SPECL [`^t`, `^s`] th))
                     \\ assume_tac th)
               \\ fs [DISCH_ALL arm_stepTheory.R_x_not_pc,
                      combinTheory.UPDATE_APPLY]
              )
           end)
in
   val state_tac =
      NO_STRIP_FULL_SIMP_TAC (srw_ss())
         [asmPropsTheory.sym_target_state_rel, arm6_target_def,
          asmPropsTheory.all_pcs, arm6_ok_def, arm6_config,
          combinTheory.APPLY_UPDATE_THM, alignmentTheory.aligned_numeric,
          alignmentTheory.align_aligned, set_sepTheory.fun2set_eq,
          integer_wordTheory.overflow_add,
          SIMP_RULE (srw_ss()) [] integer_wordTheory.overflow_sub]
      \\ NO_STRIP_REV_FULL_SIMP_TAC (srw_ss()) []
      \\ REPEAT strip_tac
      \\ reg_tac
      \\ fs [DISCH_ALL arm_stepTheory.R_x_not_pc, combinTheory.UPDATE_APPLY,
             lem1, lem2, lem3, adc_lem2, adc_lem4,
             mul_long_lem1, mul_long_lem2, GSYM wordsTheory.word_mul_def,
             alignmentTheory.align_aligned]
      \\ srw_tac []
            [combinTheory.APPLY_UPDATE_THM, alignmentTheory.aligned_numeric,
             updateTheory.APPLY_UPDATE_ID, arm_stepTheory.R_mode_11, lem1,
             decode_some_encode_immediate]
      \\ fs [adc_lem1, adc_lem3]
end

local
   fun number_of_instructions asl =
      case asmLib.strip_bytes_in_memory (List.last asl) of
         SOME l => List.length l div 4
       | NONE => raise ERR "number_of_instructions" ""
   fun can_match t = Lib.can (Term.match_term t)
   fun next_tac' asm (gs as (asl, _)) =
      let
         val j = number_of_instructions asl
         val i = j - 1
         val has_branch = asmLib.isConst asm andalso j = 3
         val neg_mem = asmLib.isMem asm andalso boolSyntax.is_neg (hd asl)
         val j = if has_branch then 2 else j
         val n = numLib.term_of_int (j - 1)
      in
         exists_tac n
         \\ simp_tac (srw_ss()++boolSimps.CONJ_ss)
              [asmPropsTheory.asserts_eval, reg_mode_eq,
               asmPropsTheory.interference_ok_def, arm6_proj_def]
         \\ NTAC 2 strip_tac
         \\ NTAC i (split_bytes_in_memory_tac 4)
         \\ (if neg_mem then
               qabbrev_tac `d = -1w * c`
               \\ imp_res_tac decode_neg_imm12_thm
             else if asmLib.isJumpCmp asm then
               qabbrev_tac `r = c0 + 0xFFFFFFF4w`
             else if asmLib.isJumpReg asm then
               `~word_bit 1 (ms.REG (R_mode ms.CPSR.M (n2w n))) /\
                ~word_bit 0 (ms.REG (R_mode ms.CPSR.M (n2w n)))`
               by utilsLib.qm_tac [lem11, lem12]
             else all_tac
             )
         \\ NTAC j next_state_tac
         \\ (if has_branch then imp_res_tac bytes_in_memory_thm2 else all_tac)
      end gs
   val (_, _, dest_arm6_enc, is_arm6_enc) =
     HolKernel.syntax_fns1 "arm6_target" "arm6_enc"
   fun get_asm tm = dest_arm6_enc (HolKernel.find_term is_arm6_enc tm)
in
   fun next_tac gs =
     let
       val asm = get_asm (snd gs)
     in
       Q.PAT_ABBREV_TAC `instr = arm6_enc _`
       \\ pop_assum mp_tac
       \\ NO_STRIP_FULL_SIMP_TAC (srw_ss()++boolSimps.LET_ss) enc_rwts
       \\ strip_tac
       \\ qunabbrev_tac `instr`
       \\ NO_STRIP_FULL_SIMP_TAC (srw_ss()) []
       \\ next_tac' asm
       \\ state_tac
     end gs
   val cnext_tac =
      next_tac
      \\ srw_tac [wordsLib.WORD_EXTRACT_ss] []
      \\ full_simp_tac (srw_ss()++wordsLib.WORD_CANCEL_ss) []
end

local
  fun r n = ``ms.REG (R_mode ms.CPSR.M (n2w ^n))``
  val n = r ``n:num``
  val n' = r ``n':num``
  fun tacs imm =
    let
      val l =
        [
         (* Equal *)
         Cases_on `q = 0w`,
         (* Lower *)
         Cases_on `FST (SND p)`,
         (* Less *)
         Cases_on `word_bit 31 q = SND (SND p)`,
         (* Test *)
         (if imm
            then Cases_on `(^n && c') = 0w`
          else Cases_on `(^n && ^n') = 0w`)
        ]
    in
      l @ l
    end
  val rwts =
    [Q.SPEC `F` markerTheory.Abbrev_def,
     blastLib.BBLAST_PROVE ``a <> b ==> (0w <> a + -1w * b: word32)``,
     blastLib.BBLAST_PROVE ``a <> b ==> (0w <> -1w * b + a: word32)``,
     word_lo_not_carry, word_lt_n_eq_v]
in
  fun cmp_tac imm =
    Cases_on `c`
    \\ (if imm then
          qabbrev_tac `p = add_with_carry (^n, ~c',T)`
          \\ qabbrev_tac `q = (-1w * c' + ^n)`
        else
          qabbrev_tac `p = add_with_carry (^n, ~^n',T)`
          \\ qabbrev_tac `q = (^n + -1w * ^n')`)
    >| tacs imm
    \\ next_tac
    \\ TRY (qunabbrev_tac `p`)
    \\ simp []
    \\ imp_res_tac lem16
    \\ fs rwts
    \\ TRY (qunabbrev_tac `r`)
    \\ TRY (qunabbrev_tac `q`)
    \\ fs [lem7, alignmentTheory.aligned_numeric,
           alignmentTheory.aligned_add_sub, aligned_add]
end

(* -------------------------------------------------------------------------
   arm6 target_ok
   ------------------------------------------------------------------------- *)

val length_arm6_encode1 = Q.prove(
  `!c i. LENGTH (arm6_encode1 c i) = 4`,
  Cases
  \\ rw [arm6_encode_def, arm6_encode1_def, arm6_encode_fail_def]
  \\ CASE_TAC
  \\ simp []
  )

val length_arm6_encode = Q.prove(
  `!l. LENGTH (arm6_encode l) = 4 * LENGTH l`,
  Induct >- rw [arm6_encode_def]
  \\ Cases
  \\ rw [arm6_encode_def, length_arm6_encode1]
  \\ fs [arm6_encode_def]
  )

val arm6_encode_not_nil = Q.prove(
  `(!c i. arm6_encode1 c i <> []) /\ (!l. (arm6_encode l <> []) = (l <> []))`,
  simp_tac std_ss
    [GSYM listTheory.LENGTH_NIL, length_arm6_encode1, length_arm6_encode])

val arm6_encoding = Q.prove (
   `!i. let l = arm6_enc i in (LENGTH l MOD 4 = 0) /\ l <> []`,
   strip_tac
   \\ asmLib.asm_cases_tac `i`
   \\ simp [arm6_enc_def, arm6_cmp_def, arm6_encode_fail_def,
            length_arm6_encode1, length_arm6_encode]
   \\ REPEAT CASE_TAC
   \\ rw [length_arm6_encode, length_arm6_encode1, arm6_encode_not_nil]
   )
   |> SIMP_RULE (bool_ss++boolSimps.LET_ss) []

val arm6_target_ok = Q.prove (
   `target_ok arm6_target`,
   rw ([asmPropsTheory.target_ok_def, asmPropsTheory.target_state_rel_def,
        arm6_proj_def, arm6_target_def, arm6_config, arm6_ok_def,
        set_sepTheory.fun2set_eq, arm6_encoding] @ enc_ok_rwts)
   \\ rfs [reg_mode_eq]
   >| [all_tac, Cases_on `ri` \\ Cases_on `cmp`, all_tac, all_tac]
   \\ lfs enc_rwts
   \\ NTAC 3 (rw [Once valid_immediate2])
   \\ blastLib.FULL_BBLAST_TAC
   )

(* -------------------------------------------------------------------------
   arm6 backend_correct
   ------------------------------------------------------------------------- *)

val print_tac = asmLib.print_tac "correct"

val arm6_backend_correct = Q.store_thm ("arm6_backend_correct",
   `backend_correct arm6_target`,
   simp [asmPropsTheory.backend_correct_def, arm6_target_ok]
   \\ qabbrev_tac `state_rel = target_state_rel arm6_target`
   \\ rw [arm6_target_def, arm6_config, asmSemTheory.asm_step_def]
   \\ qunabbrev_tac `state_rel`
   \\ Cases_on `i`
   >- (
      (*--------------
          Inst
        --------------*)
      Cases_on `i'`
      >- (
         (*--------------
             Skip
           --------------*)
         print_tac "Skip"
         \\ next_tac
         )
      >- (
         (*--------------
             Const
           --------------*)
         print_tac "Const"
         \\ REVERSE (Cases_on `EncodeARMImmediate c`)
         >- next_tac
         \\ REVERSE (Cases_on `EncodeARMImmediate ~c`)
         >- (next_tac
             \\ imp_res_tac decode_some_encode_neg_immediate
             \\ simp [])
         \\ cnext_tac
         )
      >- (
         (*--------------
             Arith
           --------------*)
         Cases_on `a`
         >- (
            (*--------------
                Binop
              --------------*)
            print_tac "Binop"
            \\ Cases_on `r`
            >- (Cases_on `b` \\ next_tac)
            \\ Cases_on `(b = Xor) /\ (c = -1w)`
            >- next_tac
            \\ Cases_on `b`
            \\ next_tac
            )
         >- (
            (*--------------
                Shift
              --------------*)
            print_tac "Shift"
            \\ Cases_on `s`
            \\ next_tac
            )
         >- (
            (*--------------
                Div
              --------------*)
            print_tac "Div"
            \\ next_tac
            )
         >- (
            (*--------------
                LongMul
              --------------*)
            print_tac "LongMul"
            \\ next_tac
            )
         >- (
            (*--------------
                LongDiv
              --------------*)
            print_tac "LongDiv"
            \\ next_tac
            )
         >- (
            (*--------------
                AddCarry
              --------------*)
            print_tac "AddCarry"
            \\ qabbrev_tac `r1 = ms.REG (R_mode ms.CPSR.M (n2w n))`
            \\ qabbrev_tac `r2 = ms.REG (R_mode ms.CPSR.M (n2w n0))`
            \\ qabbrev_tac `r3 = ms.REG (R_mode ms.CPSR.M (n2w n1))`
            \\ qabbrev_tac `r4 = ms.REG (R_mode ms.CPSR.M (n2w n2))`
            \\ Cases_on `r4 = 0w`
            >| [
               Cases_on `CARRY_OUT r2 r3 F`,
               Cases_on `CARRY_OUT r2 r3 (CARRY_OUT r4 (-1w) T)`
            ]
            \\ next_tac
            )
         >- (
            (*--------------
                AddOverflow
              --------------*)
            print_tac "AddOverflow"
            \\ qabbrev_tac `r1 = ms.REG (R_mode ms.CPSR.M (n2w n))`
            \\ qabbrev_tac `r2 = ms.REG (R_mode ms.CPSR.M (n2w n0))`
            \\ qabbrev_tac `r3 = ms.REG (R_mode ms.CPSR.M (n2w n1))`
            \\ qabbrev_tac `r4 = ms.REG (R_mode ms.CPSR.M (n2w n2))`
            \\ Cases_on `OVERFLOW r2 r3 F`
            \\ next_tac
            )
         >- (
            (*--------------
                SubOverflow
              --------------*)
            print_tac "SubOverflow"
            \\ qabbrev_tac `r1 = ms.REG (R_mode ms.CPSR.M (n2w n))`
            \\ qabbrev_tac `r2 = ms.REG (R_mode ms.CPSR.M (n2w n0))`
            \\ qabbrev_tac `r3 = ms.REG (R_mode ms.CPSR.M (n2w n1))`
            \\ qabbrev_tac `r4 = ms.REG (R_mode ms.CPSR.M (n2w n2))`
            \\ Cases_on `OVERFLOW r2 (~r3) T`
            \\ next_tac
            )
         )
         (*--------------
             Mem
           --------------*)
         \\ print_tac "Mem"
         \\ Cases_on `a`
         \\ Cases_on `m`
         \\ Cases_on `0w <= c`
         \\ cnext_tac
      ) (* close Inst *)
      (*--------------
          Jump
        --------------*)
   >- (
      print_tac "Jump"
      \\ qabbrev_tac `a = (25 >< 2) (c + 0xFFFFFFF8w): word24`
      \\ next_tac
      \\ imp_res_tac lem15
      \\ simp [lem7, alignmentTheory.aligned_add_sub, aligned_add]
      )
   >- (
      (*--------------
          JumpCmp
        --------------*)
      print_tac "JumpCmp"
      \\ Cases_on `r`
      >- cmp_tac false
      \\ cmp_tac true
      )
      (*--------------
          Call
        --------------*)
   >- (
      print_tac "Call"
      \\ qabbrev_tac `a = (25 >< 2) (c + 0xFFFFFFF8w): word24`
      \\ next_tac
      \\ imp_res_tac lem9
      \\ imp_res_tac lem10
      \\ simp [alignmentTheory.aligned_numeric, alignmentTheory.aligned_add_sub,
               aligned_add]
      )
   >- (
      (*--------------
          JumpReg
        --------------*)
      print_tac "JumpReg"
      \\ next_tac
      )
   >- (
      (*--------------
          Loc
        --------------*)
      print_tac "Loc"
      \\ Cases_on `8w <= c`
      >| [Cases_on `(31 >< 24) (c + 0xFFFFFFF8w) <> 0w : word8`
          >| [all_tac,
              Cases_on `(23 >< 16) (c + 0xFFFFFFF8w) <> 0w : word8`
              >| [all_tac,
                  Cases_on `(15 >< 8) (c + 0xFFFFFFF8w) <> 0w : word8`
              ]
          ],
          Cases_on `(31 >< 24) (-1w * c + 8w) <> 0w : word8`
          >| [all_tac,
              Cases_on `(23 >< 16) (-1w * c + 8w) <> 0w : word8`
              >| [all_tac,
                  Cases_on `(15 >< 8) (-1w * c + 8w) <> 0w : word8`
              ]
          ]
      ]
      \\ next_tac
      \\ rfs [alignmentTheory.align_aligned, alignmentTheory.aligned_numeric]
      \\ rw [combinTheory.APPLY_UPDATE_THM, alignmentTheory.aligned_numeric,
             updateTheory.APPLY_UPDATE_ID, arm_stepTheory.R_mode_11, lem1]
      \\ blastLib.FULL_BBLAST_TAC
      )
   )

val () = export_theory ()

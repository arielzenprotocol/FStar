open Prims
let module_or_interface_name:
  FStar_Syntax_Syntax.modul -> (Prims.bool* FStar_Ident.lident) =
  fun m  ->
    ((m.FStar_Syntax_Syntax.is_interface), (m.FStar_Syntax_Syntax.name))
let parse:
  FStar_ToSyntax_Env.env ->
    Prims.string Prims.option ->
      Prims.string ->
        (FStar_ToSyntax_Env.env* FStar_Syntax_Syntax.modul Prims.list)
  =
  fun env  ->
    fun pre_fn  ->
      fun fn  ->
        let uu____23 = FStar_Parser_Driver.parse_file fn in
        match uu____23 with
        | (ast,uu____33) ->
            let ast =
              match pre_fn with
              | None  -> ast
              | Some pre_fn ->
                  let uu____42 = FStar_Parser_Driver.parse_file pre_fn in
                  (match uu____42 with
                   | (pre_ast,uu____49) ->
                       (match (pre_ast, ast) with
                        | ((FStar_Parser_AST.Interface
                           (lid1,decls1,uu____58))::[],(FStar_Parser_AST.Module
                           (lid2,decls2))::[]) when
                            FStar_Ident.lid_equals lid1 lid2 ->
                            let _0_806 =
                              FStar_Parser_AST.Module
                                (let _0_805 =
                                   FStar_Parser_Interleave.interleave decls1
                                     decls2 in
                                 (lid1, _0_805)) in
                            [_0_806]
                        | uu____68 ->
                            Prims.raise
                              (FStar_Errors.Err
                                 "mismatch between pre-module and module\n"))) in
            FStar_ToSyntax_ToSyntax.desugar_file env ast
let tc_prims:
  Prims.unit ->
    ((FStar_Syntax_Syntax.modul* Prims.int)* FStar_ToSyntax_Env.env*
      FStar_TypeChecker_Env.env)
  =
  fun uu____78  ->
    let solver =
      let uu____85 = FStar_Options.lax () in
      if uu____85
      then FStar_SMTEncoding_Solver.dummy
      else FStar_SMTEncoding_Solver.solver in
    let env =
      FStar_TypeChecker_Env.initial_env
        FStar_TypeChecker_TcTerm.type_of_tot_term
        FStar_TypeChecker_TcTerm.universe_of solver
        FStar_Syntax_Const.prims_lid in
    (env.FStar_TypeChecker_Env.solver).FStar_TypeChecker_Env.init env;
    (let prims_filename = FStar_Options.prims () in
     let uu____90 =
       let _0_807 = FStar_ToSyntax_Env.empty_env () in
       parse _0_807 None prims_filename in
     match uu____90 with
     | (dsenv,prims_mod) ->
         let uu____103 =
           FStar_Util.record_time
             (fun uu____110  ->
                let _0_808 = FStar_List.hd prims_mod in
                FStar_TypeChecker_Tc.check_module env _0_808) in
         (match uu____103 with
          | ((prims_mod,env),elapsed_time) ->
              ((prims_mod, elapsed_time), dsenv, env)))
let tc_one_fragment:
  FStar_Syntax_Syntax.modul Prims.option ->
    FStar_ToSyntax_Env.env ->
      FStar_TypeChecker_Env.env ->
        FStar_Parser_ParseIt.input_frag ->
          (FStar_Syntax_Syntax.modul Prims.option* FStar_ToSyntax_Env.env*
            FStar_TypeChecker_Env.env) Prims.option
  =
  fun curmod  ->
    fun dsenv  ->
      fun env  ->
        fun frag  ->
          try
            let uu____153 = FStar_Parser_Driver.parse_fragment frag in
            match uu____153 with
            | FStar_Parser_Driver.Empty  -> Some (curmod, dsenv, env)
            | FStar_Parser_Driver.Modul ast_modul ->
                let uu____165 =
                  FStar_ToSyntax_ToSyntax.desugar_partial_modul curmod dsenv
                    ast_modul in
                (match uu____165 with
                 | (dsenv,modul) ->
                     let env =
                       match curmod with
                       | Some modul ->
                           let uu____177 =
                             let _0_810 =
                               FStar_Parser_Dep.lowercase_module_name
                                 (FStar_List.hd (FStar_Options.file_list ())) in
                             let _0_809 =
                               FStar_String.lowercase
                                 (FStar_Ident.string_of_lid
                                    modul.FStar_Syntax_Syntax.name) in
                             _0_810 <> _0_809 in
                           if uu____177
                           then
                             Prims.raise
                               (FStar_Errors.Err
                                  "Interactive mode only supports a single module at the top-level")
                           else env
                       | None  -> env in
                     let uu____179 =
                       FStar_TypeChecker_Tc.tc_partial_modul env modul in
                     (match uu____179 with
                      | (modul,uu____190,env) ->
                          Some ((Some modul), dsenv, env)))
            | FStar_Parser_Driver.Decls ast_decls ->
                let uu____201 =
                  FStar_ToSyntax_ToSyntax.desugar_decls dsenv ast_decls in
                (match uu____201 with
                 | (dsenv,decls) ->
                     (match curmod with
                      | None  ->
                          (FStar_Util.print_error
                             "fragment without an enclosing module";
                           FStar_All.exit (Prims.parse_int "1"))
                      | Some modul ->
                          let uu____223 =
                            FStar_TypeChecker_Tc.tc_more_partial_modul env
                              modul decls in
                          (match uu____223 with
                           | (modul,uu____234,env) ->
                               Some ((Some modul), dsenv, env))))
          with
          | FStar_Errors.Error (msg,r) when
              Prims.op_Negation (FStar_Options.trace_error ()) ->
              (FStar_TypeChecker_Err.add_errors env [(msg, r)]; None)
          | FStar_Errors.Err msg when
              Prims.op_Negation (FStar_Options.trace_error ()) ->
              (FStar_TypeChecker_Err.add_errors env
                 [(msg, FStar_Range.dummyRange)];
               None)
          | e when Prims.op_Negation (FStar_Options.trace_error ()) ->
              Prims.raise e
let tc_one_file:
  FStar_ToSyntax_Env.env ->
    FStar_TypeChecker_Env.env ->
      Prims.string Prims.option ->
        Prims.string ->
          ((FStar_Syntax_Syntax.modul* Prims.int) Prims.list*
            FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env)
  =
  fun dsenv  ->
    fun env  ->
      fun pre_fn  ->
        fun fn  ->
          let uu____302 = parse dsenv pre_fn fn in
          match uu____302 with
          | (dsenv,fmods) ->
              let check_mods uu____325 =
                let uu____326 =
                  FStar_All.pipe_right fmods
                    (FStar_List.fold_left
                       (fun uu____343  ->
                          fun m  ->
                            match uu____343 with
                            | (env,all_mods) ->
                                let uu____363 =
                                  FStar_Util.record_time
                                    (fun uu____370  ->
                                       FStar_TypeChecker_Tc.check_module env
                                         m) in
                                (match uu____363 with
                                 | ((m,env),elapsed_ms) ->
                                     (env, ((m, elapsed_ms) :: all_mods))))
                       (env, [])) in
                match uu____326 with
                | (env,all_mods) -> ((FStar_List.rev all_mods), dsenv, env) in
              (match fmods with
               | m::[] when
                   (FStar_Options.should_verify
                      (m.FStar_Syntax_Syntax.name).FStar_Ident.str)
                     &&
                     ((FStar_Options.record_hints ()) ||
                        (FStar_Options.use_hints ()))
                   ->
                   let _0_811 = FStar_Parser_ParseIt.find_file fn in
                   FStar_SMTEncoding_Solver.with_hints_db _0_811 check_mods
               | uu____423 -> check_mods ())
let needs_interleaving: Prims.string -> Prims.string -> Prims.bool =
  fun intf  ->
    fun impl  ->
      let m1 = FStar_Parser_Dep.lowercase_module_name intf in
      let m2 = FStar_Parser_Dep.lowercase_module_name impl in
      ((m1 = m2) &&
         (let _0_812 = FStar_Util.get_file_extension intf in _0_812 = "fsti"))
        &&
        (let _0_813 = FStar_Util.get_file_extension impl in _0_813 = "fst")
let pop_context: FStar_TypeChecker_Env.env -> Prims.string -> Prims.unit =
  fun env  ->
    fun msg  ->
      (let _0_814 = FStar_ToSyntax_Env.pop () in
       FStar_All.pipe_right _0_814 Prims.ignore);
      (let _0_815 = FStar_TypeChecker_Env.pop env msg in
       FStar_All.pipe_right _0_815 Prims.ignore);
      (env.FStar_TypeChecker_Env.solver).FStar_TypeChecker_Env.refresh ()
let push_context:
  (FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env) ->
    Prims.string -> (FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env)
  =
  fun uu____449  ->
    fun msg  ->
      match uu____449 with
      | (dsenv,env) ->
          let dsenv = FStar_ToSyntax_Env.push dsenv in
          let env = FStar_TypeChecker_Env.push env msg in (dsenv, env)
let tc_one_file_and_intf:
  Prims.string Prims.option ->
    Prims.string ->
      FStar_ToSyntax_Env.env ->
        FStar_TypeChecker_Env.env ->
          ((FStar_Syntax_Syntax.modul* Prims.int) Prims.list*
            FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env)
  =
  fun intf  ->
    fun impl  ->
      fun dsenv  ->
        fun env  ->
          FStar_Syntax_Syntax.reset_gensym ();
          (match intf with
           | None  -> tc_one_file dsenv env None impl
           | Some uu____486 when
               let _0_816 = FStar_Options.codegen () in _0_816 <> None ->
               ((let uu____489 = Prims.op_Negation (FStar_Options.lax ()) in
                 if uu____489
                 then
                   Prims.raise
                     (FStar_Errors.Err
                        "Verification and code generation are no supported together with partial modules (i.e, *.fsti); use --lax to extract code separately")
                 else ());
                tc_one_file dsenv env intf impl)
           | Some iname ->
               ((let uu____493 = FStar_Options.debug_any () in
                 if uu____493
                 then
                   FStar_Util.print1 "Interleaving iface+module: %s\n" iname
                 else ());
                (let caption = Prims.strcat "interface: " iname in
                 let uu____496 = push_context (dsenv, env) caption in
                 match uu____496 with
                 | (dsenv',env') ->
                     let uu____507 = tc_one_file dsenv' env' intf impl in
                     (match uu____507 with
                      | (uu____520,dsenv',env') ->
                          (pop_context env' caption;
                           tc_one_file dsenv env None iname)))))
type uenv = (FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env)
let tc_one_file_from_remaining:
  Prims.string Prims.list ->
    uenv ->
      (Prims.string Prims.list* (FStar_Syntax_Syntax.modul* Prims.int)
        Prims.list* (FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env))
  =
  fun remaining  ->
    fun uenv  ->
      let uu____549 = uenv in
      match uu____549 with
      | (dsenv,env) ->
          let uu____561 =
            match remaining with
            | intf::impl::remaining when needs_interleaving intf impl ->
                let _0_817 = tc_one_file_and_intf (Some intf) impl dsenv env in
                (remaining, _0_817)
            | intf_or_impl::remaining ->
                let _0_818 = tc_one_file_and_intf None intf_or_impl dsenv env in
                (remaining, _0_818)
            | [] -> ([], ([], dsenv, env)) in
          (match uu____561 with
           | (remaining,(nmods,dsenv,env)) ->
               (remaining, nmods, (dsenv, env)))
let rec tc_fold_interleave:
  ((FStar_Syntax_Syntax.modul* Prims.int) Prims.list* uenv) ->
    Prims.string Prims.list ->
      ((FStar_Syntax_Syntax.modul* Prims.int) Prims.list* uenv)
  =
  fun acc  ->
    fun remaining  ->
      match remaining with
      | [] -> acc
      | uu____674 ->
          let uu____676 = acc in
          (match uu____676 with
           | (mods,uenv) ->
               let uu____695 = tc_one_file_from_remaining remaining uenv in
               (match uu____695 with
                | (remaining,nmods,(dsenv,env)) ->
                    tc_fold_interleave
                      ((FStar_List.append mods nmods), (dsenv, env))
                      remaining))
let batch_mode_tc_no_prims:
  FStar_ToSyntax_Env.env ->
    FStar_TypeChecker_Env.env ->
      Prims.string Prims.list ->
        ((FStar_Syntax_Syntax.modul* Prims.int) Prims.list*
          FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env)
  =
  fun dsenv  ->
    fun env  ->
      fun filenames  ->
        let uu____748 = tc_fold_interleave ([], (dsenv, env)) filenames in
        match uu____748 with
        | (all_mods,(dsenv,env)) ->
            ((let uu____779 =
                (FStar_Options.interactive ()) &&
                  (let _0_819 = FStar_Errors.get_err_count () in
                   _0_819 = (Prims.parse_int "0")) in
              if uu____779
              then
                (env.FStar_TypeChecker_Env.solver).FStar_TypeChecker_Env.refresh
                  ()
              else
                (env.FStar_TypeChecker_Env.solver).FStar_TypeChecker_Env.finish
                  ());
             (all_mods, dsenv, env))
let batch_mode_tc:
  Prims.string Prims.list ->
    ((FStar_Syntax_Syntax.modul* Prims.int) Prims.list*
      FStar_ToSyntax_Env.env* FStar_TypeChecker_Env.env)
  =
  fun filenames  ->
    let uu____795 = tc_prims () in
    match uu____795 with
    | (prims_mod,dsenv,env) ->
        ((let uu____815 =
            (Prims.op_Negation (FStar_Options.explicit_deps ())) &&
              (FStar_Options.debug_any ()) in
          if uu____815
          then
            (FStar_Util.print_endline
               "Auto-deps kicked in; here's some info.";
             FStar_Util.print1
               "Here's the list of filenames we will process: %s\n"
               (FStar_String.concat " " filenames);
             (let _0_821 =
                let _0_820 = FStar_Options.verify_module () in
                FStar_String.concat " " _0_820 in
              FStar_Util.print1
                "Here's the list of modules we will verify: %s\n" _0_821))
          else ());
         (let uu____819 = batch_mode_tc_no_prims dsenv env filenames in
          match uu____819 with
          | (all_mods,dsenv,env) -> ((prims_mod :: all_mods), dsenv, env)))
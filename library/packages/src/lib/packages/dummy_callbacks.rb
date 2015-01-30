require "yast"

module Packages
  class DummyCallbacks
    class << self
      include Yast::Logger

      def register
        Yast.import "Pkg"

        SetdummyProcessCallbacks()
        SetdummyProvideCallbacks()
        SetdummyPatchCallbacks()
        SetdummySourceCreateCallbacks()
        SetdummySourceReportCallbacks()
        SetdummyProgressReportCallbacks()
        SetdummyScriptCallbacks()
        SetdummyScanDBCallbacks()
        SetdummyDownloadCallbacks()
      end

    private
      def fun_ref(*args)
        Yast::FunRef.new(*args)
      end

      def dummy_process_start(_param1, _param2, _param3)
        log.debug "Empty ProcessStart callback"
      end

      def dummy_boolean_integer(_param1)
        log.debug "Empty generic boolean(integer)->true callback"

        true
      end

      def dummy_string_string(_param1)
        log.debug "Empty generic string(string)->\"\" callback"
        ""
      end

      def dummy_void
        log.debug "Empty generic void() callback"
      end

      def SetdummyProcessCallbacks
        Yast::Pkg.CallbackProcessStart(
            fun_ref(
              method(:dummy_process_start),
              "void (string, list <string>, string)"
              )
            )
        Yast::Pkg.CallbackProcessProgress(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.CallbackProcessNextStage(fun_ref(method(:dummy_void), "void ()"))
        Yast::Pkg.CallbackProcess_done(fun_ref(method(:dummy_void), "void ()"))

        nil
      end

      def dummy_start_provide(_param1, _param2, _param3)
        log.debug "Empty StartProvide callback"

        nil
      end

      def dummy_done_provide(_error, _reason, _name)
        log.debug "Empty _doneProvide callback, returning 'I'"
        "I"
      end

      def dummy_start_package(_name, _location, _summary, _installsize, _is_delete)
        log.debug "Empty StartPackage callback"

        nil
      end

      def dummy_done_package(_error, _reason)
        log.debug "Empty _donePackage callback, returning 'I'"
        "I"
      end

      def SetdummyProvideCallbacks
        Yast::Pkg.CallbackStartProvide(
            fun_ref(method(:dummy_start_provide), "void (string, integer, boolean)")
            )
        Yast::Pkg.CallbackProgressProvide(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.Callback_doneProvide(
            fun_ref(method(:dummy_done_provide), "string (integer, string, string)")
            )
        Yast::Pkg.CallbackStartPackage(
            fun_ref(
              method(:dummy_start_package),
              "void (string, string, string, integer, boolean)"
              )
            )
        Yast::Pkg.CallbackProgressPackage(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.Callback_donePackage(
            fun_ref(method(:dummy_done_package), "string (integer, string)")
            )

        nil
      end

      def dummy_void_string(_param1)
        log.debug "Empty generic void(string) callback"

        nil
      end

      def dummy_void_integer(_param1)
        log.debug "Empty generic void(integer) callback"

        nil
      end

      def dummy_void_integer_string(_param1, _param2)
        log.debug "Empty generic void(integer, string) callback"

        nil
      end

      def dummy_void_string_integer(_param1, _param2)
        log.debug "Empty generic void(string, integer) callback"

        nil
      end

      def dummy_string_integer_string(_param1, _param2)
        log.debug "Empty generic string(integer, string) callback"
        ""
      end

      def SetdummyPatchCallbacks
        Yast::Pkg.CallbackStartDeltaDownload(
            fun_ref(method(:dummy_void_string_integer), "void (string, integer)")
            )
        Yast::Pkg.CallbackProgressDeltaDownload(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.CallbackProblemDeltaDownload(
            fun_ref(method(:dummy_void_string), "void (string)")
            )
        Yast::Pkg.CallbackFinishDeltaDownload(fun_ref(method(:dummy_void), "void ()"))

        Yast::Pkg.CallbackStartDeltaApply(
            fun_ref(method(:dummy_void_string), "void (string)")
            )
        Yast::Pkg.CallbackProgressDeltaApply(
            fun_ref(method(:dummy_void_integer), "void (integer)")
            )
        Yast::Pkg.CallbackProblemDeltaApply(
            fun_ref(method(:dummy_void_string), "void (string)")
            )
        Yast::Pkg.CallbackFinishDeltaApply(fun_ref(method(:dummy_void), "void ()"))

        nil
      end

      def dummy_source_create_error(_url, _error, _description)
        log.debug "Empty SourceCreateError callback, returning `ABORT"
        :ABORT
      end

      def dummy_source_create_end(_url, _error, _description)
        log.debug "Empty SourceCreateEnd callback"

        nil
      end

      def SetdummySourceCreateCallbacks
        Yast::Pkg.CallbackSourceCreateStart(
            fun_ref(method(:dummy_void_string), "void (string)")
            )
        Yast::Pkg.CallbackSourceCreateProgress(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.CallbackSourceCreateError(
            fun_ref(
              method(:dummy_source_create_error),
              "symbol (string, symbol, string)"
              )
            )
        Yast::Pkg.CallbackSourceCreateEnd(
            fun_ref(method(:dummy_source_create_end), "void (string, symbol, string)")
            )
        Yast::Pkg.CallbackSourceCreateInit(fun_ref(method(:dummy_void), "void ()"))
        Yast::Pkg.CallbackSourceCreateDestroy(fun_ref(method(:dummy_void), "void ()"))

        nil
      end

      def dummy_source_report_start(_source_id, _url, _task)
        log.debug "Empty SourceReportStart callback"

        nil
      end

      def dummy_source_report_error(_source_id, _url, _error, _description)
        log.debug "Empty SourceReportError callback, returning `ABORT"
        :ABORT
      end

      def dummy_source_report_end(_src_id, _url, _task, _error, _description)
        log.debug "Empty SourceReportEnd callback"

        nil
      end

      def SetdummySourceReportCallbacks
        # source report callbacks
        Yast::Pkg.CallbackSourceReportStart(
            fun_ref(
              method(:dummy_source_report_start),
              "void (integer, string, string)"
              )
            )
        Yast::Pkg.CallbackSourceReportProgress(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.CallbackSourceReportError(
            fun_ref(
              method(:dummy_source_report_error),
              "symbol (integer, string, symbol, string)"
              )
            )
        Yast::Pkg.CallbackSourceReportEnd(
            fun_ref(
              method(:dummy_source_report_end),
              "void (integer, string, string, symbol, string)"
              )
            )
        Yast::Pkg.CallbackSourceReportInit(fun_ref(method(:dummy_void), "void ()"))
        Yast::Pkg.CallbackSourceReportDestroy(fun_ref(method(:dummy_void), "void ()"))

        nil
      end

      def dummy_progress_start(_id, _task, _in_percent, _is_alive, _min, _max, _val_raw, _val_percent)
        log.debug "Empty ProgressStart callback"

        nil
      end

      def dummy_progress_progress(_id, _val_raw, _val_percent)
        log.debug "Empty ProgressProgress callback, returning true"
        true
      end

      def SetdummyProgressReportCallbacks
        Yast::Pkg.CallbackProgressReportStart(
            fun_ref(
              method(:dummy_progress_start),
              "void (integer, string, boolean, boolean, integer, integer, integer, integer)"
              )
            )
        Yast::Pkg.CallbackProgressReportProgress(
            fun_ref(
              method(:dummy_progress_progress),
              "boolean (integer, integer, integer)"
              )
            )
        Yast::Pkg.CallbackProgressReportEnd(
            fun_ref(method(:dummy_void_integer), "void (integer)")
            )

        nil
      end

      def dummy_script_start(_patch_name, _patch_version, _patch_arch, _script_path)
        log.debug "Empty ScriptStart callback"

        nil
      end

      def dummy_script_progress(_ping, _output)
        log.debug "Empty ScriptProgress callback, returning true"
        true
      end

      def dummy_message(_patch_name, _patch_version, _patch_arch, _message)
        log.debug "Empty Message callback"
        true # continue
      end

      def SetdummyScriptCallbacks
        Yast::Pkg.CallbackScriptStart(
            fun_ref(
              method(:dummy_script_start),
              "void (string, string, string, string)"
              )
            )
        Yast::Pkg.CallbackScriptProgress(
            fun_ref(method(:dummy_script_progress), "boolean (boolean, string)")
            )
        Yast::Pkg.CallbackScriptProblem(
            fun_ref(method(:dummy_string_string), "string (string)")
            )
        Yast::Pkg.CallbackScriptFinish(fun_ref(method(:dummy_void), "void ()"))

        Yast::Pkg.CallbackMessage(
            fun_ref(
              method(:dummy_message),
              "boolean (string, string, string, string)"
              )
            )

        nil
      end

      def SetdummyScanDBCallbacks
        Yast::Pkg.CallbackStartScanDb(fun_ref(method(:dummy_void), "void ()"))
        Yast::Pkg.CallbackProgressScanDb(
            fun_ref(method(:dummy_boolean_integer), "boolean (integer)")
            )
        Yast::Pkg.CallbackErrorScanDb(
            fun_ref(method(:dummy_string_integer_string), "string (integer, string)")
            )
        Yast::Pkg.CallbackDoneScanDb(
            fun_ref(method(:dummy_void_integer_string), "void (integer, string)")
            )

        nil
      end

      def dummy_start_download(_url, _localfile)
        log.debug "Empty StartDownload callback"

        nil
      end

      def dummy_progress_download(_percent, _bps_avg, _bps_current)
        log.debug "Empty ProgressDownload callback, returning true"
        true
      end

      def dummy_done_download(_error_value, _error_text)
        log.debug "Empty DoneDownload callback"

        nil
      end

      def SetdummyDownloadCallbacks
        Yast::Pkg.CallbackInitDownload(
            fun_ref(method(:dummy_void_string), "void (string)")
            )
        Yast::Pkg.CallbackStartDownload(
            fun_ref(method(:dummy_start_download), "void (string, string)")
            )
        Yast::Pkg.CallbackProgressDownload(
            fun_ref(
              method(:dummy_progress_download),
              "boolean (integer, integer, integer)"
              )
            )
        Yast::Pkg.CallbackDoneDownload(
            fun_ref(method(:dummy_done_download), "void (integer, string)")
            )
        Yast::Pkg.CallbackDestDownload(fun_ref(method(:dummy_void), "void ()"))
        Yast::Pkg.CallbackStartRefresh(fun_ref(method(:dummy_void), "void ()"))
        Yast::Pkg.CallbackDoneRefresh(fun_ref(method(:dummy_void), "void ()"))

        nil
      end

    end
  end
end

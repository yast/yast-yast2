require "yast"

module Packages
  # Empty callbacks for package bindings. To register empty bindings in Yast::Pkg just call
  # {Package::DummyCallbacks.register}
  class DummyCallbacks
    class << self
      include Yast::Logger

      def register
        Yast.import "Pkg"

        register_process_callbacks
        register_provide_callbacks
        register_patch_callbacks
        register_source_create_callbacks
        register_source_report_callbacks
        register_progress_report_callbacks
        register_script_callbacks
        register_scandb_callbacks
        register_download_callbacks
      end

    private

      def fun_ref(*args)
        Yast::FunRef.new(*args)
      end

      def process_start(_param1, _param2, _param3)
        log.debug "Empty ProcessStart callback"
      end

      def boolean_integer(_param1)
        log.debug "Empty generic boolean(integer)->true callback"

        true
      end

      def boolean_integer_ref
        fun_ref(method(:boolean_integer), "boolean (integer)")
      end

      def string_string(_param1)
        log.debug "Empty generic string(string)->\"\" callback"
        ""
      end

      def void
        log.debug "Empty generic void() callback"
      end

      def void_ref
        fun_ref(method(:void), "void ()")
      end

      def register_process_callbacks
        Yast::Pkg.CallbackProcessStart(
          fun_ref(
            method(:process_start),
            "void (string, list <string>, string)"
          )
        )
        Yast::Pkg.CallbackProcessProgress(boolean_integer_ref)
        Yast::Pkg.CallbackProcessNextStage(void_ref)
        Yast::Pkg.CallbackProcessDone(void_ref)

        nil
      end

      def start_provide(_param1, _param2, _param3)
        log.debug "Empty StartProvide callback"

        nil
      end

      def done_provide(_error, _reason, _name)
        log.debug "Empty _doneProvide callback, returning 'I'"
        "I"
      end

      def start_package(_name, _location, _summary, _installsize, _is_delete)
        log.debug "Empty StartPackage callback"

        nil
      end

      def done_package(_error, _reason)
        log.debug "Empty _donePackage callback, returning 'I'"
        "I"
      end

      def register_provide_callbacks
        Yast::Pkg.CallbackStartProvide(
          fun_ref(method(:start_provide), "void (string, integer, boolean)")
        )
        Yast::Pkg.CallbackProgressProvide(boolean_integer_ref)
        Yast::Pkg.CallbackDoneProvide(
          fun_ref(method(:done_provide), "string (integer, string, string)")
        )
        Yast::Pkg.CallbackStartPackage(
          fun_ref(
            method(:start_package),
            "void (string, string, string, integer, boolean)"
          )
        )
        Yast::Pkg.CallbackProgressPackage(boolean_integer_ref)
        Yast::Pkg.CallbackDonePackage(
          fun_ref(method(:done_package), "string (integer, string)")
        )

        nil
      end

      def void_string(_param1)
        log.debug "Empty generic void(string) callback"

        nil
      end

      def void_integer(_param1)
        log.debug "Empty generic void(integer) callback"

        nil
      end

      def void_integer_string(_param1, _param2)
        log.debug "Empty generic void(integer, string) callback"

        nil
      end

      def void_string_integer(_param1, _param2)
        log.debug "Empty generic void(string, integer) callback"

        nil
      end

      def void_string_ref
        fun_ref(method(:void_string), "void (string)")
      end

      def string_integer_string(_param1, _param2)
        log.debug "Empty generic string(integer, string) callback"
        ""
      end

      def register_patch_callbacks
        Yast::Pkg.CallbackStartDeltaDownload(
          fun_ref(method(:void_string_integer), "void (string, integer)")
        )
        Yast::Pkg.CallbackProgressDeltaDownload(boolean_integer_ref)
        Yast::Pkg.CallbackProblemDeltaDownload(void_string_ref)
        Yast::Pkg.CallbackFinishDeltaDownload(void_ref)

        Yast::Pkg.CallbackStartDeltaApply(void_string_ref)
        Yast::Pkg.CallbackProgressDeltaApply(
          fun_ref(method(:void_integer), "void (integer)")
        )
        Yast::Pkg.CallbackProblemDeltaApply(void_string_ref)
        Yast::Pkg.CallbackFinishDeltaApply(void_ref)

        nil
      end

      def source_create_error(_url, _error, _description)
        log.debug "Empty SourceCreateError callback, returning `ABORT"
        :ABORT
      end

      def source_create_end(_url, _error, _description)
        log.debug "Empty SourceCreateEnd callback"

        nil
      end

      def register_source_create_callbacks
        Yast::Pkg.CallbackSourceCreateStart(void_string_ref)
        Yast::Pkg.CallbackSourceCreateProgress(boolean_integer_ref)
        Yast::Pkg.CallbackSourceCreateError(
          fun_ref(
            method(:source_create_error),
            "symbol (string, symbol, string)"
          )
        )
        Yast::Pkg.CallbackSourceCreateEnd(
          fun_ref(method(:source_create_end), "void (string, symbol, string)")
        )
        Yast::Pkg.CallbackSourceCreateInit(void_ref)
        Yast::Pkg.CallbackSourceCreateDestroy(void_ref)

        nil
      end

      def source_report_start(_source_id, _url, _task)
        log.debug "Empty SourceReportStart callback"

        nil
      end

      def source_report_error(_source_id, _url, _error, _description)
        log.debug "Empty SourceReportError callback, returning `ABORT"
        :ABORT
      end

      def source_report_end(_src_id, _url, _task, _error, _description)
        log.debug "Empty SourceReportEnd callback"

        nil
      end

      def register_source_report_callbacks
        # source report callbacks
        Yast::Pkg.CallbackSourceReportStart(
          fun_ref(
            method(:source_report_start),
            "void (integer, string, string)"
          )
        )
        Yast::Pkg.CallbackSourceReportProgress(boolean_integer_ref)
        Yast::Pkg.CallbackSourceReportError(
          fun_ref(
            method(:source_report_error),
            "symbol (integer, string, symbol, string)"
          )
        )
        Yast::Pkg.CallbackSourceReportEnd(
          fun_ref(
            method(:source_report_end),
            "void (integer, string, string, symbol, string)"
          )
        )
        Yast::Pkg.CallbackSourceReportInit(void_ref)
        Yast::Pkg.CallbackSourceReportDestroy(void_ref)

        nil
      end

      def progress_start(_id, _task, _in_percent, _is_alive, _min, _max, _val_raw, _val_percent)
        log.debug "Empty ProgressStart callback"

        nil
      end

      def progress_progress(_id, _val_raw, _val_percent)
        log.debug "Empty ProgressProgress callback, returning true"
        true
      end

      def register_progress_report_callbacks
        Yast::Pkg.CallbackProgressReportStart(
          fun_ref(
            method(:progress_start),
            "void (integer, string, boolean, boolean, integer, integer, integer, integer)"
          )
        )
        Yast::Pkg.CallbackProgressReportProgress(
          fun_ref(
            method(:progress_progress),
            "boolean (integer, integer, integer)"
          )
        )
        Yast::Pkg.CallbackProgressReportEnd(
          fun_ref(method(:void_integer), "void (integer)")
        )

        nil
      end

      def script_start(_patch_name, _patch_version, _patch_arch, _script_path)
        log.debug "Empty ScriptStart callback"

        nil
      end

      def script_progress(_ping, _output)
        log.debug "Empty ScriptProgress callback, returning true"
        true
      end

      def message(_patch_name, _patch_version, _patch_arch, _message)
        log.debug "Empty Message callback"
        true # continue
      end

      def register_script_callbacks
        Yast::Pkg.CallbackScriptStart(
          fun_ref(
            method(:script_start),
            "void (string, string, string, string)"
          )
        )
        Yast::Pkg.CallbackScriptProgress(
          fun_ref(method(:script_progress), "boolean (boolean, string)")
        )
        Yast::Pkg.CallbackScriptProblem(
          fun_ref(method(:string_string), "string (string)")
        )
        Yast::Pkg.CallbackScriptFinish(void_ref)

        Yast::Pkg.CallbackMessage(
          fun_ref(
            method(:message),
            "boolean (string, string, string, string)"
          )
        )

        nil
      end

      def register_scandb_callbacks
        Yast::Pkg.CallbackStartScanDb(void_ref)
        Yast::Pkg.CallbackProgressScanDb(boolean_integer_ref)
        Yast::Pkg.CallbackErrorScanDb(
          fun_ref(method(:string_integer_string), "string (integer, string)")
        )
        Yast::Pkg.CallbackDoneScanDb(
          fun_ref(method(:void_integer_string), "void (integer, string)")
        )

        nil
      end

      def start_download(_url, _localfile)
        log.debug "Empty StartDownload callback"

        nil
      end

      def progress_download(_percent, _bps_avg, _bps_current)
        log.debug "Empty ProgressDownload callback, returning true"
        true
      end

      def done_download(_error_value, _error_text)
        log.debug "Empty DoneDownload callback"

        nil
      end

      def register_download_callbacks
        Yast::Pkg.CallbackInitDownload(void_string_ref)
        Yast::Pkg.CallbackStartDownload(
          fun_ref(method(:start_download), "void (string, string)")
        )
        Yast::Pkg.CallbackProgressDownload(
          fun_ref(
            method(:progress_download),
            "boolean (integer, integer, integer)"
          )
        )
        Yast::Pkg.CallbackDoneDownload(
          fun_ref(method(:done_download), "void (integer, string)")
        )
        Yast::Pkg.CallbackDestDownload(void_ref)
        Yast::Pkg.CallbackStartRefresh(void_ref)
        Yast::Pkg.CallbackDoneRefresh(void_ref)

        nil
      end
    end
  end
end

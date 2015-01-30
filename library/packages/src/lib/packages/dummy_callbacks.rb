require "yast"

module Packages
  class DummyCallbacks
    class << self
      include Yast::Logger

      def register
        Yast.import "Pkg"

        SetDummyProcessCallbacks()
        SetDummyProvideCallbacks()
        SetDummyPatchCallbacks()
        SetDummySourceCreateCallbacks()
        SetDummySourceReportCallbacks()
        SetDummyProgressReportCallbacks()
        SetDummyScriptCallbacks()
        SetDummyScanDBCallbacks()
        SetDummyDownloadCallbacks()
      end

    private
      def fun_ref(*args)
        Yast::FunRef.new(*args)
      end

      def DummyProcessStart(_param1, _param2, _param3)
        log.debug "Empty ProcessStart callback"
      end

      def DummyBooleanInteger(_param1)
        log.debug "Empty generic boolean(integer)->true callback"

        true
      end

      def DummyStringString(_param1)
        log.debug "Empty generic string(string)->\"\" callback"
        ""
      end

      def DummyVoid
        log.debug "Empty generic void() callback"
      end

      def SetDummyProcessCallbacks
        Yast::Pkg.CallbackProcessStart(
            fun_ref(
              method(:DummyProcessStart),
              "void (string, list <string>, string)"
              )
            )
        Yast::Pkg.CallbackProcessProgress(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackProcessNextStage(fun_ref(method(:DummyVoid), "void ()"))
        Yast::Pkg.CallbackProcessDone(fun_ref(method(:DummyVoid), "void ()"))

        nil
      end

      def DummyStartProvide(_param1, _param2, _param3)
        log.debug "Empty StartProvide callback"

        nil
      end

      def DummyDoneProvide(_error, _reason, _name)
        log.debug "Empty DoneProvide callback, returning 'I'"
        "I"
      end

      def DummyStartPackage(_name, _location, _summary, _installsize, _is_delete)
        log.debug "Empty StartPackage callback"

        nil
      end

      def DummyDonePackage(_error, _reason)
        log.debug "Empty DonePackage callback, returning 'I'"
        "I"
      end

      def SetDummyProvideCallbacks
        Yast::Pkg.CallbackStartProvide(
            fun_ref(method(:DummyStartProvide), "void (string, integer, boolean)")
            )
        Yast::Pkg.CallbackProgressProvide(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackDoneProvide(
            fun_ref(method(:DummyDoneProvide), "string (integer, string, string)")
            )
        Yast::Pkg.CallbackStartPackage(
            fun_ref(
              method(:DummyStartPackage),
              "void (string, string, string, integer, boolean)"
              )
            )
        Yast::Pkg.CallbackProgressPackage(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackDonePackage(
            fun_ref(method(:DummyDonePackage), "string (integer, string)")
            )

        nil
      end

      def DummyVoidString(_param1)
        log.debug "Empty generic void(string) callback"

        nil
      end

      def DummyVoidInteger(_param1)
        log.debug "Empty generic void(integer) callback"

        nil
      end

      def DummyVoidIntegerString(_param1, _param2)
        log.debug "Empty generic void(integer, string) callback"

        nil
      end

      def DummyVoidStringInteger(_param1, _param2)
        log.debug "Empty generic void(string, integer) callback"

        nil
      end

      def DummyStringIntegerString(_param1, _param2)
        log.debug "Empty generic string(integer, string) callback"
        ""
      end

      def SetDummyPatchCallbacks
        Yast::Pkg.CallbackStartDeltaDownload(
            fun_ref(method(:DummyVoidStringInteger), "void (string, integer)")
            )
        Yast::Pkg.CallbackProgressDeltaDownload(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackProblemDeltaDownload(
            fun_ref(method(:DummyVoidString), "void (string)")
            )
        Yast::Pkg.CallbackFinishDeltaDownload(fun_ref(method(:DummyVoid), "void ()"))

        Yast::Pkg.CallbackStartDeltaApply(
            fun_ref(method(:DummyVoidString), "void (string)")
            )
        Yast::Pkg.CallbackProgressDeltaApply(
            fun_ref(method(:DummyVoidInteger), "void (integer)")
            )
        Yast::Pkg.CallbackProblemDeltaApply(
            fun_ref(method(:DummyVoidString), "void (string)")
            )
        Yast::Pkg.CallbackFinishDeltaApply(fun_ref(method(:DummyVoid), "void ()"))

        nil
      end

      def DummySourceCreateError(_url, _error, _description)
        log.debug "Empty SourceCreateError callback, returning `ABORT"
        :ABORT
      end

      def DummySourceCreateEnd(_url, _error, _description)
        log.debug "Empty SourceCreateEnd callback"

        nil
      end

      def SetDummySourceCreateCallbacks
        Yast::Pkg.CallbackSourceCreateStart(
            fun_ref(method(:DummyVoidString), "void (string)")
            )
        Yast::Pkg.CallbackSourceCreateProgress(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackSourceCreateError(
            fun_ref(
              method(:DummySourceCreateError),
              "symbol (string, symbol, string)"
              )
            )
        Yast::Pkg.CallbackSourceCreateEnd(
            fun_ref(method(:DummySourceCreateEnd), "void (string, symbol, string)")
            )
        Yast::Pkg.CallbackSourceCreateInit(fun_ref(method(:DummyVoid), "void ()"))
        Yast::Pkg.CallbackSourceCreateDestroy(fun_ref(method(:DummyVoid), "void ()"))

        nil
      end

      def DummySourceReportStart(_source_id, _url, _task)
        log.debug "Empty SourceReportStart callback"

        nil
      end

      def DummySourceReportError(_source_id, _url, _error, _description)
        log.debug "Empty SourceReportError callback, returning `ABORT"
        :ABORT
      end

      def DummySourceReportEnd(_src_id, _url, _task, _error, _description)
        log.debug "Empty SourceReportEnd callback"

        nil
      end

      def SetDummySourceReportCallbacks
        # source report callbacks
        Yast::Pkg.CallbackSourceReportStart(
            fun_ref(
              method(:DummySourceReportStart),
              "void (integer, string, string)"
              )
            )
        Yast::Pkg.CallbackSourceReportProgress(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackSourceReportError(
            fun_ref(
              method(:DummySourceReportError),
              "symbol (integer, string, symbol, string)"
              )
            )
        Yast::Pkg.CallbackSourceReportEnd(
            fun_ref(
              method(:DummySourceReportEnd),
              "void (integer, string, string, symbol, string)"
              )
            )
        Yast::Pkg.CallbackSourceReportInit(fun_ref(method(:DummyVoid), "void ()"))
        Yast::Pkg.CallbackSourceReportDestroy(fun_ref(method(:DummyVoid), "void ()"))

        nil
      end

      def DummyProgressStart(_id, _task, _in_percent, _is_alive, _min, _max, _val_raw, _val_percent)
        log.debug "Empty ProgressStart callback"

        nil
      end

      def DummyProgressProgress(_id, _val_raw, _val_percent)
        log.debug "Empty ProgressProgress callback, returning true"
        true
      end

      def SetDummyProgressReportCallbacks
        Yast::Pkg.CallbackProgressReportStart(
            fun_ref(
              method(:DummyProgressStart),
              "void (integer, string, boolean, boolean, integer, integer, integer, integer)"
              )
            )
        Yast::Pkg.CallbackProgressReportProgress(
            fun_ref(
              method(:DummyProgressProgress),
              "boolean (integer, integer, integer)"
              )
            )
        Yast::Pkg.CallbackProgressReportEnd(
            fun_ref(method(:DummyVoidInteger), "void (integer)")
            )

        nil
      end

      def DummyScriptStart(_patch_name, _patch_version, _patch_arch, _script_path)
        log.debug "Empty ScriptStart callback"

        nil
      end

      def DummyScriptProgress(_ping, _output)
        log.debug "Empty ScriptProgress callback, returning true"
        true
      end

      def DummyMessage(_patch_name, _patch_version, _patch_arch, _message)
        log.debug "Empty Message callback"
        true # continue
      end

      def SetDummyScriptCallbacks
        Yast::Pkg.CallbackScriptStart(
            fun_ref(
              method(:DummyScriptStart),
              "void (string, string, string, string)"
              )
            )
        Yast::Pkg.CallbackScriptProgress(
            fun_ref(method(:DummyScriptProgress), "boolean (boolean, string)")
            )
        Yast::Pkg.CallbackScriptProblem(
            fun_ref(method(:DummyStringString), "string (string)")
            )
        Yast::Pkg.CallbackScriptFinish(fun_ref(method(:DummyVoid), "void ()"))

        Yast::Pkg.CallbackMessage(
            fun_ref(
              method(:DummyMessage),
              "boolean (string, string, string, string)"
              )
            )

        nil
      end

      def SetDummyScanDBCallbacks
        Yast::Pkg.CallbackStartScanDb(fun_ref(method(:DummyVoid), "void ()"))
        Yast::Pkg.CallbackProgressScanDb(
            fun_ref(method(:DummyBooleanInteger), "boolean (integer)")
            )
        Yast::Pkg.CallbackErrorScanDb(
            fun_ref(method(:DummyStringIntegerString), "string (integer, string)")
            )
        Yast::Pkg.CallbackDoneScanDb(
            fun_ref(method(:DummyVoidIntegerString), "void (integer, string)")
            )

        nil
      end

      def DummyStartDownload(_url, _localfile)
        log.debug "Empty StartDownload callback"

        nil
      end

      def DummyProgressDownload(_percent, _bps_avg, _bps_current)
        log.debug "Empty ProgressDownload callback, returning true"
        true
      end

      def DummyDoneDownload(_error_value, _error_text)
        log.debug "Empty DoneDownload callback"

        nil
      end

      def SetDummyDownloadCallbacks
        Yast::Pkg.CallbackInitDownload(
            fun_ref(method(:DummyVoidString), "void (string)")
            )
        Yast::Pkg.CallbackStartDownload(
            fun_ref(method(:DummyStartDownload), "void (string, string)")
            )
        Yast::Pkg.CallbackProgressDownload(
            fun_ref(
              method(:DummyProgressDownload),
              "boolean (integer, integer, integer)"
              )
            )
        Yast::Pkg.CallbackDoneDownload(
            fun_ref(method(:DummyDoneDownload), "void (integer, string)")
            )
        Yast::Pkg.CallbackDestDownload(fun_ref(method(:DummyVoid), "void ()"))
        Yast::Pkg.CallbackStartRefresh(fun_ref(method(:DummyVoid), "void ()"))
        Yast::Pkg.CallbackDoneRefresh(fun_ref(method(:DummyVoid), "void ()"))

        nil
      end

    end
  end
end

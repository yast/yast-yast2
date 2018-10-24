module Yast
  module TestfuncInclude
    def initialize_testfunc(include_target)
      Yast.include include_target, "testsuite.rb"

      @popups = {
        "a" => {
          "table" => {
            "widget"  => :checkbox,
            "summary" => fun_ref(method(:opt_sum), "string (any, string)"),
            "handle"  => :a_handle,
            "label"   => "'a' option label"
          },
          "popup" => {
            "widget" => :textentry,
            "handle" => fun_ref(method(:a_handle), "symbol (any, string, map)")
          }
        },
        "b" => {}
      }

      @widgets = {
        "w1" => {
          "widget"            => :checkbox,
          "opt"               => %i[notify immediate],
          "label"             => "Check&Box",
          "init"              => fun_ref(method(:w1_init), "void (string)"),
          "handle"            => fun_ref(
            method(:w1_handle),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:w1_validate),
            "boolean (string, map)"
          )
        },
        "w2" => {
          "widget"            => :textentry,
          "label"             => "Text&Entry",
          "store"             => fun_ref(
            method(:w2_store),
            "void (string, map)"
          ),
          "handle"            => fun_ref(
            method(:w2_handle),
            "symbol (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:w2_validate),
            "boolean (string, map)"
          )
        }
      }
    end

    def getIdList(descr)
      descr = deep_copy(descr)
      DUMP(
        Builtins.sformat(
          "Returning list of ids for table %1",
          Ops.get_string(descr, "_cwm_key", "")
        )
      )
      ["a", "b", "c"]
    end

    def id2key(descr, opt_id)
      descr = deep_copy(descr)
      opt_id = deep_copy(opt_id)
      DUMP(
        Builtins.sformat(
          "Translating id %1 of %2 to key",
          opt_id,
          Ops.get_string(descr, "_cwm_key", "")
        )
      )
      if opt_id.nil?
        DUMP("nil branch, returning a")
        return "a"
      end
      Convert.to_string(opt_id)
    end

    def opt_sum(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      DUMP(Builtins.sformat("wanting summary for %1:%2", opt_id, opt_key))
      Builtins.sformat("%1:%2", opt_id, opt_key)
    end

    def tableOptionHandle(opt_id, opt_key, event)
      opt_id = deep_copy(opt_id)
      event = deep_copy(event)
      DUMP(
        Builtins.sformat(
          "Handling op %1 on %2 (key %3)",
          event,
          opt_id,
          opt_key
        )
      )
      :new_event
    end

    def a_handle(id, key, event)
      id = deep_copy(id)
      event = deep_copy(event)
      Builtins.y2error("a_handle: id %1, key %2, event %3", id, key, event)
      nil
    end

    def fallback_init(id, key)
      id = deep_copy(id)
      Builtins.y2error("fallback_init: id %1, key %2", id, key)

      nil
    end

    def fallback_summary(opt_id, opt_key)
      opt_id = deep_copy(opt_id)
      Builtins.y2error("fallback_summary: id %1, key %2", opt_id, opt_key)
      Builtins.sformat("%1:%2", opt_id, opt_key)
    end

    def fallback_store(id, key)
      id = deep_copy(id)
      Builtins.y2error("fallback_store: id %1, key %2", id, key)

      nil
    end

    def w1_init(key)
      Builtins.y2error("w1_init: Initing %1", key)

      nil
    end

    def w1_handle(key, event)
      event = deep_copy(event)
      Builtins.y2error("w1_handle: Handling %1, event %2", key, event)
      nil
    end

    def w1_validate(key, event)
      event = deep_copy(event)
      Builtins.y2error("w1_validate: Validating %1, event %2", key, event)
      true
    end

    def w2_store(key, event)
      event = deep_copy(event)
      Builtins.y2error("w2_store: Saving %1, event %2", key, event)

      nil
    end

    def w2_handle(key, event)
      event = deep_copy(event)
      Builtins.y2error("w2_handle: Handling %1, event %2", key, event)
      nil
    end

    def w2_validate(key, event)
      event = deep_copy(event)
      Builtins.y2error("w2_validate: Validating %1, event %2", key, event)
      true
    end

    def generic_init(key)
      Builtins.y2error("generic_init: Initing %1", key)

      nil
    end

    def generic_save(key, event)
      event = deep_copy(event)
      Builtins.y2error("generic_save: Saving %1, event %2", key, event)

      nil
    end

    def w1_handle_symbol(key, event)
      event = deep_copy(event)
      Builtins.y2error("w1_handle_symbol: Handling %1, event %2", key, event)
      :symbol
    end

    def w1_validat_false(key, event)
      event = deep_copy(event)
      Builtins.y2error("w1_validate_false: Validating %1, event %2", key, event)
      false
    end
  end
end

require "amazing_print"
require "minitest/autorun"
require "minitest/hooks"
require "minitest/pride"
require "mocha/minitest"

module Minitest
  class Test
    include Minitest::Hooks

    def before_all = super
    def after_all = super

    def setup
      $stdout.stubs(:tty?).returns(false)
      $stdout.stubs(:winsize).returns([24, 80])
    end

    def teardown = super

    protected

    #
    # custom assertions
    #

    def assert_no_raises(msg = nil)
      yield
    rescue => ex
      flunk(msg || "assert_no_raises, but raised #{ex.inspect}")
    end

    def assert_equal(exp, act, msg = nil)
      # just a hack to workaround the assert_nil warning
      assert(exp == act, message(msg) { diff(exp, act) })
    end

    def assert_true(act, msg = nil) = assert_equal(true, act, msg)
    def assert_false(act, msg = nil) = assert_equal(false, act, msg)
  end
end

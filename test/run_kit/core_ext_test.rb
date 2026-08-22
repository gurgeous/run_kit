require "tmpdir"
require "run_kit"

module RunKit
  module CoreExt
    class EnumerableTest < Minitest::Test
      def test_tally_sorted
        cases = [
          ["strings", %w[b A b a c], [["b", 2], ["A", 1], ["a", 1], ["c", 1]]],
          ["numbers", [2, 1, 2, 3], [[2, 2], [1, 1], [3, 1]]],
          ["booleans", [false, true, false], [[false, 2], [true, 1]]],
          ["mixed", [1, "one", 1], [[1, 2], ["one", 1]]],
          ["mixed tie", [1, "one"], [[1, 1], ["one", 1]]],
        ]
        cases.each do |message, input, expected|
          assert_equal expected, input.tally_sorted.to_a, message
        end
      end

      def test_statistics
        assert_equal 1.0, [1, 2, 3].variance
        assert_equal 2.0 / 3, [1, 2, 3].variance(sample: false)
        assert_equal nil, [1].variance
        assert_equal nil, [].variance(sample: false)
        assert_equal 2.0, [1, 2, 3].mean
        assert_equal nil, [].mean
        assert_equal 1.0, [1, 2, 3].stddev
        assert_equal nil, [1].stddev
      end
    end

    class EnumeratorTest < Minitest::Test
      def test_with_progressbar
        output = StringIO.new
        values = []

        [1, 2].each.with_progressbar(output:, hide: true) { values << _1 }

        assert_equal [1, 2], values
        assert_equal "\e[?25l\e[?25h", output.string

        output = StringIO.new
        [1].each.with_progressbar(output:) {}
        assert_includes output.string, "Progress:"

        enum = [1, 2].each.with_progressbar(output:, hide: true)
        assert_instance_of ::Enumerator, enum
      end
    end

    class HashTest < Minitest::Test
      def test_hash_sort_by
        assert_equal({b: 1, a: 2}, {a: 2, b: 1}.hash_sort_by { _2 })
      end

      def test_to_struct
        struct = {name: "Lee", count: 2}.to_struct

        assert_equal "Lee", struct.name
        assert_equal 2, struct.count
      end
    end

    class NumericTest < Minitest::Test
      def test_sqrt
        assert_equal 3.0, 9.sqrt
      end
    end

    class PathnameTest < Minitest::Test
      attr_reader :tmpdir

      def setup
        @tmpdir = Pathname(Dir.mktmpdir("core-ext-test-"))
      end

      def teardown
        tmpdir.rmtree
      end

      def test_chmod
        path = tmp_path("data").tap { _1.write("") }

        path.chmod("u=rw,go=")

        assert_equal 0o600, path.stat.mode & 0o777
      end

      def test_mkdir
        path = tmp_path("nested/dir")

        path.mkdir
        path.mkdir

        assert_true path.directory?
      end

      private

      def tmp_path(name)
        tmpdir.join(name)
      end
    end

    class StringTest < Minitest::Test
      def test_without_curly
        assert_equal %q("one" 'two'), "“one” ‘two’".without_curly
      end
    end
  end
end

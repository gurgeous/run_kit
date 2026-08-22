require "run_kit"

module RunKit
  class ShellTest < Minitest::Test
    attr_reader :tmpdir

    def setup
      @tmpdir = Pathname(Dir.mktmpdir("run-kit-test-"))
    end

    def teardown
      tmpdir.rmtree
    end

    def test_file_read
      plain = tmp_path("plain.txt").tap { _1.write("hello\n") }
      gzip = tmp_path("gzip.txt.gz")
      Zlib::GzipWriter.open(gzip) { _1.write("hello\n") }

      assert_equal "hello\n", Shell.file_read(plain)
      assert_equal "hello\n", Shell.file_read(gzip)
    end

    def test_file_write
      plain = tmp_path("plain.txt")
      gzip = tmp_path("gzip.txt.gz")

      Shell.file_write(plain, "hello\n")
      Shell.file_write(gzip, "hello\n")

      assert_equal "hello\n", plain.read
      assert_equal "hello\n", Zlib::GzipReader.open(gzip, &:read)
    end

    def test_json_read
      path = tmp_path("data.json").tap { _1.write('{"ok":true}') }

      assert_equal({ok: true}, Shell.json_read(path))
      assert_equal({"ok" => true}, Shell.json_read(path, symbolize_names: false))
    end

    def test_json_write
      path = tmp_path("data.json")

      Shell.json_write(path, {ok: true})

      assert_equal "{\n  \"ok\": true\n}", path.read
    end

    def test_jsonl_read
      path = tmp_path("data.jsonl").tap { _1.write("{\"ok\":1}\n{\"ok\":2}") }

      assert_equal [{ok: 1}, {ok: 2}], Shell.jsonl_read(path)
      assert_equal [{"ok" => 1}, {"ok" => 2}], Shell.jsonl_read(path, symbolize_names: false)
    end

    def test_jsonl_write
      path = tmp_path("data.jsonl")

      Shell.jsonl_write(path, [{ok: 1}, {ok: 2}])

      assert_equal "{\"ok\":1}\n{\"ok\":2}", path.read
    end

    def test_gzip
      compressed = Shell.gzip("hello")

      assert_equal "hello", Zlib::GzipReader.new(StringIO.new(compressed)).read
      assert_equal "hello", Shell.gunzip(compressed)

      external = StringIO.new
      Zlib::GzipWriter.wrap(external) { _1.write("world") }
      assert_equal "world", Shell.gunzip(external.string)
    end

    def test_csv_read
      path = tmp_path("data.csv").tap { _1.write("name,stars,score\nrails,1,1.5\n") }

      assert_equal [{name: "rails", stars: "1", score: "1.5"}], Shell.csv_read(path).map(&:to_h)
      assert_equal [{name: "rails", stars: 1, score: 1.5}], Shell.csv_read(path, infer: true).map(&:to_h)
    end

    def test_csv_write
      path = tmp_path("data.csv")

      Shell.csv_write(path, [{name: "rails", stars: 1}], headers: %i[name stars])

      assert_equal "name,stars\nrails,1\n", path.read
    end

    def test_csv_write_stdout
      stdout, $stdout = $stdout, StringIO.new

      Shell.csv_write_stdout([{name: "rails", stars: 1}], headers: %i[name stars])

      assert_equal "name,stars\nrails,1\n", $stdout.string
    ensure
      $stdout = stdout
    end

    def test_shell
      cases = [
        ["varargs", ["printf", "%s", "hi"]],
        ["array", [["printf", "%s", "hi"]]],
        ["string", ["printf %s hi"]],
      ]
      cases.each do |msg, command|
        assert_equal ["hi", 0], Shell.shell(*command), msg
      end

      output, status = Shell.shell("definitely-not-a-command")
      assert_equal 127, status
      assert_includes output, "definitely-not-a-command"
    end

    def test_shell_bang
      cases = [
        ["varargs", ["printf", "%s", "hi"]],
        ["array", [["printf", "%s", "hi"]]],
        ["interpolation", ["printf %s {{word}}", {vars: {word: "hi"}}]],
      ]
      cases.each do |msg, command|
        kwargs = command.last.is_a?(Hash) ? command.pop : {}
        assert_equal "hi", Shell.shell!(*command, **kwargs), msg
      end

      path = tmp_path("hello world.txt").tap { _1.write("hi\n") }
      assert_equal "hi", Shell.shell!("cat {{path}}", vars: {path:})
      assert_equal "<one><two words>", Shell.shell!("printf '<%s>' {{words}}", vars: {words: ["one", "two words"]})

      assert_raises(RuntimeError) { Shell.shell!("false") }
      assert_raises(ArgumentError) { Shell.shell!(["printf", "{{word}}"], vars: {word: "hi"}) }
      assert_raises(ArgumentError) { Shell.shell!("printf hi", vars: {word: "hi"}) }
    end

    def test_shell_transform_bang
      src = tmp_path("src.txt").tap { _1.write("hi\n") }
      dst = tmp_path("dst.txt")
      unrelated = tmp_path(".tmp.txt").tap { _1.write("unrelated\n") }

      Shell.shell_transform!("tr a-z A-Z < {{src}} > {{dst}}", src:, dst:)

      assert_equal "HI\n", dst.read
      assert_equal "unrelated\n", unrelated.read
      assert_equal [], tmpdir.glob(".tmp-*")

      dst.write("old\n")
      assert_raises(Errno::EEXIST) do
        Shell.shell_transform!("tr a-z A-Z < {{src}} > {{dst}}", src:, dst:)
      end
      assert_equal "old\n", dst.read

      Shell.shell_transform!("tr a-z A-Z < {{src}} > {{dst}}", src:, dst:, force: true)
      assert_equal "HI\n", dst.read

      Shell.shell_transform!("tr A-Z a-z < {{src}} > {{dst}}", src: dst, dst:)
      assert_equal "hi\n", dst.read

      alias_path = Pathname("#{dst.dirname}/./#{dst.basename}")
      Shell.shell_transform!("tr a-z A-Z < {{src}} > {{dst}}", src: dst, dst: alias_path)
      assert_equal "HI\n", dst.read

      nested = tmp_path("nested/dst.txt")
      Shell.shell_transform!("cat {{src}} > {{dst}}", src:, dst: nested)
      assert_equal "hi\n", nested.read

      dst.write("old\n")
      assert_raises(RuntimeError) do
        Shell.shell_transform!("cat {{src}} > {{dst}}; false", src:, dst:, force: true)
      end
      assert_equal "old\n", dst.read
      assert_equal [], tmpdir.glob(".tmp-*")
    end

    def test_shell_transform_standalone
      src = tmp_path("standalone-src.txt").tap { _1.write("hi\n") }
      dst = tmp_path("standalone-dst.txt")
      script = <<~RUBY
        require "run_kit"
        RunKit::Shell.shell_transform!("tr a-z A-Z < {{src}} > {{dst}}", src: ARGV[0], dst: ARGV[1])
      RUBY
      _, status = Open3.capture2e(
        RbConfig.ruby, "-Ilib", "-e", script, src.to_s, dst.to_s
      )

      assert_true status.success?
      assert_equal "HI\n", dst.read
    end

    def test_shell_transform_concurrent
      hold = tmp_path("hold").tap { _1.write("") }
      ready = tmp_path("ready")
      src1 = tmp_path("src1.txt").tap { _1.write("one\n") }
      src2 = tmp_path("src2.txt").tap { _1.write("two\n") }
      dst1, dst2 = tmp_path("dst1.txt"), tmp_path("dst2.txt")
      error = nil

      command = "cat {{src}} > {{dst}}; touch #{ready.to_s.shellescape}; " \
        "while test -e #{hold.to_s.shellescape}; do sleep 0.01; done"
      thread = Thread.new do
        Shell.shell_transform!(command, src: src1, dst: dst1)
      rescue => ex
        error = ex
      end

      begin
        100.times do
          break if ready.exist?
          sleep 0.01
        end
        assert_true ready.exist?
        Shell.shell_transform!("cat {{src}} > {{dst}}", src: src2, dst: dst2)
      ensure
        hold.unlink
        thread.join
      end

      raise error if error
      assert_equal "one\n", dst1.read
      assert_equal "two\n", dst2.read
      assert_equal [], tmpdir.glob(".tmp-*")
    end

    def test_cp_metadata
      src = tmp_path("src.txt").tap { _1.write("hi\n") }
      dst = tmp_path("dst.txt").tap { _1.write("bye\n") }
      src.chmod(0o600)
      FileUtils.touch(src, mtime: Shell._now - 3600)

      Shell.cp_metadata(src, dst)

      assert_equal src.stat.mode, dst.stat.mode
      assert_equal src.mtime.to_i, dst.mtime.to_i
    end

    def test_kill_process
      Process.expects(:kill).with("KILL", 123)
      Shell.kill_process(123)

      Process.expects(:kill).with("KILL", 456).raises(Errno::ESRCH)
      assert_no_raises { Shell.kill_process(456) }
    end

    def test_glob
      tmp_path("b.txt").write("")
      tmp_path("a.txt").write("")

      assert_equal [tmp_path("a.txt"), tmp_path("b.txt")], Shell.glob(tmp_path("*.txt"))
    end

    def test_installed_predicate
      assert_true Shell.installed?("bash")
      assert_false Shell.installed?("definitely-not-a-real-command")
    end

    def test_lines_in_file
      path = tmp_path("data.txt").tap { _1.write("a\nb\nc\n") }

      assert_equal 3, Shell.lines_in_file(path)
    end

    def test_one_liners
      assert_match(/5d4.*c592/, Shell.md5("hello"))
      assert_match(/2cf.*9824/, Shell.sha256("hello"))

      program_name, $PROGRAM_NAME = $PROGRAM_NAME, "/tmp/run-kit"
      assert_equal Pathname("run-kit"), Shell.program_name
    ensure
      $PROGRAM_NAME = program_name
    end

    def test_prompt_predicate
      cases = [["yes", true], ["Y", true], ["no", false], ["", false]]
      cases.each do |input, exp|
        stdin, stderr = $stdin, $stderr
        $stdin = StringIO.new("#{input}\n")
        $stderr = StringIO.new

        assert_equal exp, Shell.prompt?("Proceed?"), "input: #{input.inspect}"
        assert_equal "Proceed? (y/n) ", $stderr.string, "input: #{input.inspect}"
      ensure
        $stdin = stdin
        $stderr = stderr
      end
    end

    def test_cache_fetch
      cache = tmp_path("cache")

      assert_equal({ok: 1}, Shell.cache_fetch(cache:, expires_in: 60) { {ok: 1} })
      assert_equal({ok: 1}, Shell.cache_fetch(cache:) { {ok: 2} })
      assert_equal({ok: 3}, Shell.cache_fetch(cache:, force: true) { {ok: 3} })
      FileUtils.touch(cache, mtime: Shell._now - 61)
      assert_equal({ok: 4}, Shell.cache_fetch(cache:, expires_in: 60) { {ok: 4} })

      cases = [
        [:bin, "hello"],
        [:str, "hello"],
        [:string, "hello"],
        [:json, {ok: 123}],
        [:jsonl, [{ok: 123}]],
        [:marshal, {ok: 123}],
      ]
      cases.each do |format, value|
        cache.rmtree
        assert_equal value, Shell.cache_fetch(cache:, format:) { value }, "format: #{format}"
      end

      cache.rmtree
      assert_equal({ok: 1}, Shell.cache_fetch(cache:, compress: true) { {ok: 1} })
      assert_equal "{", Zlib::GzipReader.open(cache, &:read)[0]

      cache.rmtree
      strings = {"a" => [{"b" => 2}]}
      assert_equal({a: [{b: 2}]}, Shell.cache_fetch(cache:) { strings })
      assert_equal strings, Shell.cache_fetch(cache:, symbolize: false) { raise "cache should be reused" }
    end

    def test_atomic_write
      path = tmp_path("nested/data.txt")

      Shell.atomic_write(path) { _1.write("hello\n") }

      assert_equal "hello\n", path.read
      assert_false Pathname("#{path}.tmp").exist?

      assert_raises(RuntimeError) do
        Shell.atomic_write(path) { raise "failed" }
      end
      assert_equal "hello\n", path.read
      assert_false Pathname("#{path}.tmp").exist?
    end

    private

    def tmp_path(name)
      tmpdir.join(name)
    end
  end
end

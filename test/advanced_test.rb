require 'helper'

class TestWrapperAdvanced < Minitest::Test
  def setup
    @latexml = LaTeXML.new(latexml_timeout: 1, setup: [
      {expire: 5},
      {autoflush: 1},
      {cache_key: 'latexml_ruby_test'},
      {timeout: 1},
      {nocomments: true},
      {nographicimages: true},
      {nopictureimages: true},
      {noparse: true}, # Don't parse the math, using MathJaX for now
      {format: 'html5'},
      {nodefaultresources: true}, # Don't copy any aux files over
      {whatsin: 'fragment'},
      {whatsout: 'fragment'},
    ])
  end

  def test_infinite_loop_times_out
    loopy_input = '\def\foo{\foo\foo}Testing: \foo'
    response = @latexml.convert(literal: loopy_input)

    # Timeout fatal message should be present
    fatal_message = response[:messages].select{|m| m[:severity] == 'fatal'}.first
    assert fatal_message
    assert_equal "timeout", fatal_message[:category]

    # Overall conversion status should be fatal(3)
    status_message = response[:messages].select{|m| m[:severity] == 'status'}.first
    assert status_message
    assert_equal "3", status_message[:what]

    # And the response should be empty
    assert response[:result].to_s.strip.empty?
  end

  def test_consequtive_restarts_dont_drop_jobs
    job = "hello world"
    expected_xml = <<EXPECTED
<article class="ltx_document">
<div id="p1" class="ltx_para">
<p class="ltx_p">hello world</p>
</div>
</article>
EXPECTED
    expected_xml.chomp!

    (1..10).each do
      response = @latexml.convert(literal: job)
      assert_equal expected_xml, response[:result]
    end
  end
end
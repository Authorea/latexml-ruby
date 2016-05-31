require 'helper'

class TestWrapperBasics < Minitest::Test
  def setup
    @latexml = LaTeXML.new(latexml_timeout: 2, setup: [
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


  def test_installation_is_present # can't use without an external installation
    assert LaTeXML.is_installed?
  end

  def test_which_executable_available
    assert (LaTeXML.executable == 'latexmls') || (LaTeXML.executable == 'latexmlc')
  end

  def test_server_can_init_if_installed
    if LaTeXML.executable == 'latexmls'
      assert @latexml.ensure_latexmls
    else
      assert true
    end
  end

  def test_hello_world_job
    response = @latexml.convert(literal: 'hello world')
    expected_xml = <<EXPECTED
<article class="ltx_document">
<div id="p1" class="ltx_para">
<p class="ltx_p">hello world</p>
</div>
</article>
EXPECTED
    expected_xml.chomp! # no EOL at the end in response
    assert_equal 0, response[:status_code], response.inspect
    assert_equal expected_xml, response[:result], response.inspect
  end
end

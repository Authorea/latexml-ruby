require 'helper'

class TestWrapperBasics < Minitest::Test
  def setup
    @latexml = LaTeXML.new
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

    assert_equal expected_xml, response[:result]
  end
end

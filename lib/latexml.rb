class LaTeXML
  require 'socket'
  require 'timeout'
  require 'net/http'
  require 'escape_utils'
  require 'json'

  def initialize(options = {})
    # Timeouts are tricky with this setup.
    # For example, we know a regular Authorea latexml job should be done in 12 seconds,
    #    but sometimes we boot a new latexmls server, which takes about 5-6 seconds total, so we end up with
    #    http requests that may take up to 18 seconds. Requires setup-specific tuning.
    options = {debug: true, preload_timeout: 6, latexml_timeout: 12, timeout_rescue_sleep: 0.5,
      setup: [
        {expire: 86400},
        {autoflush: 10000},
        {cache_key: 'latexml_ruby'}, # Cache this setup, for avoiding the startup runtime costs
        {nocomments: true},
        {nographicimages: true},
        {nopictureimages: true},
        {noparse: true}, # Don't parse the math, using MathJaX for now
        {format: 'html5'},
        {nodefaultresources: true}, # Don't copy any aux files over
        {whatsin: 'fragment'},
        {whatsout: 'fragment'},
        # TeX preloads:
        # The more preloads are provided on initialization, the faster the conversion overall
        # NOTE: LaTeXML will gracefully handle repeated \usepackage loads of the same package, so better add more preloads
        #       than worry about conflicts
        %w(article.cls graphicx.sty latexsym.sty amsfonts.sty amsmath.sty amsthm.sty
        amstext.sty amssymb.sty eucal.sty [utf8]inputenc.sty url.sty hyperref.sty textcomp.sty longtable.sty
        multirow.sty booktabs.sty fixltx2e.sty
        fullpage.sty [table,dvipsnames]xcolor.sty listings.sty deluxetable.sty xspace.sty
        [noids]latexml.sty [labels]lxRDFa.sty
        secureio.sty) # This is crucial for security reasons.
        .collect{|style| {preload: style} }].flatten
      }.merge(options)
    @debug = options[:debug]
    @preload_timeout = options[:preload_timeout]

    @latexml_timeout = options[:latexml_timeout]
    options[:setup].push({timeout: @latexml_timeout.to_s}) # also pass to latexml

    @http_timeout = @latexml_timeout + @preload_timeout
    @timeout_rescue_sleep = options[:timeout_rescue_sleep]
    # The current set of default options has historically been used for converting Authorea content
    # with LaTeXML 0.8.1 and up

    # Note that we need an array of hashes, because duplicate keys ARE allowed (e.g. path)
    #      and more importantly, the ORDER of options is meaningful (overrides are also allowed)
    @setup_options = options[:setup]

    @response_server_unreachable = options[:response_server_unreachable] || {
      result: '',
      log:[{
        severity: 'fatal',
        category: 'latexmls',
        what:     'server unreachable',
        details:  "The LaTeXML server was unreachable at this time"}]
    }

    @response_connection_reset = options[:response_connection_reset] || {
      result: '',
      log:[{
        severity: 'fatal',
        category: 'latexmls',
        what:     'connection reset',
        details:  "The LaTeXML server was unreachable at this time"}]
      }

    @response_empty_input = options[:response_empty_input] || {
      result: '',
      log:[{severity: 'no_problem'}]
    }
  end

  def convert(options={})
    source = options.delete(:literal) || options.delete(:source)
    if source.to_s.strip.empty?
      return @response_empty_input.deep_dup
    end
    source = "literal:#{source}"

    render_options = [{source: EscapeUtils.escape_uri(source)}]
    if !options[:preamble].to_s.strip.empty?
      render_options << {preamble: EscapeUtils.escape_uri(options[:preamble])}
    end
    # Discussion: This could be useful if/when we decide to have IDs in the document fragments of an article
    #             However, at the moment it is hitting a flaw in the LaTeXML design which causes all packages to reload on every conversion
    #             and that is SLOW. So commenting out for now.
    # if options[:documentid].present?
    #   render_options << {documentid: EscapeUtils.escape_uri(options[:documentid])}'"
    # end

    render_options.concat @setup_options

    time_before_call = Time.now
    # We are talking to socket servers, via the LaTeXML-Plugin-latexmls extension:
    server_port = options[:server_port] || 3334
    server_address = options[:server_address] || "0.0.0.0"
    # We can only proceed if we have a working socket server
    if !ensure_latexmls(server_port)
      return @response_server_unreachable.deep_dup
    end

    # Setting up POST request
    post_body = render_options.map{|h| h.map{|k,v| (v == true) ? k : "#{k}=#{v}"}}.flatten.join("&")
    latexmls_uri = URI.parse("http://#{server_address}:#{server_port}")
    request = Net::HTTP::Post.new(latexmls_uri.request_uri)
    request.body = post_body
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    http = Net::HTTP.new(latexmls_uri.host, latexmls_uri.port)
    http.read_timeout = @http_timeout # give up after X seconds

    puts "*** Starting LaTeXML call to port #{server_port}" if @debug
    http_response = nil
    begin
      Timeout::timeout(@http_timeout) do # we'll keep trying for X seconds before giving up
        # we are going to retry on failure, as this is likely an autoflush process reboot (expected behaviour)
        loop do
          begin
            http_response = http.request(request)
            break
          rescue => e
            puts "*** latexmls http request error: #{e.message}" if @debug
            sleep @timeout_rescue_sleep #avoid DoS
            if !ensure_latexmls(server_port)
              response = @response_connection_reset.deep_dup
              if e && e.message
                response[:what] = e.message
              end
              return response
            end
          end
        end
      end
    rescue Timeout::Error
      if @debug
        latexml_time = Time.now - time_before_call
        puts "LATEXML: Timeout took #{latexml_time} seconds"
        puts "LATEXML: request: #{request.body}"
      end
      return @response_connection_reset.deep_dup
    end
    latexml_time = Time.now - time_before_call
    puts "*** LaTeXML call to port #{server_port} took #{latexml_time} seconds" if @debug

    if @debug && (latexml_time > 5.0)
      puts "LATEXML: Slow render took #{latexml_time} seconds"
      puts "LATEXML: request: #{request.body}"
      # email_subject = "LATEXML: Slow render took #{latexml_time} seconds"
      # email_content = "#{request.body}"
      # Resque.enqueue(NotificationsWorker, email_subject, email_content)
    end

    response = JSON.parse(http_response.body)

    html = response["result"] || ""
    log = response["log"] || ""
    # if html.to_s.strip.empty?
      # puts "LATEXML: Empty result"
      # puts "LATEXML: request: #{request.body}"
      # email_subject = "LATEXML: Empty result"
      # email_content = "#{request.body}\n\nLog: #{log}"
      # Resque.enqueue(NotificationsWorker, email_subject, email_content)
    # end
    # We can check for the error code if we want to: 0 is ok, 1 is warning, 2 is error and 3 is fatal error
    # status = response["status"]

    # Return the HTML content:
    return {result: html, messages: parse_log(log)}
  end

  # Parses a log string which follows the LaTeXML convention
  # (described at http://dlmf.nist.gov/LaTeXML/manual/errorcodes/index.html)
  def parse_log(content)
    # Quit unless we have some data
    content = content.to_s.strip
    return if content.empty?
    # Obtain the individual lines
    messages = []
    in_details_mode = false
    content.split("\n").reject{|l| l.to_s.strip.empty?}.each do |line|
      # If we have found a message header and we're collecting details:
      if in_details_mode
        # If the line starts with tab, we are indeed reading in details
        if line.match(/^\t/)
          # Append details line to the last message"
          messages.last[:details].concat("\n#{line}")
          if messages.last[:line].to_s.strip.empty? # Only get the first line#col report
            if posmatch = line.match(/at Literal String(.*); line (\d+) col (\d+)/)
              messages.last[:line] = posmatch[2]
              messages.last[:col] = posmatch[3]
            end
          end
          next # This line has been consumed, next
        else
          in_details_mode = false
          # Not a details line, continue the current iteration with analyzing a new message
        end
      end

      # Since this isn't a details line, check if it's a message line:
      if matches = line.match(/^([^ :]+)\:([^ :]+)\:([^ ]+)(\s(.+))?$/)
        # Indeed a message, so record it:
        message = {severity: matches[1].downcase, category: matches[2].downcase, what: matches[3].downcase, details: matches[5] ? matches[5].downcase : ''}
        # Prepare to record follow-up lines with the message details:
        in_details_mode = true
        # Add to the array of parsed messages
        messages.push(message)
      else
        # Otherwise line is just noise, continue...
        in_details_mode = false
      end
    end
    # Return the parsed messages
    return messages
  end

  # One way of checking if we have a socket server running at a given port
  def local_port_open?(port, seconds=1)
    Timeout::timeout(seconds) do
      begin
        TCPSocket.new('localhost', port).close
        true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        false
      end
    end
  rescue Timeout::Error
    false
  end

  def ensure_latexmls(server_port = 3334)
    Timeout::timeout(@preload_timeout) do # we'll try for X seconds before giving up
      loop do
        if local_port_open?(server_port)
          break
        else
          # expire=600: daemonized, if idle for 10 minutes will self-terminate
          # expire=86400: daemonized, if idle for 24 hours will self-terminate
          # autoflush: auto-restart process after X conversions. Useful if memory is leaking (shouldn't be). 0 to disable.
          sys_options = @setup_options.map do |h|
            h.map do |k,v|
              (v==true) ? ["--#{k}"] : ["--#{k}", v.to_s]
            end
          end.flatten
          system(LaTeXML.executable,"--port",server_port.to_s, *sys_options)
        end
      end
      return true
    end
  rescue Timeout::Error
    return false
  end

  def self.is_installed?
    self.executable
  end

  def self.executable
    @@executable ||= if system("which latexmls > /dev/null 2>&1")
      'latexmls'
    elsif system("which latexmlc > /dev/null 2>&1")
      'latexmlc'
    else
      nil
    end
  end
end

#  Copyright (C) 2006 by Sergio Pistone
#  sergio_pistone@yahoo.com.ar
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the
#  Free Software Foundation, Inc.,
#  59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

require 'htmlentities'
require 'rexml/document'
require 'net/http'
require 'cgi'
require 'uri'

module Strings

	@@word_separators = " \t\n()[],.;:-¿?¡!\"/\\"

	def Strings.empty?( text )
		return text == nil ? true : (text.size == 0 ? true : text.strip.empty?() )
	end

	def Strings.shell_quote( text )
		return '"' + text.gsub( '\\', '\\\\\\' ).gsub( '"', '\\"' ).gsub( '`', '\\\`' ) + '"'
	end

	def Strings.shell_unquote( text )
		if ( text.slice( 0, 1 ) == '"' )
			return text.gsub( '\\`', '`' ).gsub( '\\"', '"' ).slice( 1..-2 )
		else # if ( text.slice( 0, 1 ) == "'" )
			return text.slice( 1..-2 )
		end
	end

	def Strings.shell_escape( text )
		return text.gsub( '\\', '\\\\\\' ).gsub( '"', '\\"' ).gsub( '`', '\\\`' ).gsub( %q/'/, %q/\\\'/ ).gsub( ' ', '\\ ' )
	end

	def Strings.shell_unescape( text )
		return text.gsub( '\\ ', ' ' ).gsub( "\\'", "'" ).gsub( '\\`', '`' ).gsub( '\\"', '"' )
	end

	def Strings.sql_quote( text )
		return "'" + Strings.sql_escape( text ) + "'"
	end

	def Strings.sql_unquote( text )
		return Strings.sql_unescape( text.slice( 1..-2 ) )
	end

	def Strings.sql_escape( text )
		return text.gsub( %q/'/, %q/\\\'/ )
	end

	def Strings.sql_unescape( text )
		return text.gsub( "\\'", "'" )
	end

	def Strings.random_token( length=10 )
		chars = ( 'a'..'z' ).to_a + ( '0'..'9' ).to_a
		password = ""
		1.upto( length ) { |i| password << chars[rand(chars.size-1)] }
		return password
	end

	def Strings.remove_invalid_filename_chars( filename )
		return Strings.remove_invalid_filename_chars!( String.new( filename ) )
	end

	def Strings.remove_invalid_filename_chars!( filename )
		filename.tr_s!( '*?:|/\<>', '' )
		return filename
	end

	def Strings.google_search_quote( text )
		text = text.gsub( '"', '' )
		text.gsub!( /^\ *the\ */i, '' )
		return Strings.empty?( text) ? '' : "\"#{text}\""
	end

	def Strings.build_google_feeling_lucky_url( query, site=nil )
		url = "http://www.google.com/search?q=#{CGI.escape( query )}"
		url += "+site%3A#{site}" if ( site != nil )
		return url + '&btnI'
	end

	def Strings.downcase( text )
		begin
			return text.to_s().unpack( 'U*' ).collect() do |c|
				if ( c >= 65 && c <= 90 ) # abcdefghijklmnopqrstuvwxyz
					c + 32
				elsif ( c >= 192 && c <= 222 ) # ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞ
					c + 32
				else
					c
				end
			end.pack( 'U*' )
		rescue Exception # fallback to normal operation on error
			return text.downcase()
		end
	end

	def Strings.downcase!( text )
		return text.replace( Strings.downcase( text ) )
	end

	def Strings.upcase( text )
		begin
			return text.to_s().unpack( 'U*' ).collect() do |c|
				if ( c >= 97 && c <= 122 ) # ABCDEFGHIJKLMNOPQRSTUVWXYZ
					c - 32
				elsif ( c >= 224 && c <= 254 ) # àáâãäåæçèéêëìíîïðñòóôõö×øùúûüýþ
					c - 32
				else
					c
				end
			end.pack( 'U*' )
		rescue Exception # fallback to normal operation on error
			return text.upcase()
		end
	end

	def Strings.upcase!( text )
		return text.replace( Strings.upcase( text ) )
	end

	def Strings.capitalize( text, downcase=false )
		text = downcase ? Strings.downcase( text ) : text.to_s()
		if ( (idx = text.index( /[a-zA-Zàáâãäåæçèéêëìíîïðñòóôõö×øùúûüýþÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞ]/ )) != nil )
			return text.slice( 0, idx ) + Strings.upcase( text.slice( idx, 1 ) ) + text.slice( idx+1, text.length )
		else
			return text
		end
	end

	def Strings.capitalize!( text, downcase=false )
		return text.replace( Strings.capitalize( text, downcase ) )
	end

	def Strings.titlecase( text, correct_case=true, downcase=false )
		text = Strings.capitalize( text, downcase )
		word_start = true
		text = text.unpack( 'U*' ).collect() do |c|
			if ( word_start )
				chr = [c].pack( 'U*' )
				if ( ! @@word_separators.include?( chr ) )
					word_start = false
					c = Strings.upcase( chr ).unpack( 'U*' )[0]
				end
			else
				chr = c < 256 ? c.chr() : [c].pack( 'U*' )
				word_start = true if ( @@word_separators.include?( chr ) )
			end
			c
		end.pack( 'U*' )
		if ( correct_case )
			lc_words = [
				'the', 'a', 'an', # articles
				'and', 'but', 'or', 'nor', # conjunctions
				'as', 'at', 'by', 'for', 'in', 'of', 'on', 'to', # short prepositions
				#'from', 'into', 'onto', 'with', # not so short prepositions
				'feat', 'vs', # special words
			]
			lc_words.each() do |lc_word|
				text.gsub!( /\ #{lc_word}([ ,;:\.-?!\"\/\\\)])/i, " #{lc_word}\\1" )
			end
		end
		return text
	end

	def Strings.titlecase!( text, correct_case=true, downcase=false )
		return text.replace( Strings.titlecase( text, correct_case, downcase ) )
	end

	def Strings.normalize_token( token )
		token = Strings.downcase( token )
		token.tr_s!( " \n\r\t.;:()[]", ' ' )
		token.strip!()
		token.gsub!( /`|´|’/, '\'' )
		token.gsub!( /''|«|»/, '"' )
		token.gsub!( /[&+]/, 'and' )
		token.gsub!( /^the /, '' )
		token.gsub!( /, the$/, '' )
		return token
	end

	def Strings.normalize_token!( token )
		return token.replace( Strings.normalize_token( token ) )
	end

	def Strings.cleanup_lyrics( lyrics )

		lyrics = HTMLEntities.decode( lyrics )

		prev_line = ''
		lines = []

		lyrics.split( /\r\n|\n|\r/ ).each do |line|

			# remove unnecesary spaces
			line.tr_s!( "\t ", ' ' )
			line.strip!()

			# quotes and double quotes
			line.gsub!( /`|´|’/, '\'' )
			line.gsub!( /''|&quot;|«|»/, '"' )

			# suspensive points
			line.gsub!( /…+/, '...' )
			line.gsub!( /[,;]?\.{2,}/, '...' )

			# add space after '?', '!', ',', ';', ':', '.', ')' and ']' if not present
			line.gsub!( /([^\.]?[\?!,;:\.\)\]])([^ "'])/, '\1 \2' )

			# remove spaces after '¿', '¡', '(' and ')'
			line.gsub!( /([¿¡\(\[]) /, '\1' )

			# remove spaces before '?', '!', ',', ';', ':', '.', ')' and ']'
			line.gsub!( /\ ([\?!,;:\.\)\]])/, '\1' )

			# remove space after ... at the beginning of sentence
			line.gsub!( /^\.\.\. /, '...' )

			# remove single points at end of sentence
			line.gsub!( /([^\.])\.$/, '\1' )

			# remove commas and semicolons at end of sentence
			line.gsub!( /[,;]$/, '' )

			# fix english I pronoun capitalization
			line.gsub!( /([ "'\(\[])i([\ '",;:\.\?!\]\)]|$)/, '\1I\2' )

			# remove spaces after " or ' at the begin of sentence of before them when at the end
			line.gsub!( /(^["'] | ["']$)/ ) { |s| s.strip() }

			# capitalize first alfabet character of the line
			Strings.capitalize!( line )

			# no more than one empty line at the time
			if ( !line.empty? || !prev_line.empty? || (line.empty? && !prev_line.empty?) )
				lines << line
				prev_line = line
			end
		end

		if ( lines.length > 0 && lines[lines.length-1].empty? )
			lines.delete_at( lines.length-1 )
		end

		return lines.join( "\n" )
	end

	def Strings.cleanup_lyrics!( lyrics )
		return lyrics.replace( Strings.cleanup_lyrics( lyrics ) )
	end

	def Strings.cleanup_artist( artist, title )
		artist = artist.strip()
		if ( artist != '' )
			if ( (md = /[ \(\[](ft\.|ft |feat\.|feat |featuring ) *([^\)\]]+)[\)\]]? *$/i.match( title.to_s() )) != nil )
				artist << ' feat. ' << md[2]
			else
				artist.gsub!( /[ \(\[](ft\.|ft |feat\.|feat |featuring ) *([^\)\]]+)[\)\]]? *$/i, ' feat. \2' )
			end
		end
		return artist
	end

	def Strings.cleanup_title( title )
		title = title.gsub( /[ \(\[](ft\.|ft |feat\.|feat |featuring ) *([^\)\]]+)[\)\]]? *$/i, '' )
		title.strip!()
		return title
	end

	def Strings.utf82latin1( text )
		begin
			return text.unpack( 'U*' ).pack( 'C*' )
		rescue Exception
			$stderr << "warning: conversion from UTF-8 to Latin1 failed\n"
			return text
		end
	end

	def Strings.latin12utf8( text )
		begin
			return text.unpack( 'C*' ).pack( 'U*' )
		rescue Exception
			$stderr << "warning: conversion from Latin1 to UTF-8 failed\n"
			return text
		end
	end

	def Strings.scramble( text )
		2.times() do
			chars = text.unpack( 'U*' ).reverse()
			chars.size().times() { |idx| chars[idx] = (chars[idx] + idx + 1) }
			text = chars.collect() { |c| c.to_s }.join( ':' )
		end
		return text
	end

	def Strings.scramble!( text )
		return text.replace( Strings.scramble( text ) )
	end

	def Strings.descramble( text )
		2.times() do
			chars = text.split( ':' ).collect() { |c| c.to_i }
			chars.size().times() { |idx| chars[idx] = (chars[idx] - idx - 1) }
			text = chars.reverse().pack( 'U*' )
		end
		return text
	end

	def Strings.descramble!( text )
		return text.replace( Strings.descramble( text ) )
	end

end

module Logging

	def Logging.reset( log_file )
		output = File.new( log_file, File::CREAT|File::TRUNC )
		output.close()
	end

	def Logging.log( log_file, msg, new_lines=1 )
		output = File.new( log_file, File::CREAT|File::APPEND|File::WRONLY )
		output.write( msg )
		new_lines.times() { output.write( "\n" ) }
		output.close()
	end

end

module XMLHash

	def XMLHash.save( filename, hash )

		begin
			file = File.new( filename )
			xml = REXML::Document.new( file )
			file.close()
			root = xml.root
		rescue Errno::ENOENT, REXML::ParseException
			xml = REXML::Document.new( '<?xml version="1.0" encoding="UTF-8" ?>' )
			root = xml.add_element( 'settings' )
		end

		hash.each do | key, value |
			if ( root.elements[key] != nil )
				root.elements[key].text = value == nil ? '' : value.to_s()
			else
				root.add_element( key ).text = value == nil ? '' : value.to_s()
			end
		end

		begin
			file = File.new( filename, File::CREAT|File::TRUNC|File::RDWR, 0644 )
			xml.write( file )
			file.close()
			return true
		rescue Errno::ENOENT
			return false
		end

	end

	def XMLHash.read( filename, hash )

		begin
			file = File.new( filename )
			elements = REXML::Document.new( file ).root.elements
			file.close()
			return false if ( elements == nil )
		rescue Errno::ENOENT
			return false
		end

		missing_keys = false

		keys = hash.clone()
		keys.each do |key, val|
			if ( elements[key] != nil )
				hash[key] = elements[key].text()
				hash[key] = '' if ( hash[key] == nil )
			else
				missing_keys = true
			end
		end

		return !missing_keys

	end

end

module URLEncodedFormData

	def URLEncodedFormData.prepare_query( params )
		query = params.collect { |name, value| "#{name}=#{CGI.escape( value.to_s() )}" }.join( '&' )
		header = { 'Content-type' => 'application/x-www-form-urlencoded' }
		return query, header
	end

end

module MultipartFormData

	@@boundary = '----------nOtA5FcjrNZuZ3TMioysxHGGCO69vA5iYysdBTL2osuNwOjcCfU7uiN'

	def MultipartFormData.text_param( name, value )
		return	"Content-Disposition: form-data; name=\"#{CGI.escape(name)}\"\r\n" \
				"\r\n" \
				"#{value}\r\n"
	end

	def MultipartFormData.file_param( name, file, mime_type, content )
		return	"Content-Disposition: form-data; name=\"#{CGI.escape(name)}\"; filename=\"#{file}\"\r\n" \
				"Content-Transfer-Encoding: binary\r\n" \
				"Content-Type: #{mime_type}\r\n" \
				"\r\n" \
				"#{content}\r\n"
	end

	def MultipartFormData.prepare_query( params )
		query = params.collect { |param| "--#{@@boundary}\r\n#{param}" }.join( '' ) + "--#{@@boundary}--"
		header = { "Content-type" => "multipart/form-data; boundary=" + @@boundary }
		return query, header
	end

end


module HTTP

	@@user_agent = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.0.2) Gecko/20060308 Firefox/1.5.0.2'

	@@proxy_url = nil
	@@proxy_excluded_urls = []
	@@proxy_reverse = false # if true, excluded_urls list becomes a list with the _only_ urls the proxy should be used for

	def HTTP.normalize_url( url, protocol='http' )
		url = url.strip()
		protocol_regexp = /^ *([^: ]+):\/+/
		md = protocol_regexp.match( url )
		return nil if ( md != nil && md[1] != protocol )
		url.gsub!( /\/+^/, '' )				# remove / at the end of the url
		url.gsub!( protocol_regexp, '' )	# remove the protocol part if there was one
		return "#{protocol}://#{url}"		# reinsert protocol part assuring protocol:// form
	end

	def HTTP.set_proxy_settings( proxy_url, excluded_urls=[], reverse=false )
		@@proxy_url = proxy_url ? HTTP.normalize_url( proxy_url, 'http' ) : nil
		@@proxy_reverse = @@proxy_url == nil ? false : reverse
		@@proxy_excluded_urls = []
		if ( @@proxy_url != nil )
			excluded_urls.each() do |url|
				url = normalize_url( url, 'http' )
				@@proxy_excluded_urls.insert( -1, url ) if ( url != nil && !@@proxy_excluded_urls.include?( url ) )
			end
		end
	end

	def HTTP.get_proxy_settings()
		ret = [@@proxy_url ? @@proxy_url.dup : nil, [], @@proxy_reverse]
		@@proxy_excluded_urls.each() { |url| ret[1][ret[1].size] = url.dup  }
		return ret
	end

	# returns proxy_host, proxy_port, proxy_user, proxy_pass for given url
	def HTTP.get_url_proxy_settings( url )

		return nil, nil, nil, nil if ( @@proxy_url == nil )
		proxy = HTTP.parse_uri( @@proxy_url )
		return nil, nil, nil, nil if ( proxy.host == nil )
		proxy.port = 80 if ( proxy.port == nil )

		# check if given url should be treated specially
		exception = false
		@@proxy_excluded_urls.each() do |exception_url|
			if ( url.index( exception_url ) == 0 )
				exception = true
				break
			end
		end

		if ( exception && @@proxy_reverse || !exception && !@@proxy_reverse )
			return proxy.host, proxy.port, proxy.user, proxy.password
		else
			return nil, nil, nil, nil
		end
	end

	def HTTP.parse_uri( uri )
		begin
			return URI.parse( uri )
		rescue URI::InvalidURIError
			return URI.parse( URI.escape( uri ) )
		end
	end

	def HTTP.fetch_page_get( url, headers=nil, follow=10 )

		p_url = HTTP.parse_uri( url )
		host, port, request_uri = p_url.host, p_url.port, p_url.request_uri
		return nil if host == nil || port == nil || request_uri == nil

		proxy_host, proxy_port, proxy_user, proxy_pass = HTTP.get_url_proxy_settings( url )
		http = Net::HTTP.new( host, port, proxy_host, proxy_port, proxy_user, proxy_pass )

		response = http.request_get( request_uri, headers )

		case response
			when Net::HTTPSuccess
				return response
			when Net::HTTPRedirection
				return follow < 0 ? response : (follow == 0 ? nil : HTTP.fetch_page_get( response['location'], nil, follow-1 ))
			else
				return nil
		end
	end

	def HTTP.fetch_page_post( url, params, headers=nil, follow=10 )

		p_url = HTTP.parse_uri( url )
		protocol, host, port, request_uri = p_url.scheme, p_url.host, p_url.port, p_url.request_uri
		return nil if host == nil || port == nil || request_uri == nil

		proxy_host, proxy_port, proxy_user, proxy_pass = HTTP.get_url_proxy_settings( url )
		http = Net::HTTP.new( host, port, proxy_host, proxy_port, proxy_user, proxy_pass )

		data, headers2 = URLEncodedFormData.prepare_query( params )
		headers2['User-Agent'] = @@user_agent
		headers2.merge!( headers ) if ( headers != nil )

		response = http.request_post( request_uri, data, headers2 )
		case response
			when Net::HTTPSuccess
				return response
			when Net::HTTPRedirection
				return follow < 0 ? response : (follow == 0 ? nil : HTTP.fetch_page_get( response['location'], nil, follow-1 ))
			else
				return nil
		end
	end


	def HTTP.fetch_page_post_form_multipart( url, params, headers=nil, follow=10 )

		p_url = HTTP.parse_uri( url )
		protocol, host, port, request_uri = p_url.scheme, p_url.host, p_url.port, p_url.request_uri
		return nil if host == nil || port == nil || request_uri == nil

		proxy_host, proxy_port, proxy_user, proxy_pass = HTTP.get_url_proxy_settings( url )
		http = Net::HTTP.new( host, port, proxy_host, proxy_port, proxy_user, proxy_pass )

		data, headers2 = MultipartFormData.prepare_query( params )
		headers2['User-Agent'] = @@user_agent
		headers2.merge!( headers ) if ( headers != nil )

		response = http.request_post( request_uri, data, headers2 )
		case response
			when Net::HTTPSuccess
				return response
			when Net::HTTPRedirection
				return follow < 0 ? response : (follow == 0 ? nil : HTTP.fetch_page_get( response['location'], nil, follow-1 ))
			else
				return nil
		end
	end

end


module KDE

	@@proxy_settings_file = "#{ENV['HOME']}/.kde/share/config/kioslaverc"

	@@cfg_type_regexp = /^ *ProxyType *= *([0-4]+) *$/
	@@excluded_regexp = /^ *NoProxyFor *= *([^ ]+) *$/
	@@reverse_regexp  = /^ *ReversedException *= *([^ ]+) *$/
	@@protocol_regexp = /^ *([^: ]+):\/+/

	# returns proxy_url, excluded_urls, reverse
	def KDE.get_proxy_settings( protocol='http' )

		protocol = protocol.downcase()
		raise ArgumentError( 'Invalid protocol specified' ) if ( protocol != 'http' && protocol != 'https' && protocol != 'ftp' )

		proxy_regexp = /^ *#{protocol}Proxy *= *([^ ]+) *$/

		cfg_type = proxy_url = excluded_urls = reverse = ''
		begin
			File.open( @@proxy_settings_file ).each() do |row|
				row.chomp!()
				md = @@cfg_type_regexp.match( row )
				cfg_type = md[1] if ( md != nil )
				md = proxy_regexp.match( row )
				proxy_url = md[1] if ( md != nil )
				md = @@excluded_regexp.match( row )
				excluded_urls = md[1] if ( md != nil )
				md = @@reverse_regexp.match( row )
				reverse = md[1] if ( md != nil )
			end
		rescue Exception => e
			puts 'Error reading KDE proxy settings file: ' + e.to_s()
			return nil, [], false
		end

		# cfg_type == 0: connect directly to the internet
		# cfg_type == 1: manual configuration
		# cfg_type == 2: use proxy configuration url (can't do anything with this one)
		# cfg_type == 3: detect automatically (can't do anything with this one either)
		# cfg_type == 4: same as manual configuration but values are read from enviroment variables

		if ( cfg_type != '1' && cfg_type != '4' )
			return nil, [], false
		elsif ( cfg_type == '4' )
			proxy_url = ENV[proxy].to_s().strip()
			excluded_urls = ENV[excluded_urls].to_s().strip()
 		end

		return nil, [], false if ( proxy_url == '' )

		# verify proxy_url
		proxy_url = HTTP.normalize_url( proxy_url, 'http' )
		return nil, [], false if ( proxy_url == nil )

		# parse excluded_urls list
		excluded_urls_list = []
		excluded_urls.split( ',' ).each() do |url|
			url = HTTP.normalize_url( url, 'http' )
			excluded_urls_list.insert( -1, url ) if ( url != nil && !excluded_urls_list.include?( url ) )
		end

		reverse = reverse.strip().downcase() == 'true'

		return proxy_url, excluded_urls_list, reverse
	end

end


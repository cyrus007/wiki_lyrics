#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'uri'

LYRIKI_VERSION = 'Lyriki Helper v0.9.2'
TOOLKITS_DEFAULT = ['qt', 'gtk', 'tk']

class LyrikiOptsParser

	SITES = {
		'AZ Lyrics' => 'www.azlyrics.com',
		'Baidu MP3' => 'mp3.baidu.com',
		'Jamendo' => 'www.jamendo.com',
		'Giitaayan' => 'www.giitaayan.com',
		'Leos Lyrics' => 'www.leoslyrics.com',
		'Lyrc' => 'lyrc.com.ar',
		'LyricWiki' => 'www.lyricwiki.org',
		'Not Popular.com' => 'www.notpopular.com',
		'Sing365' => 'www.sing365.com',
		'Terra Letras' => 'letras.terra.com.br'
	}

	def LyrikiOptsParser.parse( args )

		ret = OpenStruct.new()
		ret.cleanup = true
		ret.feat_fix = true
		ret.meta = true
		ret.submit = false
		ret.review = true
		ret.prompt_autogen = false
		ret.prompt_new = false
		ret.toolkits = TOOLKITS_DEFAULT

		opts = OptionParser.new() do |opts|
			opts.banner = 'Usage: lyriki.rb [OPTIONS]'
 			opts.separator 'Fetch and submit lyrics from and to www.lyriki.com.'
			opts.separator ''
			opts.separator 'Options:'
			opts.on( '-a', '--artist [ARTIST]', 'Song artist (mandatorty unless -b given).' ) { |artist| ret.artist = artist }
			opts.on( '-t', '--title [TITLE]', 'Song title (mandatorty unless -b given).' ) { |title| ret.title = title }
			opts.on( '-l', '--album [ALBUM]', 'Song album.' ) { |album| ret.album = album }
			opts.on( '-y', '--year [YEAR]', 'Song album year.' ) { |year| ret.year = year }
			opts.on( '-f', '--[no-]featfix', 'Correct artist and title when the later has',
											 '"feat. ARTIST" (true by default).' ) { |feat_fix| ret.feat_fix = feat_fix }
			opts.separator ''
			opts.on( '-b', '--batch-file [FILE]', 'Batch process file, artist;title;album;year',
												  'entries expected.' ) { |batch_file| ret.batch_file = batch_file }
			opts.separator ''
			opts.on( '-c', '--[no-]cleanup', 'Cleanup fetched lyrics (true by default).' ) { |cleanup| ret.cleanup = cleanup }
			opts.separator ''
			opts.on( '-m', '--[no-]meta', 'Search missing lyrics in other sites (true', 'by default).' ) { |meta| ret.meta = meta }
			opts.on( '--meta-sites [S1,S2...]', Array,	'Specify sites to query for missing lyrics,',
														'order included (defaults to all available',
														'sites if -m given).' ) { |sites| ret.sites = sites }
			opts.on( '--meta-list', 'List available sites.' ) do
				puts 'Available sites:'
				SITES.sort().each() { |site, url| puts " - #{site} (#{url})" }
				exit
			end
			opts.separator ''
			opts.on( '-s', '--[no-]submit', 'Submit lyrics to Lyriki (false by default).' ) { |submit| ret.submit = submit }
			opts.on( '-u', '--user [USERNAME]', 'Username to login with (mandatory when -s', 'specified).' ) { |user| ret.user = user }
			opts.on( '-p', '--pass [PASSWORD]', 'Password to login with (mandatory when -s', 'specified).' ) { |pass| ret.pass = pass }
			opts.on( '--persist [SESSIONFILE]', 'Restore session from file (if file exists)',
												'and save it before exiting (needs -u & -p).' ) { |file| ret.session_file = file }
			opts.on( '-r', '--[no-]review', 'Prompt for review before submitting content',
			                                '(requires -s, true by default).' ) { |review| ret.review = review }
			opts.on( '-g', '--[no-]prompt-autogen', 'Prompt for review of autogenerated pages',
													'(requires -r, false by default).' ) { |autogen| ret.prompt_autogen = autogen }
			opts.on( '-n', '--[no-]prompt-new', 'Prompt for submission even when there are',
												'no lyrics to submit (requires -r, false by',
												'default).' ) { |prompt_new| ret.prompt_new = prompt_new }
			opts.separator ''
			opts.on( '-x', '--proxy [PROXY]', 'Proxy server URL (defaults to no proxy).' ) do |proxy|
				begin
					if ( Strings.empty?( URI.parse( proxy ).to_s() ) )
						require 'utils'
						HTTP::set_proxy_settings( proxy )
					end
				rescue Exception
					raise OptionParser::InvalidOption, ', wrong URL format'
				end
			end

			opts.separator ''
			opts.on( '-k', '--toolkits [qt,gtk,tk]', Array, 'Specify UI toolkit priority (falling back',
															'to the next one when loading fails). An',
															'empty list will cause no dialog to be shown',
															'and lyrics to be dumped to stdout (defaults',
															"to #{TOOLKITS_DEFAULT.join( ',' )})." ) do |toolkits|
				ret.toolkits = toolkits == nil ? [] : toolkits
			end
			opts.separator ''
			opts.separator 'Common options:'
			opts.on_tail( '-h', '--help', 'Show this message.' ) { puts opts; exit }
			opts.on_tail( '-v', '--version', 'Show version.' ) { puts LYRIKI_VERSION; exit }
		end

		begin
			opts.parse!( args )
			raise OptionParser::InvalidOption, 'missing artist' if ( !ret.artist && !ret.batch_file )
			raise OptionParser::InvalidOption, 'missing title' if ( !ret.title && !ret.batch_file )
			raise OptionParser::InvalidOption, 'missing username' if ( ret.submit && !ret.user )
			raise OptionParser::InvalidOption, 'missing pasword' if ( ret.submit && !ret.pass )
			raise OptionParser::InvalidOption, '-b doesn\'t allow -a/-t/-l/-y' \
				if ( ret.batch_file && (ret.artist || ret.title || ret.album || ret.year) )
			raise OptionParser::InvalidOption, '--meta-sites requires -m' if ( ret.sites && !ret.meta )
			raise OptionParser::InvalidOption, '-g requires -r' if ( ret.prompt_autogen && ( !ret.submit || !ret.review ) )
			raise OptionParser::InvalidOption, '-n requires -r' if ( ret.prompt_new && ( !ret.submit || !ret.review ) )
			ret.toolkits.each() { |tk| raise OptionParser::InvalidOption, "unknown toolkit #{tk}" if (!TOOLKITS_DEFAULT.include?(tk)) }
			if ( ret.submit && ret.review && ret.toolkits.size() == 0 )
				raise OptionParser::InvalidOption, 'must provide at least one toolkit to use review mode'
			end
			return ret
		rescue OptionParser::InvalidOption => e
			puts e
			puts opts
			exit 1
		end
	end
end

opts = LyrikiOptsParser.parse( ARGV )
$metalyrics = opts.meta

require 'lyrics_lyriki'
require 'metalyrics' if ( $metalyrics )
require 'wikilyricssubmitter'

class LyrikiCLI < Lyriki

	include MetaLyrics if ( $metalyrics )
	include WikiLyricsSubmitter

	def initialize( cleanup_lyrics=true, review=true, username=nil, password=nil,
					submit=false, prompt_new=false, prompt_autogen=false, feat_fix=true )
		super( cleanup_lyrics, $LOG_FILE, review, username, password )
		@featuring_fix = feat_fix
		# WikiLyricsSubmitter params initialization:
		@submit, @prompt_autogen, @prompt_new = submit, prompt_autogen, prompt_new
		if ( !@submit || !@review )
			@prompt_new = false
			@prompt_autogen = false
		end
	end

	def process( opts, artist, title, album, year )
		if ( @featuring_fix )
			artist = Strings.cleanup_artist( artist, title )
			title  = Strings.cleanup_title( title )
		end
		puts "Searching lyrics to '#{title}' by '#{artist}'..."
		ld = lyrics_full_search( artist, title, album, year )
		if ( ld['lyrics'] != nil )
			if ( opts.toolkits.size() > 0 && ( !opts.submit || (ld['site'] == lyrics_site() && !(ld['custom']['autogen'] && opts.prompt_autogen)) ) )
				puts "Lyrics to '#{title}' by '#{artist}' found.\n\n"
				GUI.show_lyrics_dialog( ld )
			elsif ( opts.toolkits.size() == 0 )
				puts "Lyrics to '#{title}' by '#{artist}' found:\n#{ld['lyrics']}\n\n"
			end
		else
			puts "Lyrics to '#{title}' by '#{artist}' not found.\n\n"
		end
	end

end

GUI.set_toolkit_priority( opts.toolkits ) if ( opts.toolkits.size() > 0 )

lyriki = LyrikiCLI.new( opts.cleanup, opts.review, opts.user, opts.pass,
						opts.submit, opts.prompt_new, opts.prompt_autogen, opts.feat_fix )
lyriki.used_script_names = opts.sites if ( opts.sites != nil )

lyriki.restore_session( opts.session_file ) if ( opts.session_file != nil )

if ( opts.batch_file != nil )
	file = File.new( opts.batch_file, 'r' )
	counter = 0
	while (line = file.gets)
		params = line.split( ';' )
		next if ( params.length < 2 )
		lyriki.process( opts, params[0], params[1], params[2], params[3] )
		counter += 1
	end
	puts "#{counter} files processed."
	file.close()
else
	lyriki.process( opts, opts.artist, opts.title, opts.album, opts.year )
end

lyriki.save_session( opts.session_file ) if ( opts.session_file != nil )
#!/usr/bin/env ruby

# Forked from https://github.com/Natenom/mumble-ruby-related/raw/master/scripts/mumble-ruby-mpd-bot.rb (ty to him for creating the skeleton of this script <3)
# Added things such as requests, play, pause, volume, etc.

# Syntax
# ruby bot.rb mumbleserver_host mumbleserver_port mumbleserver_username mumbleserver_userpassword quality_bitrate mpd_fifopath mpd_path mpd_host mpd_port

require 'thread'
require 'mumble-ruby'
require 'ruby-mpd'
require 'youtube-dl.rb'

class MumbleMPD
  def log(msg)
    File.open('mumble.log', 'a') { |file| file.write "#{msg}\n" }
  end

  def send(user, msg)
    log "#{@mumbleserver_username}: #{msg}"
    begin
      @cli.text_user user, msg
    rescue => e
      File.open('error.log', 'a') { |file| file.write e }
    end
  end

  def currentFormat(current)
    if not current.nil?
      if current.artist.nil? && current.title.nil? && current.name.nil?
        return current.file
      elsif current.artist.nil? && current.title.nil?
        return current.name
      elsif current.artist.nil?
        return "#{current.name}: #{current.title}"
      else
        return "#{current.artist} - #{current.title}"
      end
    end
    current
  end

  def initialize
    @mpd_fifopath = ARGV[5].to_s
    @mpd_host = ARGV[6].to_s
    @mpd_port = ARGV[7].to_s

    @mpd = MPD.new @mpd_host, @mpd_port, callbacks: true

    @mumbleserver_host = ARGV[0].to_s
    @mumbleserver_port = ARGV[1].to_s
    @mumbleserver_username = ARGV[2].to_s
    @mumbleserver_userpassword = ARGV[3].to_s
    @quality_bitrate = ARGV[4].to_i

    @cli = Mumble::Client.new(@mumbleserver_host, @mumbleserver_port) do |conf|
      conf.username = @mumbleserver_username
      conf.password = @mumbleserver_userpassword
      conf.bitrate = @quality_bitrate
    end

    @cli.on_text_message do |msg|
      message = msg.message
      user = @cli.users[msg.actor].name
      if @cli.users.has_key?(msg.actor)
        log "#{user}: #{message}"
        case msg.message.to_s
        when /^current$/i
          send user, currentFormat(@mpd.current_song)
        when /^request <a href="(\S*)">/i
          options = {
            format: 'm4a/mp3',
            add_metadata: true,
            no_overwrites: true,
            no_playlist: true,
            playlist_end: 1,
            output: 'music/%(title)s-%(id)s.%(ext)s'
          }
          begin
            song = YoutubeDL.download $1, options
            @mpd.update
            @mpd.add song.filename.gsub 'music/', ''
            send user, "Done. Use \"seek #{@mpd.queue.count - 1}\" to go directly to the song."
          rescue
            send user, "Error downloading request."
          end
        when /^load (.*)/i
          begin
            playlist = @mpd.playlists[$1.to_i]
            playlist.load
            send user, "Loaded playlist: #{playlist.name}"
          rescue
            send user, "That playlist does not exist."
          end
        when /^save (.*)/i
          @mpd.save $1
        when /^next$/i
          @mpd.next
        when /^prev$/i
          @mpd.previous
        when /^play$/i
          @mpd.play
        when /^clear$/i
          @mpd.clear
        when /^shuffle$/i
          begin
            @mpd.shuffle
          rescue
            send user, "Shuffle didn't complete for some reason. Queue was most likely empty."
          end
        when /^strobe$/i
          @mpd.clear
          @mpd.add "http://streamer.strobe.fm/"
          @mpd.play
        when /^volume/i
          if message.match(/^volume (.*)/i) == nil
            vol = @mpd.volume
            send user, "Current Volume: #{vol}"
          else
            vol = message.match(/^volume (.*)/i)[1]
            begin
              @mpd.volume=(vol)
            rescue
              send user, "Invalid argument. Most likely out of range."
            end
          end
        when /^pause$/i
          @mpd.pause=(1)
        when /^stop$/i
          @mpd.stop
        when /^lsplaylists$/i
          text_out = "<br />"
          @mpd.playlists.each_with_index do |playlist, index|
            text_out << "<tr><td><b>#{index} - </b></td><td>#{playlist.name}</td></tr>"
          end

          send user, "<br /><b>I know the following playlists:</b><table border='0'>#{text_out}"
        when /^queue$/i
          text_out = "<br />"
          @mpd.queue.each do |song|
            text_out << "<tr><td><b>#{song.pos} - </b></td><td>#{currentFormat(song)}</td></tr>"
          end
          send user, "<br /><b>Current Queue:</b><table border='0'>#{text_out}"
        when /^seek (.*)/i
          begin
            @mpd.play $1
          rescue
            send user, "Cannot seek, most likely out of range."
          end
        when /^\.shut$/i
          @mpd.stop
          @cli.me.mute
        when /^\.open$/i
          @mpd.play
          @cli.me.mute false
        when /^help$/i
          send user, "<br /><b>Commands List:</b><br />" \
                   + "<br /><b>current</b> - shows the currently playing song" \
                   + "<br /><b>play</b> - starts playback" \
                   + "<br /><b>pause</b> - pauses playback" \
                   + "<br /><b>stop</b> - stops playback" \
                   + "<br /><b>next</b> - goes to the next song in the queue" \
                   + "<br /><b>prev</b> - goes to the previous song in the queue" \
                   + "<br /><b>clear</b> - clears the current queue" \
                   + "<br /><b>volume</b> - shows current volume" \
                   + "<br /><b>volume 0-100</b> - sets volume" \
                   + "<br /><b>strobe</b> - clears queue and plays strobe.fm" \
                   + "<br /><b>request</b> - accepts a link to a website (e.g. youtube, soundcloud, etc.) and adds that song to the playlist" \
                   + "<br /><b>lsplaylists</b> - shows all available playlists" \
                   + "<br /><b>load</b> - accepts a playlist number (shown by lsplaylists) to add to the current queue" \
                   + "<br /><b>queue</b> - shows the current queue" \
                   + "<br /><b>seek</b> - accepts a position number of a song in queue to seek to" \
                   + "<br /><b>.shut</b> - stops music and mutes bot" \
                   + "<br /><b>.open</b> - plays music and unmutes bot" \
                   + "<br /><b>save</b> - accepts a name to save the current queue as a playlist" \
                   + "<br /><b>shuffle</b> - shuffles the current queue"
        end
      end
    end

    @mpd.on :song do |current|
      if not current.nil? || @mpd.stopped?
        @cli.set_comment currentFormat(current)
      end
    end
  end

  def start
    @cli.connect
    @cli.on_connected do
      @cli.player.stream_named_pipe @mpd_fifopath
      @mpd.connect
    end

    begin
      t = Thread.new do
        $stdin.gets
      end
      t.join
    rescue Interrupt => e
    end
  end
end

client = MumbleMPD.new
client.start

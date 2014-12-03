#!/usr/bin/env ruby

# Forked from https://github.com/Natenom/mumble-ruby-related/raw/master/scripts/mumble-ruby-mpd-bot.rb (ty to him for creating the skeleton of this script <3)
# Added things such as requests, play, pause, volume, etc.

# Syntax
# ruby bot.rb mumbleserver_host mumbleserver_port mumbleserver_username mumbleserver_userpassword mumbleserver_targetchannel quality_bitrate mpd_fifopath mpd_path mpd_host mpd_port

require "mumble-ruby"
require 'rubygems'
require 'ruby-mpd'
require 'thread'

class MumbleMPD
  def log(msg)
    File.open('mumble.log', 'a') { |file| file.write(msg+"\n") }
  end
  def send(user, msg)
    log "#{@mumbleserver_username}: "+msg
    @cli.text_user user, msg
  end

  def initialize
    @sv_art
    @sv_alb
    @sv_tit

    @mpd_fifopath = ARGV[6].to_s
    @mpd_host = ARGV[7].to_s
    @mpd_port = ARGV[8].to_s

    @mpd = MPD.new @mpd_host, @mpd_port

    @mumbleserver_host = ARGV[0].to_s
    @mumbleserver_port = ARGV[1].to_s
    @mumbleserver_username = ARGV[2].to_s
    @mumbleserver_userpassword = ARGV[3].to_s
    @mumbleserver_targetchannel = ARGV[4].to_s
    @quality_bitrate = ARGV[5].to_i

    @cli = Mumble::Client.new(@mumbleserver_host, @mumbleserver_port) do |conf|
      conf.username = @mumbleserver_username
	  conf.password = @mumbleserver_userpassword
      conf.bitrate = @quality_bitrate
    end
    @cli.on_text_message do |msg|
      message = msg.message
      if @cli.users.has_key?(msg.actor)
	    log @cli.users[msg.actor].name + ": " + message
        case msg.message.to_s
        when /^current$/i
          current = @mpd.current_song
          if not current.nil?
            if current.artist.nil? && current.title.nil? && current.name.nil?
              send(@cli.users[msg.actor].name, "#{current.file}")
            elsif current.artist.nil? && current.title.nil?
              send(@cli.users[msg.actor].name, "#{current.name}")
            elsif current.artist.nil?
              send(@cli.users[msg.actor].name, "#{current.name}: #{current.title}")
            else
              send(@cli.users[msg.actor].name, "#{current.artist} - #{current.title}")
            end
          end
        when /^request <a href="(\S*)(.*)">/i
          matches = message.match(/^request <a href="(\S*)(.*)">/i)
          url = matches[1]
          output = %x[youtube-playlist-add.sh "#{url}"]
          if !output.empty?
            send(@cli.users[msg.actor].name, "Done.")
          end
          if output.empty?
            send(@cli.users[msg.actor].name, "Invalid link.")
          end
        when /^load (.*)/i
          playl = message.match(/^load (.*)/i)[1].to_i
          begin
            playlist = @mpd.playlists[playl]
            playlist.load
            send(@cli.users[msg.actor].name, "Loaded playlist: #{playlist.name}")
          rescue
            send(@cli.users[msg.actor].name, "That playlist does not exist.")
          end
        when /^save (.*)/i
          playname = message.match(/^save (.*)/i)
          @mpd.save("#{playname[1]}")
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
            send(@cli.users[msg.actor].name, "Shuffle didn't complete for some reason. Queue was most likely empty.")
          end
        when /^strobe$/i
          @mpd.clear
          @mpd.add "http://streamer.strobe.fm/"
          @mpd.play
        when /^volume/i
          if message.match(/^volume (\S*)(.*)/) != nil
            vol = message.match(/^volume (\S*)(.*)/)
            begin
              @mpd.volume=(vol[1])
            rescue
              send(@cli.users[msg.actor].name, "Invalid argument. Most likely out of range.")
            end
          end
          if message.match(/^volume (\S*)(.*)/) == nil
            volu = @mpd.volume
            send(@cli.users[msg.actor].name, "Current Volume: #{volu}")
          end
        when /^pause$/i
          @mpd.pause=(1)
        when /^stop$/i
          @mpd.stop
        when /^lsplaylists$/i
          text_out = "<br />"
          counter = 0
          @mpd.playlists.each do |playlist|
            text_out << "<tr><td><b>#{counter} - </b></td><td>#{playlist.name}</td></tr>"
            counter = counter + 1
          end	
          send(@cli.users[msg.actor].name, "<br /><b>I know the following playlists:</b><table border='0'>#{text_out}")
        when /^queue$/i
          text_out = "<br />"
          @mpd.queue.each do |song|
            if song.artist.nil? && song.title.nil? && song.name.nil?
              text_out << "<tr><td><b>#{song.pos} - </b></td><td>#{song.file}</td></tr>"
            elsif song.artist.nil? && song.title.nil?
              text_out << "<tr><td><b>#{song.pos} - </b></td><td>#{song.name}</td></tr>"
            elsif song.artist.nil?
              text_out << "<tr><td><b>#{song.pos} - </b></td><td>#{song.name}: #{song.title}</td></tr>"
            else
              text_out << "<tr><td><b>#{song.pos} - </b></td><td>#{song.artist} - #{song.title}</td></tr>"
            end
          end
          send(@cli.users[msg.actor].name, "<br /><b>Current Queue:</b><table border='0'>#{text_out}")
        when /^seek (.*)/i
          pos = message.match(/^seek (.*)/i)
          begin
            @mpd.play(pos[1])
          rescue
            send(@cli.users[msg.actor].name, "Cannot seek, most likely out of range.")
          end
        when /^.shut$/i
          @mpd.stop
          @cli.me.mute true
        when /^.open$/i
          @mpd.play
          @cli.me.mute false
        when /^help$/i
          send(@cli.users[msg.actor].name, "<br /><b>Commands List:</b><br />" \
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
                                         + "<br /><b>shuffle</b> - shuffles the current queue")
        end
      end
    end
  end
  def start
    @cli.connect
    sleep(1)
    @cli.player.stream_named_pipe(@mpd_fifopath)
    @mpd.connect

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

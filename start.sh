#!/usr/bin/env sh

mkfifo mpd.fifo
mpd mpd.conf
bundle exec ruby mumford.rb "$@"

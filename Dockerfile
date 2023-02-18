FROM ruby:2.6-alpine
LABEL org.opencontainers.image.source https://github.com/HuggableSquare/MUMfoRd

RUN bundle config --global frozen 1

# install mpd and other dependencies
RUN apk --no-cache add mpd libopusenc-dev ffmpeg build-base libffi-dev git curl

# download yt-dlp
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp

# idk why this is necessary but it is
RUN chown root /usr/bin/mpd

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENTRYPOINT ["/usr/src/app/start.sh"]

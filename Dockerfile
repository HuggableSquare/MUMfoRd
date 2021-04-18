FROM ruby:2.5-alpine
LABEL org.opencontainers.image.source https://github.com/HuggableSquare/MUMfoRd

RUN bundle config --global frozen 1

# install mpd, youtube-dl, and other dependencies
RUN apk --no-cache add mpd libopusenc-dev python3 py3-pip ffmpeg build-base libffi-dev git
RUN pip3 install youtube-dl

# idk why this is necessary but it is
RUN chown root /usr/bin/mpd

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENTRYPOINT ["/usr/src/app/start.sh"]
